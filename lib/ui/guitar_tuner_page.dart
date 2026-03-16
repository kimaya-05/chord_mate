import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../dsp/dsp_engine.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Standard tuning data
// ─────────────────────────────────────────────────────────────────────────────

class _GuitarString {
  final String name;      // e.g. "E"
  final int    string;    // 1=high e … 6=low E
  final double targetHz;  // target frequency in standard tuning

  const _GuitarString(this.name, this.string, this.targetHz);
}

const List<_GuitarString> _standardTuning = [
  _GuitarString('E', 6, 82.41),   // low E2
  _GuitarString('A', 5, 110.00),  // A2
  _GuitarString('D', 4, 146.83),  // D3
  _GuitarString('G', 3, 196.00),  // G3
  _GuitarString('B', 2, 246.94),  // B3
  _GuitarString('e', 1, 329.63),  // high e4
];

// ─────────────────────────────────────────────────────────────────────────────
// Tuning state
// ─────────────────────────────────────────────────────────────────────────────

enum _TuneState { idle, flat, inTune, sharp }

// ─────────────────────────────────────────────────────────────────────────────
// GuitarTunerPage
// ─────────────────────────────────────────────────────────────────────────────

class GuitarTunerPage extends StatefulWidget {
  const GuitarTunerPage({super.key});

  @override
  State<GuitarTunerPage> createState() => _GuitarTunerPageState();
}

class _GuitarTunerPageState extends State<GuitarTunerPage>
    with TickerProviderStateMixin {

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioService _audio = AudioService();
  bool _isListening = false;

  // ── Selected string ────────────────────────────────────────────────────────
  int _selectedStringIndex = 0; // index into _standardTuning (0=low E)

  // ── Detection ──────────────────────────────────────────────────────────────
  double _detectedHz   = 0;
  double _centsOff     = 0;       // negative=flat, positive=sharp
  _TuneState _tuneState = _TuneState.idle;
  String _detectedNote = '—';

  static const double _inTuneCents    = 5.0;  // ±5 cents = in tune
  static const double _maxDisplayCents = 50.0; // bar saturates at ±50¢

  // ── Animations ─────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final AnimationController _liveCtrl;
  late final AnimationController _barCtrl;
  late Animation<double> _barAnim; // animates towards _centsOff

  double _lastBarValue = 0;

  // Frequency smoothing — prevents frame-to-frame flicker
  double _smoothedHz   = 0;
  int    _stableFrames = 0;
  static const int    _stableThreshold = 4;   // frames before accepting new freq
  static const double _smoothingAlpha  = 0.3; // EMA coefficient

  @override
  void initState() {
    super.initState();

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _liveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _barCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _barAnim = AlwaysStoppedAnimation(0);
  }

  @override
  void dispose() {
    _audio.dispose();
    _pulseCtrl.dispose();
    _liveCtrl.dispose();
    _barCtrl.dispose();
    super.dispose();
  }

  // ── String selection ───────────────────────────────────────────────────────

  void _selectString(int index) {
    if (_selectedStringIndex == index) return;
    HapticFeedback.selectionClick();
    setState(() {
      _selectedStringIndex = index;
      _centsOff   = 0;
      _detectedHz = 0;
      _detectedNote = '—';
      _tuneState  = _TuneState.idle;
      _lastBarValue = 0;
      _smoothedHz   = 0;
      _stableFrames = 0;
    });
    _audio.resetDSP();
    _animateBar(0);
  }

  // ── Mic ────────────────────────────────────────────────────────────────────

  Future<void> _toggleListen() async {
    if (_isListening) {
      await _audio.stop();
      if (mounted) {
        setState(() {
          _isListening  = false;
          _tuneState    = _TuneState.idle;
          _detectedHz   = 0;
          _centsOff     = 0;
          _detectedNote = '—';
          _smoothedHz   = 0;
          _stableFrames = 0;
        });
        _animateBar(0);
      }
      return;
    }

    _audio.resetDSP();
    final ok = await _audio.startWithDSP(_onDSP);
    if (!mounted) return;
    if (ok) {
      setState(() => _isListening = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not access microphone')),
      );
    }
  }

  // ── DSP callback ───────────────────────────────────────────────────────────

  void _onDSP(DSPResult result) {
    if (!mounted) return;

    final double rms  = result.rmsLevel;
    final double freq = result.fundamentalFreq;

    // Noise gate
    if (rms < 0.012 || freq <= 0) {
      _stableFrames = 0;
      if (mounted) {
        setState(() {
          _tuneState    = _TuneState.idle;
          _detectedNote = '—';
          _detectedHz   = 0;
        });
        _animateBar(0);
      }
      return;
    }

    // ── Frequency smoothing ────────────────────────────────────────────────
    // Only accept a new frequency if it's within 1 semitone of the smoothed
    // value, OR if we haven't locked onto anything yet.
    // This kills the frame-to-frame octave jumps that cause flickering.
    final bool firstReading = _smoothedHz <= 0;
    final bool withinOneSemitone = !firstReading &&
        (freq / _smoothedHz).abs() < 1.0595 &&
        (_smoothedHz / freq).abs() < 1.0595;

    if (firstReading || withinOneSemitone) {
      // EMA smoothing
      _smoothedHz = firstReading
          ? freq
          : _smoothedHz * (1 - _smoothingAlpha) + freq * _smoothingAlpha;
      _stableFrames++;
    } else {
      // Outlier — count toward stability before accepting
      _stableFrames = 0;
      _smoothedHz   = freq; // reset to new candidate
      return; // skip this frame — wait for stability
    }

    // Require a few stable frames before updating UI
    if (_stableFrames < _stableThreshold) return;

    final _GuitarString target = _standardTuning[_selectedStringIndex];

    // Cents offset: 1200 * log2(smoothed / target)
    final double cents =
        1200.0 * (math.log(_smoothedHz / target.targetHz) / math.ln2);

    final String noteName = _dsp_frequencyToNoteName(_smoothedHz);

    _TuneState state;
    if (cents.abs() <= _inTuneCents) {
      state = _TuneState.inTune;
      if (_tuneState != _TuneState.inTune) {
        HapticFeedback.mediumImpact();
        _pulseCtrl.repeat(reverse: true);
      }
    } else {
      state = cents < 0 ? _TuneState.flat : _TuneState.sharp;
      if (_tuneState == _TuneState.inTune) {
        _pulseCtrl.stop();
        _pulseCtrl.reset();
      }
    }

    _animateBar(cents);

    if (mounted) {
      setState(() {
        _detectedHz   = _smoothedHz;
        _centsOff     = cents;
        _detectedNote = noteName;
        _tuneState    = state;
      });
    }
  }

  void _animateBar(double targetCents) {
    _barAnim = Tween<double>(
      begin: _lastBarValue,
      end: targetCents.clamp(-_maxDisplayCents, _maxDisplayCents),
    ).animate(CurvedAnimation(parent: _barCtrl, curve: Curves.easeOut));
    _lastBarValue = targetCents.clamp(-_maxDisplayCents, _maxDisplayCents);
    _barCtrl.forward(from: 0);
  }

  /// Minimal frequency → note name conversion (no DSPEngine dependency)
  String _dsp_frequencyToNoteName(double freq) {
    const List<String> notes = [
      'C','C#','D','D#','E','F','F#','G','G#','A','A#','B'
    ];
    const double a4 = 440.0;
    const int    a4midi = 69;
    final double semitones = 12.0 * (math.log(freq / a4) / math.ln2);
    final int    midi = (a4midi + semitones).round();
    return notes[((midi % 12) + 12) % 12];
  }

  // ── Colours ────────────────────────────────────────────────────────────────

  Color get _stateColor {
    switch (_tuneState) {
      case _TuneState.inTune: return Colors.greenAccent;
      case _TuneState.flat:   return const Color(0xFF64B5F6); // blue = tune up
      case _TuneState.sharp:  return Colors.orangeAccent;     // orange = tune down
      case _TuneState.idle:   return Colors.white24;
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          'Tuner',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        actions: [
          if (_isListening)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: _LiveBadge(controller: _liveCtrl),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
            const SizedBox(height: 12),

            // ── Guitar head with pegs ─────────────────────────────────
            SizedBox(
              height: 320,
              child: _GuitarHeadWidget(
                selectedIndex:  _selectedStringIndex,
                tuneState:      _tuneState,
                onSelectString: _selectString,
                pulseCtrl:      _pulseCtrl,
              ),
            ),

            // ── Detected note + cents ─────────────────────────────────
            _buildNoteDisplay(),

            const SizedBox(height: 16),

            // ── Vertical tuning bar ───────────────────────────────────
            _buildTuningBar(),

            const SizedBox(height: 16),

            // ── Hint text ─────────────────────────────────────────────
            _buildHintText(),

            const SizedBox(height: 20),

            // ── Mic button ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: _MicButton(
                isListening: _isListening,
                onTap: _toggleListen,
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  // ── Note display ───────────────────────────────────────────────────────────

  Widget _buildNoteDisplay() {
    final target = _standardTuning[_selectedStringIndex];
    return Column(
      children: [
        // Large detected note
        AnimatedDefaultTextStyle(
          duration: const Duration(milliseconds: 200),
          style: TextStyle(
            fontSize: 80,
            fontWeight: FontWeight.w800,
            color: _stateColor,
            height: 1,
            letterSpacing: -2,
          ),
          child: Text(
            _isListening && _detectedNote != '—' ? _detectedNote : target.name,
          ),
        ),
        const SizedBox(height: 6),
        // Cents readout
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 150),
          child: Text(
            key: ValueKey(_tuneState),
            _tuneStateLabel(),
            style: TextStyle(
              fontSize: 13,
              color: _stateColor.withOpacity(0.7),
              fontWeight: FontWeight.w500,
              letterSpacing: 0.5,
            ),
          ),
        ),
        const SizedBox(height: 4),
        if (_detectedHz > 0)
          Text(
            '${_detectedHz.toStringAsFixed(1)} Hz',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.25),
            ),
          ),
      ],
    );
  }

  String _tuneStateLabel() {
    if (!_isListening) return 'Tap mic to start';
    switch (_tuneState) {
      case _TuneState.idle:   return 'Play the string…';
      case _TuneState.inTune: return '✓ In tune';
      case _TuneState.flat:
        return '${_centsOff.abs().toStringAsFixed(0)}¢ flat — tune up ↑';
      case _TuneState.sharp:
        return '${_centsOff.abs().toStringAsFixed(0)}¢ sharp — tune down ↓';
    }
  }

  // ── Tuning bar ─────────────────────────────────────────────────────────────

  Widget _buildTuningBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: AnimatedBuilder(
        animation: _barCtrl,
        builder: (_, __) {
          final double fraction =
              _barAnim.value / _maxDisplayCents; // -1..+1
          return _TuningBarPainter(
            fraction:   fraction,
            stateColor: _stateColor,
            isActive:   _isListening && _tuneState != _TuneState.idle,
          );
        },
      ),
    );
  }

  // ── Hint ───────────────────────────────────────────────────────────────────

  Widget _buildHintText() {
    return Text(
      _tuneState == _TuneState.flat
          ? 'Tighten the peg to raise pitch'
          : _tuneState == _TuneState.sharp
              ? 'Loosen the peg to lower pitch'
              : _isListening
                  ? 'Pluck the ${_standardTuning[_selectedStringIndex].name} string'
                  : 'Select a string and start listening',
      style: TextStyle(
        fontSize: 12,
        color: Colors.white.withOpacity(0.3),
        letterSpacing: 0.3,
      ),
      textAlign: TextAlign.center,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _GuitarHeadWidget — draws a stylised guitar headstock with 6 pegs
// ─────────────────────────────────────────────────────────────────────────────

class _GuitarHeadWidget extends StatelessWidget {
  final int           selectedIndex;
  final _TuneState    tuneState;
  final void Function(int) onSelectString;
  final AnimationController pulseCtrl;

  const _GuitarHeadWidget({
    required this.selectedIndex,
    required this.tuneState,
    required this.onSelectString,
    required this.pulseCtrl,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, constraints) {
      final double w = constraints.maxWidth;
      final double h = constraints.maxHeight;

      // Peg positions: 3 on left (low E, A, D), 3 on right (G, B, high e)
      // Indexed 0–5 matching _standardTuning order
      final List<Offset> pegOffsets = _pegPositions(w, h);

      return Stack(
        children: [
          // Guitar head body
          Center(
            child: CustomPaint(
              size: Size(w * 0.55, h * 0.88),
              painter: _HeadstockPainter(),
            ),
          ),

          // Pegs
          for (int i = 0; i < _standardTuning.length; i++)
            Positioned(
              left:  pegOffsets[i].dx - 28,
              top:   pegOffsets[i].dy - 28,
              child: _PegButton(
                label:        _standardTuning[i].name,
                isSelected:   i == selectedIndex,
                isInTune:     i == selectedIndex && tuneState == _TuneState.inTune,
                pulseCtrl:    pulseCtrl,
                onTap:        () => onSelectString(i),
              ),
            ),
        ],
      );
    });
  }

  List<Offset> _pegPositions(double w, double h) {
    final double cx = w / 2;
    // Left pegs (strings 6=E, 5=A, 4=D) — indices 0,1,2
    // Right pegs (strings 3=G, 2=B, 1=e) — indices 3,4,5
    final double leftX  = cx - w * 0.30;
    final double rightX = cx + w * 0.30;
    final double top    = h * 0.10;
    final double mid    = h * 0.38;
    final double bot    = h * 0.66;

    return [
      Offset(leftX,  top),   // 0: low E
      Offset(leftX,  mid),   // 1: A
      Offset(leftX,  bot),   // 2: D
      Offset(rightX, top),   // 3: G
      Offset(rightX, mid),   // 4: B
      Offset(rightX, bot),   // 5: high e
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _HeadstockPainter — draws a simple Strat-style headstock outline
// ─────────────────────────────────────────────────────────────────────────────

class _HeadstockPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    final bodyPaint = Paint()
      ..color = const Color(0xFF1A1A24)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    // Simplified headstock silhouette
    final path = Path();
    path.moveTo(w * 0.35, 0);
    path.lineTo(w * 0.65, 0);
    // Right side curves
    path.quadraticBezierTo(w * 0.85, 0,      w * 0.9,  h * 0.08);
    path.lineTo(w * 0.9,  h * 0.72);
    path.quadraticBezierTo(w * 0.9,  h * 0.85, w * 0.75, h * 0.92);
    path.lineTo(w * 0.6,  h * 0.98);
    path.lineTo(w * 0.55, h);
    path.lineTo(w * 0.45, h);
    path.lineTo(w * 0.4,  h * 0.98);
    path.lineTo(w * 0.25, h * 0.92);
    path.quadraticBezierTo(w * 0.1, h * 0.85, w * 0.1, h * 0.72);
    path.lineTo(w * 0.1, h * 0.08);
    path.quadraticBezierTo(w * 0.15, 0, w * 0.35, 0);
    path.close();

    canvas.drawPath(path, bodyPaint);
    canvas.drawPath(path, borderPaint);

    // Nut line
    final nutPaint = Paint()
      ..color = Colors.white.withOpacity(0.25)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(w * 0.15, h * 0.06),
      Offset(w * 0.85, h * 0.06),
      nutPaint,
    );

    // String lines (6 vertical lines)
    final stringPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..strokeWidth = 1;
    for (int i = 0; i < 6; i++) {
      final double x = w * 0.18 + i * (w * 0.64 / 5);
      canvas.drawLine(
        Offset(x, h * 0.06),
        Offset(x, h * 0.88),
        stringPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// _PegButton — individual tuning peg with label
// ─────────────────────────────────────────────────────────────────────────────

class _PegButton extends StatelessWidget {
  final String  label;
  final bool    isSelected;
  final bool    isInTune;
  final AnimationController pulseCtrl;
  final VoidCallback onTap;

  const _PegButton({
    required this.label,
    required this.isSelected,
    required this.isInTune,
    required this.pulseCtrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedBuilder(
        animation: pulseCtrl,
        builder: (_, child) {
          double glowRadius = 0;
          if (isInTune) {
            glowRadius = 8 + 6 * pulseCtrl.value;
          }
          return Container(
            width:  56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isInTune
                  ? Colors.greenAccent.withOpacity(0.15)
                  : isSelected
                      ? Colors.white.withOpacity(0.12)
                      : const Color(0xFF1E1E28),
              border: Border.all(
                color: isInTune
                    ? Colors.greenAccent
                    : isSelected
                        ? Colors.white54
                        : Colors.white.withOpacity(0.15),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isInTune
                  ? [
                      BoxShadow(
                        color: Colors.greenAccent.withOpacity(0.4),
                        blurRadius: glowRadius,
                        spreadRadius: glowRadius * 0.3,
                      )
                    ]
                  : isSelected
                      ? [
                          BoxShadow(
                            color: Colors.white.withOpacity(0.08),
                            blurRadius: 8,
                          )
                        ]
                      : null,
            ),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isInTune
                      ? Colors.greenAccent
                      : isSelected
                          ? Colors.white
                          : Colors.white38,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TuningBarPainter — the horizontal tuning indicator bar
// fraction: -1 (50¢ flat) … 0 (in tune) … +1 (50¢ sharp)
// ─────────────────────────────────────────────────────────────────────────────

class _TuningBarPainter extends StatelessWidget {
  final double fraction;
  final Color  stateColor;
  final bool   isActive;

  const _TuningBarPainter({
    required this.fraction,
    required this.stateColor,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 64,
      child: CustomPaint(
        painter: _BarPainter(
          fraction:   fraction,
          stateColor: isActive ? stateColor : Colors.white12,
          isActive:   isActive,
        ),
        size: const Size(double.infinity, 64),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double fraction;
  final Color  stateColor;
  final bool   isActive;

  _BarPainter({
    required this.fraction,
    required this.stateColor,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double w  = size.width;
    final double h  = size.height;
    final double cx = w / 2;
    final double cy = h / 2;

    // ── Background track ────────────────────────────────────────────────────
    final trackPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: w, height: 8),
      const Radius.circular(4),
    );
    canvas.drawRRect(trackRect, trackPaint);

    // ── Tick marks ──────────────────────────────────────────────────────────
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..strokeWidth = 1;
    for (int i = -4; i <= 4; i++) {
      final double x = cx + i * (w / 8);
      final double tickH = i == 0 ? 20.0 : 10.0;
      canvas.drawLine(
        Offset(x, cy - tickH / 2),
        Offset(x, cy + tickH / 2),
        tickPaint,
      );
    }

    // ── Centre marker ───────────────────────────────────────────────────────
    final centrePaint = Paint()
      ..color = Colors.white.withOpacity(0.4)
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(cx, cy - 16),
      Offset(cx, cy + 16),
      centrePaint,
    );

    if (!isActive) return;

    // ── Active indicator bar ─────────────────────────────────────────────────
    final double barX  = cx + fraction * (w / 2) * 0.9;
    const double barHalfW = 3.0;

    // Glow
    final glowPaint = Paint()
      ..color = stateColor.withOpacity(0.25)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(barX, cy), width: barHalfW * 6, height: 36),
        const Radius.circular(4),
      ),
      glowPaint,
    );

    // Bar
    final barPaint = Paint()
      ..color = stateColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(barX, cy), width: barHalfW * 2, height: 32),
        const Radius.circular(3),
      ),
      barPaint,
    );

    // Labels
    final flatTp = TextPainter(
      text: TextSpan(
        text: '♭',
        style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.25),
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    flatTp.paint(canvas, Offset(8, cy - flatTp.height / 2));

    final sharpTp = TextPainter(
      text: TextSpan(
        text: '♯',
        style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.25),
            fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    sharpTp.paint(
        canvas, Offset(w - sharpTp.width - 8, cy - sharpTp.height / 2));
  }

  @override
  bool shouldRepaint(covariant _BarPainter old) =>
      old.fraction != fraction ||
      old.stateColor != stateColor ||
      old.isActive != isActive;
}

// ─────────────────────────────────────────────────────────────────────────────
// _MicButton
// ─────────────────────────────────────────────────────────────────────────────

class _MicButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onTap;

  const _MicButton({required this.isListening, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 56,
        decoration: BoxDecoration(
          color: isListening
              ? Colors.redAccent.withOpacity(0.12)
              : Colors.greenAccent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isListening
                ? Colors.redAccent.withOpacity(0.45)
                : Colors.greenAccent.withOpacity(0.35),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isListening ? Icons.stop : Icons.mic,
              color: isListening ? Colors.redAccent : Colors.greenAccent,
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              isListening ? 'Stop' : 'Start Tuning',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color:
                    isListening ? Colors.redAccent : Colors.greenAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _LiveBadge
// ─────────────────────────────────────────────────────────────────────────────

class _LiveBadge extends StatelessWidget {
  final AnimationController controller;
  const _LiveBadge({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      FadeTransition(
        opacity: controller,
        child: Container(
          width: 7, height: 7,
          decoration: const BoxDecoration(
              shape: BoxShape.circle, color: Colors.redAccent),
        ),
      ),
      const SizedBox(width: 5),
      const Text('LIVE',
          style: TextStyle(
              fontSize: 11,
              color: Colors.redAccent,
              letterSpacing: 1.4,
              fontWeight: FontWeight.bold)),
    ]);
  }
}