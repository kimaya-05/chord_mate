import 'package:cloud_firestore/cloud_firestore.dart';
import 'forum_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ForumService
// ─────────────────────────────────────────────────────────────────────────────

class ForumService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collection references ─────────────────────────────────────────────────

  CollectionReference get _posts       => _db.collection('posts');
  CollectionReference get _modReports  => _db.collection('moderator_reports');
  CollectionReference get _users       => _db.collection('users');

  CollectionReference _comments(String postId) =>
      _posts.doc(postId).collection('comments');
  CollectionReference _ratings(String postId) =>
      _posts.doc(postId).collection('ratings');
  CollectionReference _reports(String postId) =>
      _posts.doc(postId).collection('reports');

  // ── Posts — read ──────────────────────────────────────────────────────────

  Future<List<ForumPost>> searchPosts(String query) async {
    final snap = await _posts.orderBy('createdAt', descending: true).get();
    final all  = snap.docs.map(ForumPost.fromFirestore).toList();
    if (query.trim().isEmpty) return all;
    final q = query.trim().toLowerCase();
    return all
        .where((p) =>
            p.title.toLowerCase().contains(q) ||
            p.artist.toLowerCase().contains(q))
        .toList();
  }

  Future<ForumPost?> songOfTheDay() async {
    try {
      final since = DateTime.now().subtract(const Duration(days: 7));
      final snap = await _posts
          .where('createdAt', isGreaterThan: Timestamp.fromDate(since))
          .orderBy('createdAt', descending: true)
          .limit(20)
          .get();

      if (snap.docs.isNotEmpty) {
        final posts = snap.docs.map(ForumPost.fromFirestore).toList();
        posts.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        return posts.first;
      }
    } catch (_) {}

    try {
      final fallback = await _posts
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();
      if (fallback.docs.isEmpty) return null;
      return ForumPost.fromFirestore(fallback.docs.first);
    } catch (_) {
      return null;
    }
  }

  Stream<List<ForumPost>> userPostsStream(String uid) {
    return _posts
        .where('authorUid', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ForumPost.fromFirestore).toList());
  }

  Stream<ForumPost?> postStream(String postId) {
    return _posts.doc(postId).snapshots().map(
      (s) => s.exists ? ForumPost.fromFirestore(s) : null,
    );
  }

  // ── Posts — write ─────────────────────────────────────────────────────────

  /// Stream of posts. Shadow-banned authors' posts are filtered out for
  /// regular users; moderators see everything.
  Stream<List<ForumPost>> postsStream({
    String? genre,
    String? difficulty,
    String? key,
    bool    isModerator = false,
  }) {
    Query q = _posts.orderBy('createdAt', descending: true);
    if (genre      != null) q = q.where('genre',      isEqualTo: genre);
    if (difficulty != null) q = q.where('difficulty', isEqualTo: difficulty);
    if (key        != null) q = q.where('key',        isEqualTo: key);
    return q.snapshots().map((s) {
      final all = s.docs.map(ForumPost.fromFirestore).toList();
      if (isModerator) return all;
      return all.where((p) => !p.authorShadowBanned).toList();
    });
  }

  /// Creates a post. Throws [StateError] if the user is not permitted to post.
  Future<String> createPost(ForumPost post, {bool canPost = true}) async {
    if (!canPost) throw StateError('User is not permitted to post.');

    final userDoc = await _users.doc(post.authorUid).get();
    final isShadowBanned = userDoc.exists
        ? (userDoc.data() as Map<String, dynamic>)['shadowBanned'] as bool? ?? false
        : false;

    final data = {
      ...post.toFirestore(),
      'authorShadowBanned': isShadowBanned,
    };

    final ref = await _posts.add(data);
    return ref.id;
  }

  /// Updates the editable fields of a post. Accepts a [ForumPost] produced
  /// via [ForumPost.copyWith] and writes only the user-editable fields plus
  /// a fresh [updatedAt] timestamp.
  Future<void> updatePost(ForumPost post) async {
    await _posts.doc(post.id).update({
      'title':      post.title,
      'artist':     post.artist,
      'content':    post.content,
      'key':        post.key,
      'capo':       post.capo,
      'difficulty': post.difficulty,
      'genre':      post.genre,
      'updatedAt':  Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deletePost(String postId) async {
    await _posts.doc(postId).delete();
  }

  // ── Comments ──────────────────────────────────────────────────────────────

  Stream<List<ForumComment>> commentsStream(String postId) {
    return _comments(postId)
        .orderBy('createdAt', descending: false)
        .snapshots()
        .map((s) => s.docs.map(ForumComment.fromFirestore).toList());
  }

  Future<void> addComment(String postId, ForumComment comment) async {
    await _comments(postId).add(comment.toFirestore());
  }

  Future<void> deleteComment(String postId, String commentId) async {
    await _comments(postId).doc(commentId).delete();
  }

  // ── Ratings ───────────────────────────────────────────────────────────────

  Future<int?> getUserRating(String postId, String uid) async {
    final doc = await _ratings(postId).doc(uid).get();
    if (!doc.exists) return null;
    return (doc.data() as Map<String, dynamic>)['value'] as int?;
  }

  Future<void> ratePost(String postId, String uid, int newRating) async {
    final postRef   = _posts.doc(postId);
    final ratingRef = _ratings(postId).doc(uid);

    await _db.runTransaction((tx) async {
      final ratingSnap = await tx.get(ratingRef);
      final postSnap   = await tx.get(postRef);

      double sum   = (postSnap['ratingSum']   as num).toDouble();
      int    count = (postSnap['ratingCount'] as num).toInt();

      if (ratingSnap.exists) {
        final int old =
            (ratingSnap.data() as Map<String, dynamic>)['value'] as int;
        sum = sum - old + newRating;
      } else {
        sum   += newRating;
        count += 1;
      }

      tx.set(ratingRef, {'value': newRating});
      tx.update(postRef, {'ratingSum': sum, 'ratingCount': count});
    });
  }

  // ── Reports ───────────────────────────────────────────────────────────────

  Future<bool> hasUserReported(String postId, String uid) async {
    final doc = await _reports(postId).doc(uid).get();
    return doc.exists;
  }

  Future<void> reportPost({
    required ForumPost post,
    required String    reporterUid,
    required String    reporterName,
    required String    reason,
  }) async {
    final batch = _db.batch();

    batch.set(_reports(post.id).doc(reporterUid), {
      'reason':    reason,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    batch.update(_posts.doc(post.id), {
      'reportCount': FieldValue.increment(1),
    });

    final modRef = _modReports.doc();
    batch.set(modRef, ModeratorReport(
      id:            modRef.id,
      postId:        post.id,
      postTitle:     post.title,
      postAuthorUid: post.authorUid,
      reporterUid:   reporterUid,
      reporterName:  reporterName,
      reason:        reason,
      createdAt:     DateTime.now(),
      resolved:      false,
    ).toFirestore());

    await batch.commit();
  }

  // ── Moderator — reports ───────────────────────────────────────────────────

  Stream<List<ModeratorReport>> modReportsStream({
    required bool resolvedOnly,
  }) {
    return _modReports
        .where('resolved', isEqualTo: resolvedOnly)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ModeratorReport.fromFirestore).toList());
  }

  Future<void> resolveReport(String reportId) async {
    await _modReports.doc(reportId).update({'resolved': true});
  }

  Future<void> moderatorDeletePost(String postId) async {
    await deletePost(postId);
    final open = await _modReports
        .where('postId',   isEqualTo: postId)
        .where('resolved', isEqualTo: false)
        .get();
    if (open.docs.isEmpty) return;
    final batch = _db.batch();
    for (final doc in open.docs) {
      batch.update(doc.reference, {'resolved': true});
    }
    await batch.commit();
  }

  // ── Moderator — users ─────────────────────────────────────────────────────

  Stream<List<AppUserRecord>> usersStream() {
    return _users
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(AppUserRecord.fromFirestore).toList());
  }

  Future<void> warnUser(String uid) async {
    await _applyInfraction(
      uid:          uid,
      severity:     'minor',
      reason:       'Warning issued by moderator',
      newStatus:    'warned',
      onlyIfStatus: ['active'],
    );
  }

  Future<void> muteUser(String uid, Duration duration) async {
    await _applyInfraction(
      uid:               uid,
      severity:          'minor',
      reason:            'Muted for ${_durationLabel(duration)}',
      newStatus:         'muted',
      restrictionEndsAt: DateTime.now().add(duration),
    );
  }

  Future<void> suspendUser(String uid, Duration duration) async {
    await _applyInfraction(
      uid:               uid,
      severity:          'major',
      reason:            'Suspended for ${_durationLabel(duration)}',
      newStatus:         'suspended',
      restrictionEndsAt: DateTime.now().add(duration),
    );
  }

  Future<void> banUser(String uid) async {
    await _applyInfraction(
      uid:       uid,
      severity:  'major',
      reason:    'Permanently banned',
      newStatus: 'banned',
    );
  }

  Future<void> shadowBanUser(String uid, {required bool enable}) async {
    final userUpdate = <String, dynamic>{'shadowBanned': enable};
    if (enable) {
      final entry = {
        'severity':  'major',
        'reason':    'Shadow banned',
        'createdAt': Timestamp.fromDate(DateTime.now()),
      };
      userUpdate['majorInfractions']  = FieldValue.increment(1);
      userUpdate['infractionHistory'] = FieldValue.arrayUnion([entry]);
    }
    await _users.doc(uid).set(userUpdate, SetOptions(merge: true));

    final userPosts = await _posts.where('authorUid', isEqualTo: uid).get();
    if (userPosts.docs.isEmpty) return;
    for (int i = 0; i < userPosts.docs.length; i += 500) {
      final batch = _db.batch();
      final chunk = userPosts.docs.skip(i).take(500);
      for (final doc in chunk) {
        batch.update(doc.reference, {'authorShadowBanned': enable});
      }
      await batch.commit();
    }
  }

  Future<void> restoreUser(String uid) async {
    await _users.doc(uid).set({
      'status':            'active',
      'shadowBanned':      false,
      'restrictionEndsAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  // ── Private helpers ───────────────────────────────────────────────────────

  Future<void> _applyInfraction({
    required String  uid,
    required String  severity,
    required String  reason,
    required String  newStatus,
    DateTime?        restrictionEndsAt,
    List<String>?    onlyIfStatus,
  }) async {
    final entry = {
      'severity':  severity,
      'reason':    reason,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    };

    final isMajor      = severity == 'major';
    final counterField = isMajor ? 'majorInfractions' : 'minorInfractions';

    if (onlyIfStatus != null) {
      final snap    = await _users.doc(uid).get();
      final current = snap.exists
          ? (snap.data() as Map<String, dynamic>)['status'] as String? ?? 'active'
          : 'active';
      if (!onlyIfStatus.contains(current)) {
        await _users.doc(uid).set({
          counterField:        FieldValue.increment(1),
          'infractionHistory': FieldValue.arrayUnion([entry]),
        }, SetOptions(merge: true));
        return;
      }
    }

    final update = <String, dynamic>{
      'status':            newStatus,
      counterField:        FieldValue.increment(1),
      'infractionHistory': FieldValue.arrayUnion([entry]),
    };
    if (restrictionEndsAt != null) {
      update['restrictionEndsAt'] = Timestamp.fromDate(restrictionEndsAt);
    }

    await _users.doc(uid).set(update, SetOptions(merge: true));
  }

  String _durationLabel(Duration d) {
    if (d.inDays  >= 1) return '${d.inDays} day${d.inDays == 1 ? '' : 's'}';
    if (d.inHours >= 1) return '${d.inHours} hour${d.inHours == 1 ? '' : 's'}';
    return '${d.inMinutes} minutes';
  }
}