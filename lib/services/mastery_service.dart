import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class MasteryService {
  static final _db = FirebaseFirestore.instance;

  static CollectionReference<Map<String, dynamic>> _col() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('No signed-in user');
    return _db.collection('users').doc(uid).collection('chordMastery');
  }

  /// Returns how many solid hits have been recorded for this chord.
  static Future<int> getHitCount(String mlLabel) async {
    try {
      final doc = await _col().doc(mlLabel).get();
      final count = (doc.data()?['hits'] as num?)?.toInt() ?? 0;
      debugPrint('[MasteryService] getHitCount $mlLabel → $count');
      return count;
    } catch (e) {
      debugPrint('[MasteryService] getHitCount error: $e');
      return 0;
    }
  }

  /// Increments the hit counter by 1. Returns the new total.
  static Future<int> recordHit(String mlLabel) async {
    try {
      final ref = _col().doc(mlLabel);
      // Write the increment to Firestore (fire and forget)
      await ref.set(
        {'hits': FieldValue.increment(1)},
        SetOptions(merge: true),
      );
      // Read back with a small delay to let the server-side increment settle
      await Future.delayed(const Duration(milliseconds: 300));
      final doc = await ref.get();
      final count = (doc.data()?['hits'] as num?)?.toInt() ?? 1;
      debugPrint('[MasteryService] recordHit $mlLabel → hits=$count');
      return count;
    } catch (e) {
      debugPrint('[MasteryService] recordHit error: $e');
      return 0;
    }
  }

  static bool isMastered(int hits) => hits >= 5;
}