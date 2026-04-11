import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/pb_service.dart';
import '../chords/chord_library.dart';
import '../services/audio_service.dart';
import '../services/metronome_service.dart';
import 'results_screen.dart';

class DrillScreen extends StatefulWidget {
  final ChordData chordA;
  final ChordData chordB;
  final int bpm;
  final int? targetCount;   // number of transitions, or null
  final int? targetSeconds; // duration in seconds, or null
 
  const DrillScreen({
    required this.chordA,
    required this.chordB,
    required this.bpm,
    this.targetCount,
    this.targetSeconds,
  });
 
  @override
  State<DrillScreen> createState() => DrillScreenState();
}
 
class DrillScreenState extends State<DrillScreen>
    with SingleTickerProviderStateMixin {
  final AudioService _audio = AudioService();
  late final MetronomeService _metronome;
 
  // Beat / metronome state
  Timer? _sampleTimer;   // fires 300 ms after each beat
  Timer? _countdownTimer;
 
  // Drill state
  bool _isRunning = false;
  bool _isCountingDown = false;
  int _countdown = 3;
 
  // Current beat
  int _beatIndex = 0;     // 0 = should be on chordA, 1 = should be on chordB
  bool _isOnChordA = true;
 
  // Scoring
  int _correct = 0;
  int _total = 0;
  int _elapsedSeconds = 0;
 
  // Latest detection
  String _detectedChord = '';
  double _detectedConfidence = 0;
  bool? _lastTransitionCorrect;  // null = not yet judged
 
  // Visual flash
  bool _flashCorrect = false;
  bool _flashWrong = false;
 
  // Beat flash for visual metronome
  bool _beatFlash = false;
 
  // All transition results for results screen
  final List<TransitionResult> _results = [];
 
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulseAnim;
 
  @override
  void initState() {
    super.initState();
    _metronome = MetronomeService(onBeat: _onBeatTick);
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.06).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeOut),
    );
    _initAudio();
    
  }
 
  @override
  void dispose() {
    _sampleTimer?.cancel();
    _countdownTimer?.cancel();
    _audio.stop();
    _metronome.stop();
    _metronome.dispose();
    _audio.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }
 
  Future<void> _initAudio() async {
    await _metronome.init();
    await _audio.init();
    await _audio.startWithDSP((result) {
      if (!mounted) return;
      setState(() {
        _detectedChord = result.chord;
        _detectedConfidence = result.confidence;
      });
    });
  }
 
  // ── Countdown → Start ──────────────────────────────────────────────────────
 
  void _beginCountdown() {
    setState(() {
      _isCountingDown = true;
      _countdown = 3;
      _isOnChordA = true;
      _beatIndex = 0;
      _correct = 0;
      _total = 0;
      _elapsedSeconds = 0;
      _results.clear();
      _lastTransitionCorrect = null;
    });
 
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_countdown <= 1) {
        t.cancel();
        setState(() => _isCountingDown = false);
        _startDrill();
      } else {
        setState(() => _countdown--);
      }
    });
  }
 
  void _startDrill() {
    setState(() => _isRunning = true);
 
    _metronome.start(widget.bpm);
 
    // Elapsed seconds counter (separate from beat)
    if (widget.targetSeconds != null) {
      _countdownTimer =
          Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        setState(() => _elapsedSeconds++);
        if (_elapsedSeconds >= widget.targetSeconds!) {
          t.cancel();
          _stopDrill();
        }
      });
    }
  }

  void _onBeatTick(int tick) {
    if (!mounted) return;

    // Trigger beat flash & haptic
    setState(() {
      _beatFlash = true;
      _isOnChordA = _beatIndex.isEven;
    });
    HapticFeedback.lightImpact();
    _pulseCtrl.forward().then((_) => _pulseCtrl.reverse());

    // Schedule beat flash off
    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) setState(() => _beatFlash = false);
    });

    // Schedule sample 300 ms after beat — gives chord time to stabilise
    final sampleOffset = const Duration(milliseconds: 300);
    _sampleTimer?.cancel();
    _sampleTimer = Timer(sampleOffset, () {
      if (!mounted || !_isRunning) return;
      _judgeTransition();
    });

    _beatIndex++;

    // Duration-based ending
    if (widget.targetSeconds != null) {
      final newElapsed = _elapsedSeconds + 1;
      if (newElapsed >= widget.targetSeconds! * widget.bpm ~/ 60) {
        _stopDrill();
      }
    }
  }
 
  void _judgeTransition() {
    // Which chord should the user currently be on?
    final expected = _isOnChordA ? widget.chordA : widget.chordB;
    final detected = _detectedChord.toLowerCase().trim();
    final expectedLabel = expected.mlLabel.toLowerCase().trim();
 
    // Accept if confidence is reasonable and label matches
    final isCorrect =
        detected == expectedLabel && _detectedConfidence >= 0.35;
 
    setState(() {
      _total++;
      if (isCorrect) _correct++;
      _lastTransitionCorrect = isCorrect;
      _flashCorrect = isCorrect;
      _flashWrong = !isCorrect;
    });
 
    _results.add(TransitionResult(
      expectedLabel: expected.mlLabel,
      detectedLabel: _detectedChord,
      correct: isCorrect,
      confidence: _detectedConfidence,
    ));
 
    // Clear flash after 400 ms
    Future.delayed(const Duration(milliseconds: 400), () {
      if (mounted) {
        setState(() {
          _flashCorrect = false;
          _flashWrong = false;
        });
      }
    });
 
    // Count-based ending
    if (widget.targetCount != null && _total >= widget.targetCount!) {
      _stopDrill();
    }
  }
 
  Future<void> _stopDrill() async {
    _metronome.stop();
    _sampleTimer?.cancel();
    _countdownTimer?.cancel();
    _audio.stop();

    if (!mounted) return;
    setState(() => _isRunning = false);

    // Save personal best if this session was better
    final newPb = await PbService.saveIfBetter(
      labelA: widget.chordA.mlLabel,
      labelB: widget.chordB.mlLabel,
      correct: _correct,
      total: _total,
    );

    if (!mounted) return;

    if (newPb != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'New personal best!  ${newPb.correct}/${newPb.total}'
            '  •  ${(newPb.accuracy * 100).toStringAsFixed(0)}%',
          ),
          backgroundColor: Colors.amber.shade800,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }

    Navigator.of(context).pushReplacement(MaterialPageRoute(
      settings: const RouteSettings(name: '/transition-drill'),
      builder: (_) => ResultsScreen(
        chordA: widget.chordA,
        chordB: widget.chordB,
        bpm: widget.bpm,
        correct: _correct,
        total: _total,
        results: _results,
      ),
    ));
  }
 
  // ── Build ──────────────────────────────────────────────────────────────────
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white54),
          onPressed: () {
            _metronome.stop();
            _sampleTimer?.cancel();
            _countdownTimer?.cancel();
            Navigator.pop(context);
          },
        ),
        title: Text(
          '${widget.chordA.displayName}  ↔  ${widget.chordB.displayName}',
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text(
                '${widget.bpm} BPM',
                style: TextStyle(
                    fontSize: 12, color: Colors.white.withOpacity(0.4)),
              ),
            ),
          ),
        ],
      ),
      body: _isCountingDown
          ? _buildCountdown()
          : _isRunning
              ? _buildDrillUI()
              : _buildReadyUI(),
    );
  }
 
  Widget _buildReadyUI() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Ready?',
            style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w800,
                color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Switch chords on every beat.',
            style: TextStyle(
                fontSize: 15, color: Colors.white.withOpacity(0.4)),
          ),
          const SizedBox(height: 40),
          _buildChordLabels(),
          const SizedBox(height: 48),
          ElevatedButton(
            onPressed: _beginCountdown,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(
                  horizontal: 48, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: const Text('Start',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
 
  Widget _buildCountdown() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '$_countdown',
            style: const TextStyle(
              fontSize: 96,
              fontWeight: FontWeight.w900,
              color: Colors.greenAccent,
            ),
          ),
          const SizedBox(height: 12),
          Text('Get ready…',
              style: TextStyle(
                  fontSize: 16, color: Colors.white.withOpacity(0.4))),
        ],
      ),
    );
  }
 
  Widget _buildDrillUI() {
    final currentChord = _isOnChordA ? widget.chordA : widget.chordB;
    final nextChord = _isOnChordA ? widget.chordB : widget.chordA;
 
    // Background flash color
    Color bgTint = Colors.transparent;
    if (_flashCorrect) bgTint = Colors.greenAccent.withOpacity(0.06);
    if (_flashWrong)   bgTint = Colors.redAccent.withOpacity(0.06);
 
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      color: bgTint,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          children: [
            const SizedBox(height: 16),
 
            // ── Score bar ──────────────────────────────────────────
            _buildScoreBar(),
 
            const Spacer(flex: 2),
 
            // ── Beat flash dot ─────────────────────────────────────
            AnimatedContainer(
              duration: const Duration(milliseconds: 60),
              width: _beatFlash ? 14 : 10,
              height: _beatFlash ? 14 : 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _beatFlash
                    ? Colors.greenAccent
                    : Colors.white.withOpacity(0.15),
              ),
            ),
 
            const Spacer(flex: 1),
 
            // ── Current chord (large) ──────────────────────────────
            ScaleTransition(
              scale: _pulseAnim,
              child: Column(
                children: [
                  Text(
                    'NOW',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 1.6,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    currentChord.displayName,
                    style: TextStyle(
                      fontSize: 80,
                      fontWeight: FontWeight.w900,
                      color: _flashCorrect
                          ? Colors.greenAccent
                          : _flashWrong
                              ? Colors.redAccent
                              : Colors.white,
                      height: 1.0,
                    ),
                  ),
                  Text(
                    currentChord.fullName,
                    style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.35)),
                  ),
                ],
              ),
            ),
 
            const Spacer(flex: 2),
 
            // ── Detection readout ──────────────────────────────────
            _buildDetectionReadout(currentChord),
 
            const Spacer(flex: 1),
 
            // ── Next chord hint ────────────────────────────────────
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.04),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('NEXT  ',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withOpacity(0.25),
                          letterSpacing: 1.2)),
                  Text(nextChord.displayName,
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white.withOpacity(0.5))),
                ],
              ),
            ),
 
            const Spacer(flex: 3),
 
            // ── Stop button ────────────────────────────────────────
            TextButton(
              onPressed: _stopDrill,
              child: Text('Stop drill',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.25),
                      fontSize: 13)),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
 
  Widget _buildScoreBar() {
    final accuracy =
        _total == 0 ? 0.0 : _correct / _total;
    final target = widget.targetCount ?? widget.targetSeconds ?? 10;
    final progress =
        widget.targetCount != null ? _total / target : _elapsedSeconds / target;
 
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _scorePill('$_correct / $_total', 'correct'),
            _scorePill('${(accuracy * 100).round()}%', 'accuracy'),
            if (widget.targetCount != null)
              _scorePill(
                  '${target - _total}', 'remaining')
            else
              _scorePill(
                  '${widget.targetSeconds! - _elapsedSeconds}s', 'left'),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: Colors.white.withOpacity(0.06),
            valueColor: AlwaysStoppedAnimation<Color>(
              accuracy >= 0.8
                  ? Colors.greenAccent
                  : accuracy >= 0.5
                      ? Colors.amber
                      : Colors.redAccent,
            ),
            minHeight: 4,
          ),
        ),
      ],
    );
  }
 
  Widget _scorePill(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(label,
            style: TextStyle(
                fontSize: 10, color: Colors.white.withOpacity(0.3))),
      ],
    );
  }
 
  Widget _buildDetectionReadout(ChordData expected) {
    final isMatch =
        _detectedChord.toLowerCase().trim() ==
            expected.mlLabel.toLowerCase().trim();
 
    if (_detectedChord.isEmpty || _detectedChord == 'Unknown') {
      return Text('Listening…',
          style: TextStyle(
              fontSize: 13, color: Colors.white.withOpacity(0.25)));
    }
 
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isMatch ? Icons.check_circle_outline : Icons.hearing_outlined,
          size: 14,
          color: isMatch
              ? Colors.greenAccent.withOpacity(0.7)
              : Colors.white.withOpacity(0.3),
        ),
        const SizedBox(width: 6),
        Text(
          'Hearing: $_detectedChord',
          style: TextStyle(
            fontSize: 13,
            color: isMatch
                ? Colors.greenAccent.withOpacity(0.7)
                : Colors.white.withOpacity(0.35),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '${(_detectedConfidence * 100).round()}%',
          style: TextStyle(
              fontSize: 11, color: Colors.white.withOpacity(0.2)),
        ),
      ],
    );
  }
 
  Widget _buildChordLabels() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _chordPill(widget.chordA, isActive: true),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Icon(Icons.swap_horiz,
              color: Colors.white.withOpacity(0.2), size: 24),
        ),
        _chordPill(widget.chordB, isActive: false),
      ],
    );
  }
 
  Widget _chordPill(ChordData chord, {required bool isActive}) {
    return Column(
      children: [
        Text(chord.displayName,
            style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        Text(chord.fullName,
            style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.35))),
      ],
    );
  }
}