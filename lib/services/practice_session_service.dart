import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import '../models/octave_exercise.dart';
import '../dsp/dsp_engine.dart';
import '../services/audio_service.dart';
import 'note_debug_logger.dart';

export 'note_debug_logger.dart' show NoteDebugLogger, NoteLogEntry;

enum SessionState { idle, running, resting, complete }

class LapResult {
  final int setNumber;
  final int lapNumber;
  final double accuracy;
  final int notesHit;
  final int totalNotes;

  LapResult({
    required this.setNumber,
    required this.lapNumber,
    required this.accuracy,
    required this.notesHit,
    required this.totalNotes,
  });
}

class PracticeSessionService {
  late int _bpm;
  late int _totalSets;
  late int _totalLaps;
  late int _restSeconds;
  late OctaveExercise _selectedExercise;

  SessionState _state = SessionState.idle;
  int _currentSet = 1;
  int _currentLap = 1;
  int _lapNotesHit = 0;
  int _lapNotesTotal = 0;
  int _beatCounter = 0;

  final List<LapResult> _lapResultsList = [];
  TraversalSequence? _sequence;

  Timer? _metronomeTimer;
  Timer? _restTimer;
  DSPResult? _latestDspResult;

  /// ± cents window accepted as "in tune". 50 ¢ = half a semitone.
  static const double _centsTolerance = 50.0;
  static const double _ln2 = 0.693147180559945;

  static const Map<String, double> _baseFreqs = {
    'C': 261.63, 'C#': 277.18, 'D': 293.66, 'D#': 311.13,
    'E': 329.63, 'F': 349.23, 'F#': 369.99, 'G': 392.00,
    'G#': 415.30, 'A': 440.00, 'A#': 466.16, 'B': 493.88,
  };

  // ── Debug logger (always created; caller can disable it) ─────────────────
  final NoteDebugLogger debugLogger;

  // ── Callbacks ─────────────────────────────────────────────────────────────
  final void Function(OctaveExercise) onExerciseChanged;
  final void Function(int lap, int totalLaps, int set, int totalSets)
      onProgressChanged;
  final void Function(int notesHit, int notesTotal, double accuracy)
      onLapScoreChanged;
  final void Function(int secondsRemaining) onRestTick;
  final void Function(bool success, ScaleNote expectedNote, double detectedFreq)
      onNoteResult;
  final void Function(double accuracy) onSessionComplete;
  final void Function(ScaleNote note, bool playGuide) onMetronomeTick;

  bool _guideAudioEnabled = false;

  PracticeSessionService({
    required this.onExerciseChanged,
    required this.onProgressChanged,
    required this.onLapScoreChanged,
    required this.onRestTick,
    required this.onNoteResult,
    required this.onSessionComplete,
    required this.onMetronomeTick,
    bool debugLogging = true,
  }) : debugLogger = NoteDebugLogger(enabled: debugLogging);

  // ── Public getters ────────────────────────────────────────────────────────
  SessionState get state => _state;
  List<LapResult> get lapResults => List.unmodifiable(_lapResultsList);
  ScaleNote? get currentNote => _sequence?.current;
  OctaveExercise? get baseExercise =>
      _state != SessionState.idle ? _selectedExercise : null;
  TraversalSequence? get sequence => _sequence;

  // ── Session control ───────────────────────────────────────────────────────
  void startSession({
    required OctaveExercise exercise,
    required int bpm,
    required int sets,
    required int laps,
    required int restDurationSeconds,
    bool guideAudioEnabled = false,
  }) {
    _selectedExercise = exercise;
    _bpm = bpm;
    _totalSets = sets;
    _totalLaps = laps;
    _restSeconds = restDurationSeconds;
    _guideAudioEnabled = guideAudioEnabled;
    _state = SessionState.running;
    _currentSet = 1;
    _currentLap = 1;
    _lapNotesHit = 0;
    _lapNotesTotal = 0;
    _beatCounter = 0;
    _lapResultsList.clear();
    debugLogger.clear();

    _sequence = exercise.generateDiatonicMajorScale();
    onExerciseChanged(exercise);
    onProgressChanged(_currentLap, _totalLaps, _currentSet, _totalSets);
    _startMetronome();
  }

  void processDSPResult(DSPResult result) {
    if (_state == SessionState.running) _latestDspResult = result;
  }

  void stop() {
    _state = SessionState.idle;
    _metronomeTimer?.cancel();
    _restTimer?.cancel();
    _latestDspResult = null;
    // Print summary to console whenever the session is stopped.
    debugPrint(debugLogger.summary());
  }

  void dispose() => stop();

  // ── Metronome ─────────────────────────────────────────────────────────────
  void _startMetronome() {
    _metronomeTimer?.cancel();
    final intervalMs = (60000 / _bpm).round();
    if (_sequence != null) {
      onMetronomeTick(_sequence!.current, _guideAudioEnabled);
    }
    _metronomeTimer =
        Timer.periodic(Duration(milliseconds: intervalMs), (_) {
      if (_state == SessionState.running) _processBeat();
    });
  }

  void _processBeat() {
    if (_sequence == null) return;

    final expectedNote = _sequence!.current;
    final isHigh = _sequence!.isHighOctave;
    final targetNoteStr = expectedNote.noteWithOctave(highOctave: isHigh);
    final expectedHz = _noteToFrequency(targetNoteStr);

    double detectedHz = 0;
    bool hit = false;

    if (_latestDspResult != null) {
      detectedHz = _latestDspResult!.fundamentalFreq;
      if (detectedHz > 0 && expectedHz > 0) {
        final centsDiff =
            1200.0 * (log(detectedHz / expectedHz) / _ln2);
        if (centsDiff.abs() <= _centsTolerance) hit = true;
      }
    }

    if (hit) _lapNotesHit++;
    _lapNotesTotal++;
    _beatCounter++;

    // ── Log this beat ──────────────────────────────────────────────────────
    debugLogger.log(
      set: _currentSet,
      lap: _currentLap,
      beat: _beatCounter,
      expectedNote: targetNoteStr,
      expectedHz: expectedHz,
      detectedHz: detectedHz,
      wasHit: hit,
    );

    onNoteResult(hit, expectedNote, detectedHz);
    onLapScoreChanged(
        _lapNotesHit, _lapNotesTotal, _lapNotesHit / _lapNotesTotal * 100);

    final lapDone = _sequence!.advanceNote();
    if (lapDone) {
      _completeLap();
    } else {
      onMetronomeTick(_sequence!.current, _guideAudioEnabled);
    }

    _latestDspResult = null;
  }

  void _completeLap() {
    _metronomeTimer?.cancel();
    final lapAcc = _lapNotesTotal == 0
        ? 0.0
        : _lapNotesHit / _lapNotesTotal * 100;

    _lapResultsList.add(LapResult(
      setNumber: _currentSet,
      lapNumber: _currentLap,
      accuracy: lapAcc,
      notesHit: _lapNotesHit,
      totalNotes: _lapNotesTotal,
    ));

    if (_currentLap < _totalLaps) {
      _currentLap++;
      _lapNotesHit = 0;
      _lapNotesTotal = 0;
      _sequence!.reset();
      onProgressChanged(_currentLap, _totalLaps, _currentSet, _totalSets);
      _startMetronome();
    } else if (_currentSet < _totalSets) {
      _state = SessionState.resting;
      _currentSet++;
      _currentLap = 1;
      _lapNotesHit = 0;
      _lapNotesTotal = 0;
      _sequence!.reset();
      _startRestCountdown();
    } else {
      _state = SessionState.complete;
      final avg = _lapResultsList.isEmpty
          ? 0.0
          : _lapResultsList.fold<double>(0, (s, l) => s + l.accuracy) /
              _lapResultsList.length;
      // Print summary before notifying UI.
      debugPrint(debugLogger.summary());
      onSessionComplete(avg);
    }
  }

  void _startRestCountdown() {
    int left = _restSeconds;
    onRestTick(left);
    _restTimer?.cancel();
    _restTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      left--;
      if (left <= 0) {
        t.cancel();
        _state = SessionState.running;
        onProgressChanged(_currentLap, _totalLaps, _currentSet, _totalSets);
        _startMetronome();
      } else {
        onRestTick(left);
      }
    });
  }

  // ── Frequency helpers ─────────────────────────────────────────────────────

  static double _noteToFrequency(String noteStr) {
    final match =
        RegExp(r'^([A-G]#?)(-?\d+)$').firstMatch(noteStr.trim());
    if (match == null) return 0;
    final name = match.group(1)!;
    final octave = int.tryParse(match.group(2)!);
    if (octave == null) return 0;
    final base = _baseFreqs[name];
    if (base == null) return 0;
    return base * pow(2.0, (octave - 4).toDouble());
  }

  static String frequencyToNoteName(double freq) {
    if (freq <= 0) return '—';
    const a4 = 440.0;
    const a4Midi = 69;
    const noteNames = [
      'C', 'C#', 'D', 'D#', 'E', 'F',
      'F#', 'G', 'G#', 'A', 'A#', 'B'
    ];
    final semitones = 12.0 * (log(freq / a4) / _ln2);
    final midi = (a4Midi + semitones).round();
    final noteIndex = ((midi % 12) + 12) % 12;
    final octave = (midi ~/ 12) - 1;
    return '${noteNames[noteIndex]}$octave';
  }
}