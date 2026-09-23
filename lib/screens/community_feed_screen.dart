import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/community_post.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';

/// FB/Waze hybrid feed: live posts + upvote/downvote + post with GPS.
class CommunityFeedScreen extends StatefulWidget {
  const CommunityFeedScreen({super.key});
  @override
  State<CommunityFeedScreen> createState() => _CommunityFeedScreenState();
}

class _CommunityFeedScreenState extends State<CommunityFeedScreen> {
  final _ctrl = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty || _posting) return;
    final auth = context.read<AuthService>();
    final uid = auth.current()?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mag-login muna sa Account tab para mag-post.')));
      return;
    }
    setState(() => _posting = true);
    try {
      double lat = 0, lng = 0;
      try {
        final p = await Geolocator.getCurrentPosition()
            .timeout(const Duration(seconds: 8));
        lat = p.latitude;
        lng = p.longitude;
      } catch (_) {}
      final post = CommunityPost(
        id: const Uuid().v4(),
        userId: uid,
        text: text,
        lat: lat,
        lng: lng,
        createdAt: DateTime.now(),
      );
      await context.read<FirestoreService>().addPost(post);
      _ctrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Posted! Salamat sa update, bida.'),
          backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Post failed: $e')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    return Scaffold(
      appBar: AppBar(title: const Text('Community Traffic')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                decoration: const InputDecoration(
                    hintText: 'Traffic update? Pila sa terminal? Aksidente?'),
                onSubmitted: (_) => _post(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              icon: _posting
                  ? const SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.send),
              onPressed: _posting ? null : _post,
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: fs.feedStream(),
            builder: (ctx, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Hindi ma-load ang feed: ${snap.error}\n(Mag-login sa Account tab — members only ang feed.)',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }
              final docs = snap.data?.docs ?? [];
              if (docs.isEmpty) {
                return const Center(
                  child: Text('Walang posts pa. Ikaw ang mauna, bida!'),
                );
              }
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  final score =
                      ((d['upvotes'] ?? 0) as int) - ((d['downvotes'] ?? 0) as int);
                  return Card(
                    margin: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    child: ListTile(
                      title: Text('${d['text'] ?? ''}'),
                      subtitle: Text(
                          'Score: $score  •  ▲ ${d['upvotes'] ?? 0}  ▼ ${d['downvotes'] ?? 0}'),
                      trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.arrow_upward),
                                onPressed: () =>
                                    fs.votePost(docs[i].id, true)),
                            IconButton(
                                icon: const Icon(Icons.arrow_downward),
                                onPressed: () =>
                                    fs.votePost(docs[i].id, false)),
                          ]),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}
