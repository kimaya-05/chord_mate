import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../services/mastery_service.dart';
import '../services/pb_service.dart';
import '../chords/chord_library.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The 14 practice chords (A–G major and minor, no sharps)
// ─────────────────────────────────────────────────────────────────────────────

final List<ChordData> _practiceChords =
    allChords.where((c) => !c.name.contains('#')).toList();

// The same suggested pairs from transition_drill_page
const List<_TransitionPair> _transitionPairs = [
  _TransitionPair('A minor', 'C',       'Am → C'),
  _TransitionPair('A minor', 'E minor', 'Am → Em'),
  _TransitionPair('C',       'G',       'C → G'),
  _TransitionPair('G',       'D',       'G → D'),
  _TransitionPair('E',       'A',       'E → A'),
  _TransitionPair('C',       'F',       'C → F'),
  _TransitionPair('G',       'E minor', 'G → Em'),
  _TransitionPair('D',       'A',       'D → A'),
  _TransitionPair('B minor', 'G',       'Bm → G'),
  _TransitionPair('D',       'B minor', 'D → Bm'),
  _TransitionPair('F',       'B minor', 'F → Bm'),
  _TransitionPair('D minor', 'F',       'Dm → F'),
  _TransitionPair('B',       'E',       'B → E'),
  _TransitionPair('A minor', 'D minor', 'Am → Dm'),
];

class _TransitionPair {
  final String labelA;
  final String labelB;
  final String display;
  const _TransitionPair(this.labelA, this.labelB, this.display);
}

// ─────────────────────────────────────────────────────────────────────────────
// Stats Page
// ─────────────────────────────────────────────────────────────────────────────

class StatsPage extends StatefulWidget {
  const StatsPage({super.key});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _StatsPageState extends State<StatsPage>
    with SingleTickerProviderStateMixin {
  bool _loading = true;

  // Mastery data
  int _masteredCount = 0;
  final Map<String, int> _hitCounts = {};

  // Personal bests
  final Map<String, PersonalBest?> _personalBests = {};

  late AnimationController _animCtrl;
  late Animation<double> _animProgress;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animProgress = CurvedAnimation(
      parent: _animCtrl,
      curve: Curves.easeOutCubic,
    );
    _loadStats();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    // Load mastery counts for all 14 practice chords
    int mastered = 0;
    for (final chord in _practiceChords) {
      final hits = await MasteryService.getHitCount(chord.mlLabel);
      _hitCounts[chord.mlLabel] = hits;
      if (MasteryService.isMastered(hits)) mastered++;
    }

    // Load personal bests for all transition pairs
    for (final pair in _transitionPairs) {
      final key = '${pair.labelA}__${pair.labelB}';
      final pb = await PbService.load(pair.labelA, pair.labelB);
      _personalBests[key] = pb;
    }

    if (mounted) {
      setState(() {
        _masteredCount = mastered;
        _loading = false;
      });
      _animCtrl.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white54),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Your Stats',
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.greenAccent))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMasterySection(),
                  const SizedBox(height: 32),
                  _buildPersonalBestsSection(),
                ],
              ),
            ),
    );
  }

  // ── Mastery Section ──────────────────────────────────────────────────────

  Widget _buildMasterySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Chord Mastery'),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            children: [
              // Circular chart
              AnimatedBuilder(
                animation: _animProgress,
                builder: (context, child) {
                  return SizedBox(
                    width: 180,
                    height: 180,
                    child: CustomPaint(
                      painter: _MasteryRingPainter(
                        mastered: _masteredCount,
                        total: 14,
                        progress: _animProgress.value,
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${(_masteredCount * _animProgress.value).round()}',
                              style: const TextStyle(
                                fontSize: 42,
                                fontWeight: FontWeight.w800,
                                color: Colors.greenAccent,
                                letterSpacing: -1,
                                height: 1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'of 14',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.4),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'mastered',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.25),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // Chord pills grid
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: _practiceChords.map((chord) {
                  final hits = _hitCounts[chord.mlLabel] ?? 0;
                  final mastered = MasteryService.isMastered(hits);
                  return _chordPill(chord.displayName, hits, mastered);
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _chordPill(String name, int hits, bool mastered) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: mastered
            ? Colors.greenAccent.withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: mastered
              ? Colors.greenAccent.withOpacity(0.4)
              : Colors.white.withOpacity(0.08),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (mastered)
            const Padding(
              padding: EdgeInsets.only(right: 5),
              child: Icon(Icons.check_circle, size: 13, color: Colors.greenAccent),
            ),
          Text(
            name,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: mastered ? Colors.greenAccent : Colors.white.withOpacity(0.5),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '$hits/5',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: mastered
                  ? Colors.greenAccent.withOpacity(0.6)
                  : Colors.white.withOpacity(0.25),
            ),
          ),
        ],
      ),
    );
  }

  // ── Personal Bests Section ───────────────────────────────────────────────

  Widget _buildPersonalBestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Transition Personal Bests'),
        const SizedBox(height: 16),
        ..._transitionPairs.map((pair) {
          final key = '${pair.labelA}__${pair.labelB}';
          final pb = _personalBests[key];
          return _buildPbRow(pair.display, pb);
        }),
      ],
    );
  }

  Widget _buildPbRow(String pairLabel, PersonalBest? pb) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: pb != null
              ? Colors.amber.withOpacity(0.15)
              : Colors.white.withOpacity(0.06),
        ),
      ),
      child: Row(
        children: [
          // Pair label
          SizedBox(
            width: 90,
            child: Text(
              pairLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: pb != null ? Colors.white : Colors.white.withOpacity(0.4),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // PB data or placeholder
          Expanded(
            child: pb != null
                ? Row(
                    children: [
                      const Icon(Icons.emoji_events_rounded,
                          size: 14, color: Colors.amber),
                      const SizedBox(width: 8),
                      Text(
                        '${pb.correct}/${pb.total}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Accuracy bar
                      Expanded(
                        child: _buildAccuracyBar(pb.accuracy),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${(pb.accuracy * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _accuracyColor(pb.accuracy),
                        ),
                      ),
                    ],
                  )
                : Text(
                    'No record yet',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.2),
                      fontStyle: FontStyle.italic,
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccuracyBar(double accuracy) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(3),
      ),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: accuracy.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _accuracyColor(accuracy).withOpacity(0.7),
                _accuracyColor(accuracy),
              ],
            ),
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    );
  }

  Color _accuracyColor(double accuracy) {
    if (accuracy >= 0.9) return Colors.greenAccent;
    if (accuracy >= 0.7) return Colors.amber;
    if (accuracy >= 0.5) return Colors.orangeAccent;
    return Colors.redAccent;
  }

  Widget _sectionLabel(String label) => Text(
        label.toUpperCase(),
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white.withOpacity(0.3),
            letterSpacing: 1.4),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Custom painter for the mastery ring
// ─────────────────────────────────────────────────────────────────────────────

class _MasteryRingPainter extends CustomPainter {
  final int mastered;
  final int total;
  final double progress;

  _MasteryRingPainter({
    required this.mastered,
    required this.total,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 10.0;

    // Background ring
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // Individual segment ticks (14 segments)
    final tickPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    for (int i = 0; i < total; i++) {
      final angle = -math.pi / 2 + (2 * math.pi * i / total);
      final outer = Offset(
        center.dx + (radius + strokeWidth / 2 + 2) * math.cos(angle),
        center.dy + (radius + strokeWidth / 2 + 2) * math.sin(angle),
      );
      final inner = Offset(
        center.dx + (radius - strokeWidth / 2 - 2) * math.cos(angle),
        center.dy + (radius - strokeWidth / 2 - 2) * math.sin(angle),
      );
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Progress arc
    if (mastered > 0) {
      final sweepAngle = (2 * math.pi * mastered / total) * progress;
      final progressPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          startAngle: -math.pi / 2,
          endAngle: -math.pi / 2 + 2 * math.pi,
          colors: const [
            Color(0xFF69F0AE),
            Color(0xFF00E676),
            Color(0xFF69F0AE),
          ],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );

      // Glow effect
      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth + 6
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8)
        ..color = Colors.greenAccent.withOpacity(0.2);

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        glowPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MasteryRingPainter oldDelegate) =>
      oldDelegate.mastered != mastered ||
      oldDelegate.total != total ||
      oldDelegate.progress != progress;
}
