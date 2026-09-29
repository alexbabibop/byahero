import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import '../models/journey.dart';

/// Lokal na tahanan ng mga byahe (sqflite).
///
/// Regla ng ByaHero:
/// - LAHAT ng tapos na byahe ay laging nasesave sa device — kahit walang
///   account, kahit offline. Walang byahe ang nawawala.
/// - Kapag walang account, naka-tag sila sa [guestId]; kapag nag-login ang
///   user, ia-claim ng bagong uid ang mga yun at i-fi-flag na pending sa
///   cloud sync (tingnan ang SyncService).
/// - Ang `synced` flag ang naghihiwalay ng "nasa device lang" sa
///   "nasa Firestore na".
class JourneyStore {
  static const guestId = 'guest';
  static const _table = 'journeys';

  Database? _db;

  Future<Database> _database() async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getApplicationDocumentsDirectory();
    final db = await openDatabase(
      '${dir.path}/byahero_journeys_v1.db',
      version: 1,
      onCreate: (d, _) => d.execute('''
        CREATE TABLE $_table (
          id TEXT PRIMARY KEY,
          user_id TEXT NOT NULL,
          started_at INTEGER NOT NULL,
          ended_at INTEGER,
          dest_lat REAL,
          dest_lng REAL,
          dest_label TEXT,
          points TEXT NOT NULL,
          auto_logs TEXT NOT NULL,
          synced INTEGER NOT NULL DEFAULT 0
        )
      '''),
    );
    _db = db;
    return db;
  }

  /// Idagdag o palitan ang byahe. Laging tinatry kahit walang net.
  Future<void> save(Journey j, {required String userId, bool synced = false}) async {
    try {
      final db = await _database();
      await db.insert(
        _table,
        j.toStorage(synced: synced ? 1 : 0),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {
      // Storage unavailable (bihirang mangyari) — huwag pabagsakin ang app.
    }
  }

  /// Lahat ng byahe ng isang user, bago pataas.
  Future<List<Journey>> listFor(String userId) async {
    try {
      final db = await _database();
      final rows = await db.query(
        _table,
        where: 'user_id = ?',
        whereArgs: [userId],
        orderBy: 'started_at DESC',
      );
      return rows.map(Journey.fromStorage).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Mga hindi pa nai-push sa cloud (para sa sync).
  Future<List<Journey>> pendingFor(String userId) async {
    try {
      final db = await _database();
      final rows = await db.query(
        _table,
        where: 'user_id = ? AND synced = 0',
        whereArgs: [userId],
        orderBy: 'started_at ASC',
      );
      return rows.map(Journey.fromStorage).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<int> pendingCount(String userId) async {
    try {
      final db = await _database();
      final r = await db.rawQuery(
        'SELECT COUNT(*) AS c FROM $_table WHERE user_id = ? AND synced = 0',
        [userId],
      );
      return Sqflite.firstIntValue(r) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> markSynced(String id) async {
    try {
      final db = await _database();
      await db.update(_table, {'synced': 1}, where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }

  /// Ilipat lahat ng byahe ng ibang user (guest o ibang account) sa bagong uid.
  /// Ibabalik ang synced = 0 para i-push sa cloud.
  Future<int> claimAll(String fromUserId, String toUserId) async {
    if (fromUserId == toUserId) return 0;
    try {
      final db = await _database();
      return await db.update(
        _table,
        {'user_id': toUserId, 'synced': 0},
        where: 'user_id = ?',
        whereArgs: [fromUserId],
      );
    } catch (_) {
      return 0;
    }
  }

  Future<void> remove(String id) async {
    try {
      final db = await _database();
      await db.delete(_table, where: 'id = ?', whereArgs: [id]);
    } catch (_) {}
  }
}
