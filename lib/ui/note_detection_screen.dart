import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../dsp/dsp_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data
// ─────────────────────────────────────────────────────────────────────────────

class _DetectionEvent {
  final DateTime time;
  final double hz;
  final String note;   // e.g. "E2"
  final String pitch;  // e.g. "E"
  final int octave;
  final double centsOff; // deviation from nearest semitone

  _DetectionEvent({
    required this.time,
    required this.hz,
    required this.note,
    required this.pitch,
    required this.octave,
    required this.centsOff,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Note Detection Screen
// ─────────────────────────────────────────────────────────────────────────────

class NoteDetectionScreen extends StatefulWidget {
  const NoteDetectionScreen({super.key});

  @override
  State<NoteDetectionScreen> createState() => _NoteDetectionScreenState();
}

class _NoteDetectionScreenState extends State<NoteDetectionScreen>
    with TickerProviderStateMixin {

  final AudioService _audioService = AudioService();
  bool _isListening = false;

  // Current frame data
  double _currentHz = 0;
  String _currentNote = '—';
  String _currentPitch = '—';
  int _currentOctave = 0;
  double _currentCents = 0;
  double _rms = 0;

  // History — last 30 distinct detected notes
  final List<_DetectionEvent> _history = [];
  static const int _maxHistory = 30;

  // Octave confusion tracker: maps "expected→detected" pair counts
  // We track this as how often the same pitch class appeared at diff octaves
  final Map<String, int> _octaveConfusionMap = {};

  // Silence tracking
  int _silentFrames = 0;
  int _totalFrames = 0;

  // Animations
  late final AnimationController _pulseController;
  late final AnimationController _meterController;

  // Note colours by pitch class (like a piano roll)
  static const Map<String, Color> _noteColors = {
    'C':  Color(0xFFEF5350),
    'C#': Color(0xFFEC407A),
    'D':  Color(0xFFAB47BC),
    'D#': Color(0xFF7E57C2),
    'E':  Color(0xFF42A5F5),
    'F':  Color(0xFF26C6DA),
    'F#': Color(0xFF26A69A),
    'G':  Color(0xFF66BB6A),
    'G#': Color(0xFFD4E157),
    'A':  Color(0xFFFFCA28),
    'A#': Color(0xFFFFA726),
    'B':  Color(0xFFFF7043),
  };

  static const double _ln2 = 0.693147180559945;
  static const double _a4 = 440.0;
  static const int _a4Midi = 69;
  static const List<String> _noteNames = [
    'C', 'C#', 'D', 'D#', 'E', 'F',
    'F#', 'G', 'G#', 'A', 'A#', 'B',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _meterController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
  }

  @override
  void dispose() {
    _audioService.dispose();
    _pulseController.dispose();
    _meterController.dispose();
    super.dispose();
  }

  // ── Audio ─────────────────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _audioService.stop();
      setState(() => _isListening = false);
      return;
    }

    _audioService.resetDSP();
    final ok = await _audioService.startWithDSP(_onDSPResult);
    if (!mounted) return;

    if (ok) {
      setState(() {
        _isListening = true;
        _history.clear();
        _octaveConfusionMap.clear();
        _silentFrames = 0;
        _totalFrames = 0;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not access microphone')),
      );
    }
  }

  void _onDSPResult(DSPResult result) {
    if (!mounted) return;
    _totalFrames++;

    final hz = result.fundamentalFreq;
    final rms = result.rmsLevel;

    if (hz <= 0 || rms < 0.005) {
      _silentFrames++;
      setState(() {
        _rms = rms;
        _currentHz = 0;
        _currentNote = '—';
        _currentPitch = '—';
      });
      return;
    }

    // Convert Hz → note
    final semitones = 12.0 * (math.log(hz / _a4) / _ln2);
    final midi = (_a4Midi + semitones).round();
    final noteIdx = ((midi % 12) + 12) % 12;
    final octave = (midi ~/ 12) - 1;
    final pitch = _noteNames[noteIdx];
    final note = '$pitch$octave';

    // Cents deviation from nearest semitone
    final exactSemitones = 12.0 * (math.log(hz / _a4) / _ln2);
    final cents = (exactSemitones - exactSemitones.roundToDouble()) * 100;

    // Only add to history when note changes
    final isNewNote = _history.isEmpty || _history.last.note != note;
    if (isNewNote) {
      HapticFeedback.selectionClick();
      _pulseController.forward(from: 0);

      // Track octave confusion: if same pitch appeared recently at diff octave
      if (_history.isNotEmpty) {
        final prev = _history.last;
        if (prev.pitch == pitch && prev.octave != octave) {
          final key = '${prev.note}→$note';
          _octaveConfusionMap[key] = (_octaveConfusionMap[key] ?? 0) + 1;
        }
      }

      final event = _DetectionEvent(
        time: DateTime.now(),
        hz: hz,
        note: note,
        pitch: pitch,
        octave: octave,
        centsOff: cents,
      );

      setState(() {
        _history.insert(0, event);
        if (_history.length > _maxHistory) _history.removeLast();
      });
    }

    setState(() {
      _currentHz = hz;
      _currentNote = note;
      _currentPitch = pitch;
      _currentOctave = octave;
      _currentCents = cents;
      _rms = rms;
    });
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Color _colorFor(String pitch) =>
      _noteColors[pitch] ?? Colors.white;

  String _centsLabel(double cents) {
    if (cents == 0) return '0 ¢';
    return '${cents > 0 ? '+' : ''}${cents.toStringAsFixed(1)} ¢';
  }

  Color _centsColor(double cents) {
    final abs = cents.abs();
    if (abs <= 10) return Colors.greenAccent;
    if (abs <= 25) return Colors.yellowAccent;
    return Colors.redAccent;
  }

  double get _silenceRatio =>
      _totalFrames == 0 ? 0 : _silentFrames / _totalFrames;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          'Note Detective',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: Colors.white,
          ),
        ),
        actions: [
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _buildLiveBadge(),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Big note display ─────────────────────────────────────────────
          _buildNoteHero(),
          // ── Stats row ────────────────────────────────────────────────────
          _buildStatsRow(),
          const SizedBox(height: 12),
          // ── Octave confusion panel ────────────────────────────────────────
          if (_octaveConfusionMap.isNotEmpty) _buildConfusionPanel(),
          // ── History list ─────────────────────────────────────────────────
          Expanded(child: _buildHistory()),
          // ── Start/stop button ─────────────────────────────────────────────
          _buildMicButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Live badge ────────────────────────────────────────────────────────────

  Widget _buildLiveBadge() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.5, end: 1.0),
          duration: const Duration(milliseconds: 700),
          builder: (_, v, __) => Opacity(
            opacity: v,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.redAccent,
              ),
            ),
          ),
          onEnd: () => setState(() {}),
        ),
        const SizedBox(width: 6),
        const Text('LIVE',
            style: TextStyle(
                fontSize: 12,
                color: Colors.redAccent,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ── Note hero ─────────────────────────────────────────────────────────────

  Widget _buildNoteHero() {
    final color = _currentPitch == '—'
        ? Colors.white12
        : _colorFor(_currentPitch);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, __) {
        final scale = 1.0 +
            0.04 *
                math.sin(_pulseController.value * math.pi);
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          padding: const EdgeInsets.symmetric(
              vertical: 28, horizontal: 20),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withOpacity(0.35),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.08),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Note name
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Transform.scale(
                    scale: scale,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _currentNote,
                      style: TextStyle(
                        fontSize: 72,
                        fontWeight: FontWeight.w800,
                        color: color,
                        height: 1,
                        letterSpacing: -2,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _currentHz > 0
                        ? '${_currentHz.toStringAsFixed(2)} Hz'
                        : 'no signal',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),

              // Cents tuning meter
              _buildCentsMeter(),
            ],
          ),
        );
      },
    );
  }

  // ── Cents meter (vertical bar) ────────────────────────────────────────────

  Widget _buildCentsMeter() {
    final cents = _currentHz > 0 ? _currentCents : 0.0;
    final normalised = (cents / 50.0).clamp(-1.0, 1.0);
    final color = _centsColor(cents);

    return Column(
      children: [
        Text(
          _currentHz > 0 ? _centsLabel(cents) : '— ¢',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 28,
          height: 80,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Track
              Container(
                width: 6,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.white10,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              // Centre tick
              Container(
                  width: 14, height: 1.5, color: Colors.white24),
              // Indicator
              AnimatedAlign(
                duration: const Duration(milliseconds: 80),
                alignment: Alignment(0, -normalised),
                child: Container(
                  width: 14,
                  height: 6,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.6),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text('tune',
            style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.2),
                letterSpacing: 1)),
      ],
    );
  }

  // ── Stats row ─────────────────────────────────────────────────────────────

  Widget _buildStatsRow() {
    final silencePct = (_silenceRatio * 100).toStringAsFixed(0);
    final confusion = _octaveConfusionMap.values.fold(0, (a, b) => a + b);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _statCard('Detections', '${_history.length}',
              Colors.white70),
          const SizedBox(width: 10),
          _statCard('Silence', '$silencePct%',
              _silenceRatio > 0.5 ? Colors.orangeAccent : Colors.white70),
          const SizedBox(width: 10),
          _statCard('Oct. jumps', '$confusion',
              confusion > 0 ? Colors.orangeAccent : Colors.white70),
          const SizedBox(width: 10),
          // RMS bar
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF13131A),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Level',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.35),
                          letterSpacing: 0.8)),
                  const SizedBox(height: 5),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (_rms / 0.5).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                        _rms > 0.4
                            ? Colors.redAccent
                            : _rms > 0.15
                                ? Colors.greenAccent
                                : Colors.white38,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCard(String label, String value, Color valueColor) =>
      Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.35),
                    letterSpacing: 0.8)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: valueColor)),
          ],
        ),
      );

  // ── Octave confusion panel ────────────────────────────────────────────────

  Widget _buildConfusionPanel() {
    final sorted = _octaveConfusionMap.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border:
            Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded,
                size: 15, color: Colors.orangeAccent),
            const SizedBox(width: 6),
            const Text('Octave jumps detected',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Colors.orangeAccent)),
          ]),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: sorted.take(6).map((e) {
              return Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${e.key}  ×${e.value}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.orangeAccent),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Text(
            'Same pitch class, different octave — '
            'likely HPS locking onto a harmonic.',
            style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.35)),
          ),
        ],
      ),
    );
  }

  // ── History list ──────────────────────────────────────────────────────────

  Widget _buildHistory() {
    if (!_isListening && _history.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.mic_none,
                size: 48,
                color: Colors.white.withOpacity(0.1)),
            const SizedBox(height: 12),
            Text(
              'Tap the mic to start',
              style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.2)),
            ),
          ],
        ),
      );
    }

    if (_isListening && _history.isEmpty) {
      return Center(
        child: Text(
          'Listening… play a note',
          style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.2)),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      itemCount: _history.length,
      itemBuilder: (_, i) => _buildHistoryRow(_history[i], i),
    );
  }

  Widget _buildHistoryRow(_DetectionEvent e, int index) {
    final color = _colorFor(e.pitch);
    final isLatest = index == 0;
    final centsColor = _centsColor(e.centsOff);

    // Check if this was an octave jump from the next item
    final isOctaveJump = index < _history.length - 1 &&
        _history[index + 1].pitch == e.pitch &&
        _history[index + 1].octave != e.octave;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 6),
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isLatest
            ? color.withOpacity(0.10)
            : const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isOctaveJump
              ? Colors.orangeAccent.withOpacity(0.5)
              : isLatest
                  ? color.withOpacity(0.3)
                  : Colors.white.withOpacity(0.05),
          width: isLatest ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          // Colour dot
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(
                  isLatest ? 1.0 : 0.4),
            ),
          ),
          const SizedBox(width: 12),

          // Note name
          SizedBox(
            width: 44,
            child: Text(
              e.note,
              style: TextStyle(
                fontSize: isLatest ? 20 : 16,
                fontWeight: isLatest
                    ? FontWeight.bold
                    : FontWeight.w500,
                color: color.withOpacity(
                    isLatest ? 1.0 : 0.65),
              ),
            ),
          ),

          // Hz
          Expanded(
            child: Text(
              '${e.hz.toStringAsFixed(1)} Hz',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
          ),

          // Cents
          Text(
            _centsLabel(e.centsOff),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: centsColor.withOpacity(
                  isLatest ? 1.0 : 0.5),
            ),
          ),

          const SizedBox(width: 10),

          // Octave jump warning badge
          if (isOctaveJump)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('OCT',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.orangeAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5)),
            ),

          // Time
          const SizedBox(width: 8),
          Text(
            '${e.time.hour.toString().padLeft(2, '0')}:'
            '${e.time.minute.toString().padLeft(2, '0')}:'
            '${e.time.second.toString().padLeft(2, '0')}',
            style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.2)),
          ),
        ],
      ),
    );
  }

  // ── Mic button ────────────────────────────────────────────────────────────

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.symmetric(horizontal: 16),
        height: 60,
        decoration: BoxDecoration(
          color: _isListening
              ? Colors.redAccent.withOpacity(0.15)
              : Colors.greenAccent.withOpacity(0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isListening
                ? Colors.redAccent.withOpacity(0.5)
                : Colors.greenAccent.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isListening ? Icons.stop : Icons.mic,
              color: _isListening
                  ? Colors.redAccent
                  : Colors.greenAccent,
              size: 22,
            ),
            const SizedBox(width: 10),
            Text(
              _isListening ? 'Stop Listening' : 'Start Listening',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _isListening
                    ? Colors.redAccent
                    : Colors.greenAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}