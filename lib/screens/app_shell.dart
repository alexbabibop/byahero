import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/journey_store.dart';
import '../services/journey_tracker.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';
import 'auth_screen.dart';
import 'community_feed_screen.dart';
import 'home_tracker_screen.dart';
import 'journey_history_screen.dart';
import 'proof_camera_screen.dart';

/// Bottom-tab shell: lahat ng PRD functions, isang tap lang ang layo.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  String? _syncedFor;

  static const _pages = [
    HomeTrackerScreen(),
    ProofCameraScreen(),
    JourneyHistoryScreen(),
    CommunityFeedScreen(),
    AuthScreen(),
  ];

  @override
  void dispose() {
    // Hindi ito namin ang tracker: ang provider ang may-ari nito at siya
    // ang humahawak ng pag-clean up (ito ay child lamang ng provider tree).
    super.dispose();
  }

  Future<void> _maybeSync(String uid) async {
    if (uid == JourneyStore.guestId || _syncedFor == uid) return;
    _syncedFor = uid;
    await SyncService.sync(
      store: context.read<JourneyTracker>().store,
      fs: context.read<FirestoreService>(),
      uid: uid,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final uid = auth.current()?.uid ?? JourneyStore.guestId;
    // I-link ang mga byahe sa naka-login na account, o sa guest device.
    final tracker = context.read<JourneyTracker>();
    if (tracker.userId != uid) tracker.userId = uid;
    if (uid != JourneyStore.guestId) {
      // Sync agad pagkatapos ng login (o sa app start kung naka-login na).
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeSync(uid));
    }

    // Sinasadyang LAZY (hindi IndexedStack): ang camera/maps native SDKs ay
    // hindi dapat mag-init sa cold start — nakita sa Android 16.
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppTheme.line)),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.navigation_outlined),
              selectedIcon: Icon(Icons.navigation_rounded),
              label: 'Tracker',
            ),
            NavigationDestination(
              icon: Icon(Icons.camera_alt_outlined),
              selectedIcon: Icon(Icons.camera_alt_rounded),
              label: 'Proof',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
              selectedIcon: Icon(Icons.route_rounded),
              label: 'Mga Byahe',
            ),
            NavigationDestination(
              icon: Icon(Icons.forum_outlined),
              selectedIcon: Icon(Icons.forum_rounded),
              label: 'Community',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Account',
            ),
          ],
        ),
      ),
    );
  }
}
