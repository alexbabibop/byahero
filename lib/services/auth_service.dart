import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Tunay na account system: Email register/login + Google Sign-In.
/// Kapag walang Firebase config ang build (offline mode), nagtatapon ng
/// malinaw na error imbes na silent fail.
class AuthService extends ChangeNotifier {
  bool busy = false;
  String? lastError;

  bool get available {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  void _need() {
    if (!available) {
      throw StateError(
        'Offline mode — walang Firebase config ang build na ito. '
        'Ilagay ang firebase_options (tingnan ang SETUP_GUIDE).',
      );
    }
  }

  Stream<User?> stream() {
    _need();
    return FirebaseAuth.instance.authStateChanges();
  }

  User? current() => available ? FirebaseAuth.instance.currentUser : null;

  Future<User> signUp(String email, String password, {String? name}) async {
    _need();
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      if (name != null && name.trim().isNotEmpty) {
        await cred.user?.updateDisplayName(name.trim());
      }
      await _saveProfile(cred.user);
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      lastError = _msg(e);
      notifyListeners();
      throw StateError(lastError!);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<User> signIn(String email, String password) async {
    _need();
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _saveProfile(cred.user);
      return cred.user!;
    } on FirebaseAuthException catch (e) {
      lastError = _msg(e);
      notifyListeners();
      throw StateError(lastError!);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<User> signInWithGoogle() async {
    _need();
    busy = true;
    lastError = null;
    notifyListeners();
    try {
      final g = await GoogleSignIn().signIn();
      if (g == null) throw StateError('Cancelled ang Google sign-in.');
      final ga = await g.authentication;
      final cred = GoogleAuthProvider.credential(
        accessToken: ga.accessToken,
        idToken: ga.idToken,
      );
      final res = await FirebaseAuth.instance.signInWithCredential(cred);
      await _saveProfile(res.user);
      return res.user!;
    } on FirebaseAuthException catch (e) {
      lastError = _msg(e);
      notifyListeners();
      throw StateError(lastError!);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    if (!available) return;
    try {
      await GoogleSignIn().signOut();
    } catch (_) {}
    await FirebaseAuth.instance.signOut();
    notifyListeners();
  }

  /// Best-effort user profile doc (users/{uid}) — hindi blocker kapag offline.
  Future<void> _saveProfile(User? u) async {
    if (u == null) return;
    try {
      await FirebaseFirestore.instance.collection('users').doc(u.uid).set(
        {
          'email': u.email,
          'displayName': u.displayName,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {}
  }

  static String _msg(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'May account na sa email na yan. Mag-login na lang.';
      case 'invalid-email':
        return 'Maling email format.';
      case 'weak-password':
        return 'Mahinang password — hindi bababa sa 6 characters.';
      case 'user-not-found':
        return 'Walang account sa email na yan. Mag-register muna.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Maling email o password.';
      case 'network-request-failed':
        return 'Walang internet connection.';
      case 'operation-not-allowed':
        return 'Hindi pa naka-enable ang provider na ito sa Firebase Console.';
      default:
        return e.message ?? 'Auth error (${e.code}).';
    }
  }
}
