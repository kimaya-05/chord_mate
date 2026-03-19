import 'package:flutter/material.dart';
import 'how_to_hold_page.dart';
import 'chord_diagrams_page.dart';
import 'reading_tabs_page.dart';
import 'glossary_page.dart';
import 'strumming_patterns_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model
// ─────────────────────────────────────────────────────────────────────────────

class _LearnTopic {
  final String     title;
  final String     subtitle;
  final String     duration;
  final IconData   icon;
  final Color      accent;
  final Widget     page;
  final bool       featured;

  const _LearnTopic({
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.icon,
    required this.accent,
    required this.page,
    this.featured = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// LearnHomePage
// ─────────────────────────────────────────────────────────────────────────────

class LearnHomePage extends StatelessWidget {
  const LearnHomePage({super.key});

  static const _featured = _LearnTopic(
    title:    'How to hold a guitar',
    subtitle: 'Posture, fretting hand, pick grip — before you play a single note.',
    duration: '5 min read',
    icon:     Icons.music_note_outlined,
    accent:   Colors.greenAccent,
    page:     HowToHoldPage(),
    featured: true,
  );

  static const _topics = <_LearnTopic>[
    _LearnTopic(
      title:    'How to read chord diagrams',
      subtitle: 'Frets, fingers, mutes and open strings explained.',
      duration: '4 min read',
      icon:     Icons.grid_view_rounded,
      accent:   Color(0xFF64B5F6),
      page:     ChordDiagramsPage(),
    ),
    _LearnTopic(
      title:    'How to read tabs',
      subtitle: 'String numbers, fret positions and technique markings.',
      duration: '5 min read',
      icon:     Icons.linear_scale_rounded,
      accent:   Color(0xFF7E8CE0),
      page:     ReadingTabsPage(),
    ),
    _LearnTopic(
      title:    'Glossary of terms',
      subtitle: 'Keys, scales, intervals, chord types and more.',
      duration: '8 min read',
      icon:     Icons.menu_book_outlined,
      accent:   Colors.amber,
      page:     GlossaryPage(),
    ),
    _LearnTopic(
      title:    'Strumming patterns',
      subtitle: 'Down, up and mixed patterns with notation guides.',
      duration: '4 min read',
      icon:     Icons.music_note_outlined,
      accent:   Colors.orangeAccent,
      page:     StrummingPatternsPage(),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        slivers: [
          // ── App bar ────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0F),
            elevation: 0,
            floating: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new,
                  size: 18, color: Colors.white54),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Learn',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white),
            ),
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Header ───────────────────────────────────────────
                Text(
                  'Beginner guides',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.5,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Everything you need to go from zero to playing.',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.4),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 28),

                // ── START HERE label ─────────────────────────────────
                _sectionLabel('START HERE'),
                const SizedBox(height: 10),

                // ── Featured card ────────────────────────────────────
                _FeaturedCard(topic: _featured),
                const SizedBox(height: 28),

                // ── GUIDES label ─────────────────────────────────────
                _sectionLabel('GUIDES'),
                const SizedBox(height: 10),

                // ── Topic list ───────────────────────────────────────
                ..._topics.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _TopicCard(topic: t),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _sectionLabel(String label) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white.withOpacity(0.3),
        letterSpacing: 1.4,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FeaturedCard — large hero card for the "Start Here" topic
// ─────────────────────────────────────────────────────────────────────────────

class _FeaturedCard extends StatelessWidget {
  final _LearnTopic topic;
  const _FeaturedCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => topic.page),
      ),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: topic.accent.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + badge row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: topic.accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(topic.icon,
                      color: topic.accent, size: 24),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: topic.accent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: topic.accent.withOpacity(0.3)),
                      ),
                      child: Text(
                        'BEGINNER',
                        style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: topic.accent,
                            letterSpacing: 1),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      topic.duration,
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.35)),
                    ),
                  ],
                ),
                const Spacer(),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: topic.accent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: topic.accent.withOpacity(0.25)),
                  ),
                  child: Icon(Icons.arrow_forward_rounded,
                      size: 16, color: topic.accent),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 16),
            Text(
              topic.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              topic.subtitle,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withOpacity(0.5),
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _TopicCard — compact row card for each guide
// ─────────────────────────────────────────────────────────────────────────────

class _TopicCard extends StatelessWidget {
  final _LearnTopic topic;
  const _TopicCard({required this.topic});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => topic.page),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                color: topic.accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(11),
              ),
              child: Icon(topic.icon,
                  color: topic.accent, size: 20),
            ),
            const SizedBox(width: 14),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    topic.title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    topic.subtitle,
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4),
                        height: 1.4),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  // Duration chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.04),
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.08)),
                    ),
                    child: Text(
                      topic.duration,
                      style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.35),
                          fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
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