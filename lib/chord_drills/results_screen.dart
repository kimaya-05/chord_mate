import 'package:flutter/material.dart';
import '../chords/chord_library.dart';
import 'drill_screen.dart';

class ResultsScreen extends StatelessWidget {
  final ChordData chordA;
  final ChordData chordB;
  final int bpm;
  final int correct;
  final int total;
  final List<TransitionResult> results;
 
  const ResultsScreen({
    required this.chordA,
    required this.chordB,
    required this.bpm,
    required this.correct,
    required this.total,
    required this.results,
  });
 
  double get accuracy => total == 0 ? 0 : correct / total;
 
  String get _grade {
    if (accuracy >= 0.9) return 'Excellent';
    if (accuracy >= 0.75) return 'Good';
    if (accuracy >= 0.5) return 'Needs work';
    return 'Keep practicing';
  }
 
  Color get _gradeColor {
    if (accuracy >= 0.9) return Colors.greenAccent;
    if (accuracy >= 0.75) return Colors.lightGreenAccent;
    if (accuracy >= 0.5) return Colors.amber;
    return Colors.redAccent;
  }
 
  String get _tip {
    if (accuracy >= 0.9) {
      return 'Great clean transitions! Try increasing the BPM by 5–10.';
    }
    if (accuracy >= 0.75) {
      return 'Solid. Slow down by 5 BPM and focus on the problem beats.';
    }
    if (accuracy >= 0.5) {
      return 'Try reducing BPM by 10–15 and practice the pivot finger — '
          'keep one finger touching the strings during the switch.';
    }
    return 'Take it slow — practice each chord individually first, '
        'then try at ${(bpm * 0.6).round()} BPM.';
  }
 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text('Drill Results',
            style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Colors.white)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Summary card ────────────────────────────────────────
            _buildSummaryCard(),
            const SizedBox(height: 20),
 
            // ── Tip ─────────────────────────────────────────────────
            _buildTipCard(),
            const SizedBox(height: 24),
 
            // ── Beat-by-beat breakdown ──────────────────────────────
            if (results.isNotEmpty) ...[
              _sectionLabel('Beat-by-beat'),
              const SizedBox(height: 10),
              _buildBeatGrid(),
              const SizedBox(height: 24),
            ],
 
            // ── Actions ─────────────────────────────────────────────
            _buildActions(context),
          ],
        ),
      ),
    );
  }
 
  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Column(
        children: [
          // Pair label
          Text(
            '${chordA.displayName}  ↔  ${chordB.displayName}',
            style: TextStyle(
                fontSize: 13, color: Colors.white.withOpacity(0.4)),
          ),
          const SizedBox(height: 14),
 
          // Big accuracy ring
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 110,
                height: 110,
                child: CircularProgressIndicator(
                  value: accuracy,
                  strokeWidth: 8,
                  backgroundColor: Colors.white.withOpacity(0.07),
                  valueColor:
                      AlwaysStoppedAnimation<Color>(_gradeColor),
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${(accuracy * 100).round()}%',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: _gradeColor),
                  ),
                  Text(
                    _grade,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4)),
                  ),
                ],
              ),
            ],
          ),
 
          const SizedBox(height: 20),
 
          // Stats row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statCol('$correct', 'Correct'),
              _statCol('${total - correct}', 'Missed'),
              _statCol('$total', 'Total'),
              _statCol('$bpm', 'BPM'),
            ],
          ),
        ],
      ),
    );
  }
 
  Widget _statCol(String value, String label) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white)),
        const SizedBox(height: 2),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: Colors.white.withOpacity(0.35))),
      ],
    );
  }
 
  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _gradeColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _gradeColor.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline_rounded,
              size: 16, color: _gradeColor.withOpacity(0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _tip,
              style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withOpacity(0.6),
                  height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
 
  Widget _buildBeatGrid() {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: results.asMap().entries.map((e) {
        final i = e.key;
        final r = e.value;
        return Tooltip(
          message:
              'Beat ${i + 1}: expected ${r.expectedLabel}, heard ${r.detectedLabel}',
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: r.correct
                  ? Colors.greenAccent.withOpacity(0.2)
                  : Colors.redAccent.withOpacity(0.2),
              border: Border.all(
                color: r.correct
                    ? Colors.greenAccent.withOpacity(0.5)
                    : Colors.redAccent.withOpacity(0.4),
              ),
            ),
            child: Icon(
              r.correct ? Icons.check : Icons.close,
              size: 16,
              color: r.correct
                  ? Colors.greenAccent
                  : Colors.redAccent,
            ),
          ),
        );
      }).toList(),
    );
  }
 
  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        // Try again (same config)
        ElevatedButton(
          onPressed: () => Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => DrillScreen(
                chordA: chordA,
                chordB: chordB,
                bpm: bpm,
                targetCount: total > 0 ? total : 10,
              ),
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.greenAccent,
            foregroundColor: Colors.black,
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: const Text('Try again',
              style:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 10),
 
        // Back to setup
        OutlinedButton(
          onPressed: () {
            Navigator.of(context).popUntil(
                (route) => route.settings.name == '/transition-drill' ||
                    route.isFirst);
          },
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.white70,
            side: BorderSide(color: Colors.white.withOpacity(0.12)),
            minimumSize: const Size.fromHeight(50),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: const Text('Change chords',
              style: TextStyle(fontSize: 15)),
        ),
      ],
    );
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
// Supporting data classes
// ─────────────────────────────────────────────────────────────────────────────
 
class TransitionResult {
  final String expectedLabel;
  final String detectedLabel;
  final bool correct;
  final double confidence;
 
  const TransitionResult({
    required this.expectedLabel,
    required this.detectedLabel,
    required this.correct,
    required this.confidence,
  });
}