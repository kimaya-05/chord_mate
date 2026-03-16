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

// ─────────────────────────────────────────────────────────────────────────────
// Static content — tips and song of the day
// ─────────────────────────────────────────────────────────────────────────────

const List<String> _dailyTips = [
  'Warm up with chromatic exercises before practicing chords — it loosens your fingers and reduces injury risk.',
  'Practice chord transitions slowly at first. Speed comes naturally once the muscle memory is there.',
  'Use a metronome even for slow practice. Consistent timing is more important than speed.',
  'Record yourself playing occasionally. You\'ll catch mistakes your ears miss in the moment.',
  'The secret to a clean barre chord is pressing with the side of your index finger, not the pad.',
  'Learn songs you actually love — motivation is the best practice tool there is.',
  'Rest is part of practice. Short daily sessions beat long infrequent ones every time.',
  'When a chord buzzes, check your thumb position behind the neck first — it affects everything.',
  'Nail the first and last beat of every bar. The middle fills itself in over time.',
  'Calluses take 4–6 weeks to build. Play through the soreness — it gets easier.',
  'Try playing without looking at your fretting hand. It builds spatial muscle memory faster.',
  'Strumming patterns are easier to learn if you say them out loud — "down up down up".',
  'Tune your guitar every single time before you play. Your ear learns pitch faster that way.',
  'The best practice session is the one you actually do, even if it\'s just 10 minutes.',
];

// Song of the day — placeholder until forum is built
// Each entry: title, artist, key, a short description
const List<Map<String, String>> _songSuggestions = [
  {
    'title': 'Wonderwall',
    'artist': 'Oasis',
    'key': 'Em',
    'desc': 'A beginner classic — Em, G, Dsus4 and A7sus4 repeat throughout.',
  },
  {
    'title': 'Let Her Go',
    'artist': 'Passenger',
    'key': 'G',
    'desc': 'Fingerpicking pattern over G, D, Em and C. Great for chord transitions.',
  },
  {
    'title': 'Brown Eyed Girl',
    'artist': 'Van Morrison',
    'key': 'G',
    'desc': 'G, C, D and Em — four chords, endless fun. Perfect strumming practice.',
  },
  {
    'title': 'House of the Rising Sun',
    'artist': 'The Animals',
    'key': 'Am',
    'desc': 'Am, C, D, F and E arpeggiated. Iconic fingerpicking introduction.',
  },
  {
    'title': 'Knockin\' on Heaven\'s Door',
    'artist': 'Bob Dylan',
    'key': 'G',
    'desc': 'G, D, Am and C. One of the most rewarding beginner songs to learn.',
  },
  {
    'title': 'Hotel California',
    'artist': 'Eagles',
    'key': 'Bm',
    'desc': 'The iconic intro uses Bm, F#, A, E, G, D, Em and F#. A chord workout.',
  },
  {
    'title': 'Black Bird',
    'artist': 'The Beatles',
    'key': 'G',
    'desc': 'Solo fingerpicking with open strings. Deceptively challenging and rewarding.',
  },
];

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
    _NavItem(icon: Icons.home_outlined,      activeIcon: Icons.home,             label: 'Home'),
    _NavItem(icon: Icons.music_note_outlined, activeIcon: Icons.music_note,       label: 'Practice'),
    _NavItem(icon: Icons.tune_outlined,       activeIcon: Icons.tune,             label: 'Tuner'),
    _NavItem(icon: Icons.timer_outlined,      activeIcon: Icons.timer,            label: 'Metronome'),
    _NavItem(icon: Icons.forum_outlined, activeIcon: Icons.forum, label: 'Forum'),
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
          const GuitarTunerPage(),
          const MetronomePage(),
          const ForumFeedPage(),
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

  // Pick tip + song based on day of year so they change daily
  late final int _tipIndex;
  late final Map<String, String> _todaySong;

  @override
  void initState() {
    super.initState();
    final int dayOfYear = DateTime.now().difference(
      DateTime(DateTime.now().year, 1, 1),
    ).inDays;
    _tipIndex  = dayOfYear % _dailyTips.length;
    _todaySong = _songSuggestions[dayOfYear % _songSuggestions.length];
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
                _buildSongCard(),
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

                // ── Quick access ─────────────────────────────────────────
                _buildSectionLabel('Quick Access'),
                const SizedBox(height: 10),
                _buildQuickAccess(),
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

  Widget _buildSongCard() {
    return Container(
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
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.library_music_outlined,
              color: Colors.greenAccent,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _todaySong['title']!,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  _todaySong['artist']!,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.45),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _todaySong['desc']!,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.55),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Key badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.greenAccent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                  color: Colors.greenAccent.withOpacity(0.3)),
            ),
            child: Text(
              'Key of\n${_todaySong['key']}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.greenAccent,
                height: 1.3,
              ),
            ),
          ),
        ],
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

  Widget _buildQuickAccess() {
    final items = [
      _QuickItem(
        icon:    Icons.music_note,
        label:   'Chords',
        color:   Colors.greenAccent,
        navIndex: 1,
      ),
      _QuickItem(
        icon:    Icons.tune,
        label:   'Tuner',
        color:   const Color(0xFF64B5F6),
        navIndex: 2,
      ),
      _QuickItem(
        icon:    Icons.timer,
        label:   'Metronome',
        color:   Colors.orangeAccent,
        navIndex: 3,
      ),
      _QuickItem(
        icon:    Icons.forum_outlined,
        label:   'Forum',
        color:   const Color(0xFF7E8CE0),
        navIndex: 4, 
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 2.2,
      children: items.map((item) {
        final bool comingSoon = item.navIndex == null;
        return GestureDetector(
          onTap: comingSoon
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Forum coming soon!'),
                      duration: Duration(seconds: 1),
                    ),
                  )
              : () => widget.onNavigate?.call(item.navIndex!),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF13131A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: comingSoon
                    ? Colors.white.withOpacity(0.06)
                    : item.color.withOpacity(0.2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  item.icon,
                  color: comingSoon
                      ? Colors.white24
                      : item.color,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: comingSoon
                            ? Colors.white24
                            : Colors.white,
                      ),
                    ),
                    if (comingSoon)
                      Text(
                        'Coming soon',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.white.withOpacity(0.2),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _QuickItem {
  final IconData icon;
  final String   label;
  final Color    color;
  final int?     navIndex;

  const _QuickItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.navIndex,
  });
}