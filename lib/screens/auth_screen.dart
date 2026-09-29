import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../services/firestore_service.dart';
import '../services/journey_tracker.dart';
import '../services/sync_service.dart';
import '../theme/app_theme.dart';

/// Account tab: Register / Login / Google Sign-In + profile + logout.
/// Walang account? Fine — guest mode pa rin ang byahe, nasesave sa device.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loginMode = true;
  bool _obscure = true;
  bool _tried = false;
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

  String? _nameError(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ilagay ang pangalan mo';
    if (v.trim().length < 2) return 'Mas mahaba pa ang pangalan';
    return null;
  }

  String? _emailError(String? v) {
    if (v == null || v.trim().isEmpty) return 'Ilagay ang email mo';
    final re = RegExp(r'^[\w.+-]+@[\w-]+\.[\w.-]+$');
    if (!re.hasMatch(v.trim())) return 'Mali ang format ng email';
    return null;
  }

  String? _passError(String? v) {
    if (v == null || v.isEmpty) return 'Ilagay ang password';
    if (v.length < 6) return 'Min. 6 characters ang password';
    return null;
  }

  /// Login/register + i-sync ang mga nasesave na guest na byahe.
  Future<void> _submit(AuthService auth) async {
    setState(() => _tried = true);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    try {
      final User u = _loginMode
          ? await auth.signIn(_email.text, _pass.text)
          : await auth.signUp(_email.text, _pass.text, name: _name.text);
      final n = await SyncService.sync(
        store: context.read<JourneyTracker>().store,
        fs: context.read<FirestoreService>(),
        uid: u.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(
          content: Text(
            n > 0
                ? 'Welcome! Naka-sync ang $n na byahe mo sa account.'
                : (_loginMode
                    ? 'Welcome back, bida!'
                    : 'Account created! Welcome sa ByaHero!'),
          ),
        ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Bad state: ', ''))));
    }
  }

  Future<void> _runGoogle(AuthService auth) async {
    try {
      final u = await auth.signInWithGoogle();
      final n = await SyncService.sync(
        store: context.read<JourneyTracker>().store,
        fs: context.read<FirestoreService>(),
        uid: u.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(n > 0
              ? 'Welcome! Naka-sync ang $n na byahe mo.'
              : 'Welcome sa ByaHero, bida!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString().replaceFirst('Bad state: ', ''))));
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
              Text('Guest mode',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
              SizedBox(height: 8),
              Text(
                'Walang Firebase config ang build na ito, kaya naka-guest ka. '
                'Gumagana pa rin lahat: tracker, mapa, at PDF. Nasesave ang '
                'mga byahe sa phone mo.',
                style: TextStyle(color: AppTheme.muted),
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

  Widget _guestBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.gold.withValues(alpha: .16),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.gold),
      ),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.info_rounded, size: 20, color: Colors.brown),
        SizedBox(width: 10),
        Expanded(
          child: Text(
            'Guest ka ngayon — nasesave pa rin ang lahat ng byahe sa phone mo '
            '(offline-safe). Mag-login para ma-sync sa cloud at mabackup.',
            style: TextStyle(fontSize: 12.5, color: Colors.brown, height: 1.35),
          ),
        ),
      ]),
    );
  }

  Widget _form(BuildContext context, AuthService auth) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Form(
        key: _formKey,
        autovalidateMode:
            _tried ? AutovalidateMode.always : AutovalidateMode.disabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('ByaHero Account',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Sync ng byahe, i-download ang PDF reports.',
                style: TextStyle(color: AppTheme.muted)),
            const SizedBox(height: 16),
            _guestBanner(),
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
            if (!_loginMode) ...[
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: _nameError,
              ),
              const SizedBox(height: 10),
            ],
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.alternate_email),
              ),
              validator: _emailError,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _pass,
              obscureText: _obscure,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(auth),
              decoration: InputDecoration(
                labelText: 'Password (min. 6)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  icon: Icon(_obscure
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: _passError,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: auth.busy ? null : () => _submit(auth),
              child: auth.busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(_loginMode ? 'Login' : 'Gumawa ng Account'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.g_mobiledata_rounded, size: 26),
              label: const Text('Continue with Google'),
              onPressed: auth.busy ? null : () => _runGoogle(auth),
            ),
            const SizedBox(height: 8),
            if (auth.lastError != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 6),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(children: [
                  const Icon(Icons.error_outline, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(auth.lastError!,
                        style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _profile(BuildContext context, AuthService auth, User u) {
    final display = (u.displayName?.isNotEmpty ?? false) ? u.displayName! : 'Bida';
    final initial =
        (u.displayName?.isNotEmpty == true ? u.displayName![0] : (u.email?[0] ?? '?'))
            .toUpperCase();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(children: [
              CircleAvatar(
                radius: 30,
                backgroundColor: AppTheme.brandRed,
                child: Text(initial,
                    style: const TextStyle(
                        fontSize: 24,
                        color: Colors.white,
                        fontWeight: FontWeight.w900)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(display,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 2),
                    Text(u.email ?? '',
                        style: const TextStyle(
                            color: AppTheme.muted, fontSize: 13)),
                  ],
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 12),
        const _InfoRow(
          icon: Icons.cloud_done_rounded,
          title: 'Naka-sync na ang byahe',
          body: 'Lahat ng trips mo ay nasa cloud na. Kapag offline, '
              'nase-save muna sa phone at automatic na sisindin kapag online.',
        ),
        const SizedBox(height: 10),
        const _InfoRow(
          icon: Icons.delete_sweep_rounded,
          title: 'Sign out',
          body: 'Naiiwan sa phone ang nasesave na byahe. Kapag bumalik ka, '
              'magla-log in muli para ma-link sa account mo.',
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Sign out'),
          onPressed: () async {
            await auth.signOut();
            if (!context.mounted) return;
            // Bumabalik sa guest mode; hindi mawawala ang data —
            // nananatili sa device ang trips, at maaaring i-link ulit
            // sa (parehong o ibang) account sa next login.
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content:
                    Text('Na-log out. Nananatili ang trips mo sa device.')));
          },
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 20, color: AppTheme.brandRed),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 3),
                Text(body,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppTheme.muted, height: 1.35)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
