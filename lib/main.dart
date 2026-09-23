import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:provider/provider.dart';
import 'services/auth_service.dart';
import 'services/journey_tracker.dart';
import 'services/firestore_service.dart';
import 'screens/splash_screen.dart';
import 'theme/app_theme.dart';
import 'firebase_options_stub.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // 1) Native config (google-services.json) kung meron.
  // 2) firebase_options_stub — palitan ng tunay na values mula sa
  //    `flutterfire configure` o Firebase Console web config.
  // Kapag parehong wala, offline mode (tracker + PDF gumagana locally).
  try {
    await Firebase.initializeApp();
  } catch (_) {
    try {
      await Firebase.initializeApp(options: firebaseOptionsStub);
    } catch (_) {}
  }
  runApp(const ByaHeroApp());
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
