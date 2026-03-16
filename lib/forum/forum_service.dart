import 'package:cloud_firestore/cloud_firestore.dart';
import 'forum_models.dart';

// ─────────────────────────────────────────────────────────────────────────────
// ForumService — all Firestore operations for the forum
// ─────────────────────────────────────────────────────────────────────────────

class ForumService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ── Collections ─────────────────────────────────────────────────────────────

  CollectionReference get _posts         => _db.collection('posts');
  CollectionReference get _modReports    => _db.collection('moderator_reports');

  CollectionReference _comments(String postId) =>
      _posts.doc(postId).collection('comments');
  CollectionReference _ratings(String postId) =>
      _posts.doc(postId).collection('ratings');
  CollectionReference _reports(String postId) =>
      _posts.doc(postId).collection('reports');

  // ── Posts — read ────────────────────────────────────────────────────────────

  /// Stream of all posts ordered by newest first.
  Stream<List<ForumPost>> postsStream({
    String? genre,
    String? difficulty,
    String? key,
  }) {
    Query q = _posts.orderBy('createdAt', descending: true);
    if (genre      != null) q = q.where('genre',      isEqualTo: genre);
    if (difficulty != null) q = q.where('difficulty', isEqualTo: difficulty);
    if (key        != null) q = q.where('key',        isEqualTo: key);
    return q.snapshots().map(
      (s) => s.docs.map(ForumPost.fromFirestore).toList(),
    );
  }

  /// Single post stream — for live updates inside the post viewer.
  Stream<ForumPost?> postStream(String postId) {
    return _posts.doc(postId).snapshots().map(
      (s) => s.exists ? ForumPost.fromFirestore(s) : null,
    );
  }

  // ── Posts — write ───────────────────────────────────────────────────────────

  Future<String> createPost(ForumPost post) async {
    final ref = await _posts.add(post.toFirestore());
    return ref.id;
  }

  Future<void> updatePost(String postId, {
    required String content,
    required String key,
    required int    capo,
    required String difficulty,
    required String genre,
  }) async {
    await _posts.doc(postId).update({
      'content':    content,
      'key':        key,
      'capo':       capo,
      'difficulty': difficulty,
      'genre':      genre,
      'updatedAt':  Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<void> deletePost(String postId) async {
    // Delete the post document — subcollections are NOT auto-deleted by
    // Firestore on the client side. For a production app use a Cloud Function.
    // For now we just delete the post doc itself.
    await _posts.doc(postId).delete();
  }

  // ── Comments ─────────────────────────────────────────────────────────────────

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

  // ── Ratings ──────────────────────────────────────────────────────────────────

  /// Returns the current user's rating for a post, or null if not rated.
  Future<int?> getUserRating(String postId, String uid) async {
    final doc = await _ratings(postId).doc(uid).get();
    if (!doc.exists) return null;
    return (doc.data() as Map<String, dynamic>)['value'] as int?;
  }

  /// Submit or update a rating. Uses a transaction to keep ratingSum/ratingCount
  /// consistent.
  Future<void> ratePost(String postId, String uid, int newRating) async {
    final postRef   = _posts.doc(postId);
    final ratingRef = _ratings(postId).doc(uid);

    await _db.runTransaction((tx) async {
      final ratingSnap = await tx.get(ratingRef);
      final postSnap   = await tx.get(postRef);

      double sum   = (postSnap['ratingSum']   as num).toDouble();
      int    count = (postSnap['ratingCount'] as num).toInt();

      if (ratingSnap.exists) {
        // Replace old rating
        final int oldRating =
            (ratingSnap.data() as Map<String, dynamic>)['value'] as int;
        sum = sum - oldRating + newRating;
      } else {
        // New rating
        sum   += newRating;
        count += 1;
      }

      tx.set(ratingRef, {'value': newRating});
      tx.update(postRef, {'ratingSum': sum, 'ratingCount': count});
    });
  }

  // ── Reports ──────────────────────────────────────────────────────────────────

  /// Check whether the current user has already reported this post.
  Future<bool> hasUserReported(String postId, String uid) async {
    final doc = await _reports(postId).doc(uid).get();
    return doc.exists;
  }

  /// File a report. Creates an entry in the post's reports subcollection
  /// AND in the top-level moderator_reports collection.
  Future<void> reportPost({
    required ForumPost post,
    required String    reporterUid,
    required String    reporterName,
    required String    reason,
  }) async {
    final batch = _db.batch();

    // Mark that this user has reported this post (prevents duplicates)
    final userReportRef = _reports(post.id).doc(reporterUid);
    batch.set(userReportRef, {
      'reason':    reason,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });

    // Increment post reportCount
    final postRef = _posts.doc(post.id);
    batch.update(postRef, {'reportCount': FieldValue.increment(1)});

    // Add to moderator_reports
    final modReportRef = _modReports.doc();
    final report = ModeratorReport(
      id:            modReportRef.id,
      postId:        post.id,
      postTitle:     post.title,
      postAuthorUid: post.authorUid,
      reporterUid:   reporterUid,
      reporterName:  reporterName,
      reason:        reason,
      createdAt:     DateTime.now(),
      resolved:      false,
    );
    batch.set(modReportRef, report.toFirestore());

    await batch.commit();
  }

  // ── Moderator actions ─────────────────────────────────────────────────────────

  Stream<List<ModeratorReport>> modReportsStream({bool unresolvedOnly = true}) {
    Query q = _modReports.orderBy('createdAt', descending: true);
    if (unresolvedOnly) q = q.where('resolved', isEqualTo: false);
    return q.snapshots().map(
      (s) => s.docs.map(ModeratorReport.fromFirestore).toList(),
    );
  }

  Future<void> resolveReport(String reportId) async {
    await _modReports.doc(reportId).update({'resolved': true});
  }

  /// Moderator deletes a post and resolves all its open reports.
  Future<void> moderatorDeletePost(String postId) async {
    await deletePost(postId);
    // Resolve all open reports for this post
    final openReports = await _modReports
        .where('postId',   isEqualTo: postId)
        .where('resolved', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in openReports.docs) {
      batch.update(doc.reference, {'resolved': true});
    }
    await batch.commit();
  }

  /// Ban a user — sets a 'banned' flag on their user document.
  Future<void> banUser(String uid) async {
    await _db.collection('users').doc(uid).update({'banned': true});
  }
}