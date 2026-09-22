import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journey.dart';
import '../models/community_post.dart';

/// Firestore wiring + offline queue stub.
/// Production: palitan ang _queue ng sqflite table at i-flush kapag online
/// (connectivity_plus listener).
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final List<Map<String, dynamic>> _queue = [];

  Future<void> saveJourney(Journey j, {String? proofPhotoUrl, String? hash}) async {
    final data = {...j.toJson(), 'proofPhotoUrl': proofPhotoUrl, 'hash': hash};
    try {
      await _db.collection('journeys').doc(j.id).set(data);
    } catch (_) {
      _queue.add({'col': 'journeys', 'id': j.id, 'data': data});
    }
  }

  Future<void> votePost(String postId, bool up) async {
    await _db.collection('posts').doc(postId).update({
      up ? 'upvotes' : 'downvotes': FieldValue.increment(1),
    });
  }

  Stream<QuerySnapshot> feedStream() =>
      _db.collection('posts').orderBy('createdAt', descending: true).limit(50).snapshots();

  Future<void> addPost(CommunityPost p) async {
    await _db.collection('posts').doc(p.id).set(p.toJson());
  }

  Future<void> sendBugReport(Map<String, dynamic> report) async {
    await _db.collection('bug_reports').add({
      ...report,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
