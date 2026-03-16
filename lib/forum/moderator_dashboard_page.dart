import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../auth/auth_provider.dart';
import 'forum_models.dart';
import 'forum_service.dart';
import 'post_viewer_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ModeratorDashboardPage extends StatefulWidget {
  const ModeratorDashboardPage({super.key});

  @override
  State<ModeratorDashboardPage> createState() =>
      _ModeratorDashboardPageState();
}

class _ModeratorDashboardPageState extends State<ModeratorDashboardPage> {
  final ForumService _service = ForumService();
  bool _showResolved = false;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0A0F),
        elevation: 0,
        title: const Text(
          'Moderator Dashboard',
          style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => auth.signOut(),
            child: const Text('Sign out',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Toggle resolved ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(children: [
              Text('REPORTS',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withOpacity(0.3),
                      letterSpacing: 1.4)),
              const Spacer(),
              GestureDetector(
                onTap: () =>
                    setState(() => _showResolved = !_showResolved),
                child: Row(children: [
                  Text(
                    _showResolved
                        ? 'Showing all'
                        : 'Showing open',
                    style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withOpacity(0.4)),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.swap_horiz,
                      size: 16,
                      color: Colors.white.withOpacity(0.4)),
                ]),
              ),
            ]),
          ),

          Expanded(
            child: StreamBuilder<List<ModeratorReport>>(
              stream: _service.modReportsStream(
                  unresolvedOnly: !_showResolved),
              builder: (context, snapshot) {
                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.greenAccent),
                  );
                }
                final reports = snapshot.data ?? [];
                if (reports.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.check_circle_outline,
                            size: 48,
                            color: Colors.greenAccent.withOpacity(0.3)),
                        const SizedBox(height: 16),
                        Text(
                          _showResolved
                              ? 'No reports found'
                              : 'No open reports — all clear!',
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
                  itemCount: reports.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) => _ReportCard(
                    report:  reports[i],
                    service: _service,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// _ReportCard
// ─────────────────────────────────────────────────────────────────────────────

class _ReportCard extends StatelessWidget {
  final ModeratorReport report;
  final ForumService    service;

  const _ReportCard({required this.report, required this.service});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF13131A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: report.resolved
              ? Colors.white.withOpacity(0.05)
              : Colors.redAccent.withOpacity(0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge + title
          Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: report.resolved
                    ? Colors.white.withOpacity(0.05)
                    : Colors.redAccent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                report.resolved ? 'Resolved' : 'Open',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: report.resolved
                        ? Colors.white38
                        : Colors.redAccent,
                    letterSpacing: 0.5),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                report.postTitle,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ]),
          const SizedBox(height: 8),

          // Reason
          Row(children: [
            Icon(Icons.flag_outlined,
                size: 13,
                color: Colors.white.withOpacity(0.35)),
            const SizedBox(width: 6),
            Text(report.reason,
                style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.6))),
          ]),
          const SizedBox(height: 4),

          // Reporter
          Row(children: [
            Icon(Icons.person_outline,
                size: 13,
                color: Colors.white.withOpacity(0.3)),
            const SizedBox(width: 6),
            Text('Reported by ${report.reporterName}',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.3))),
            const Spacer(),
            Text(_timeAgo(report.createdAt),
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.25))),
          ]),

          if (!report.resolved) ...[
            const SizedBox(height: 14),
            Divider(height: 1, color: Colors.white.withOpacity(0.06)),
            const SizedBox(height: 12),

            // Action buttons
            Row(children: [
              // View post
              Expanded(
                child: _ActionButton(
                  label: 'View Post',
                  icon:  Icons.visibility_outlined,
                  color: Colors.white54,
                  onTap: () async {
                    // Fetch post and navigate
                    try {
                      final snap = await FirebaseForumHelper
                          .getPostDoc(report.postId);
                      if (snap != null && context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                PostViewerPage(post: snap),
                          ),
                        );
                      }
                    } catch (_) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Post not found')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),

              // Delete post
              Expanded(
                child: _ActionButton(
                  label: 'Delete Post',
                  icon:  Icons.delete_outline,
                  color: Colors.redAccent,
                  onTap: () => _confirmDelete(context),
                ),
              ),
              const SizedBox(width: 8),

              // Dismiss
              Expanded(
                child: _ActionButton(
                  label: 'Dismiss',
                  icon:  Icons.check,
                  color: Colors.greenAccent,
                  onTap: () => service.resolveReport(report.id),
                ),
              ),
            ]),

            const SizedBox(height: 8),

            // Ban user
            _ActionButton(
              label: 'Ban User',
              icon:  Icons.block,
              color: Colors.orangeAccent,
              onTap: () => _confirmBan(context),
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: const Text('Delete post?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'This will permanently delete "${report.postTitle}" and resolve this report.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await service.moderatorDeletePost(report.postId);
            },
            child: const Text('Delete',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _confirmBan(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E28),
        title: const Text('Ban user?',
            style: TextStyle(color: Colors.white)),
        content: Text(
          'This will ban the author of "${report.postTitle}". They will no longer be able to log in.',
          style: TextStyle(color: Colors.white.withOpacity(0.6)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await service.banUser(report.postAuthorUid);
              await service.resolveReport(report.id);
            },
            child: const Text('Ban',
                style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours   < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}

class _ActionButton extends StatelessWidget {
  final String    label;
  final IconData  icon;
  final Color     color;
  final VoidCallback onTap;
  final bool      fullWidth;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(
            horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize:
              fullWidth ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
            Text(label,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper to fetch a single post for the View Post button
// ─────────────────────────────────────────────────────────────────────────────

class FirebaseForumHelper {
  static Future<ForumPost?> getPostDoc(String postId) async {
    final snap = await FirebaseFirestore.instance
        .collection('posts')
        .doc(postId)
        .get();
    if (!snap.exists) return null;
    return ForumPost.fromFirestore(snap);
  }
}


