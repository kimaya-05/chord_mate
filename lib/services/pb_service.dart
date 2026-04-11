import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PersonalBest {
  final int correct;
  final int total;
  final double accuracy; // 0.0 – 1.0
  final DateTime timestamp;

  const PersonalBest({
    required this.correct,
    required this.total,
    required this.accuracy,
    required this.timestamp,
  });

  factory PersonalBest.fromMap(Map<String, dynamic> m) => PersonalBest(
        correct: (m['correct'] as num).toInt(),
        total: (m['total'] as num).toInt(),
        accuracy: (m['accuracy'] as num).toDouble(),
        timestamp: (m['timestamp'] as Timestamp).toDate(),
      );

  Map<String, dynamic> toMap() => {
        'correct': correct,
        'total': total,
        'accuracy': accuracy,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}

class PbService {
  static final _db = FirebaseFirestore.instance;

  /// Stable key for a chord pair — always sorted so "Am-C" == "C-Am".
  static String pairKey(String labelA, String labelB) {
    final sorted = [labelA, labelB]..sort();
    return '${sorted[0]}__${sorted[1]}';
  }

  static CollectionReference<Map<String, dynamic>> _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user');
    return _db.collection('users').doc(uid).collection('personalBests');
  }

  /// Returns null if no record exists yet.
  static Future<PersonalBest?> load(String labelA, String labelB) async {
    final doc = await _col().doc(pairKey(labelA, labelB)).get();
    if (!doc.exists) return null;
    return PersonalBest.fromMap(doc.data()!);
  }

  /// Writes only if [accuracy] is strictly better than the stored record.
  /// Returns the new PersonalBest if saved, null if the old one was kept.
  static Future<PersonalBest?> saveIfBetter({
    required String labelA,
    required String labelB,
    required int correct,
    required int total,
  }) async {
    if (total == 0) return null;
    final accuracy = correct / total;
    final existing = await load(labelA, labelB);

    if (existing != null && existing.accuracy >= accuracy) return null;

    final pb = PersonalBest(
      correct: correct,
      total: total,
      accuracy: accuracy,
      timestamp: DateTime.now(),
    );
    await _col().doc(pairKey(labelA, labelB)).set(pb.toMap());
    return pb;
  }
}