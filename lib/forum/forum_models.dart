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
  final String   id;
  final String   authorUid;
  final String   authorName;
  final String   title;
  final String   artist;
  final String   key;
  final int      capo;
  final String   difficulty;
  final String   genre;
  final String   content;
  final double   ratingSum;
  final int      ratingCount;
  final int      reportCount;
  final DateTime createdAt;
  final DateTime updatedAt;

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
      authorUid:   d['authorUid']    as String? ?? '',
      authorName:  d['authorName']   as String? ?? 'Unknown',
      title:       d['title']        as String? ?? '',
      artist:      d['artist']       as String? ?? '',
      key:         d['key']          as String? ?? 'C',
      capo:        (d['capo']        as num?)?.toInt() ?? 0,
      difficulty:  d['difficulty']   as String? ?? 'Beginner',
      genre:       d['genre']        as String? ?? 'Pop',
      content:     d['content']      as String? ?? '',
      ratingSum:   (d['ratingSum']   as num?)?.toDouble() ?? 0,
      ratingCount: (d['ratingCount'] as num?)?.toInt() ?? 0,
      reportCount: (d['reportCount'] as num?)?.toInt() ?? 0,
      createdAt:   (d['createdAt']   as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt:   (d['updatedAt']   as Timestamp?)?.toDate() ?? DateTime.now(),
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
// ModeratorReport
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
      postId:        d['postId']        as String? ?? '',
      postTitle:     d['postTitle']     as String? ?? '',
      postAuthorUid: d['postAuthorUid'] as String? ?? '',
      reporterUid:   d['reporterUid']   as String? ?? '',
      reporterName:  d['reporterName']  as String? ?? 'Unknown',
      reason:        d['reason']        as String? ?? '',
      createdAt:     (d['createdAt']    as Timestamp?)?.toDate() ?? DateTime.now(),
      resolved:      d['resolved']      as bool? ?? false,
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

// ─────────────────────────────────────────────────────────────────────────────
// InfractionRecord — one entry in a user's moderation history
// ─────────────────────────────────────────────────────────────────────────────

class InfractionRecord {
  final String   id;
  /// 'major' | 'minor'
  final String   severity;
  final String   reason;
  final DateTime createdAt;

  const InfractionRecord({
    required this.id,
    required this.severity,
    required this.reason,
    required this.createdAt,
  });

  factory InfractionRecord.fromMap(String id, Map<String, dynamic> d) {
    return InfractionRecord(
      id:        id,
      severity:  d['severity']  as String? ?? 'minor',
      reason:    d['reason']    as String? ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'severity':  severity,
    'reason':    reason,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

// ─────────────────────────────────────────────────────────────────────────────
// AppUserRecord — user document as seen by moderators
//
// Fields that exist at signup:  displayName, email, role, createdAt
// Fields written on first mod action: status, shadowBanned, postCount,
//   majorInfractions, minorInfractions, infractionHistory
// All moderation fields default gracefully if absent.
// ─────────────────────────────────────────────────────────────────────────────

class AppUserRecord {
  final String                 uid;
  final String                 displayName;
  final String                 email;
  final String                 role;
  /// 'active' | 'warned' | 'muted' | 'suspended' | 'banned'
  final String                 status;
  final bool                   shadowBanned;
  final int                    postCount;
  final int                    majorInfractions;
  final int                    minorInfractions;
  /// Timestamp at signup — maps to Firestore field 'createdAt'
  final DateTime               joinedAt;
  /// Non-null while a timed mute/suspension is active
  final DateTime?              restrictionEndsAt;
  final List<InfractionRecord> infractionHistory;

  const AppUserRecord({
    required this.uid,
    required this.displayName,
    required this.email,
    required this.role,
    required this.status,
    required this.shadowBanned,
    required this.postCount,
    required this.majorInfractions,
    required this.minorInfractions,
    required this.joinedAt,
    required this.restrictionEndsAt,
    required this.infractionHistory,
  });

  factory AppUserRecord.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;

    // infractionHistory is stored as an array of maps on the user doc.
    // Defaults to empty list if the field hasn't been written yet.
    final rawHistory = d['infractionHistory'] as List<dynamic>? ?? [];
    final history = rawHistory.asMap().entries.map((e) {
      return InfractionRecord.fromMap(
        e.key.toString(),
        Map<String, dynamic>.from(e.value as Map),
      );
    }).toList();

    return AppUserRecord(
      uid:               doc.id,
      displayName:       d['displayName']       as String? ?? 'Unknown',
      email:             d['email']             as String? ?? '',
      role:              d['role']              as String? ?? 'user',
      // All fields below may be absent on users created before mod system
      status:            d['status']            as String? ?? 'active',
      shadowBanned:      d['shadowBanned']      as bool?   ?? false,
      postCount:         (d['postCount']        as num?)?.toInt() ?? 0,
      majorInfractions:  (d['majorInfractions'] as num?)?.toInt() ?? 0,
      minorInfractions:  (d['minorInfractions'] as num?)?.toInt() ?? 0,
      // Firestore field is 'createdAt' — this is the signup timestamp
      joinedAt:          (d['createdAt']        as Timestamp?)?.toDate() ?? DateTime.now(),
      restrictionEndsAt: (d['restrictionEndsAt'] as Timestamp?)?.toDate(),
      infractionHistory: history,
    );
  }
}