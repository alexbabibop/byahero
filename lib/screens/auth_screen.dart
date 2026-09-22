import 'package:flutter/material.dart';

/// Firebase Auth: Email/Password + Google Sign-In (wiring stub).
/// Production: firebase_auth + google_sign_in packages (nasa pubspec na).
class AuthScreen extends StatelessWidget {
  const AuthScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final email = TextEditingController();
    final pass = TextEditingController();
    return Scaffold(
      appBar: AppBar(title: const Text('ByaHero — Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: pass, obscureText: true, decoration: const InputDecoration(labelText: 'Password')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () {
              // TODO: FirebaseAuth.instance.signInWithEmailAndPassword(...)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('TODO: wire Firebase Auth'))),
            },
            child: const Text('Login'),
          ),
          OutlinedButton(
            onPressed: () {
              // TODO: GoogleSignIn().signIn() -> Firebase credential
            },
            child: const Text('Sign in with Google'),
          ),
        ]),
      ),
    );
  }
}
