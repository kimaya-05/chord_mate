import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import '../chords/chord_list_page.dart';
import '../chords/chord_detail_page.dart';
import '../chords/chord_voicings.dart';
import '../ui/metronome_page.dart';
import '../ui/guitar_tuner_page.dart';
import '../forum/forum_feed_page.dart';
import '../forum/forum_models.dart';
import '../forum/forum_service.dart';
import '../forum/post_viewer_page.dart';
import '../learn/learn_home_page.dart';
import '../chord_drills/transition_drill_page.dart';
import '../ui/stats_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Static content — tips and song of the day
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _dailyTips = [
  'Warm up with chromatic exercises before practicing chords, it loosens your fingers and reduces injury risk.',
  'Practice chord transitions slowly at first. Speed comes naturally once the muscle memory is there.',
  'Use a metronome even for slow practice. Consistent timing is more important than speed.',
  'Record yourself playing occasionally. You\'ll catch mistakes your ears miss in the moment.',
  'The secret to a clean barre chord is pressing with the side of your index finger, not the pad.',
  'Learn songs you actually love, motivation is the best practice tool there is.',
  'Rest is part of practice. Short daily sessions beat long infrequent ones every time.',
  'When a chord buzzes, check your thumb position behind the neck first, it affects everything.',
  'Nail the first and last beat of every bar. The middle fills itself in over time.',
  'Calluses take 4–6 weeks to build. Play through the soreness, it gets easier.',
  'Try playing without looking at your fretting hand. It builds spatial muscle memory faster.',
  'Strumming patterns are easier to learn if you say them out loud, "down up down up".',
  'Tune your guitar every single time before you play. Your ear learns pitch faster that way.',
  'The best practice session is the one you actually do, even if it\'s just 10 minutes.',
];

// Static songs removed — song of the day now fetched from Firestore

// ─────────────────────────────────────────────────────────────────────────────
// Recently viewed chords — in-memory store (persists for app session)
// ─────────────────────────────────────────────────────────────────────────────

class RecentChordsStore {
  static final RecentChordsStore _instance = RecentChordsStore._();
  RecentChordsStore._();
  factory RecentChordsStore() => _instance;

  final List<PracticeChord> _recent = [];
  static const int _maxRecent = 3;

  void add(PracticeChord chord) {
    _recent.removeWhere((c) => c.displayName == chord.displayName);
    _recent.insert(0, chord);
    if (_recent.length > _maxRecent) _recent.removeLast();
  }

  List<PracticeChord> get chords => List.unmodifiable(_recent);
}

// ─────────────────────────────────────────────────────────────────────────────
// MainShell — bottom nav wrapper
// ─────────────────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _currentIndex = 0;

  static const List<_NavItem> _items = [
    _NavItem(icon: Icons.home_outlined,       activeIcon: Icons.home,             label: 'Home'),
    _NavItem(icon: Icons.music_note_outlined, activeIcon: Icons.music_note,       label: 'Practice'),
    _NavItem(icon: Icons.flash_on_outlined,   activeIcon: Icons.flash_on,         label: 'Drills'),
    _NavItem(icon: Icons.forum_outlined,      activeIcon: Icons.forum,            label: 'Forum'),
    _NavItem(icon: Icons.person_outline,      activeIcon: Icons.person,           label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          UserHomePage(onNavigate: (i) => setState(() => _currentIndex = i)),
          const ChordListPage(),
          const TransitionDrillPage(),
          const ForumFeedPage(),
          const UserProfilePage(),
        ],
      ),
      bottomNavigationBar: _BottomNav(
        currentIndex: _currentIndex,
        items: _items,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final IconData activeIcon;
  final String   label;
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// _BottomNav
// ─────────────────────────────────────────────────────────────────────────────

class _BottomNav extends StatelessWidget {
  final int currentIndex;
  final List<_NavItem> items;
  final ValueChanged<int> onTap;

  const _BottomNav({
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final item     = items[i];
              final selected = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          selected ? item.activeIcon : item.icon,
                          size:  22,
                          color: selected
                              ? Colors.greenAccent
                              : Colors.white38,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                            color: selected
                                ? Colors.greenAccent
                                : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UserHomePage
// ─────────────────────────────────────────────────────────────────────────────

class UserHomePage extends StatefulWidget {
  final ValueChanged<int>? onNavigate;

  const UserHomePage({super.key, this.onNavigate});

  @override
  State<UserHomePage> createState() => _UserHomePageState();
}

class _UserHomePageState extends State<UserHomePage> {
  final ForumService _forumService = ForumService();

  // Tip rotates daily
  late final int _tipIndex;

  // Song of the day — fetched from Firestore
  ForumPost? _songOfTheDay;
  bool       _songLoading = true;

  @override
  void initState() {
    super.initState();
    final int dayOfYear = DateTime.now().difference(
      DateTime(DateTime.now().year, 1, 1),
    ).inDays;
    _tipIndex = dayOfYear % _dailyTips.length;
    _loadSongOfTheDay();
  }

  Future<void> _loadSongOfTheDay() async {
    final post = await _forumService.songOfTheDay();
    if (mounted) setState(() {
      _songOfTheDay = post;
      _songLoading  = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final String name = auth.appUser?.displayName ?? 'there';
    final List<PracticeChord> recent = RecentChordsStore().chords;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: CustomScrollView(
        slivers: [
          // ── App bar ──────────────────────────────────────────────────
          SliverAppBar(
            backgroundColor: const Color(0xFF0A0A0F),
            elevation: 0,
            floating: true,
            title: Row(
              children: [
                Image.asset(
                  'assets/images/logo.png',
                  height: 28,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.music_note,
                    color: Colors.greenAccent,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'ChordMate',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white38, size: 20),
                tooltip: 'Sign out',
                onPressed: () => context.read<AuthProvider>().signOut(),
              ),
            ],
          ),

          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ── Welcome ─────────────────────────────────────────────
                _buildWelcome(name),
                const SizedBox(height: 28),

                // ── Song of the day ──────────────────────────────────────
                _buildSectionLabel('Song of the Day'),
                const SizedBox(height: 10),
                _buildSongCard(context),
                const SizedBox(height: 28),

                // ── Tip of the day ───────────────────────────────────────
                _buildSectionLabel('Tip of the Day'),
                const SizedBox(height: 10),
                _buildTipCard(),
                const SizedBox(height: 28),

                // ── Recent chords ────────────────────────────────────────
                if (recent.isNotEmpty) ...[
                  _buildSectionLabel('Recently Practised'),
                  const SizedBox(height: 10),
                  _buildRecentChords(recent),
                  const SizedBox(height: 28),
                ],

                // ── Tools ────────────────────────────────────────────────
                _buildSectionLabel('Tools'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildToolCard(
                        context: context,
                        title: 'Tuner',
                        icon: Icons.tune,
                        page: const GuitarTunerPage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToolCard(
                        context: context,
                        title: 'Metronome',
                        icon: Icons.timer,
                        page: const MetronomePage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildToolCard(
                        context: context,
                        title: 'Stats',
                        icon: Icons.bar_chart_rounded,
                        page: const StatsPage(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Quick access ─────────────────────────────────────────
                _buildSectionLabel('Quick Access'),
                const SizedBox(height: 10),
                _buildLearnCard(context),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── Welcome ────────────────────────────────────────────────────────────────

  Widget _buildWelcome(String name) {
    final hour = DateTime.now().hour;
    final String greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$greeting,',
          style: TextStyle(
            fontSize: 15,
            color: Colors.white.withOpacity(0.4),
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          name,
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -1,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Ready to practise?',
          style: TextStyle(
            fontSize: 14,
            color: Colors.white.withOpacity(0.35),
          ),
        ),
      ],
    );
  }

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _buildSectionLabel(String label) {
    return Text(
      label.toUpperCase(),
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: Colors.white.withOpacity(0.3),
        letterSpacing: 1.4,
      ),
    );
  }

  // ── Song of the day ────────────────────────────────────────────────────────

  Widget _buildSongCard(BuildContext context) {
    if (_songLoading) {
      return Container(
        height: 80,
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: Colors.greenAccent),
        ),
      );
    }

    if (_songOfTheDay == null) {
      return Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(children: [
          const Icon(Icons.library_music_outlined,
              color: Colors.white24, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              'No posts yet — be the first to share a chord sheet!',
              style: TextStyle(
                  fontSize: 13, color: Colors.white.withOpacity(0.4)),
            ),
          ),
        ]),
      );
    }

    final post = _songOfTheDay!;
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostViewerPage(post: post)),
      ),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.greenAccent.withOpacity(0.12),
              Colors.greenAccent.withOpacity(0.04),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.greenAccent.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.library_music_outlined,
                  color: Colors.greenAccent, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                  Text(post.artist,
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.45))),
                  const SizedBox(height: 4),
                  Row(children: [
                    if (post.ratingCount > 0) ...[
                      const Icon(Icons.star_rounded,
                          color: Colors.amber, size: 12),
                      const SizedBox(width: 3),
                      Text(post.averageRating.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.amber,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(width: 8),
                    ],
                    Text('Tap to view →',
                        style: TextStyle(
                            fontSize: 11,
                            color: Colors.greenAccent.withOpacity(0.6))),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
              ),
              child: Text(
                'Key of\n${post.key}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.greenAccent,
                    height: 1.3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tip of the day ─────────────────────────────────────────────────────────

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.07)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.amber.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.lightbulb_outline,
              color: Colors.amber,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Today\'s tip',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.amber.withOpacity(0.7),
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _dailyTips[_tipIndex],
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.7),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent chords ──────────────────────────────────────────────────────────

  Widget _buildRecentChords(List<PracticeChord> recent) {
    return Row(
      children: recent.map((chord) {
        final Color accent = chord.isMinor
            ? const Color(0xFF7E8CE0)
            : Colors.greenAccent;
        return Expanded(
          child: GestureDetector(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ChordDetailPage(chord: chord),
              ),
            ),
            child: Container(
              margin: EdgeInsets.only(
                right: chord == recent.last ? 0 : 8,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF13131A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: accent.withOpacity(0.25)),
              ),
              child: Column(
                children: [
                  Text(
                    chord.displayName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: accent,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chord.isMinor ? 'Minor' : 'Major',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Quick access ───────────────────────────────────────────────────────────

  Widget _buildLearnCard(BuildContext context) {
      final topics = [
        (label: 'Chord diagrams', icon: Icons.grid_view_rounded),
        (label: 'Reading tabs',   icon: Icons.linear_scale_rounded),
        (label: 'Guitar basics',  icon: Icons.music_note_outlined),
        (label: 'Glossary',       icon: Icons.menu_book_outlined),
      ];

      return GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const LearnHomePage()),
        ),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF13131A),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.school_outlined,
                      color: Colors.greenAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Beginner guides',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                      Text('4 topics to get you started',
                          style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withOpacity(0.4))),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 14, color: Colors.white.withOpacity(0.25)),
              ]),
              const SizedBox(height: 14),
              Divider(height: 1, color: Colors.white.withOpacity(0.06)),
              const SizedBox(height: 14),
              // Topic chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: topics.map((t) => Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: Colors.white.withOpacity(0.09)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon,
                          size: 13,
                          color: Colors.white.withOpacity(0.4)),
                      const SizedBox(width: 5),
                      Text(t.label,
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.5),
                              fontWeight: FontWeight.w500)),
                    ],
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
      );
    }

  // ── Tools ──────────────────────────────────────────────────────────────────

  Widget _buildToolCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget page,
  }) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => page),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: Colors.greenAccent.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.greenAccent, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// UserProfilePage
// ─────────────────────────────────────────────────────────────────────────────

class UserProfilePage extends StatelessWidget {
  const UserProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth    = context.watch<AuthProvider>();
    final service = ForumService();
    final uid     = auth.appUser?.uid ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text('Profile',
            style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.3)),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, size: 16, color: Colors.white38),
            label: const Text('Sign out',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
            onPressed: () => auth.signOut(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Avatar + name ─────────────────────────────────────────
            Row(children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: Colors.greenAccent.withOpacity(0.15),
                child: Text(
                  (auth.appUser?.displayName.isNotEmpty == true)
                      ? auth.appUser!.displayName[0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.greenAccent),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      auth.appUser?.displayName ?? '—',
                      style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      auth.appUser?.email ?? '',
                      style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.4)),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: Colors.greenAccent.withOpacity(0.3)),
                      ),
                      child: Text(
                        auth.role.name.toUpperCase(),
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.greenAccent,
                            letterSpacing: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
            const SizedBox(height: 32),

            // ── My posts ──────────────────────────────────────────────
            Text('MY POSTS',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withOpacity(0.3),
                    letterSpacing: 1.4)),
            const SizedBox(height: 12),

            StreamBuilder<List<ForumPost>>(
              stream: service.userPostsStream(uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.greenAccent));
                }
                final posts = snapshot.data ?? [];
                if (posts.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFF13131A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.06)),
                    ),
                    child: Center(
                      child: Text(
                        "You haven't posted any chord sheets yet.",
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.35)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                // Stats row
                final totalRatings = posts.fold<int>(
                    0, (sum, p) => sum + p.ratingCount);
                final avgRating = posts.isEmpty
                    ? 0.0
                    : posts.fold<double>(
                            0, (sum, p) => sum + p.ratingSum) /
                        (totalRatings == 0 ? 1 : totalRatings);

                return Column(
                  children: [
                    // Stats
                    Row(children: [
                      _StatCard(
                        value: '${posts.length}',
                        label: 'Posts',
                        color: Colors.greenAccent,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        value: totalRatings > 0
                            ? avgRating.toStringAsFixed(1)
                            : '—',
                        label: 'Avg Rating',
                        color: Colors.amber,
                        icon: totalRatings > 0
                            ? Icons.star_rounded
                            : null,
                      ),
                      const SizedBox(width: 10),
                      _StatCard(
                        value: '$totalRatings',
                        label: 'Ratings received',
                        color: const Color(0xFF7E8CE0),
                      ),
                    ]),
                    const SizedBox(height: 16),

                    // Post list
                    ...posts.map((post) => _ProfilePostTile(post: post)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String  value;
  final String  label;
  final Color   color;
  final IconData? icon;

  const _StatCard({
    required this.value,
    required this.label,
    required this.color,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: color, size: 16),
                  const SizedBox(width: 4),
                ],
                Text(value,
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    fontSize: 10,
                    color: Colors.white.withOpacity(0.35)),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _ProfilePostTile extends StatelessWidget {
  final ForumPost post;
  const _ProfilePostTile({required this.post});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PostViewerPage(post: post)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(post.title,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(post.artist,
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.4))),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (post.ratingCount > 0)
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        color: Colors.amber, size: 13),
                    const SizedBox(width: 3),
                    Text(post.averageRating.toStringAsFixed(1),
                        style: const TextStyle(
                            fontSize: 12,
                            color: Colors.amber,
                            fontWeight: FontWeight.w600)),
                  ]),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.greenAccent.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(post.key,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right,
                color: Colors.white.withOpacity(0.2), size: 18),
          ],
        ),
      ),
    );
  }
}