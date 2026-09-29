import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/journey.dart';
import 'firestore_service.dart';
import 'journey_store.dart';

/// Core Journey Tracker: Start / Pause / Resume / End + Idle detect + Geofence + Adaptive polling.
///
/// PRD:
/// - Idle: speed < 1 km/h nang > 3 min -> reverse geocode log
///   "Probably stopped near ... at ...".
/// - Geofence: 100m radius ng destination -> callback para mag-confirm ng End Trip.
/// - Adaptive polling: moving = every 10m, idle/queueing = 30-50m.
/// - Offline: LAHAT ng byahe ay laging nasesave sa JourneyStore (sqflite)
///   kahit walang account — auto-sync sa cloud kapag nag-login.
class JourneyTracker extends ChangeNotifier {
  JourneyTracker({JourneyStore? store, this.fs})
      : store = store ?? JourneyStore();

  final JourneyStore store;
  final FirestoreService? fs;

  Journey? current;
  JourneyState state = JourneyState.idle;
  VehicleMode mode = VehicleMode.bus;
  String userId = JourneyStore.guestId;

  StreamSubscription<Position>? _sub;
  DateTime? _slowSince;
  int _autosave = 0;
  VehicleMode _modeBeforePause = VehicleMode.bus;
  bool liteMapMode = false; // true kapag RAM < 400MB (set mula sa telemetry)
  double destRadiusM = 100;

  /// Callback kapag pumasok sa geofence — UI ang magpapakita ng confirm dialog.
  void Function()? onDestinationReached;

  bool get isActive => state == JourneyState.active;
  bool get isPaused => state == JourneyState.paused;

  String? lastError;

  Future<void> startJourney({double? destLat, double? destLng, String? destLabel}) async {
    lastError = null;
    // Location services check.
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    if (!serviceOn) {
      lastError = 'Naka-off ang Location/GPS ng phone. I-on muna sa Settings → Location.';
      notifyListeners();
      throw StateError(lastError!);
    }
    // Permission flow (kasama ang deniedForever).
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      lastError = 'Denied ang Location permission. Payagan sa popup o sa App Settings.';
      notifyListeners();
      throw StateError(lastError!);
    }
    if (perm == LocationPermission.deniedForever) {
      lastError = 'Naka-"Don\'t allow" forever ang Location. Buksan: Settings → Apps → ByaHero → Permissions → Location → Allow.';
      notifyListeners();
      throw StateError(lastError!);
    }
    current = Journey(
      id: const Uuid().v4(),
      userId: userId,
      startedAt: DateTime.now(),
    )
      ..destLat = destLat
      ..destLng = destLng
      ..destLabel = destLabel;
    state = JourneyState.active;
    _slowSince = null;
    _autosave = 0;
    _geofenceHit = false;
    await _closeInterrupted();
    await store.save(current!, userId: userId); // draft mula sa umpisa
    _listenAdaptive();
    notifyListeners();
  }

  /// Ang mga dating on-going na byahe (namatay ang app / hindi na-end)
  /// ay bibigyan ng patapos na oras para hindi sila umikot nang walang hanggan.
  Future<void> _closeInterrupted() async {
    try {
      final rows = await store.listFor(userId);
      for (final j in rows) {
        if (j.endedAt == null) {
          j.endedAt =
              j.points.isNotEmpty ? j.points.last.timestamp : j.startedAt;
          await store.save(j, userId: userId, synced: false);
        }
      }
    } catch (_) {}
  }

  void setMode(VehicleMode m) {
    if (m == mode) return;
    mode = m;
    _listenAdaptive();
    notifyListeners();
  }

  void pauseJourney() {
    if (state != JourneyState.active) return;
    if (mode != VehicleMode.paused) _modeBeforePause = mode;
    state = JourneyState.paused;
    mode = VehicleMode.paused;
    _restartListener(distanceFilter: 50);
    notifyListeners();
  }

  void resumeJourney() {
    if (state != JourneyState.paused) return;
    state = JourneyState.active;
    // Ibalik ang dating mode (hindi na dapat manatiling "Paused").
    mode = _modeBeforePause;
    _restartListener(distanceFilter: 10);
    notifyListeners();
  }

  Future<void> endJourney() async {
    await _sub?.cancel();
    current?.endedAt = DateTime.now();
    state = JourneyState.finished;
    notifyListeners();
    final j = current;
    if (j == null) return;
    // 1) Laging i-save sa device (kahit offline, kahit walang account).
    await store.save(j, userId: userId);
    // 2) Best-effort cloud push kapag naka-login na.
    final service = fs;
    if (service != null &&
        service.available &&
        userId != JourneyStore.guestId) {
      final ok = await service.saveJourney(j);
      if (ok) await store.markSynced(j.id);
    }
    notifyListeners();
  }

  /// I-save ang kasalukuyang (on-going) byahe sa device — pang-proteksyon
  /// kapag namatay ang app o ma-lowbat. Tinatawag habang active ang trip.
  Future<void> _autosaveNow() async {
    final j = current;
    if (j == null) return;
    await store.save(j, userId: userId);
  }

  void _listenAdaptive() {
    // Moving default: 10m. Kapag Nakapila/Paused: 30-50m (battery saver).
    final filter = (mode == VehicleMode.nakapila || mode == VehicleMode.paused) ? 40 : 10;
    _restartListener(distanceFilter: filter);
  }

  void _restartListener({required int distanceFilter}) {
    _sub?.cancel();
    // Adaptive polling (totoo na): maliit ang hakbang kapag gumagalaw,
    // malaki kapag nakapila — para tipid sa baterya.
    final filter = distanceFilter > 0
        ? distanceFilter
        : ((mode == VehicleMode.nakapila || mode == VehicleMode.paused) ? 40 : 10);
    _sub = Geolocator.getPositionStream(
      locationSettings: LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: filter,
      ),
    ).listen(_onPosition);
  }

  bool _geofenceHit = false;

  Future<void> _onPosition(Position pos) async {
    if (current == null || (state != JourneyState.active && state != JourneyState.paused)) return;
    final kmh = pos.speed * 3.6;
    final effectiveMode = state == JourneyState.paused ? VehicleMode.paused : mode;

    current!.points.add(RoutePoint(
      lat: pos.latitude,
      lng: pos.longitude,
      timestamp: DateTime.now(),
      mode: effectiveMode,
      speedKmh: kmh < 0 ? 0 : kmh,
    ));

    // Autosave: bawat 20 points, i-save ang draft sa device para hindi
    // mawala ang byahe kapag namatay ang app o naubusan ng baterya.
    _autosave++;
    if (_autosave >= 20) {
      _autosave = 0;
      unawaited(_autosaveNow());
    }

    // Idle detection: speed < 1 km/h for > 3 minutes.
    if (kmh < 1.0) {
      _slowSince ??= DateTime.now();
      final slowFor = DateTime.now().difference(_slowSince!);
      if (slowFor.inMinutes >= 3 &&
          !current!.autoLogs.any((l) => l.contains(_fmtTime(_slowSince!)))) {
        // MVP: coordinates muna (geocoding plugin tinanggal para iwas
        // SDK/version conflict). Laging may bagong log kada pag-detect.
        final place =
            '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        current!.autoLogs.add(
          'Probably stopped near $place at ${_fmtTime(DateTime.now())} '
          '(${_durStr(slowFor)})',
        );
        notifyListeners();
      }
    } else {
      _slowSince = null;
    }

    // Geofence: 100m radius — FIRE ONCE per journey para hindi ma-spam
    // ang confirm dialog habang nasa loob na.
    if (current!.destLat != null &&
        current!.destLng != null &&
        !_geofenceHit) {
      final d = Geolocator.distanceBetween(pos.latitude, pos.longitude,
          current!.destLat!, current!.destLng!);
      if (d <= destRadiusM) {
        _geofenceHit = true;
        onDestinationReached?.call();
      }
    }
    notifyListeners();
  }

  String _durStr(Duration d) {
    if (d.inMinutes > 0) return '${d.inMinutes} min';
    return '${d.inSeconds} sec';
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
