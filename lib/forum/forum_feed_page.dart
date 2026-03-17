import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import 'forum_models.dart';
import 'forum_service.dart';
import 'post_viewer_page.dart';
import 'create_post_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ForumFeedPage
// ─────────────────────────────────────────────────────────────────────────────

class ForumFeedPage extends StatefulWidget {
  const ForumFeedPage({super.key});

  @override
  State<ForumFeedPage> createState() => _ForumFeedPageState();
}

class _ForumFeedPageState extends State<ForumFeedPage> {
  final ForumService _service = ForumService();

  String? _filterGenre;
  String? _filterDifficulty;
  String? _filterKey;

  // Search
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool   _isSearching = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  bool get _hasFilter =>
      _filterGenre != null ||
      _filterDifficulty != null ||
      _filterKey != null;

  void _clearFilters() {
    _searchCtrl.clear();
    setState(() {
      _filterGenre      = null;
      _filterDifficulty = null;
      _filterKey        = null;
      _searchQuery      = '';
      _isSearching      = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: _isSearching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white, fontSize: 16),
                decoration: InputDecoration(
                  hintText: 'Search songs or artists…',
                  hintStyle: TextStyle(
                      color: Colors.white.withOpacity(0.35), fontSize: 15),
                  border: InputBorder.none,
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              )
            : const Text(
                'Chord Sheets',
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.3),
              ),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close : Icons.search,
              color: Colors.white54,
            ),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchCtrl.clear();
                  _searchQuery = '';
                }
              });
            },
          ),
          if (!_isSearching)
            IconButton(
              icon: const Icon(Icons.add, color: Colors.greenAccent),
              tooltip: 'New post',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreatePostPage()),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          if (_hasFilter)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Filtering results',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4)),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearFilters,
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                          fontSize: 12,
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(child: _buildFeed()),
        ],
      ),
    );
  }

  // ── Filter row ──────────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _FilterChip(
            label: _filterGenre ?? 'Genre',
            active: _filterGenre != null,
            options: kGenres,
            onSelected: (v) => setState(() => _filterGenre = v),
            onCleared: () => setState(() => _filterGenre = null),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: _filterDifficulty ?? 'Difficulty',
            active: _filterDifficulty != null,
            options: kDifficulties,
            onSelected: (v) => setState(() => _filterDifficulty = v),
            onCleared: () => setState(() => _filterDifficulty = null),
          ),
          const SizedBox(width: 8),
          _FilterChip(
            label: _filterKey ?? 'Key',
            active: _filterKey != null,
            options: kKeys,
            onSelected: (v) => setState(() => _filterKey = v),
            onCleared: () => setState(() => _filterKey = null),
          ),
        ],
      ),
    );
  }

  // ── Feed ────────────────────────────────────────────────────────────────────

  Widget _buildFeed() {
    return StreamBuilder<List<ForumPost>>(
      stream: _service.postsStream(
        genre:      _filterGenre,
        difficulty: _filterDifficulty,
        key:        _filterKey,
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Colors.greenAccent));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading posts',
                style:
                    TextStyle(color: Colors.white.withOpacity(0.4))),
          );
        }
        List<ForumPost> posts = snapshot.data ?? [];
        // Client-side search filter
        if (_searchQuery.trim().isNotEmpty) {
          final q = _searchQuery.trim().toLowerCase();
          posts = posts.where((p) =>
            p.title.toLowerCase().contains(q) ||
            p.artist.toLowerCase().contains(q),
          ).toList();
        }
        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.library_music_outlined,
                    size: 48, color: Colors.white.withOpacity(0.15)),
                const SizedBox(height: 16),
                Text(
                  _hasFilter
                      ? 'No posts match your filters'
                      : 'No posts yet — be the first!',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.35),
                      fontSize: 14),
                ),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (_, i) => _PostCard(
            post:    posts[i],
            service: _service,
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _PostCard
// ─────────────────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final ForumPost    post;
  final ForumService service;

  const _PostCard({required this.post, required this.service});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PostViewerPage(post: post),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.07)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title + artist
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.title,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        post.artist,
                        style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.45)),
                      ),
                    ],
                  ),
                ),
                // Rating
                if (post.ratingCount > 0) ...[
                  const Icon(Icons.star_rounded,
                      color: Colors.amber, size: 16),
                  const SizedBox(width: 3),
                  Text(
                    post.averageRating.toStringAsFixed(1),
                    style: const TextStyle(
                        fontSize: 13,
                        color: Colors.amber,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Tags row
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _Tag(post.key,        Colors.greenAccent),
                _Tag(post.difficulty, _difficultyColor(post.difficulty)),
                _Tag(post.genre,      Colors.white38),
                if (post.capo > 0)
                  _Tag(post.capoLabel, const Color(0xFF7E8CE0)),
              ],
            ),
            const SizedBox(height: 10),

            // Footer
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 13,
                    color: Colors.white.withOpacity(0.3)),
                const SizedBox(width: 4),
                Text(
                  post.authorName,
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.3)),
                ),
                const Spacer(),
                Icon(Icons.access_time,
                    size: 13,
                    color: Colors.white.withOpacity(0.3)),
                const SizedBox(width: 4),
                Text(
                  _timeAgo(post.createdAt),
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withOpacity(0.3)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Color _difficultyColor(String d) {
    switch (d.toLowerCase()) {
      case 'beginner':     return Colors.greenAccent;
      case 'intermediate': return Colors.orangeAccent;
      case 'advanced':     return Colors.redAccent;
      default:             return Colors.white38;
    }
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    if (diff.inDays    < 7)  return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

class _Tag extends StatelessWidget {
  final String text;
  final Color  color;
  const _Tag(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color.withOpacity(0.9)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _FilterChip
// ─────────────────────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String         label;
  final bool           active;
  final List<String>   options;
  final ValueChanged<String> onSelected;
  final VoidCallback   onCleared;

  const _FilterChip({
    required this.label,
    required this.active,
    required this.options,
    required this.onSelected,
    required this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: active
          ? onCleared
          : () => _showPicker(context),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active
              ? Colors.greenAccent.withOpacity(0.12)
              : const Color(0xFF13131A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? Colors.greenAccent.withOpacity(0.5)
                : Colors.white12,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: active ? Colors.greenAccent : Colors.white54,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              active ? Icons.close : Icons.keyboard_arrow_down,
              size:  14,
              color: active ? Colors.greenAccent : Colors.white38,
            ),
          ],
        ),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 12),
        children: options
            .map((o) => ListTile(
                  title: Text(o,
                      style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    onSelected(o);
                  },
                ))
            .toList(),
      ),
    );
  }
}