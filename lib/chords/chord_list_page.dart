import 'package:flutter/material.dart';
import 'chord_voicings.dart';
import 'chord_detail_page.dart';
import '../services/mastery_service.dart';

class ChordListPage extends StatelessWidget {
  const ChordListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          'Chord Practice',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: -0.3,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.white.withOpacity(0.06), height: 1),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text(
              'Select a chord to practise',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.4),
                letterSpacing: 0.3,
              ),
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              itemCount: practiceChords.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final chord = practiceChords[index];
                return _ChordTile(chord: chord);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ChordTile extends StatefulWidget {
  final PracticeChord chord;
  const _ChordTile({required this.chord});

  @override
  State<_ChordTile> createState() => _ChordTileState();
}

class _ChordTileState extends State<_ChordTile> {
  bool _mastered = false;

  @override
  void initState() {
    super.initState();
    MasteryService.getHitCount(widget.chord.mlLabel).then((count) {
      if (mounted) setState(() => _mastered = MasteryService.isMastered(count));
    });
  }

  @override
  Widget build(BuildContext context) {
    final Color accent =
        widget.chord.isMinor ? const Color(0xFF7E8CE0) : Colors.greenAccent;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChordDetailPage(chord: widget.chord),
        ),
      ).then((_) {
        // Refresh mastery when returning from detail page
        MasteryService.getHitCount(widget.chord.mlLabel).then((count) {
          if (mounted) setState(() => _mastered = MasteryService.isMastered(count));
        });
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _mastered
                ? Colors.amber.withOpacity(0.35)
                : Colors.white.withOpacity(0.07),
          ),
        ),
        child: Row(
          children: [
            // Chord symbol badge
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: accent.withOpacity(0.3)),
              ),
              child: Center(
                child: Text(
                  widget.chord.displayName,
                  style: TextStyle(
                    fontSize: widget.chord.displayName.length > 2 ? 16 : 20,
                    fontWeight: FontWeight.w800,
                    color: accent,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),

            // Name + voicing count
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.chord.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  if (_mastered) ...[
                    Row(
                      children: [
                        const Icon(Icons.emoji_events_rounded,
                            size: 11, color: Colors.amber),
                        const SizedBox(width: 4),
                        const Text(
                          'Mastery achieved',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.amber,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Text(
                      '${widget.chord.voicings.length} voicing${widget.chord.voicings.length > 1 ? 's' : ''}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.35),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Major / Minor chip
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.25)),
              ),
              child: Text(
                widget.chord.isMinor ? 'Minor' : 'Major',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accent.withOpacity(0.8),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.2), size: 20),
          ],
        ),
      ),
    );
  }
}