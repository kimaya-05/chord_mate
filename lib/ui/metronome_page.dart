import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';

class MetronomePage extends StatefulWidget {
  const MetronomePage({Key? key}) : super(key: key);

  @override
  State<MetronomePage> createState() => _MetronomePageState();
}

class _MetronomePageState extends State<MetronomePage>
    with SingleTickerProviderStateMixin {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  bool _isPlaying = false;
  bool _isPlayerInitialized = false;

  int _bpm = 120;
  int _numerator = 4; // 1–4 only (1/4, 2/4, 3/4, 4/4)
  int _currentBeat = 1;

  late AnimationController _needleController;
  late Animation<double> _needleAnimation;

  final int _sampleRate = 44100;
  Timer? _generatorTimer;

  int _totalSamplesPushed = 0;
  final Stopwatch _playStopwatch = Stopwatch();

  // Dragging state — when true, needle jumps instantly with no animation lag
  bool _isDragging = false;

  // Text controller for the direct BPM input field
  late TextEditingController _bpmTextController;
  final FocusNode _bpmFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    // ── Fix 1: initialise controller first, then seed _needleAnimation
    // with a plain fixed value so it's never uninitialised. ──────────────
    _needleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    // Seed with the angle for the initial BPM so .value is always valid.
    _needleAnimation = AlwaysStoppedAnimation(_bpmToAngle(_bpm));

    // Now safe to call _updateNeedleAnimation (it reads _needleAnimation.value)
    _updateNeedleAnimation(_bpm);

    _bpmTextController = TextEditingController(text: _bpm.toString());

    _initAudio();
  }

  // ── Fix 2: _updateNeedleAnimation must not run before _needleAnimation
  // is initialised — guaranteed by the initState order above. ─────────────
  void _updateNeedleAnimation(int targetBpm, {bool instant = false}) {
    final double endAngle = _bpmToAngle(targetBpm);
    if (instant) {
      // During drag: jump directly — no animation lag.
      _needleAnimation = AlwaysStoppedAnimation(endAngle);
      _needleController.stop();
    } else {
      // Buttons / text input: short smooth snap.
      _needleAnimation = Tween<double>(
        begin: _needleAnimation.value,
        end: endAngle,
      ).animate(CurvedAnimation(
        parent: _needleController,
        curve: Curves.easeOutCubic,
      ));
      _needleController.forward(from: 0.0);
    }
  }

  double _bpmToAngle(int bpm) {
    const double minBpm   = 30.0;
    const double maxBpm   = 240.0;
    const double minAngle = -120.0 * math.pi / 180.0;
    const double maxAngle =  120.0 * math.pi / 180.0;
    final double p = ((bpm - minBpm) / (maxBpm - minBpm)).clamp(0.0, 1.0);
    return minAngle + p * (maxAngle - minAngle);
  }

  Future<void> _initAudio() async {
    await _player.openPlayer();
    if (mounted) setState(() => _isPlayerInitialized = true);
  }

  @override
  void dispose() {
    _generatorTimer?.cancel();
    _needleController.dispose();
    _bpmTextController.dispose();
    _bpmFocusNode.dispose();
    if (_isPlayerInitialized) _player.closePlayer();
    super.dispose();
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  void _togglePlay() async {
    if (!_isPlayerInitialized) return;
    if (_isPlaying) {
      await _stopMetronome();
    } else {
      await _startMetronome();
    }
  }

  Future<void> _startMetronome() async {
    setState(() {
      _isPlaying    = true;
      _currentBeat  = 1;
    });

    await _player.startPlayerFromStream(
      codec:       Codec.pcm16,
      numChannels: 1,
      sampleRate:  _sampleRate,
      interleaved: true,
      bufferSize:  8192,
    );

    _totalSamplesPushed = 0;
    _playStopwatch
      ..reset()
      ..start();

    // Push the very first beat immediately so there's no silent gap.
    _pushNextBeatBuffer();

    _generatorTimer = Timer.periodic(const Duration(milliseconds: 20), (_) {
      if (!_isPlaying) return;
      _checkAndPushBuffer();
    });
  }

  Future<void> _stopMetronome() async {
    _generatorTimer?.cancel();
    _generatorTimer = null;
    _playStopwatch.stop();

    // ── Fix 3: stop the player before updating state so the sink is
    // still valid during the final buffer push. ──────────────────────────
    await _player.stopPlayer();

    if (mounted) {
      setState(() {
        _isPlaying   = false;
        _currentBeat = 1;
      });
    }
  }

  void _checkAndPushBuffer() {
    final double secondsElapsed =
        _playStopwatch.elapsedMicroseconds / 1_000_000.0;
    final int samplesPlayed    = (secondsElapsed * _sampleRate).floor();
    final int samplesPerBeat   = (_sampleRate * 60) ~/ _bpm;
    final int leadSamples      = (_sampleRate * 0.2).floor();

    if (_totalSamplesPushed < samplesPlayed + leadSamples) {
      _pushNextBeatBuffer();
    }

    // Sync the UI beat indicator to the audio clock.
    final int totalBeats       = (samplesPlayed ~/ samplesPerBeat) + 1;
    final int expectedBeat     = ((totalBeats - 1) % _numerator) + 1;
    if (_currentBeat != expectedBeat && mounted) {
      setState(() => _currentBeat = expectedBeat);
    }
  }

  void _pushNextBeatBuffer() {
    final int samplesPerBeat = (_sampleRate * 60) ~/ _bpm;

    // ── Fix 4: derive accent from how many full beats have been pushed,
    // not from _currentBeat (which lags by one UI frame). ────────────────
    final int upcomingBeatIndex = _totalSamplesPushed ~/ samplesPerBeat;
    final bool isAccent         = (upcomingBeatIndex % _numerator) == 0;

    final Uint8List buffer =
        _generateClickBuffer(samplesPerBeat, isAccent: isAccent);
    _player.uint8ListSink?.add(buffer);
    _totalSamplesPushed += samplesPerBeat;
  }

  Uint8List _generateClickBuffer(int totalSamples,
      {required bool isAccent}) {
    final double toneFreq    = isAccent ? 1500.0 : 1000.0;
    final int    beepSamples =
        (_sampleRate * (isAccent ? 0.015 : 0.010)).floor();
    final double amplitude   = isAccent ? 0.9 : 0.5;

    final Int16List pcm = Int16List(totalSamples);
    for (int i = 0; i < totalSamples; i++) {
      if (i < beepSamples) {
        final double t     = i / _sampleRate;
        final double wave  = math.sin(2.0 * math.pi * toneFreq * t);
        final double decay = math.exp(-i / (beepSamples * 0.3));
        pcm[i] = (wave * decay * amplitude * 32767).toInt();
      }
      // else leave as 0 (silence for the rest of the beat interval)
    }
    return pcm.buffer.asUint8List();
  }

  // ── BPM controls ──────────────────────────────────────────────────────────

  void _changeBpm(int delta) {
    setState(() {
      _bpm = (_bpm + delta).clamp(30, 240);
      _bpmTextController.text = _bpm.toString();
      _updateNeedleAnimation(_bpm); // smooth for buttons
    });
  }

  void _updateBpmFromSlider(double value) {
    setState(() {
      _bpm = value.toInt().clamp(30, 240);
      _updateNeedleAnimation(_bpm);
    });
  }

  // ── Circular slider drag ──────────────────────────────────────────────────
  // Converts a drag position (relative to the widget centre) into a BPM value
  // by mapping the angle onto the same -210°..+30° arc as the speedometer.

  static const double _arcStart = -210 * math.pi / 180; // radians
  static const double _arcSweep =  240 * math.pi / 180;

  // The arc ends at _arcStart + _arcSweep = -210° + 240° = +30° (≈ 0.524 rad).
  // Anything past that end (clockwise into the "dead zone" below the dial) is
  // ignored so a hurried swipe doesn't wrap around to 240 BPM.
  static const double _arcEnd = _arcStart + _arcSweep; // +30° in radians

  void _onCircularDragUpdate(DragUpdateDetails details, Offset widgetCentre) {
    final Offset pos = details.localPosition - widgetCentre;

    // Ignore tiny movements right at the centre (avoid jitter).
    if (pos.distance < 20) return;

    double angle = math.atan2(pos.dy, pos.dx); // -π .. +π

    // Normalise relative to arc start into 0..2π.
    double relative = (angle - _arcStart) % (2 * math.pi);
    if (relative < 0) relative += 2 * math.pi;

    // Dead zone: the gap below the dial spans from _arcSweep (240°) to 2π.
    // If the finger is in the dead zone clamp to the nearest endpoint instead
    // of wrapping — this prevents the needle jumping to 240 on a low-BPM drag.
    if (relative > _arcSweep) {
      // Closer to the start (30 BPM) or the end (240 BPM)?
      final double distToStart = relative - _arcSweep; // distance past end
      final double distToEnd   = 2 * math.pi - relative; // distance before start
      relative = distToStart < distToEnd ? _arcSweep : 0.0;
    }

    final double fraction = (relative / _arcSweep).clamp(0.0, 1.0);
    final int newBpm = (30 + fraction * (240 - 30)).round().clamp(30, 240);
    if (newBpm != _bpm) {
      setState(() {
        _bpm = newBpm;
        _bpmTextController.text = newBpm.toString();
        _updateNeedleAnimation(_bpm, instant: true); // no lag during drag
      });
    }
  }

  void _onCircularDragEnd(DragEndDetails _) {
    // After the finger lifts, re-run with smooth animation so the needle
    // settles cleanly onto the final position.
    _updateNeedleAnimation(_bpm);
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Metronome',
            style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: MediaQuery.of(context).size.height -
                  MediaQuery.of(context).padding.top -
                  kToolbarHeight,
            ),
            child: Column(
              children: [
              const SizedBox(height: 20),

              // ── Speedometer + circular drag ─────────────────────────
              SizedBox(
                height: 320,
                child: Center(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      const double dialSize = 300;
                      const Offset centre =
                          Offset(dialSize / 2, dialSize / 2);
                      return GestureDetector(
                        onPanUpdate: (details) =>
                            _onCircularDragUpdate(details, centre),
                        onPanEnd: _onCircularDragEnd,
                        child: AnimatedBuilder(
                          animation: _needleController,
                          builder: (context, _) => CustomPaint(
                            size: const Size(dialSize, dialSize),
                            painter: SpeedometerPainter(
                              needleAngle: _needleAnimation.value,
                              currentBpm:  _bpm,
                              isPlaying:   _isPlaying,
                              currentBeat: _currentBeat,
                              numerator:   _numerator,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── BPM fine/coarse controls ─────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24.0, vertical: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _BpmButton(
                        label: '−10', onPressed: () => _changeBpm(-10)),
                    const SizedBox(width: 8),
                    _BpmButton(
                        label: '−1', onPressed: () => _changeBpm(-1)),
                    const SizedBox(width: 16),
                    SizedBox(
                      width: 72,
                      child: TextField(
                        controller: _bpmTextController,
                        focusNode: _bpmFocusNode,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        decoration: InputDecoration(
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 4),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide(
                                color:
                                    Colors.white.withOpacity(0.15)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: const BorderSide(
                                color: Colors.greenAccent, width: 1.5),
                          ),
                          filled: true,
                          fillColor: Colors.white.withOpacity(0.05),
                        ),
                        onSubmitted: (val) {
                          final int? parsed = int.tryParse(val);
                          if (parsed != null) {
                            final int clamped = parsed.clamp(30, 240);
                            setState(() {
                              _bpm = clamped;
                              _bpmTextController.text =
                                  clamped.toString();
                              _updateNeedleAnimation(_bpm);
                            });
                          } else {
                            _bpmTextController.text = _bpm.toString();
                          }
                          _bpmFocusNode.unfocus();
                        },
                      ),
                    ),
                    const SizedBox(width: 16),
                    _BpmButton(
                        label: '+1', onPressed: () => _changeBpm(1)),
                    const SizedBox(width: 8),
                    _BpmButton(
                        label: '+10', onPressed: () => _changeBpm(10)),
                  ],
                ),
              ),

              // ── Time signature + play button ─────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 32),
                decoration: const BoxDecoration(
                  color: Color(0xFF13131A),
                  borderRadius:
                      BorderRadius.vertical(top: Radius.circular(32)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Time signature label
                    Text(
                      'Time Signature',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.35),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 1/4 2/4 3/4 4/4 chips
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [1, 2, 3, 4].map((n) {
                        final bool selected = _numerator == n;
                        return GestureDetector(
                          onTap: () =>
                              setState(() => _numerator = n),
                          child: AnimatedContainer(
                            duration:
                                const Duration(milliseconds: 150),
                            margin: const EdgeInsets.symmetric(
                                horizontal: 6),
                            width: 56,
                            height: 72,
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.greenAccent
                                      .withOpacity(0.15)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius:
                                  BorderRadius.circular(14),
                              border: Border.all(
                                color: selected
                                    ? Colors.greenAccent
                                        .withOpacity(0.7)
                                    : Colors.white12,
                                width: selected ? 1.5 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment:
                                  MainAxisAlignment.center,
                              crossAxisAlignment:
                                  CrossAxisAlignment.center,
                              children: [
                                Text(
                                  '$n',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: selected
                                        ? Colors.greenAccent
                                        : Colors.white54,
                                  ),
                                ),
                                Container(
                                  height: 1.5,
                                  width: 20,
                                  color: selected
                                      ? Colors.greenAccent
                                          .withOpacity(0.7)
                                      : Colors.white24,
                                  margin: const EdgeInsets.symmetric(
                                      vertical: 2),
                                ),
                                Text(
                                  '4',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.greenAccent
                                        : Colors.white38,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 28),

                    // Play / Stop button
                    GestureDetector(
                      onTap: _togglePlay,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isPlaying
                              ? Colors.redAccent.withOpacity(0.2)
                              : Colors.greenAccent.withOpacity(0.2),
                          border: Border.all(
                            color: _isPlaying
                                ? Colors.redAccent
                                : Colors.greenAccent,
                            width: 3,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (_isPlaying
                                      ? Colors.redAccent
                                      : Colors.greenAccent)
                                  .withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isPlaying
                              ? Icons.stop_rounded
                              : Icons.play_arrow_rounded,
                          size: 40,
                          color: _isPlaying
                              ? Colors.redAccent
                              : Colors.greenAccent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
        ),
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────────────────
// _BpmButton — compact outlined button for ±1 / ±10 controls
// ─────────────────────────────────────────────────────────────────────────────

class _BpmButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _BpmButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SpeedometerPainter
// ─────────────────────────────────────────────────────────────────────────────

class SpeedometerPainter extends CustomPainter {
  final double needleAngle;
  final int    currentBpm;
  final bool   isPlaying;
  final int    currentBeat;
  final int    numerator;

  const SpeedometerPainter({
    required this.needleAngle,
    required this.currentBpm,
    required this.isPlaying,
    required this.currentBeat,
    required this.numerator,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    const double startAngle = -210 * math.pi / 180;
    const double sweepAngle =  240 * math.pi / 180;

    // Background arc
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle, sweepAngle, false,
      Paint()
        ..color       = Colors.white.withOpacity(0.05)
        ..style       = PaintingStyle.stroke
        ..strokeWidth = 20
        ..strokeCap   = StrokeCap.round,
    );

    // Tick marks + labels
    final tickPaint = Paint()
      ..color       = Colors.white24
      ..strokeWidth = 2
      ..strokeCap   = StrokeCap.round;
    final majorTickPaint = Paint()
      ..color       = Colors.white54
      ..strokeWidth = 4
      ..strokeCap   = StrokeCap.round;

    for (int bpm = 30; bpm <= 240; bpm += 10) {
      final double p     = (bpm - 30) / 210.0;
      final double angle = startAngle + p * sweepAngle;
      final bool major   = bpm % 30 == 0;
      final double inner = radius - 30;
      final double outer = inner + (major ? 15 : 8);

      canvas.drawLine(
        Offset(center.dx + inner * math.cos(angle),
               center.dy + inner * math.sin(angle)),
        Offset(center.dx + outer * math.cos(angle),
               center.dy + outer * math.sin(angle)),
        major ? majorTickPaint : tickPaint,
      );

      if (major) {
        final tp = TextPainter(
          text: TextSpan(
            text: bpm.toString(),
            style:
                const TextStyle(color: Colors.white70, fontSize: 12),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final double tr = radius - 55;
        tp.paint(
          canvas,
          Offset(center.dx + tr * math.cos(angle) - tp.width  / 2,
                 center.dy + tr * math.sin(angle) - tp.height / 2),
        );
      }
    }

    // Needle — rotate -90° so 0 rad points up
    final double va = needleAngle - math.pi / 2;
    final needlePath = Path()
      ..moveTo(center.dx + 6 * math.cos(va - math.pi / 2),
               center.dy + 6 * math.sin(va - math.pi / 2))
      ..lineTo(center.dx + (radius - 20) * math.cos(va),
               center.dy + (radius - 20) * math.sin(va))
      ..lineTo(center.dx + 6 * math.cos(va + math.pi / 2),
               center.dy + 6 * math.sin(va + math.pi / 2))
      ..close();

    canvas.drawShadow(needlePath, Colors.greenAccent, 8, true);
    canvas.drawPath(needlePath,
        Paint()..color = Colors.greenAccent..style = PaintingStyle.fill);

    // Centre cap
    canvas.drawCircle(center, 16,
        Paint()..color = const Color(0xFF1E1E24));
    canvas.drawCircle(center, 16,
        Paint()
          ..color       = Colors.greenAccent
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 3);

    // BPM number — positioned below centre
    final bpmTp = TextPainter(
      text: TextSpan(
        text: currentBpm.toString(),
        style: const TextStyle(
            color: Colors.white, fontSize: 64,
            fontWeight: FontWeight.bold, height: 1.0),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    bpmTp.paint(canvas,
        Offset(center.dx - bpmTp.width / 2,
               center.dy + radius * 0.4));

    final labelTp = TextPainter(
      text: const TextSpan(
        text: 'BPM',
        style: TextStyle(
            color: Colors.greenAccent, fontSize: 14,
            fontWeight: FontWeight.bold, letterSpacing: 2),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    labelTp.paint(canvas,
        Offset(center.dx - labelTp.width / 2,
               center.dy + radius * 0.4 + bpmTp.height));

    if (isPlaying) _drawBeatIndicators(canvas, center, radius);
  }

  void _drawBeatIndicators(
      Canvas canvas, Offset center, double radius) {
    const double spacing     = 20.0;
    const double dotR        = 8.0;
    final double totalWidth  = (numerator - 1) * spacing;
    final double startX      = center.dx - totalWidth / 2;
    final double startY      = center.dy + radius * 1.0;

    for (int i = 0; i < numerator; i++) {
      final bool isActive = (i + 1) == currentBeat;
      final bool isAccent = i == 0;
      final double r      = dotR; // same size for all dots; colour alone distinguishes accent
      final Offset pos    = Offset(startX + i * spacing, startY);

      canvas.drawCircle(
        pos, r,
        Paint()
          ..color = isActive
              ? (isAccent ? Colors.redAccent : Colors.greenAccent)
              : Colors.white24
          ..style = PaintingStyle.fill,
      );

      if (isActive) {
        canvas.drawCircle(
          pos, r,
          Paint()
            ..color = (isAccent
                    ? Colors.redAccent
                    : Colors.greenAccent)
                .withOpacity(0.5)
            ..style      = PaintingStyle.stroke
            ..strokeWidth = 4
            ..maskFilter =
                const MaskFilter.blur(BlurStyle.normal, 8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant SpeedometerPainter old) =>
      old.needleAngle  != needleAngle  ||
      old.currentBpm   != currentBpm   ||
      old.isPlaying    != isPlaying    ||
      old.currentBeat  != currentBeat  ||
      old.numerator    != numerator;
}