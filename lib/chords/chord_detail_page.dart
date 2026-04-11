import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../services/audio_service.dart';
import '../dsp/dsp_engine.dart';
import 'chord_voicings.dart';
import 'chord_diagram_widget.dart';
import '../ui/user_home_page.dart';
import '../services/mastery_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Detection state
// ─────────────────────────────────────────────────────────────────────────────

enum _FeedbackState { idle, listening, correct, wrong }

// ─────────────────────────────────────────────────────────────────────────────
// ChordDetailPage
// ─────────────────────────────────────────────────────────────────────────────

class ChordDetailPage extends StatefulWidget {
  final PracticeChord chord;

  const ChordDetailPage({super.key, required this.chord});

  @override
  State<ChordDetailPage> createState() => _ChordDetailPageState();
}

class _ChordDetailPageState extends State<ChordDetailPage>
    with TickerProviderStateMixin {

  // ── Audio ──────────────────────────────────────────────────────────────────
  final AudioService _audio = AudioService();
  final FlutterSoundPlayer _chimePlayer = FlutterSoundPlayer();
  bool _isListening = false;
  bool _chimeReady  = false;

  // ── Detection ──────────────────────────────────────────────────────────────
  _FeedbackState _state      = _FeedbackState.idle;
  String  _detectedLabel     = '—';
  double  _confidence        = 0;
  double  _rms               = 0;
  int     _correctStreak     = 0;
  static const int _streakThreshold = 6;

  // ── Voicing swipe ──────────────────────────────────────────────────────────
  late final PageController _pageController;
  int _currentPage = 0;

  // ── Pulse animation ────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final Animation<double>   _pulseAnim;

  // ── Live badge ─────────────────────────────────────────────────────────────
  late final AnimationController _liveCtrl;

  int  _hitCount        = 0;
  bool _justMastered    = false;
  bool _hitRecordedThisSession = false;

  Widget _buildMasteryBanner() {
    final mastered = MasteryService.isMastered(_hitCount);
    if (!mastered) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: mastered ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.amber.withOpacity(0.09),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber.withOpacity(0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.emoji_events_rounded,
                size: 16, color: Colors.amber),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _justMastered
                    ? 'Mastery achieved! Keep it up 🎸'
                    : 'Mastery achieved',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.amber,
                ),
              ),
            ),
            Text(
              '${_hitCount} solid hits',
              style: TextStyle(
                fontSize: 11,
                color: Colors.amber.withOpacity(0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    RecentChordsStore().add(widget.chord);
    _pageController = PageController(viewportFraction: 0.85);

    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseAnim = Tween<double>(begin: 1.0, end: 1.04).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );

    _liveCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);

    _initChime();
    MasteryService.getHitCount(widget.chord.mlLabel).then((count) {
      if (mounted) setState(() => _hitCount = count);
    });
  }

  @override
  void dispose() {
    _audio.dispose();
    _chimePlayer.closePlayer();
    _pulseCtrl.dispose();
    _liveCtrl.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // ── Chime ──────────────────────────────────────────────────────────────────

  Future<void> _initChime() async {
    await _chimePlayer.openPlayer();
    setState(() => _chimeReady = true);
  }

  Future<void> _playChime() async {
    if (!_chimeReady) return;
    try {
      final Uint8List pcm = _generateChimePcm();
      await _chimePlayer.startPlayer(
        fromDataBuffer: pcm,
        codec: Codec.pcm16,
        numChannels: 1,
        sampleRate: 44100,
      );
    } catch (_) {}
  }

  /// Generates a short pleasant two-tone chime (C5 + E5) as raw PCM16.
  Uint8List _generateChimePcm() {
    const int   sampleRate  = 44100;
    const double durationSec = 0.35;
    final int   totalSamples = (sampleRate * durationSec).toInt();
    // Two sine tones mixed together
    const List<double> freqs = [523.25, 659.25]; // C5, E5
    final Int16List pcm = Int16List(totalSamples);

    for (int i = 0; i < totalSamples; i++) {
      final double t     = i / sampleRate;
      final double decay = math.exp(-t / 0.12);
      double sample = 0;
      for (final f in freqs) {
        sample += 0.4 * math.sin(2 * math.pi * f * t) * decay;
      }
      pcm[i] = (sample * 32767).toInt().clamp(-32768, 32767);
    }
    return pcm.buffer.asUint8List();
  }

  // ── Mic toggle ─────────────────────────────────────────────────────────────

  Future<void> _toggleListen() async {
    if (_isListening) {
      // Stopping — record a hit if the user got it correct at least once
       if (_hitRecordedThisSession) {
        MasteryService.recordHit(widget.chord.mlLabel).then((newCount) {
          if (!mounted) return;
          setState(() {
            _justMastered = !MasteryService.isMastered(_hitCount) &&
                            MasteryService.isMastered(newCount);
            _hitCount = newCount;
          });
        });
      }

      await _audio.stop();
      if (mounted) {
        setState(() {
          _isListening          = false;
          _state                = _FeedbackState.idle;
          _detectedLabel        = '—';
          _confidence           = 0;
          _correctStreak        = 0;
          _hitRecordedThisSession = false;
        });
      }
      return;
    }

    // Starting — reset session flag
    _hitRecordedThisSession = false;
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

    final double rms = result.rmsLevel;

    if (rms < 0.008) {
      if (mounted) {
        setState(() {
          _rms        = rms;
          _state      = _FeedbackState.listening;
          _correctStreak = 0;
        });
      }
      return;
    }

    // Use ML only for major chords — the ML model is unreliable for minor.
    // For minor chords, always fall back to the DSP chroma classifier which
    // explicitly checks the third interval and is more accurate for minor.
    final bool mlGood = result.mlConfidence >= 0.55 &&
        result.mlPrediction.isNotEmpty &&
        result.mlPrediction != 'Unknown' &&
        !result.mlPrediction.toLowerCase().contains('minor');

    // The DSP result.chord is already simplified; only simplify the raw
    // ML prediction to avoid double‑simplifying minor chords.
    final bool   useML      = mlGood;
    final String simplified = useML
        ? simplifyChordName(result.mlPrediction)
        : result.chord;
    final double conf       = useML ? result.mlConfidence : result.confidence;

    final bool match = simplified.toLowerCase() ==
        widget.chord.mlLabel.toLowerCase();

    if (match) {
      _correctStreak++;
    } else {
      _correctStreak = 0;
    }

    final bool solidHit = _correctStreak >= _streakThreshold;

    if (solidHit && _state != _FeedbackState.correct) {
    HapticFeedback.mediumImpact();
    _playChime();
    _pulseCtrl.repeat(reverse: true);
    _hitRecordedThisSession = true; 
    }

    if (mounted) {
      setState(() {
        _rms        = rms;
        _confidence = conf;

        // UI smoothing: only update the visible label when confidence
        // is reasonably high or we have a solid hit to reduce flicker.
        if (simplified.isNotEmpty && (conf >= 0.45 || solidHit)) {
          _detectedLabel = simplified;
        }

        // Treat low‑confidence frames as "listening" instead of "wrong"
        // so the card styling doesn't rapidly flash red.
        _state = solidHit
            ? _FeedbackState.correct
            : (conf >= 0.45
                ? _FeedbackState.wrong
                : _FeedbackState.listening);
      });
    }
  }

  // ── Colours ────────────────────────────────────────────────────────────────

  Color get _accentColor =>
      widget.chord.isMinor ? const Color(0xFF7E8CE0) : Colors.greenAccent;

  Color get _feedbackColor {
    switch (_state) {
      case _FeedbackState.correct:   return Colors.greenAccent;
      case _FeedbackState.wrong:     return Colors.redAccent;
      case _FeedbackState.listening: return Colors.white24;
      case _FeedbackState.idle:      return Colors.white12;
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          widget.chord.fullName,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: Colors.white,
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
        child: Column(
          children: [
            // ── Voicing page indicator ───────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Swipe to see voicings',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                  Row(
                    children: List.generate(
                      widget.chord.voicings.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width:  _currentPage == i ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: _currentPage == i
                              ? _accentColor
                              : Colors.white24,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Swipeable chord diagram cards ────────────────────────
            SizedBox(
              height: 340,
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.chord.voicings.length,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemBuilder: (_, i) {
                  final voicing = widget.chord.voicings[i];
                  return _VoicingCard(
                    voicing:       voicing,
                    feedbackState: _state,
                    feedbackColor: _feedbackColor,
                    accentColor:   _accentColor,
                    pulseAnim:     _pulseAnim,
                    isActive:      i == _currentPage,
                  );
                },
              ),
            ),

            // ── Detection feedback strip ─────────────────────────────
            if (_isListening)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 8),
                child: _DetectionStrip(
                  feedbackState: _state,
                  detectedLabel: _detectedLabel,
                  confidence:    _confidence,
                  rms:           _rms,
                  targetLabel:   widget.chord.displayName,
                  feedbackColor: _feedbackColor,
                ),
              ),

            const Spacer(),

            _buildMasteryBanner(),
            // ── Tip from current voicing ─────────────────────────────
            if (widget.chord.voicings[_currentPage].data.tips.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: _accentColor.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 14,
                          color: _accentColor.withOpacity(0.7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          widget.chord.voicings[_currentPage].data.tips[0],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.55),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 16),

            // ── Mic button ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
              child: GestureDetector(
                onTap: _toggleListen,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    color: _isListening
                        ? Colors.redAccent.withOpacity(0.12)
                        : _accentColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _isListening
                          ? Colors.redAccent.withOpacity(0.5)
                          : _accentColor.withOpacity(0.5),
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
                            : _accentColor,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        _isListening
                            ? 'Stop Listening'
                            : 'Start Listening',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _isListening
                              ? Colors.redAccent
                              : _accentColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _VoicingCard  — one swipeable card with a pulsing diagram
// ─────────────────────────────────────────────────────────────────────────────

class _VoicingCard extends StatelessWidget {
  final ChordVoicing     voicing;
  final _FeedbackState   feedbackState;
  final Color            feedbackColor;
  final Color            accentColor;
  final Animation<double> pulseAnim;
  final bool             isActive;

  const _VoicingCard({
    required this.voicing,
    required this.feedbackState,
    required this.feedbackColor,
    required this.accentColor,
    required this.pulseAnim,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: pulseAnim,
      builder: (_, child) {
        final double scale =
            feedbackState == _FeedbackState.correct && isActive
                ? pulseAnim.value
                : 1.0;
        return Transform.scale(scale: scale, child: child);
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isActive
                ? _borderColor(feedbackState, feedbackColor, accentColor)
                : Colors.white.withOpacity(0.06),
            width: isActive &&
                    feedbackState != _FeedbackState.idle &&
                    feedbackState != _FeedbackState.listening
                ? 2
                : 1,
          ),
          boxShadow: isActive &&
                  feedbackState == _FeedbackState.correct
              ? [
                  BoxShadow(
                    color: Colors.greenAccent.withOpacity(0.12),
                    blurRadius: 24,
                    spreadRadius: 4,
                  )
                ]
              : isActive && feedbackState == _FeedbackState.wrong
                  ? [
                      BoxShadow(
                        color: Colors.redAccent.withOpacity(0.10),
                        blurRadius: 16,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Voicing label
            Text(
              voicing.label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.4),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Chord diagram — colour shifts with feedback
            ChordDiagramWidget(
              chord: voicing.data,
              size:  ChordDiagramSize.large,
              showName: false,
            ),

            const SizedBox(height: 12),

            // Feedback icon row
            if (feedbackState == _FeedbackState.correct && isActive)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle,
                      color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 6),
                  const Text('Correct!',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              )
            else if (feedbackState == _FeedbackState.wrong && isActive)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.cancel, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 6),
                  const Text('Keep trying',
                      style: TextStyle(
                          color: Colors.redAccent,
                          fontSize: 14,
                          fontWeight: FontWeight.w600)),
                ],
              )
            else
              const SizedBox(height: 22),
          ],
        ),
      ),
    );
  }

  Color _borderColor(
      _FeedbackState state, Color feedbackColor, Color accent) {
    switch (state) {
      case _FeedbackState.correct:   return Colors.greenAccent.withOpacity(0.6);
      case _FeedbackState.wrong:     return Colors.redAccent.withOpacity(0.5);
      case _FeedbackState.listening: return accent.withOpacity(0.3);
      case _FeedbackState.idle:      return Colors.white.withOpacity(0.07);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _DetectionStrip  — shows detected chord, confidence, level bar
// ─────────────────────────────────────────────────────────────────────────────

class _DetectionStrip extends StatelessWidget {
  final _FeedbackState feedbackState;
  final String         detectedLabel;
  final double         confidence;
  final double         rms;
  final String         targetLabel;
  final Color          feedbackColor;

  const _DetectionStrip({
    required this.feedbackState,
    required this.detectedLabel,
    required this.confidence,
    required this.rms,
    required this.targetLabel,
    required this.feedbackColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: feedbackColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          // Detected label
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Heard',
                    style: TextStyle(
                        fontSize: 10,
                        color: Colors.white.withOpacity(0.35),
                        letterSpacing: 0.8)),
                const SizedBox(height: 2),
                Text(
                  rms < 0.008 ? '—' : detectedLabel,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: feedbackColor,
                  ),
                ),
              ],
            ),
          ),

          // Divider
          Container(
              width: 1, height: 36, color: Colors.white10),
          const SizedBox(width: 16),

          // Level bar
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Level',
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.35),
                      letterSpacing: 0.8)),
              const SizedBox(height: 6),
              SizedBox(
                width: 60,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    value: (rms / 0.5).clamp(0.0, 1.0),
                    minHeight: 6,
                    backgroundColor: Colors.white10,
                    valueColor: AlwaysStoppedAnimation(
                      rms > 0.35
                          ? Colors.redAccent
                          : rms > 0.01
                              ? Colors.greenAccent
                              : Colors.white24,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
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

