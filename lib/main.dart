import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/journey_tracker.dart';
import 'services/firestore_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'firebase_options_stub.dart';

final _navKey = GlobalKey<NavigatorState>();

/// Global crash catcher: imbes na silent minimize, magpapakita ng
/// error dialog na puwedeng kopyahin at isend (pang-debug sa device
/// na walang Android Studio).
void _showFatal(String title, String detail) {
  final ctx = _navKey.currentContext;
  if (ctx == null) return;
  showDialog(
    context: ctx,
    barrierDismissible: false,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(child: Text(detail)),
      actions: [
        TextButton(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: detail));
            ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(content: Text('Kinopya! Isend kay dev.')));
          },
          child: const Text('Kopyahin'),
        ),
        FilledButton(
          onPressed: () =>
              _navKey.currentState?.popUntil((r) => r.isFirst),
          child: const Text('Balik sa app'),
        ),
      ],
    ),
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) {
    FlutterError.presentError(d);
    _showFatal('May error ang app',
        '${d.exceptionAsString()}\n\n${d.stack ?? ''}');
  };
  // 1) Native config (google-services.json) kung meron.
  // 2) firebase_options_stub — tunay na values ng byahero-3dea7.
  // Kapag parehong wala, offline mode (tracker + PDF gumagana locally).
  try {
    await Firebase.initializeApp();
  } catch (_) {
    try {
      await Firebase.initializeApp(options: firebaseOptionsStub);
    } catch (_) {}
  }
  runZonedGuarded(() => runApp(const ByaHeroApp()), (e, s) {
    _showFatal('Biglang error', '$e\n\n$s');
  });
}

class ByaHeroApp extends StatelessWidget {
  const ByaHeroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => JourneyTracker()),
        Provider(create: (_) => FirestoreService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: MaterialApp(
        title: 'ByaHero',
        debugShowCheckedModeBanner: false,
        navigatorKey: _navKey,
        theme: AppTheme.light(),
        home: const _Root(),
      ),
    );
  }
}

class _Root extends StatelessWidget {
  const _Root();
  @override
  Widget build(BuildContext context) {
    // Simpleng gate: kung may journey o naka-login na, diretso tracker.
    // Full auth wiring nasa auth_screen.dart
    return const AuthGate();
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context) {
    // TODO: StreamBuilder FirebaseAuth.instance.authStateChanges()
    // MVP: splash muna, tapos tracker.
    return const SplashScreen();
  }
}
