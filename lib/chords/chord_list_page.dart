import 'package:flutter/material.dart';
import 'chord_voicings.dart';
import 'chord_detail_page.dart';

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

class _ChordTile extends StatelessWidget {
  final PracticeChord chord;

  const _ChordTile({required this.chord});

  @override
  Widget build(BuildContext context) {
    final Color accent =
        chord.isMinor ? const Color(0xFF7E8CE0) : Colors.greenAccent;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ChordDetailPage(chord: chord),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
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
                  chord.displayName,
                  style: TextStyle(
                    fontSize: chord.displayName.length > 2 ? 16 : 20,
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
                    chord.fullName,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${chord.voicings.length} voicing${chord.voicings.length > 1 ? 's' : ''}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),

            // Major / Minor chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.25)),
              ),
              child: Text(
                chord.isMinor ? 'Minor' : 'Major',
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