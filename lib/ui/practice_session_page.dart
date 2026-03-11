import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../services/practice_session_service.dart';
import '../models/octave_exercise.dart';
import '../dsp/dsp_engine.dart';
import 'fretboard_widget.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Session Summary Page
// ─────────────────────────────────────────────────────────────────────────────

class SessionSummaryPage extends StatelessWidget {
  final double accuracy;
  final List<LapResult> lapResults;
  final VoidCallback onRetry;
  final VoidCallback onExit;

  const SessionSummaryPage({
    super.key,
    required this.accuracy,
    required this.lapResults,
    required this.onRetry,
    required this.onExit,
  });

  Color _color(double acc) {
    if (acc >= 80) return Colors.greenAccent;
    if (acc >= 50) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session Complete')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.emoji_events, size: 80, color: Colors.amber),
            const SizedBox(height: 16),
            const Text('Session Complete!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Text('${accuracy.toStringAsFixed(1)}%',
                style: TextStyle(
                    fontSize: 56,
                    fontWeight: FontWeight.bold,
                    color: _color(accuracy))),
            const Text('Overall Accuracy',
                style: TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 32),
            const Align(
              alignment: Alignment.centerLeft,
              child: Text('Lap Results',
                  style:
                      TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ),
            const SizedBox(height: 8),
            ...lapResults.map((lap) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Set ${lap.setNumber} · Lap ${lap.lapNumber}',
                          style: const TextStyle(fontSize: 14)),
                      Text(
                        '${lap.accuracy.toStringAsFixed(1)}%  '
                        '(${lap.notesHit}/${lap.totalNotes})',
                        style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _color(lap.accuracy)),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Practice Again')),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                    onPressed: onExit,
                    icon: const Icon(Icons.exit_to_app),
                    label: const Text('Exit')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Practice Session Page
// ─────────────────────────────────────────────────────────────────────────────

enum _PagePhase { config, countdown, running }

class PracticeSessionPage extends StatefulWidget {
  final ExerciseMode mode;
  final OctaveExercise? selectedExercise;

  const PracticeSessionPage({
    super.key,
    required this.mode,
    this.selectedExercise,
  });

  @override
  State<PracticeSessionPage> createState() => _PracticeSessionPageState();
}

class _PracticeSessionPageState extends State<PracticeSessionPage>
    with SingleTickerProviderStateMixin {

  // ── Services ──────────────────────────────────────────────────────────────
  final AudioService _audioService = AudioService();
  late final PracticeSessionService _practiceService;

  // ── Available note names for scale picker ─────────────────────────────────
  static const List<String> _allNotes = [
    'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B', 'C', 'C#', 'D', 'D#',
  ];

  // ── Config ────────────────────────────────────────────────────────────────
  int _bpm = 60;
  int _sets = 2;
  int _laps = 4;
  int _restSeconds = 5;
  String _selectedScale = 'E';
  StringPair _selectedStringPair = StringPair.eAndD;
  late OctaveExercise _exercise;

  // ── Page phase ────────────────────────────────────────────────────────────
  _PagePhase _phase = _PagePhase.config;

  // ── Countdown ─────────────────────────────────────────────────────────────
  int _countdownBeatsLeft = 4;
  Timer? _countdownTimer;

  // ── Session UI state ──────────────────────────────────────────────────────
  int _currentLap = 1;
  int _currentSet = 1;
  int _lapNotesHit = 0;
  int _lapNotesTotal = 0;
  int _restCountdown = 0;
  SessionState _sessionState = SessionState.idle;

  bool _lastNoteWasHit = false;
  double _lastDetectedFreq = 0;
  String _lastDetectedNote = '—';
  String _lastExpectedNote = '—';

  // ── Debug panel ───────────────────────────────────────────────────────────
  bool _debugExpanded = false;
  // Snapshot of the last N log entries displayed in the panel.
  List<NoteLogEntry> _recentEntries = [];
  static const int _maxDisplayEntries = 12;

  // ── Pulse animation ───────────────────────────────────────────────────────
  late final AnimationController _pulseController;
  late final Animation<Color?> _pulseAnimation;

  // ── Cached navigator ──────────────────────────────────────────────────────
  NavigatorState? _navigator;

  // ─────────────────────────────────────────────────────────────────────────

  OctaveExercise _pickExercise(String scale, StringPair pair) {
    final all = StandardOctaves.getAll();
    final match =
        all.where((e) => e.noteName == scale && e.stringPair == pair);
    if (match.isNotEmpty) return match.first;
    final scaleOnly = all.where((e) => e.noteName == scale);
    if (scaleOnly.isNotEmpty) return scaleOnly.first;
    return all.first;
  }

  @override
  void initState() {
    super.initState();
    _exercise = widget.selectedExercise ??
        _pickExercise(_selectedScale, _selectedStringPair);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    )..addStatusListener((s) {
        if (s == AnimationStatus.completed) _pulseController.reverse();
      });

    _pulseAnimation = ColorTween(
      begin: Colors.grey[850],
      end: Colors.green[400],
    ).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeOut));

    _practiceService = PracticeSessionService(
      onExerciseChanged: _onExerciseChanged,
      onProgressChanged: _onProgressChanged,
      onLapScoreChanged: _onLapScoreChanged,
      onRestTick: _onRestTick,
      onNoteResult: _onNoteResult,
      onSessionComplete: _onSessionComplete,
      onMetronomeTick: _onMetronomeTick,
      debugLogging: true, // ← flip to false to silence console output
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _navigator = Navigator.of(context);
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    _audioService.dispose();
    _practiceService.dispose();
    super.dispose();
  }

  // ── Session flow ──────────────────────────────────────────────────────────

  Future<void> _beginSession() async {
    _audioService.resetDSP();
    _audioService.setTargetOctave(_exercise.targetLow, _exercise.targetHigh);

    final micOk = await _audioService.startWithDSP(_onDSPResult);
    if (!mounted) return;

    if (!micOk) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not access microphone.')),
      );
      return;
    }

    setState(() {
      _phase = _PagePhase.countdown;
      _countdownBeatsLeft = 4;
      _lastDetectedNote = '—';
      _lastExpectedNote = '—';
      _lastDetectedFreq = 0;
      _recentEntries = [];
    });

    _runCountdown();
  }

  void _runCountdown() {
    final beatMs = (60000 / _bpm).round();
    _tickCountdown();
    _countdownTimer =
        Timer.periodic(Duration(milliseconds: beatMs), (t) {
      if (_countdownBeatsLeft <= 0) {
        t.cancel();
        _launchSession();
      } else {
        _tickCountdown();
      }
    });
  }

  void _tickCountdown() {
    HapticFeedback.mediumImpact();
    if (mounted) setState(() => _countdownBeatsLeft--);
  }

  void _launchSession() {
    if (!mounted) return;
    setState(() {
      _phase = _PagePhase.running;
      _sessionState = SessionState.running;
    });
    _practiceService.startSession(
      exercise: _exercise,
      bpm: _bpm,
      sets: _sets,
      laps: _laps,
      restDurationSeconds: _restSeconds,
    );
  }

  Future<void> _stopSession() async {
    _countdownTimer?.cancel();
    _practiceService.stop();
    await _audioService.stop();
    if (mounted) {
      setState(() {
        _phase = _PagePhase.config;
        _sessionState = SessionState.idle;
        _lapNotesHit = 0;
        _lapNotesTotal = 0;
        _lastDetectedNote = '—';
        _lastExpectedNote = '—';
      });
    }
  }

  // ── Service callbacks ─────────────────────────────────────────────────────

  void _onExerciseChanged(OctaveExercise exercise) {
    _audioService.setTargetOctave(exercise.targetLow, exercise.targetHigh);
  }

  void _onProgressChanged(int lap, int totalLaps, int set, int totalSets) {
    if (!mounted) return;
    setState(() {
      _currentLap = lap;
      _currentSet = set;
      _lapNotesHit = 0;
      _lapNotesTotal = 0;
      _sessionState = SessionState.running;
    });
  }

  void _onLapScoreChanged(int hit, int total, double accuracy) {
    if (!mounted) return;
    setState(() {
      _lapNotesHit = hit;
      _lapNotesTotal = total;
    });
  }

  void _onRestTick(int secondsLeft) {
    if (!mounted) return;
    setState(() {
      _restCountdown = secondsLeft;
      _sessionState = SessionState.resting;
    });
  }

  void _onNoteResult(
      bool success, ScaleNote expectedNote, double detectedFreq) {
    if (!mounted) return;
    final isHigh = _practiceService.sequence?.isHighOctave ?? false;

    // Refresh the debug entry list from the logger.
    final allEntries = _practiceService.debugLogger.entries;
    final recent = allEntries.length <= _maxDisplayEntries
        ? allEntries.toList()
        : allEntries
            .sublist(allEntries.length - _maxDisplayEntries)
            .toList();

    setState(() {
      _lastNoteWasHit = success;
      _lastDetectedFreq = detectedFreq;
      _lastDetectedNote = detectedFreq > 0
          ? PracticeSessionService.frequencyToNoteName(detectedFreq)
          : '—';
      _lastExpectedNote = expectedNote.noteWithOctave(highOctave: isHigh);
      _recentEntries = recent;
    });

    if (success) {
      HapticFeedback.lightImpact();
      _pulseController.forward(from: 0);
    }
  }

  void _onMetronomeTick(ScaleNote note, bool playGuide) {}

  void _onSessionComplete(double accuracy) {
    _audioService.stop();
    _practiceService.stop();
    final nav = _navigator;
    if (nav == null) return;
    final results = List<LapResult>.from(_practiceService.lapResults);
    final exercise = _exercise;
    final mode = widget.mode;
    nav.pushReplacement(
      MaterialPageRoute(
        builder: (_) => SessionSummaryPage(
          accuracy: accuracy,
          lapResults: results,
          onRetry: () => nav.pushReplacement(
            MaterialPageRoute(
              builder: (_) => PracticeSessionPage(
                  mode: mode, selectedExercise: exercise),
            ),
          ),
          onExit: nav.pop,
        ),
      ),
    );
  }

  // ── DSP callback ──────────────────────────────────────────────────────────

  void _onDSPResult(DSPResult result) {
    if (mounted && result.fundamentalFreq > 0) {
      setState(() {
        _lastDetectedFreq = result.fundamentalFreq;
        _lastDetectedNote = PracticeSessionService.frequencyToNoteName(
            result.fundamentalFreq);
      });
    }
    if (_practiceService.state == SessionState.running) {
      _practiceService.processDSPResult(result);
    }
  }

  // ── Customise sheet ───────────────────────────────────────────────────────

  void _showCustomiseSheet() {
    int bpm = _bpm, sets = _sets, laps = _laps, rest = _restSeconds;
    String scale = _selectedScale;
    StringPair pair = _selectedStringPair;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.grey[900],
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) {
          Widget sliderRow(String label, int value, int min, int max,
              int step, ValueChanged<int> onChange) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(children: [
                SizedBox(
                    width: 76,
                    child: Text(label,
                        style: const TextStyle(
                            fontSize: 13, color: Colors.white70))),
                Expanded(
                  child: Slider(
                    value: value.toDouble(),
                    min: min.toDouble(),
                    max: max.toDouble(),
                    divisions: (max - min) ~/ step,
                    label: value.toString(),
                    onChanged: (v) =>
                        setSheet(() => onChange(v.toInt())),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text(value.toString(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                ),
              ]),
            );
          }

          Widget pairChip(StringPair v, String label) {
            final sel = v == pair;
            return ChoiceChip(
              label: Text(label),
              selected: sel,
              onSelected: (_) => setSheet(() => pair = v),
              selectedColor: Colors.blue[700],
              backgroundColor: Colors.grey[800],
              labelStyle: TextStyle(
                color: sel ? Colors.white : Colors.white70,
                fontWeight:
                    sel ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Customise Session',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white)),
                  const SizedBox(height: 20),

                  // Scale chips
                  const Text('Scale',
                      style: TextStyle(
                          fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: _allNotes.map((note) {
                      final sel = note == scale;
                      return ChoiceChip(
                        label: Text(note),
                        selected: sel,
                        onSelected: (_) =>
                            setSheet(() => scale = note),
                        selectedColor: Colors.green[700],
                        backgroundColor: Colors.grey[800],
                        labelStyle: TextStyle(
                          color: sel ? Colors.white : Colors.white70,
                          fontWeight: sel
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),

                  // String pair chips
                  const Text('String pair',
                      style: TextStyle(
                          fontSize: 13, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 6, children: [
                    pairChip(StringPair.eAndD, 'Low E & D'),
                    pairChip(StringPair.aAndG, 'A & G'),
                    pairChip(StringPair.dAndB, 'D & B'),
                    pairChip(StringPair.gAndHighE, 'G & High E'),
                  ]),
                  const SizedBox(height: 20),

                  // Sliders
                  sliderRow(
                      'BPM', bpm, 30, 360, 10, (v) => bpm = v),
                  sliderRow(
                      'Sets', sets, 1, 5, 1, (v) => sets = v),
                  sliderRow(
                      'Laps', laps, 1, 10, 1, (v) => laps = v),
                  sliderRow(
                      'Rest (s)', rest, 0, 15, 1, (v) => rest = v),
                  const SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      setState(() {
                        _bpm = bpm;
                        _sets = sets;
                        _laps = laps;
                        _restSeconds = rest;
                        _selectedScale = scale;
                        _selectedStringPair = pair;
                        _exercise = _pickExercise(scale, pair);
                      });
                    },
                    style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    child: const Text('Apply'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Octave Practice'),
        actions: _phase == _PagePhase.running
            ? [
                // Toggle debug panel
                IconButton(
                  icon: Icon(_debugExpanded
                      ? Icons.bug_report
                      : Icons.bug_report_outlined),
                  tooltip: 'Debug log',
                  onPressed: () =>
                      setState(() => _debugExpanded = !_debugExpanded),
                ),
                IconButton(
                  icon: const Icon(Icons.stop_circle_outlined),
                  tooltip: 'Stop',
                  onPressed: _stopSession,
                ),
              ]
            : null,
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: switch (_phase) {
          _PagePhase.config    => _buildConfigView(),
          _PagePhase.countdown => _buildCountdownView(),
          _PagePhase.running   => _buildRunningView(),
        },
      ),
    );
  }

  // ── Config view ───────────────────────────────────────────────────────────

  Widget _buildConfigView() {
    return SingleChildScrollView(
      key: const ValueKey('config'),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_exercise.noteName,
              style: const TextStyle(
                  fontSize: 28, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          Text(_exercise.description,
              style:
                  const TextStyle(fontSize: 14, color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 24),
          FretboardWidget(currentExercise: _exercise),
          const SizedBox(height: 28),
          Card(
            color: Colors.grey[850],
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Session Details',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Colors.white70)),
                  const SizedBox(height: 14),
                  _detailRow(Icons.music_note, 'Scale',
                      '$_selectedScale major'),
                  _detailRow(Icons.cable, 'Strings',
                      _exercise.description),
                  _detailRow(Icons.speed, 'BPM', '$_bpm'),
                  _detailRow(Icons.layers, 'Sets', '$_sets'),
                  _detailRow(
                      Icons.repeat, 'Laps per set', '$_laps'),
                  _detailRow(Icons.timer_outlined,
                      'Rest between sets', '${_restSeconds}s'),
                  const Divider(height: 24, color: Colors.white12),
                  OutlinedButton.icon(
                    onPressed: _showCustomiseSheet,
                    icon: const Icon(Icons.tune, size: 17),
                    label: const Text('Customise Session'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white60,
                      side: const BorderSide(
                          color: Colors.white24),
                      minimumSize: const Size.fromHeight(44),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _beginSession,
            icon: const Icon(Icons.play_arrow_rounded, size: 26),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Start Session',
                  style: TextStyle(fontSize: 17)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green[700],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [
          Icon(icon, size: 17, color: Colors.white38),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14, color: Colors.white60))),
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white)),
        ]),
      );

  // ── Countdown view ────────────────────────────────────────────────────────

  Widget _buildCountdownView() {
    final beatsLeft = _countdownBeatsLeft.clamp(0, 4);
    return Center(
      key: const ValueKey('countdown'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('Get ready…',
              style:
                  TextStyle(fontSize: 22, color: Colors.white70)),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (i) {
              final lit = i < (4 - beatsLeft);
              return AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                margin:
                    const EdgeInsets.symmetric(horizontal: 8),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      lit ? Colors.greenAccent : Colors.white24,
                ),
              );
            }),
          ),
          const SizedBox(height: 36),
          Text(
            beatsLeft > 0 ? '$beatsLeft' : 'Go!',
            style: const TextStyle(
                fontSize: 80,
                fontWeight: FontWeight.bold,
                color: Colors.white),
          ),
        ],
      ),
    );
  }

  // ── Running view ──────────────────────────────────────────────────────────

  Widget _buildRunningView() {
    final currentNote = _practiceService.currentNote;
    final baseExercise = _practiceService.baseExercise;
    final isHighOctave =
        _practiceService.sequence?.isHighOctave ?? false;

    if (currentNote == null || baseExercise == null) {
      return const Center(
          key: ValueKey('loading'),
          child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      key: const ValueKey('running'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Progress header
          Text(
            _sessionState == SessionState.resting
                ? 'Rest – next set in ${_restCountdown}s'
                : 'Set $_currentSet/$_sets · Lap $_currentLap/$_laps',
            style: const TextStyle(
                fontSize: 15, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text('Notes hit: $_lapNotesHit / $_lapNotesTotal',
              style: const TextStyle(
                  fontSize: 13, color: Colors.grey),
              textAlign: TextAlign.center),
          const SizedBox(height: 16),

          if (_sessionState == SessionState.resting)
            _buildRestCard()
          else
            _buildNoteDisplay(currentNote, isHighOctave),

          const SizedBox(height: 14),
          _buildDetectionPanel(),
          const SizedBox(height: 14),

          // ── Debug log panel (shown when toggled) ─────────────────────────
          if (_debugExpanded) _buildDebugPanel(),
          if (_debugExpanded) const SizedBox(height: 14),

          SizedBox(
              height: 140,
              child: FretboardWidget(currentExercise: baseExercise)),
        ],
      ),
    );
  }

  // ── Detection panel ───────────────────────────────────────────────────────

  Widget _buildDetectionPanel() {
    final heard = _lastDetectedFreq > 0;
    final correct = _lastNoteWasHit && heard;
    final wrong = !_lastNoteWasHit && heard && _lapNotesTotal > 0;

    Color border = Colors.white12;
    if (correct) border = Colors.greenAccent;
    if (wrong) border = Colors.redAccent;

    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _detCell('Expected', _lastExpectedNote, Colors.white70),
          Container(width: 1, height: 32, color: Colors.white12),
          _detCell(
              'Detected',
              _lastDetectedNote,
              correct
                  ? Colors.greenAccent
                  : wrong
                      ? Colors.redAccent
                      : Colors.white54),
          Container(width: 1, height: 32, color: Colors.white12),
          _detCell(
              'Hz',
              heard
                  ? _lastDetectedFreq.toStringAsFixed(1)
                  : '—',
              Colors.white38),
        ],
      ),
    );
  }

  Widget _detCell(String label, String value, Color valueColor) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Colors.white38)),
          const SizedBox(height: 2),
          Text(value,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: valueColor)),
        ],
      );

  // ── Debug panel ───────────────────────────────────────────────────────────

  Widget _buildDebugPanel() {
    final logger = _practiceService.debugLogger;
    final octaveErrors = logger.octaveErrors.length;
    final wrongNotes = logger.wrongNoteErrors.length;
    final silent = logger.silentBeats.length;
    final total = logger.entries.length;

    return Container(
      decoration: BoxDecoration(
        color: Colors.black87,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header row
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 8, 6),
            child: Row(
              children: [
                const Icon(Icons.bug_report,
                    size: 16, color: Colors.amber),
                const SizedBox(width: 6),
                const Text('Debug Log',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber)),
                const Spacer(),
                // Stats chips
                _statChip('OCT $octaveErrors', Colors.orange),
                const SizedBox(width: 4),
                _statChip('WRONG $wrongNotes', Colors.red),
                const SizedBox(width: 4),
                _statChip('SIL $silent', Colors.grey),
                const SizedBox(width: 8),
                // Export button
                GestureDetector(
                  onTap: () async {
                    final path =
                        await logger.exportTsv();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(path != null
                              ? 'Saved: $path'
                              : 'Export failed'),
                          duration:
                              const Duration(seconds: 3),
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: Colors.amber.withOpacity(0.4)),
                    ),
                    child: const Text('Export TSV',
                        style: TextStyle(
                            fontSize: 11, color: Colors.amber)),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Colors.white10),

          // Last N entries
          if (_recentEntries.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('No beats recorded yet.',
                  style: TextStyle(
                      fontSize: 12, color: Colors.white38)),
            )
          else
            ...(_recentEntries.reversed.take(_maxDisplayEntries))
                .map((e) => _debugEntryRow(e)),

          if (total > _maxDisplayEntries)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Text(
                '… and ${total - _maxDisplayEntries} earlier beats',
                style: const TextStyle(
                    fontSize: 11, color: Colors.white30),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statChip(String label, Color color) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(label,
            style: TextStyle(fontSize: 10, color: color)),
      );

  Widget _debugEntryRow(NoteLogEntry e) {
    final isOctaveErr = () {
      if (e.detectedNote == '—') return false;
      final ec = e.expectedNote.replaceAll(RegExp(r'\d'), '');
      final dc = e.detectedNote.replaceAll(RegExp(r'\d'), '');
      return ec == dc && e.expectedNote != e.detectedNote;
    }();

    Color rowColor = Colors.transparent;
    if (e.wasHit) rowColor = Colors.green.withOpacity(0.06);
    if (isOctaveErr) rowColor = Colors.orange.withOpacity(0.10);
    if (!e.wasHit && !isOctaveErr && e.detectedNote != '—')
      rowColor = Colors.red.withOpacity(0.06);

    final centsStr = e.centsOff == 0
        ? '0 ¢'
        : '${e.centsOff > 0 ? '+' : ''}${e.centsOff.toStringAsFixed(0)} ¢';

    return Container(
      color: rowColor,
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Row(children: [
        // Beat number
        SizedBox(
          width: 28,
          child: Text('B${e.beatNumber}',
              style: const TextStyle(
                  fontSize: 11, color: Colors.white30)),
        ),
        // Hit/miss icon
        Icon(
          e.wasHit ? Icons.check_circle : Icons.cancel,
          size: 14,
          color: e.wasHit ? Colors.greenAccent : Colors.redAccent,
        ),
        const SizedBox(width: 8),
        // Expected
        SizedBox(
          width: 32,
          child: Text(e.expectedNote,
              style: const TextStyle(
                  fontSize: 12, color: Colors.white70)),
        ),
        const Icon(Icons.arrow_forward,
            size: 12, color: Colors.white24),
        const SizedBox(width: 4),
        // Detected
        SizedBox(
          width: 36,
          child: Text(
            e.detectedNote,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: e.wasHit
                  ? Colors.greenAccent
                  : isOctaveErr
                      ? Colors.orange
                      : Colors.redAccent,
            ),
          ),
        ),
        // Cents
        Expanded(
          child: Text(
            e.detectedNote == '—' ? 'silence' : centsStr,
            style: TextStyle(
                fontSize: 11,
                color: e.detectedNote == '—'
                    ? Colors.white24
                    : Colors.white38),
            textAlign: TextAlign.right,
          ),
        ),
      ]),
    );
  }

  // ── Rest card ─────────────────────────────────────────────────────────────

  Widget _buildRestCard() => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.blue, width: 1.5),
        ),
        child: Column(children: [
          const Text('Rest',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('$_restCountdown s',
              style: const TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue)),
        ]),
      );

  // ── Note display ──────────────────────────────────────────────────────────

  Widget _buildNoteDisplay(ScaleNote note, bool isHighOctave) =>
      AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (_, child) => Container(
          padding: const EdgeInsets.symmetric(
              vertical: 24, horizontal: 20),
          decoration: BoxDecoration(
            color: _pulseAnimation.value,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: Colors.blueGrey, width: 1.5),
          ),
          child: child,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _noteCard(note.targetLow,
                isActive: !isHighOctave,
                wasHit: _lastNoteWasHit && !isHighOctave),
            const Text('&',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white38)),
            _noteCard(note.targetHigh,
                isActive: isHighOctave,
                wasHit: _lastNoteWasHit && isHighOctave),
          ],
        ),
      );

  Widget _noteCard(String label,
      {required bool isActive, required bool wasHit}) {
    Color color = isActive ? Colors.white : Colors.white24;
    if (isActive && _lapNotesTotal > 0) {
      color = wasHit ? Colors.greenAccent : Colors.redAccent;
    }
    return Column(children: [
      Text(label,
          style: TextStyle(
              fontSize: 44,
              fontWeight: FontWeight.bold,
              color: color)),
      const SizedBox(height: 4),
      Icon(
        wasHit
            ? Icons.check_circle
            : isActive
                ? Icons.radio_button_unchecked
                : Icons.circle,
        color: wasHit
            ? Colors.greenAccent
            : isActive
                ? Colors.white38
                : Colors.white12,
        size: 20,
      ),
    ]);
  }
}