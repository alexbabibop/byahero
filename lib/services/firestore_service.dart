import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import '../models/journey.dart';
import '../models/community_post.dart';

/// Firestore wiring — laging safe kahit walang Firebase config ang build.
/// Ang mga write ay best-effort: kapag offline, ibabalik false at hayaang
/// mag-abang ang local store (tingnan ang SyncService).
class FirestoreService {
  FirebaseFirestore? _dbInstance;

  bool get available {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseFirestore get _db {
    final cached = _dbInstance;
    if (cached != null) return cached;
    final db = FirebaseFirestore.instance;
    _dbInstance = db;
    return db;
  }

  static const _timeout = Duration(seconds: 20);

  /// I-push ang byahe sa cloud. true = naituloy (o kasalukuyang nakasulat).
  Future<bool> saveJourney(Journey j, {String? proofPhotoUrl, String? hash}) async {
    if (!available) return false;
    try {
      await _db
          .collection('journeys')
          .doc(j.id)
          .set({
            ...j.toJson(),
            'proofPhotoUrl': proofPhotoUrl,
            'hash': hash,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(_timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> votePost(String postId, bool up) async {
    if (!available) return false;
    try {
      await _db.collection('posts').doc(postId).update({
        up ? 'upvotes' : 'downvotes': FieldValue.increment(1),
      }).timeout(_timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Stream<QuerySnapshot>? feedStream() {
    if (!available) return null;
    try {
      return _db
          .collection('posts')
          .orderBy('createdAt', descending: true)
          .limit(50)
          .snapshots();
    } catch (_) {
      return null;
    }
  }

  Future<bool> addPost(CommunityPost p) async {
    if (!available) return false;
    try {
      await _db.collection('posts').doc(p.id).set(p.toJson()).timeout(_timeout);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<void> sendBugReport(Map<String, dynamic> report) async {
    if (!available) return;
    try {
      await _db.collection('bug_reports').add({
        ...report,
        'createdAt': FieldValue.serverTimestamp(),
      }).timeout(_timeout);
    } catch (_) {}
  }
}
