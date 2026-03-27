import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/audio_service.dart';
import '../dsp/dsp_engine.dart';
import 'chord_library.dart';
import 'chord_diagram_widget.dart';

class ChordPracticePage extends StatefulWidget {
  const ChordPracticePage({super.key});

  @override
  State<ChordPracticePage> createState() => _ChordPracticePageState();
}

class _ChordPracticePageState extends State<ChordPracticePage>
    with SingleTickerProviderStateMixin {

  final AudioService _audio = AudioService();
  bool _isListening = false;

  // ← was: ChordLibrary.all.first — allChords is the top-level list
  ChordData _selected = allChords.first;

  // Detection state
  String _detectedChord  = '—';
  double _mlConfidence   = 0.0;
  double _dspConfidence  = 0.0;
  double _rms            = 0.0;
  bool   _isCorrect      = false;
  int    _correctFrames  = 0;
  int _incorrectFrames = 0;                    
  static const int _correctHoldFrames = 6;
  static const int _incorrectGraceFrames = 12;

  _Filter _filter = _Filter.all;

  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
  }

  @override
  void dispose() {
    _audio.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ── Audio ─────────────────────────────────────────────────────────────────

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _audio.stop();
      if (mounted) {
        setState(() {
          _isListening  = false;
          _detectedChord = '—';
          _mlConfidence  = 0;
          _dspConfidence = 0;
          _rms           = 0;
          _isCorrect     = false;
          _correctFrames = 0;
          _incorrectFrames = 0;
        });
      }
      return;
    }
    _audio.resetDSP();
    final ok = await _audio.startWithDSP(_onDSPResult);
    if (!mounted) return;
    if (ok) {
      setState(() => _isListening = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not access microphone')),
      );
    }
  }

  void _onDSPResult(DSPResult result) {
    if (!mounted) return;

    final bool mlGood = result.mlConfidence >= 0.55 &&
      result.mlPrediction.isNotEmpty &&
      result.mlPrediction != 'Unknown' &&
      !result.mlPrediction.toLowerCase().contains('minor');

    // DSP already reports a simplified chord name in result.chord.
    // Only simplify the raw ML prediction to avoid double‑simplifying
    // minor chords.
    final bool   useML      = mlGood;
    final String simplified = useML
        ? simplifyChordName(result.mlPrediction)
        : result.chord;
    final double conf       = useML ? result.mlConfidence : result.confidence;

    // ← was: _selected.dspMatchName — correct field is mlLabel
    final bool correct = simplified.trim().toLowerCase() ==
        _selected.mlLabel.trim().toLowerCase() &&
        conf >= 0.45 &&
        result.rmsLevel >= 0.008;

    if (correct) {
      _correctFrames++;
      _incorrectFrames = 0;          // reset grace counter on any correct frame
    } else {
      _incorrectFrames++;
      // Only reset correct streak once grace period is exhausted
      if (_incorrectFrames >= _incorrectGraceFrames) {
        _correctFrames   = 0;
        _incorrectFrames = 0;
      }
    }

    final bool solidHit = _correctFrames >= _correctHoldFrames;

    if (solidHit && !_isCorrect) {
      HapticFeedback.mediumImpact();
      _pulseController.forward(from: 0);
    }

    setState(() {
      // UI smoothing: only update the visible detected label when the
      // underlying confidence is reasonably high or we have a solid hit.
      if (simplified.isNotEmpty && (conf >= 0.45 || solidHit)) {
        _detectedChord = simplified;
      } else if (simplified.isEmpty) {
        _detectedChord = '—';
      }

      _mlConfidence  = result.mlConfidence;
      _dspConfidence = result.confidence;
      _rms           = result.rmsLevel;
      _isCorrect     = solidHit;
    });
  }

  // ── Chord selection ───────────────────────────────────────────────────────

  List<ChordData> get _visibleChords {
    switch (_filter) {
      case _Filter.majors: return majorChords; // ← was ChordLibrary.majors
      case _Filter.minors: return minorChords; // ← was ChordLibrary.minors
      case _Filter.all:    return allChords;   // ← was ChordLibrary.all
    }
  }

  void _selectChord(ChordData c) {
    if (c == _selected) return;
    setState(() {
      _selected      = c;
      _isCorrect     = false;
      _correctFrames = 0;
      _incorrectFrames = 0;
      _detectedChord = '—';
    });
    _audio.resetDSP();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text('Chord Practice',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        actions: [
          if (_isListening)
            Padding(
                padding: const EdgeInsets.only(right: 16),
                child: _LiveBadge()),
        ],
      ),
      body: Column(
        children: [
          _buildChordSelector(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildDiagramAndFeedback(),
                  const SizedBox(height: 20),
                  if (_isListening) ...[
                    _buildDetectionPanel(),
                    const SizedBox(height: 20),
                  ],
                  _buildTips(),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
          _buildMicButton(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ── Chord selector ────────────────────────────────────────────────────────

  Widget _buildChordSelector() {
    return Container(
      color: const Color(0xFF0A0A0F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              _filterChip('All',   _Filter.all),
              const SizedBox(width: 8),
              _filterChip('Major', _Filter.majors),
              const SizedBox(width: 8),
              _filterChip('Minor', _Filter.minors),
            ]),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _visibleChords.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final c   = _visibleChords[i];
                final sel = c == _selected;
                return GestureDetector(
                  onTap: () => _selectChord(c),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: sel
                          ? Colors.blueAccent.withOpacity(0.2)
                          : const Color(0xFF13131A),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: sel
                            ? Colors.blueAccent
                            : Colors.white12,
                        width: sel ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      c.displayName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            sel ? FontWeight.bold : FontWeight.normal,
                        color: sel ? Colors.blueAccent : Colors.white60,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),
        ],
      ),
    );
  }

  Widget _filterChip(String label, _Filter f) {
    final sel = _filter == f;
    return GestureDetector(
      onTap: () => setState(() => _filter = f),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: sel
              ? Colors.white.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: sel ? Colors.white : Colors.white38,
            fontWeight: sel ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ── Diagram + feedback ────────────────────────────────────────────────────

  Widget _buildDiagramAndFeedback() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (_, child) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isCorrect
                  ? Colors.greenAccent.withOpacity(0.5)
                  : Colors.white.withOpacity(0.07),
              width: _isCorrect ? 1.5 : 1,
            ),
            boxShadow: _isCorrect
                ? [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.08),
                      blurRadius: 24,
                      spreadRadius: 4,
                    )
                  ]
                : null,
          ),
          child: child,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ChordDiagramWidget(
            chord: _selected,
            size: ChordDiagramSize.large,
            showName: true,
          ),
          const SizedBox(width: 24),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selected.fullName,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  // ← was: _selected.isMajor — correct is !_selected.isMinor
                  !_selected.isMinor ? 'Major chord' : 'Minor chord',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.4)),
                ),
                const SizedBox(height: 20),
                if (_isListening) _buildStatusBadge(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge() {
    if (_rms < 0.008) {
      return _badge(
          'Play the chord', Colors.white24, Icons.music_note_outlined);
    }
    if (_isCorrect) {
      return _badge('Correct!', Colors.greenAccent, Icons.check_circle);
    }
    return _badge(
      _detectedChord == '—' ? 'Detecting…' : 'Heard: $_detectedChord',
      Colors.orangeAccent,
      Icons.graphic_eq,
    );
  }

  Widget _badge(String label, Color color, IconData icon) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  fontSize: 13,
                  color: color,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Detection panel ───────────────────────────────────────────────────────

  Widget _buildDetectionPanel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detection',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.35),
                  letterSpacing: 0.8)),
          const SizedBox(height: 12),
          Row(children: [
            _detCell('Detected', _detectedChord,
                _isCorrect ? Colors.greenAccent : Colors.white70),
            _vdivider(),
            _detCell(
                'ML',
                '${(_mlConfidence * 100).toStringAsFixed(0)}%',
                _mlConfidence >= 0.55
                    ? Colors.greenAccent
                    : Colors.white38),
            _vdivider(),
            _detCell(
                'DSP',
                '${(_dspConfidence * 100).toStringAsFixed(0)}%',
                Colors.white38),
            _vdivider(),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Level',
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.35))),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: (_rms / 0.5).clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: Colors.white10,
                      valueColor: AlwaysStoppedAnimation(
                        _rms > 0.35
                            ? Colors.redAccent
                            : _rms > 0.01
                                ? Colors.greenAccent
                                : Colors.white24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _detCell(String label, String value, Color c) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.35))),
              const SizedBox(height: 2),
              Text(value,
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: c)),
            ]),
      );

  Widget _vdivider() => Container(
        width: 1,
        height: 32,
        color: Colors.white10,
        margin: const EdgeInsets.only(right: 14),
      );

  // ── Tips ──────────────────────────────────────────────────────────────────

  Widget _buildTips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.lightbulb_outline,
                size: 15, color: Colors.amber),
            const SizedBox(width: 6),
            Text('Tips',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber.withOpacity(0.9))),
          ]),
          const SizedBox(height: 10),
          ..._selected.tips.map((tip) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.amber.withOpacity(0.5)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(tip,
                          style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withOpacity(0.7),
                              height: 1.4)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  // ── Mic button ────────────────────────────────────────────────────────────

  Widget _buildMicButton() {
    return GestureDetector(
      onTap: _toggleListening,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        height: 56,
        decoration: BoxDecoration(
          color: _isListening
              ? Colors.redAccent.withOpacity(0.12)
              : Colors.greenAccent.withOpacity(0.10),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _isListening
                ? Colors.redAccent.withOpacity(0.45)
                : Colors.greenAccent.withOpacity(0.35),
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
              size: 20,
            ),
            const SizedBox(width: 10),
            Text(
              _isListening ? 'Stop Listening' : 'Start Listening',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: _isListening
                      ? Colors.redAccent
                      : Colors.greenAccent),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

enum _Filter { all, majors, minors }

class _LiveBadge extends StatefulWidget {
  @override
  State<_LiveBadge> createState() => _LiveBadgeState();
}

class _LiveBadgeState extends State<_LiveBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      FadeTransition(
        opacity: _c,
        child: Container(
          width: 7,
          height: 7,
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