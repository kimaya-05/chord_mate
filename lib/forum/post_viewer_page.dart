import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import 'forum_models.dart';
import 'forum_service.dart';
import 'chord_sheet_renderer.dart';
import 'create_post_page.dart';

class PostViewerPage extends StatefulWidget {
  final ForumPost post;

  const PostViewerPage({super.key, required this.post});

  @override
  State<PostViewerPage> createState() => _PostViewerPageState();
}

class _PostViewerPageState extends State<PostViewerPage> {
  final ForumService    _service      = ForumService();
  final ScrollController _scrollCtrl  = ScrollController();
  final TextEditingController _commentCtrl = TextEditingController();

  int  _transposeSemitones = 0;
  bool _autoscroll         = false;
  double _scrollSpeed      = 1.0; // pixels per tick
  Timer? _scrollTimer;

  int?  _myRating;
  bool  _hasReported = false;
  bool  _submittingComment = false;

  // Local copy of the post so edits reflect immediately without a reload
  late ForumPost _post;

  @override
  void initState() {
    super.initState();
    _post = widget.post;
    _loadUserData();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _scrollCtrl.dispose();
    _commentCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final uid = context.read<AuthProvider>().appUser?.uid;
    if (uid == null) return;
    final rating   = await _service.getUserRating(_post.id, uid);
    final reported = await _service.hasUserReported(_post.id, uid);
    if (mounted) setState(() {
      _myRating    = rating;
      _hasReported = reported;
    });
  }

  // ── Autoscroll ──────────────────────────────────────────────────────────────

  void _toggleAutoscroll() {
    setState(() => _autoscroll = !_autoscroll);
    if (_autoscroll) {
      _scrollTimer = Timer.periodic(const Duration(milliseconds: 30), (_) {
        if (!_scrollCtrl.hasClients) return;
        final max = _scrollCtrl.position.maxScrollExtent;
        final cur = _scrollCtrl.offset;
        if (cur >= max) {
          _toggleAutoscroll(); // stop at end
          return;
        }
        _scrollCtrl.jumpTo((cur + _scrollSpeed).clamp(0, max));
      });
    } else {
      _scrollTimer?.cancel();
    }
  }

  // ── Transpose ───────────────────────────────────────────────────────────────

  void _transpose(int delta) {
    setState(() {
      _transposeSemitones = (_transposeSemitones + delta) % 12;
    });
  }

  // ── Rating ──────────────────────────────────────────────────────────────────

  Future<void> _submitRating(int stars) async {
    final uid = context.read<AuthProvider>().appUser?.uid;
    if (uid == null) return;
    await _service.ratePost(_post.id, uid, stars);
    if (mounted) setState(() => _myRating = stars);
  }

  // ── Report ──────────────────────────────────────────────────────────────────

  void _showReportDialog() {
    if (_hasReported) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You have already reported this post')),
      );
      return;
    }
    final reasons = [
      'Incorrect chords',
      'Inappropriate content',
      'Spam or advertisement',
      'Copyright violation',
      'Other',
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF13131A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Text('Report post',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700)),
          ),
          ...reasons.map((r) => ListTile(
                title: Text(r,
                    style: const TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _fileReport(r);
                },
              )),
          const SizedBox(height: 12),
        ],
      ),
    );
  }

  Future<void> _fileReport(String reason) async {
    final auth = context.read<AuthProvider>();
    if (auth.appUser == null) return;
    await _service.reportPost(
      post:         _post,
      reporterUid:  auth.appUser!.uid,
      reporterName: auth.appUser!.displayName,
      reason:       reason,
    );
    if (mounted) {
      setState(() => _hasReported = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Post reported. Thank you.')),
      );
    }
  }

  // ── Edit ─────────────────────────────────────────────────────────────────────

  void _showEditSheet() async {
    final updated = await Navigator.push<ForumPost>(
      context,
      MaterialPageRoute(
        builder: (_) => CreatePostPage(existingPost: _post),
      ),
    );
    // If the user saved, update the local copy so the viewer reflects changes
    if (updated != null && mounted) {
      setState(() => _post = updated);
    }
  }

  // ── Delete ──────────────────────────────────────────────────────────────────

  Future<void> _confirmDeletePost() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete post?',
            style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700)),
        content: Text(
          'This will permanently delete "${_post.title}". This action cannot be undone.',
          style: TextStyle(
              color: Colors.white.withOpacity(0.6),
              fontSize: 14,
              height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.5),
                    fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Delete',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deletePost(_post.id);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Post deleted.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete post: $e')),
        );
      }
    }
  }

  // ── Comment ─────────────────────────────────────────────────────────────────

  Future<void> _submitComment() async {
    final text = _commentCtrl.text.trim();
    if (text.isEmpty) return;
    final auth = context.read<AuthProvider>();
    if (auth.appUser == null) return;

    setState(() => _submittingComment = true);
    try {
      await _service.addComment(
        _post.id,
        ForumComment(
          id:         '',
          authorUid:  auth.appUser!.uid,
          authorName: auth.appUser!.displayName,
          text:       text,
          createdAt:  DateTime.now(),
        ),
      );
      _commentCtrl.clear();
    } finally {
      if (mounted) setState(() => _submittingComment = false);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uid = context.read<AuthProvider>().appUser?.uid;
    final isAuthor = uid != null && uid == _post.authorUid;

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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_post.title,
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(_post.artist,
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.4))),
          ],
        ),
        actions: [
          // Edit — only shown to the post's author
          if (isAuthor)
            IconButton(
              icon: const Icon(Icons.edit_outlined,
                  color: Colors.white54, size: 20),
              tooltip: 'Edit post',
              onPressed: _showEditSheet,
            ),
          // Delete — only shown to the post's author
          if (isAuthor)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: Colors.redAccent, size: 20),
              tooltip: 'Delete post',
              onPressed: _confirmDeletePost,
            ),
          IconButton(
            icon: Icon(Icons.flag_outlined,
                color: _hasReported
                    ? Colors.redAccent
                    : Colors.white38,
                size: 20),
            tooltip: 'Report',
            onPressed: _showReportDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Toolbar ────────────────────────────────────────────────
          _buildToolbar(),
          Divider(height: 1, color: Colors.white.withOpacity(0.06)),

          // ── Scrollable content ──────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.all(20),
              // Prevent horizontal overflow — content must wrap, not scroll sideways
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width - 40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Post metadata
                    _buildMetaRow(),
                    const SizedBox(height: 20),

                    // Chord sheet — clipped to available width; renderer must wrap
                    ClipRect(
                      child: ChordSheetRenderer(
                        content:            _post.content,
                        transposeSemitones: _transposeSemitones,
                        showInlineDiagrams: false,
                        // If ChordSheetRenderer accepts a softWrap / maxWidth
                        // parameter, pass it here. The ConstrainedBox above
                        // already enforces the layout width.
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Rating
                    _buildRatingSection(isAuthor),
                    const SizedBox(height: 32),

                    // Comments
                    _buildCommentsSection(),
                    const SizedBox(height: 80),
                  ],
                ),
              ),
            ),
          ),

          // ── Comment input ───────────────────────────────────────────
          _buildCommentInput(),
        ],
      ),
    );
  }

  // ── Toolbar ─────────────────────────────────────────────────────────────────

  Widget _buildToolbar() {
    return Container(
      color: const Color(0xFF0A0A0F),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Transpose
          const Text('Transpose:',
              style: TextStyle(
                  fontSize: 12, color: Colors.white38)),
          const SizedBox(width: 8),
          _ToolbarButton(
            icon: Icons.remove,
            onTap: () => _transpose(-1),
          ),
          const SizedBox(width: 6),
          Container(
            width: 40,
            alignment: Alignment.center,
            child: Text(
              _transposeSemitones == 0
                  ? '0'
                  : (_transposeSemitones > 0
                      ? '+$_transposeSemitones'
                      : '$_transposeSemitones'),
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontWeight: FontWeight.w700,
                  fontSize: 13),
            ),
          ),
          const SizedBox(width: 6),
          _ToolbarButton(
            icon: Icons.add,
            onTap: () => _transpose(1),
          ),

          const Spacer(),

          // Autoscroll speed (only when active)
          if (_autoscroll) ...[
            const Icon(Icons.speed, size: 14, color: Colors.white38),
            const SizedBox(width: 6),
            DropdownButton<double>(
              value: _scrollSpeed,
              dropdownColor: const Color(0xFF13131A),
              underline: const SizedBox.shrink(),
              style: const TextStyle(
                  color: Colors.greenAccent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600),
              items: const [
                DropdownMenuItem(value: 0.3, child: Text('Very slow')),
                DropdownMenuItem(value: 0.7, child: Text('Slow')),
                DropdownMenuItem(value: 1.0, child: Text('Normal')),
                DropdownMenuItem(value: 1.8, child: Text('Fast')),
                DropdownMenuItem(value: 3.0, child: Text('Very fast')),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _scrollSpeed = v);
              },
            ),
            const SizedBox(width: 8),
          ],

          // Autoscroll toggle
          GestureDetector(
            onTap: _toggleAutoscroll,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _autoscroll
                    ? Colors.greenAccent.withOpacity(0.15)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: _autoscroll
                        ? Colors.greenAccent.withOpacity(0.5)
                        : Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _autoscroll
                        ? Icons.pause
                        : Icons.play_arrow,
                    size: 14,
                    color: _autoscroll
                        ? Colors.greenAccent
                        : Colors.white38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Scroll',
                    style: TextStyle(
                        fontSize: 11,
                        color: _autoscroll
                            ? Colors.greenAccent
                            : Colors.white38,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Meta row ─────────────────────────────────────────────────────────────────

  Widget _buildMetaRow() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _MetaChip(_post.key,        Colors.greenAccent),
        _MetaChip(_post.difficulty, _difficultyColor(_post.difficulty)),
        _MetaChip(_post.genre,      Colors.white38),
        if (_post.capo > 0)
          _MetaChip(_post.capoLabel, const Color(0xFF7E8CE0)),
        _MetaChip('by ${_post.authorName}', Colors.white24),
      ],
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

  // ── Rating section ────────────────────────────────────────────────────────

  Widget _buildRatingSection(bool isAuthor) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF13131A),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.white.withOpacity(0.07)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
          const SizedBox(width: 6),
          Text(
            _post.ratingCount == 0
                ? 'No ratings yet'
                : '${_post.averageRating.toStringAsFixed(1)} / 5  (${_post.ratingCount} ${_post.ratingCount == 1 ? 'rating' : 'ratings'})',
            style: const TextStyle(
                color: Colors.amber,
                fontWeight: FontWeight.w600,
                fontSize: 13),
          ),
        ]),
        const SizedBox(height: 12),
        if (isAuthor)
          Text(
            'You cannot rate your own post.',
            style: TextStyle(
                fontSize: 12, color: Colors.white.withOpacity(0.3)),
          )
        else ...[
          Text('Rate this chord sheet:',
              style: TextStyle(
                  fontSize: 12, color: Colors.white.withOpacity(0.4))),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (i) {
              final star = i + 1;
              final filled = _myRating != null && star <= _myRating!;
              return GestureDetector(
                onTap: () => _submitRating(star),
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    filled ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: filled ? Colors.amber : Colors.white24,
                    size: 30,
                  ),
                ),
              );
            }),
          ),
        ],
      ],
    ),
  );
}

  // ── Comments ──────────────────────────────────────────────────────────────

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('COMMENTS',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white.withOpacity(0.3),
                letterSpacing: 1.4)),
        const SizedBox(height: 12),
        StreamBuilder<List<ForumComment>>(
          stream: _service.commentsStream(_post.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white24));
            }
            final comments = snapshot.data ?? [];
            if (comments.isEmpty) {
              return Text('No comments yet — be the first!',
                  style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.3)));
            }
            return Column(
              children: comments
                  .map((c) => _CommentTile(
                        comment: c,
                        currentUid: context
                            .read<AuthProvider>()
                            .appUser
                            ?.uid,
                        onDelete: () => _service.deleteComment(
                            _post.id, c.id),
                      ))
                  .toList(),
            );
          },
        ),
      ],
    );
  }

  // ── Comment input ─────────────────────────────────────────────────────────

  Widget _buildCommentInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: MediaQuery.of(context).viewInsets.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.07))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentCtrl,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Add a comment…',
                hintStyle: TextStyle(
                    color: Colors.white.withOpacity(0.3), fontSize: 14),
                border: InputBorder.none,
              ),
              onSubmitted: (_) => _submitComment(),
            ),
          ),
          _submittingComment
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.greenAccent))
              : IconButton(
                  icon: const Icon(Icons.send_rounded,
                      color: Colors.greenAccent, size: 20),
                  onPressed: _submitComment,
                ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _EditField — reusable text field for the edit sheet
// ─────────────────────────────────────────────────────────────────────────────

class _EditField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final int    maxLines;

  const _EditField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.4),
                letterSpacing: 0.8)),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0A0A0F),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: TextField(
            controller: controller,
            maxLines: maxLines,
            style: const TextStyle(
                color: Colors.white, fontSize: 13, height: 1.5),
            decoration: const InputDecoration(
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              border: InputBorder.none,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _CommentTile
// ─────────────────────────────────────────────────────────────────────────────

class _CommentTile extends StatelessWidget {
  final ForumComment comment;
  final String?      currentUid;
  final VoidCallback onDelete;

  const _CommentTile({
    required this.comment,
    required this.currentUid,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bool isOwn = comment.authorUid == currentUid;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.white10,
            child: Text(
              comment.authorName.isNotEmpty
                  ? comment.authorName[0].toUpperCase()
                  : '?',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text(comment.authorName,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                  const SizedBox(width: 8),
                  Text(_timeAgo(comment.createdAt),
                      style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withOpacity(0.3))),
                  if (isOwn) ...[
                    const Spacer(),
                    GestureDetector(
                      onTap: onDelete,
                      child: Icon(Icons.delete_outline,
                          size: 15,
                          color: Colors.white.withOpacity(0.3)),
                    ),
                  ],
                ]),
                const SizedBox(height: 3),
                Text(comment.text,
                    style: TextStyle(
                        fontSize: 13,
                        color: Colors.white.withOpacity(0.7),
                        height: 1.4)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small helpers
// ─────────────────────────────────────────────────────────────────────────────

class _ToolbarButton extends StatelessWidget {
  final IconData    icon;
  final VoidCallback onTap;
  const _ToolbarButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(7),
        ),
        child: Icon(icon, size: 16, color: Colors.white54),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final String text;
  final Color  color;
  const _MetaChip(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color.withOpacity(0.9))),
    );
  }
}