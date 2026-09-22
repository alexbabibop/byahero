import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/firestore_service.dart';

/// FB/Waze hybrid feed: live posts + upvote/downvote + live-stream URL placeholder.
class CommunityFeedScreen extends StatelessWidget {
  const CommunityFeedScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final fs = context.read<FirestoreService>();
    final ctrl = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('Community Traffic')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(children: [
            Expanded(
              child: TextField(controller: ctrl,
                decoration: const InputDecoration(
                  hintText: 'Traffic update? Pila sa terminal? Aksidente?',
                  border: OutlineInputBorder())),
            ),
            IconButton(
              icon: const Icon(Icons.send),
              onPressed: () {
                // TODO: addPost with GPS + userId
                ctrl.clear();
              },
            ),
          ]),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: fs.feedStream(),
            builder: (ctx, snap) {
              if (!snap.hasData) {
                return const Center(child: Text('No posts yet (connect Firebase to go live).'));
              }
              final docs = snap.data!.docs;
              return ListView.builder(
                itemCount: docs.length,
                itemBuilder: (_, i) {
                  final d = docs[i].data() as Map<String, dynamic>;
                  return Card(
                    child: ListTile(
                      title: Text('${d['text'] ?? ''}'),
                      subtitle: Text('▲ ${d['upvotes'] ?? 0}  ▼ ${d['downvotes'] ?? 0}'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_upward),
                          onPressed: () => fs.votePost(docs[i].id, true)),
                        IconButton(
                          icon: const Icon(Icons.arrow_downward),
                          onPressed: () => fs.votePost(docs[i].id, false)),
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
