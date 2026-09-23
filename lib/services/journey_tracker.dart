import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:uuid/uuid.dart';
import '../models/journey.dart';

/// Core Journey Tracker: Start / Pause / Resume / End + Idle detect + Geofence + Adaptive polling.
///
/// PRD:
/// - Idle: speed < 1 km/h nang > 3 min -> reverse geocode log
///   "Probably stopped near ... at ...".
/// - Geofence: 100m radius ng destination -> callback para mag-confirm ng End Trip.
/// - Adaptive polling: moving = every 10m, idle/queueing = 30-50m.
/// - Offline: kapag walang net, i-cache sa memory queue (production: sqflite),
///   tapos i-flush sa Firestore kapag online (gamit ang FirestoreService).
class JourneyTracker extends ChangeNotifier {
  Journey? current;
  JourneyState state = JourneyState.idle;
  VehicleMode mode = VehicleMode.bus;

  StreamSubscription<Position>? _sub;
  DateTime? _slowSince;
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
      userId: 'local-user', // TODO: FirebaseAuth.instance.currentUser.uid
      startedAt: DateTime.now(),
    )
      ..destLat = destLat
      ..destLng = destLng
      ..destLabel = destLabel;
    state = JourneyState.active;
    _slowSince = null;
    _listenAdaptive();
    notifyListeners();
  }

  void setMode(VehicleMode m) {
    mode = m;
    notifyListeners();
  }

  void pauseJourney() {
    if (state != JourneyState.active) return;
    state = JourneyState.paused;
    setMode(VehicleMode.paused);
    _restartListener(distanceFilter: 50);
  }

  void resumeJourney() {
    if (state != JourneyState.paused) return;
    state = JourneyState.active;
    _restartListener(distanceFilter: 10);
    notifyListeners();
  }

  Future<void> endJourney() async {
    await _sub?.cancel();
    current?.endedAt = DateTime.now();
    state = JourneyState.finished;
    notifyListeners();
    // TODO: FirestoreService().saveJourney(current!) + flush offline queue
  }

  void _listenAdaptive() {
    // Moving default: 10m. Kapag Nakapila/Paused: 30-50m (battery saver).
    final filter = (mode == VehicleMode.nakapila || mode == VehicleMode.paused) ? 40 : 10;
    _restartListener(distanceFilter: filter);
  }

  void _restartListener({required int distanceFilter}) {
    _sub?.cancel();
    const settings = LocationSettings(accuracy: LocationAccuracy.high);
    // distanceFilter emulated: Geolocator Android settings via old API;
    // sa production gamitin ang AndroidSettings(distanceFilter: ...).
    _sub = Geolocator.getPositionStream(locationSettings: settings).listen(_onPosition);
  }

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

    // Adaptive: lumipat ng filter kapag nagbago ang mode.
    _listenAdaptive();

    // Idle detection: speed < 1 km/h for > 3 minutes.
    if (kmh < 1.0) {
      _slowSince ??= DateTime.now();
      final slowFor = DateTime.now().difference(_slowSince!);
      if (slowFor.inMinutes >= 3 && !current!.autoLogs.any((l) => l.contains(_slowSince.toString()))) {
        // MVP: coordinates muna (geocoding plugin tinanggal para iwas SDK/version conflict).
        // TODO: ibalik ang reverse-geocode (placemark) kapag stable na ang geocoding plugin.
        final place = '${pos.latitude.toStringAsFixed(4)}, ${pos.longitude.toStringAsFixed(4)}';
        current!.autoLogs.add(
          'Probably stopped near $place at ${_fmtTime(DateTime.now())} [slowSince=$_slowSince]',
        );
        notifyListeners();
      }
    } else {
      _slowSince = null;
    }

    // Geofence: 100m radius.
    if (current!.destLat != null && current!.destLng != null) {
      final d = Geolocator.distanceBetween(
        pos.latitude, pos.longitude, current!.destLat!, current!.destLng!);
      if (d <= destRadiusM) {
        onDestinationReached?.call();
      }
    }
    notifyListeners();
  }

  String _fmtTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}
