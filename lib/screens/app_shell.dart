import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/journey_tracker.dart';
import 'home_tracker_screen.dart';
import 'proof_camera_screen.dart';
import 'pdf_preview_screen.dart';
import 'community_feed_screen.dart';
import 'auth_screen.dart';

/// Bottom-tab shell: lahat ng PRD functions, isang tap lang ang layo.
class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _pages = [
    HomeTrackerScreen(),
    ProofCameraScreen(),
    PdfPreviewScreen(),
    CommunityFeedScreen(),
    AuthScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    // I-link ang journeys sa naka-login na account (o 'local-user' kung offline).
    final tracker = context.read<JourneyTracker>();
    tracker.userId =
        context.watch<AuthService>().current()?.uid ?? 'local-user';
    // Sinasadyang LAZY (hindi IndexedStack): ang camera/maps native SDKs ay
    // hindi dapat mag-init sa cold start — nag-crash sa ilang devices.
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
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
            icon: Icon(Icons.picture_as_pdf_outlined),
            selectedIcon: Icon(Icons.picture_as_pdf_rounded),
            label: 'Reports',
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
    );
  }
}
