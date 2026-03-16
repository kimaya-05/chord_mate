import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────────────────────────────────────

const List<String> kGenres = [
  'Rock', 'Pop', 'Blues', 'Classical', 'Jazz', 'Folk', 'Country', 'Metal',
];

const List<String> kDifficulties = [
  'Beginner', 'Intermediate', 'Advanced',
];

const List<String> kKeys = [
  'C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B',
  'Cm', 'C#m', 'Dm', 'D#m', 'Em', 'Fm', 'F#m', 'Gm', 'G#m', 'Am', 'A#m', 'Bm',
];

// ─────────────────────────────────────────────────────────────────────────────
// ForumPost
// ─────────────────────────────────────────────────────────────────────────────

class ForumPost {
  final String    id;
  final String    authorUid;
  final String    authorName;
  final String    title;
  final String    artist;
  final String    key;
  final int       capo;
  final String    difficulty;
  final String    genre;
  final String    content;   // raw chord sheet text
  final double    ratingSum;
  final int       ratingCount;
  final int       reportCount;
  final DateTime  createdAt;
  final DateTime  updatedAt;

  const ForumPost({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.title,
    required this.artist,
    required this.key,
    required this.capo,
    required this.difficulty,
    required this.genre,
    required this.content,
    required this.ratingSum,
    required this.ratingCount,
    required this.reportCount,
    required this.createdAt,
    required this.updatedAt,
  });

  double get averageRating =>
      ratingCount == 0 ? 0 : ratingSum / ratingCount;

  String get capoLabel => capo == 0 ? 'No capo' : 'Capo $capo';

  factory ForumPost.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ForumPost(
      id:          doc.id,
      authorUid:   d['authorUid']   as String? ?? '',
      authorName:  d['authorName']  as String? ?? 'Unknown',
      title:       d['title']       as String? ?? '',
      artist:      d['artist']      as String? ?? '',
      key:         d['key']         as String? ?? 'C',
      capo:        (d['capo']       as num?)?.toInt() ?? 0,
      difficulty:  d['difficulty']  as String? ?? 'Beginner',
      genre:       d['genre']       as String? ?? 'Pop',
      content:     d['content']     as String? ?? '',
      ratingSum:   (d['ratingSum']  as num?)?.toDouble() ?? 0,
      ratingCount: (d['ratingCount'] as num?)?.toInt() ?? 0,
      reportCount: (d['reportCount'] as num?)?.toInt() ?? 0,
      createdAt:   (d['createdAt']  as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:   (d['updatedAt']  as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'authorUid':   authorUid,
    'authorName':  authorName,
    'title':       title,
    'artist':      artist,
    'key':         key,
    'capo':        capo,
    'difficulty':  difficulty,
    'genre':       genre,
    'content':     content,
    'ratingSum':   ratingSum,
    'ratingCount': ratingCount,
    'reportCount': reportCount,
    'createdAt':   Timestamp.fromDate(createdAt),
    'updatedAt':   Timestamp.fromDate(updatedAt),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ForumComment
// ─────────────────────────────────────────────────────────────────────────────

class ForumComment {
  final String   id;
  final String   authorUid;
  final String   authorName;
  final String   text;
  final DateTime createdAt;

  const ForumComment({
    required this.id,
    required this.authorUid,
    required this.authorName,
    required this.text,
    required this.createdAt,
  });

  factory ForumComment.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ForumComment(
      id:         doc.id,
      authorUid:  d['authorUid']  as String? ?? '',
      authorName: d['authorName'] as String? ?? 'Unknown',
      text:       d['text']       as String? ?? '',
      createdAt:  (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirestore() => {
    'authorUid':  authorUid,
    'authorName': authorName,
    'text':       text,
    'createdAt':  Timestamp.fromDate(createdAt),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// ModeratorReport — top-level collection for mod dashboard
// ─────────────────────────────────────────────────────────────────────────────

class ModeratorReport {
  final String   id;
  final String   postId;
  final String   postTitle;
  final String   postAuthorUid;
  final String   reporterUid;
  final String   reporterName;
  final String   reason;
  final DateTime createdAt;
  final bool     resolved;

  const ModeratorReport({
    required this.id,
    required this.postId,
    required this.postTitle,
    required this.postAuthorUid,
    required this.reporterUid,
    required this.reporterName,
    required this.reason,
    required this.createdAt,
    required this.resolved,
  });

  factory ModeratorReport.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return ModeratorReport(
      id:            doc.id,
      postId:        d['postId']       as String? ?? '',
      postTitle:     d['postTitle']    as String? ?? '',
      postAuthorUid: d['postAuthorUid'] as String? ?? '',
      reporterUid:   d['reporterUid']  as String? ?? '',
      reporterName:  d['reporterName'] as String? ?? 'Unknown',
      reason:        d['reason']       as String? ?? '',
      createdAt:     (d['createdAt']   as Timestamp?)?.toDate() ?? DateTime.now(),
      resolved:      d['resolved']     as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'postId':        postId,
    'postTitle':     postTitle,
    'postAuthorUid': postAuthorUid,
    'reporterUid':   reporterUid,
    'reporterName':  reporterName,
    'reason':        reason,
    'createdAt':     Timestamp.fromDate(createdAt),
    'resolved':      resolved,
  };
}