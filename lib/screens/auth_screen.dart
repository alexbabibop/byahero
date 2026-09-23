import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';

/// Account tab: Register / Login / Google Sign-In + profile + logout.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool _loginMode = true;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _run(Future Function() fn, {String? successMsg}) async {
    try {
      await fn();
      if (!mounted || successMsg == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: Colors.green.shade700,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString()), duration: const Duration(seconds: 5)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();

    if (!auth.available) {
      return Scaffold(
        appBar: AppBar(title: const Text('Account')),
        body: const Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Offline mode',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text(
                'Walang Firebase config ang build na ito, kaya hindi pa gagana ang login. '
                'Tracker at PDF gumagana pa rin locally.',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
      body: StreamBuilder<User?>(
        stream: auth.stream(),
        builder: (_, snap) {
          final u = snap.data ?? auth.current();
          if (u != null) return _profile(context, auth, u);
          return _form(context, auth);
        },
      ),
    );
  }

  Widget _form(BuildContext context, AuthService auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('ByaHero Account',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          const Text('Isang account para sa journeys, proofs, at reports.',
              style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 16),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Login')),
              ButtonSegment(value: false, label: Text('Register')),
            ],
            selected: {_loginMode},
            onSelectionChanged: (s) => setState(() => _loginMode = s.first),
          ),
          const SizedBox(height: 16),
          if (!_loginMode)
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
          if (!_loginMode) const SizedBox(height: 10),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pass,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'Password (min 6)'),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: auth.busy
                ? null
                : () => _run(
                      () => _loginMode
                          ? auth.signIn(_email.text, _pass.text)
                          : auth.signUp(_email.text, _pass.text,
                              name: _name.text),
                      successMsg: _loginMode
                          ? 'Welcome back sa ByaHero!'
                          : 'Account created! Welcome sa ByaHero!',
                    ),
            child: auth.busy
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_loginMode ? 'Login' : 'Create account'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.g_mobiledata_rounded, size: 28),
            label: const Text('Continue with Google'),
            onPressed: auth.busy
                ? null
                : () => _run(auth.signInWithGoogle,
                    successMsg: 'Welcome sa ByaHero!'),
          ),
          const SizedBox(height: 4),
          const Text(
            'Note: ang Google button ay nangangailangan ng SHA-1 ng app na naka-register sa Firebase (tingnan ang guide). Kung nag-error 10, gamitin muna ang email.',
            style: TextStyle(fontSize: 11, color: Colors.grey),
          ),
          if (auth.lastError != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(auth.lastError!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            ),
        ],
      ),
    );
  }

  Widget _profile(BuildContext context, AuthService auth, User u) {
    final initial =
        (u.displayName?.isNotEmpty == true ? u.displayName![0] : (u.email?[0] ?? '?'))
            .toUpperCase();
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            CircleAvatar(
                radius: 30,
                child: Text(initial, style: const TextStyle(fontSize: 24))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(u.displayName ?? 'BiyaHero',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800)),
                  Text(u.email ?? '', style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('UID: ${u.uid}',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
            onPressed: () => _run(auth.signOut),
          ),
          const SizedBox(height: 8),
          const Text(
            'Naka-link na ang journeys at reports sa account na ito.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ),
    );
  }
}
