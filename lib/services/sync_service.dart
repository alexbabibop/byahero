import 'package:firebase_core/firebase_core.dart';
import 'firestore_service.dart';
import 'journey_store.dart';

/// Cloud sync ng mga locally-saved na byahe.
///
/// Tumatakbo nang: (1) pag-login/register, (2) app start kung naka-login na,
/// (3) pag-end ng byahe kung online. Laging best-effort — kapag offline,
/// tetatagal sa device at susubukan sa susunod na pagkakataon.
class SyncService {
  SyncService._();

  static bool get _firebaseOk {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// I-claim ang guest/ibang-uid na byahe para sa bagong account, tapos
  /// i-push ang lahat ng pending sa Firestore.
  /// Bumabalik sa bilang ng na-sync na byahe.
  static Future<int> sync({
    required JourneyStore store,
    required FirestoreService fs,
    required String uid,
  }) async {
    if (uid.isEmpty || uid == JourneyStore.guestId || !_firebaseOk) return 0;
    try {
      await store.claimAll(JourneyStore.guestId, uid);
      final pending = await store.pendingFor(uid);
      if (pending.isEmpty) return 0;
      var ok = 0;
      for (final j in pending) {
        final pushed = await fs.saveJourney(j);
        if (!pushed) break; // offline / error — itigil, itutuloy susunod na beses
        await store.markSynced(j.id);
        ok++;
      }
      return ok;
    } catch (_) {
      return 0;
    }
  }
}
