import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/community_post.dart';
import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../theme/app_theme.dart';

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
    final fs = context.read<FirestoreService>();
    final uid = auth.current()?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Mag-login muna sa Account tab para mag-post.')));
      return;
    }
    if (!fs.available) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Offline mode — kailangan ng internet para mag-post.')));
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
      final ok = await fs.addPost(post);
      _ctrl.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(ok
              ? 'Posted! Salamat sa update, bida.'
              : 'Hindi na-post — offline o hindi pa na-sync. Subukan ulit.'),
          backgroundColor: ok ? Colors.green.shade700 : Colors.red.shade700));
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
    final auth = context.watch<AuthService>();
    final signedIn = auth.available && auth.current() != null;
    final stream = fs.feedStream();
    return Scaffold(
      appBar: AppBar(title: const Text('Community Traffic')),
      body: Column(children: [
        if (!signedIn)
          Container(
            width: double.infinity,
            color: AppTheme.gold.withValues(alpha: .2),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: const Row(children: [
              Icon(Icons.info_rounded, size: 18, color: Colors.brown),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Feed ay members-only. Mag-login sa Account tab para makita '
                  'at makapag-post.',
                  style: TextStyle(fontSize: 12, color: Colors.brown),
                ),
              ),
            ]),
          ),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: TextField(
                controller: _ctrl,
                enabled: signedIn,
                textInputAction: TextInputAction.send,
                decoration: InputDecoration(
                    hintText: signedIn
                        ? 'Traffic update? Pila sa terminal? Aksidente?'
                        : 'Mag-login para makapag-post'),
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
                  : const Icon(Icons.send_rounded),
              onPressed: _posting || !signedIn ? null : _post,
            ),
          ]),
        ),
        Expanded(
          child: stream == null
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Offline mode — kailangan ng internet para sa community '
                      'feed. Ang tracker at trips mo ay gumagana pa rin.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : StreamBuilder<QuerySnapshot>(
                  stream: stream,
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
                        final score = ((d['upvotes'] ?? 0) as int) -
                            ((d['downvotes'] ?? 0) as int);
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
