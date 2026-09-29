import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../models/journey.dart';
import '../services/journey_tracker.dart';
import '../theme/app_theme.dart';

/// Angkas-style commute screen: buong mapa sa itaas, live route path na
/// naka-paint mula sa pinagsimulan hanggang sa kasalukuyang posisyon,
/// at malinaw na Start / Pause / Resume / End flow sa baba.
class HomeTrackerScreen extends StatefulWidget {
  const HomeTrackerScreen({super.key});

  @override
  State<HomeTrackerScreen> createState() => _HomeTrackerScreenState();
}

class _HomeTrackerScreenState extends State<HomeTrackerScreen> {
  LatLng? _dest;

  void _onLongPressMap(LatLng p) {
    final tracker = context.read<JourneyTracker>();
    if (tracker.isActive || tracker.isPaused) {
      _toast('Hindi mapapansin ang destination habang nagta-trip.');
      return;
    }
    setState(() => _dest = p);
    _toast('Itinakda ang destination. Itutuloy ito sa mapa.');
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  Future<void> _start(JourneyTracker tracker) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Privacy disclosure'),
        content: const Text(
          'Kokolektahin ng ByaHero ang live location mo habang naka-on ang '
          'trip para sa commute tracking, delay proof, at mapa.\n\n'
          'Nase-save sa phone mo kahit offline. Kapag mag-login ka, '
          'i-sync sa account mo. Hindi ito ibinebenta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Hindi pa'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Start Trip'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await tracker.startJourney(
        destLat: _dest?.latitude,
        destLng: _dest?.longitude,
        destLabel: _dest == null ? null : 'Pin sa mapa',
      );
      setState(() {});
      _toast('Nagsimula na ang trip. Safe ka, bida!');
    } catch (e) {
      _toast(e.toString().replaceFirst('Bad state: ', ''));
    }
  }

  Future<void> _end(JourneyTracker tracker) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('I-end ang trip?'),
        content: const Text(
            'Mase-save ang byahe sa phone mo at mag-sync sa account kapag online.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Bail out')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('End at i-save')),
        ],
      ),
    );
    if (confirm != true) return;
    await tracker.endJourney();
    if (!mounted) return;
    _toast('Nai-save ang trip! Buksan ang Trips para sa PDF.');
  }

  String _dur(Duration d) {
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    if (d.inMinutes > 0) return '${d.inMinutes}m ${d.inSeconds.remainder(60)}s';
    return '${d.inSeconds}s';
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<JourneyTracker>();
    final j = tracker.current;
    final live = tracker.isActive || tracker.isPaused;

    tracker.onDestinationReached = () {
      if (!mounted) return;
      showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Nasa destination ka na'),
          content: const Text('Pasok ka sa radius ng pinili mong place. '
              'I-end na ang trip?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hindi pa')),
            FilledButton(
              onPressed: () {
                Navigator.pop(context);
                _end(tracker);
              },
              child: const Text('I-end'),
            ),
          ],
        ),
      );
    };

    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.directions_bus_filled_rounded, color: AppTheme.gold),
          SizedBox(width: 8),
          Text('ByaHero'),
        ]),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(child: _statusPill(tracker)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
        children: [
          _LiveMapCard(
            onLongPress: _onLongPressMap,
            dest: _dest ?? _journeyDest(tracker),
          ),
          const SizedBox(height: 12),
          _destRow(tracker),
          const SizedBox(height: 12),
          _modePicker(tracker, live),
          const SizedBox(height: 14),
          if (!live) ..._startArea(tracker) else ..._liveArea(tracker, j!),
        ],
      ),
    );
  }

  LatLng? _journeyDest(JourneyTracker t) {
    final lat = t.current?.destLat;
    final lng = t.current?.destLng;
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Widget _statusPill(JourneyTracker t) {
    final (Color bg, String label) = switch (t.state) {
      JourneyState.active => (AppTheme.success, 'ON TRIP'),
      JourneyState.paused => (Colors.orange.shade700, 'PAUSED'),
      JourneyState.finished => (Colors.blueGrey, 'TAPOS NA'),
      JourneyState.idle => (Colors.white24, 'READY'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
              color: Colors.white, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white)),
      ]),
    );
  }

  Widget _destRow(JourneyTracker t) {
    final live = t.isActive || t.isPaused;
    final has = live ? _journeyDest(t) != null : _dest != null;
    return Row(children: [
      const Icon(Icons.place_outlined, size: 20, color: AppTheme.brandRed),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          has
              ? 'Destination: Pin sa mapa'
              : 'Wala pang destination — long-press ang mapa para maglagay.',
          style: TextStyle(
            fontSize: 13,
            fontWeight: has ? FontWeight.w700 : FontWeight.w500,
            color: has ? AppTheme.ink : AppTheme.muted,
          ),
        ),
      ),
      if (has && !live)
        TextButton(
          onPressed: () => setState(() => _dest = null),
          child: const Text('Alisin'),
        ),
    ]);
  }

  Widget _modePicker(JourneyTracker t, bool live) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(live ? 'Saan ka ngayon?' : 'Anong vehicle?',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
        const SizedBox(height: 8),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: VehicleMode.values
                .where((m) => m != VehicleMode.paused)
                .map((m) {
              final sel = t.mode == m;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  selected: sel,
                  showCheckmark: false,
                  onSelected: (_) => t.setMode(m),
                  avatar: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: sel ? Colors.white : m.color,
                        shape: BoxShape.circle),
                  ),
                  label: Text(m.label),
                  labelStyle: TextStyle(
                    color: sel ? Colors.white : AppTheme.ink,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  selectedColor: m.color,
                  backgroundColor: Colors.white,
                  side: BorderSide(color: sel ? m.color : AppTheme.line),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  List<Widget> _startArea(JourneyTracker t) {
    return [
      FilledButton.icon(
        icon: const Icon(Icons.play_arrow_rounded, size: 26),
        label: const Text('Start Journey'),
        onPressed: () => _start(t),
      ),
      if (t.lastError != null) ...[
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(children: [
            const Icon(Icons.warning_amber_rounded,
                size: 18, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t.lastError!,
                  style:
                      const TextStyle(color: Colors.red, fontSize: 12)),
            ),
          ]),
        ),
      ],
    ];
  }

  List<Widget> _liveArea(JourneyTracker t, Journey j) {
    return [
      // Malaking live timer card
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: t.isPaused
                ? [Colors.orange.shade800, Colors.orange.shade600]
                : [AppTheme.midnight, const Color(0xFF5C1414)],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('TOTAL BYAAHE',
                    style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1)),
                const SizedBox(height: 4),
                Text(_dur(j.totalTime),
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w900,
                        fontFeatures: [ui.FontFeature.tabularFigures()])),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: t.mode.color,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.navigation_rounded,
                color: Colors.white, size: 28),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Row(children: [
        _miniStat('Pila', _dur(j.waitingTime), Colors.amber.shade700),
        const SizedBox(width: 10),
        _miniStat('Points', '${j.points.length}', AppTheme.brandRed),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        if (t.isActive)
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.pause_rounded),
              label: const Text('Pause'),
              onPressed: t.pauseJourney,
            ),
          ),
        if (t.isPaused)
          Expanded(
            child: FilledButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Resume'),
              onPressed: t.resumeJourney,
            ),
          ),
        const SizedBox(width: 10),
        Expanded(
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red.shade800,
                foregroundColor: Colors.white),
            icon: const Icon(Icons.stop_rounded),
            label: const Text('End Trip'),
            onPressed: () => _end(t),
          ),
        ),
      ]),
    ];
  }

  Widget _miniStat(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.muted,
                    letterSpacing: .8)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: color,
                    fontFeatures: const [ui.FontFeature.tabularFigures()])),
          ],
        ),
      ),
    );
  }
}

/// Angkas-style live map: Positron tiles, white-cased color-coded route,
/// live marker, at follow-mode na awtomatikong sumusunod sa GPS.
class _LiveMapCard extends StatefulWidget {
  const _LiveMapCard({this.onLongPress, this.dest});

  final void Function(LatLng)? onLongPress;
  final LatLng? dest;

  @override
  State<_LiveMapCard> createState() => _LiveMapCardState();
}

class _LiveMapCardState extends State<_LiveMapCard> {
  StreamSubscription<Position>? _sub;
  final _map = MapController();
  Position? _pos;
  String? _gpsErr;
  bool _locOk = false;
  bool _follow = true;

  @override
  void initState() {
    super.initState();
    _watchGps();
  }

  Future<void> _watchGps() async {
    // Huwag mag-request ng permission dito — Start Trip ang humihingi.
    // Kung granted na, mag-stream; kung hindi, mapa pa rin ang gumana.
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsErr = 'Live marker: payagan ang Location.');
        return;
      }
      if (mounted) setState(() => _locOk = true);
      _pos = await Geolocator.getLastKnownPosition();
      if (mounted) setState(() {});
      if (_pos == null) {
        _pos = await Geolocator.getCurrentPosition()
            .timeout(const Duration(seconds: 12));
        if (mounted) setState(() {});
      }
      final first = _pos;
      if (first != null) _followTo(first);
      _sub = Geolocator.getPositionStream(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      ).listen((e) {
        _pos = e;
        if (mounted) setState(() {});
        if (_follow) _followTo(e);
      }, onError: (_) {
        if (mounted) setState(() => _gpsErr = 'Nawalan ng signal ng GPS.');
      });
    } catch (e) {
      if (mounted) setState(() => _gpsErr = 'GPS: $e');
    }
  }

  void _followTo(Position p) {
    try {
      _map.move(LatLng(p.latitude, p.longitude), _map.camera.zoom);
    } catch (_) {
      // MapController hindi pa attached — susunod sa unang GPS fix
      // ang onMapReady callback.
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<JourneyTracker>();
    final pts = tracker.current?.points ?? const <RoutePoint>[];

    // Color-coded segments: bawat pagbago ng mode ay bagong kulay.
    final segs = <List<RoutePoint>>[];
    for (final pt in pts) {
      if (segs.isEmpty || segs.last.last.mode != pt.mode) {
        segs.add([pt]);
      } else {
        segs.last.add(pt);
      }
    }
    final lines = <Polyline>[];
    // White casing sa ilalim para malinis ang ruta kahit light tiles.
    if (pts.length >= 2) {
      lines.add(Polyline(
        points: pts.map((e) => LatLng(e.lat, e.lng)).toList(),
        color: Colors.white,
        strokeWidth: 10,
      ));
    }
    for (var i = 0; i < segs.length; i++) {
      if (segs[i].length < 2) continue;
      lines.add(Polyline(
        points: segs[i].map((e) => LatLng(e.lat, e.lng)).toList(),
        color: segs[i].first.mode.color,
        strokeWidth: 5,
      ));
    }

    final marks = <Marker>[];
    if (pts.isNotEmpty) {
      marks.add(_pin(LatLng(pts.first.lat, pts.first.lng),
          Icons.play_arrow_rounded, Colors.green.shade700));
    }
    final dest = widget.dest;
    if (dest != null) {
      marks.add(_pin(dest, Icons.flag_rounded, AppTheme.brandRed));
    }
    final p = _pos;
    if (p != null) {
      marks.add(Marker(
        point: LatLng(p.latitude, p.longitude),
        width: 26,
        height: 26,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: .3),
                  blurRadius: 6,
                  offset: const Offset(0, 2)),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.all(3),
            child:
                Icon(Icons.navigation_rounded, color: Color(0xFF1E88E5), size: 16),
          ),
        ),
      ));
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        SizedBox(
          height: 300,
          child: Stack(children: [
            FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: p != null
                    ? LatLng(p.latitude, p.longitude)
                    : const LatLng(14.5995, 120.9842),
                initialZoom: 15.5,
                onLongPress: widget.onLongPress == null
                    ? null
                    : (tap, point) => widget.onLongPress!(point),
                onMapReady: () {
                  final pos = _pos;
                  if (pos != null) _followTo(pos);
                },
                onPositionChanged: (camera, hasGesture) {
                  // Kapag nag-drag ang user, i-stop ang auto-follow para
                  // hindi biglang ma-draw away ang view.
                  if (hasGesture && _follow) setState(() => _follow = false);
                },
              ),
              children: [
                TileLayer(
                  urlTemplate:
                      'https://basemaps.cartocdn.com/light_all/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.alexbabibop.byahero',
                ),
                PolylineLayer(polylines: lines),
                MarkerLayer(markers: marks),
              ],
            ),
            // Recenter button
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 2,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: p == null
                      ? null
                      : () {
                          setState(() => _follow = true);
                          _followTo(p);
                        },
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      _follow
                          ? Icons.my_location_rounded
                          : Icons.location_searching_rounded,
                      size: 20,
                      color: _follow ? AppTheme.brandRed : AppTheme.muted,
                    ),
                  ),
                ),
              ),
            ),
            if (_follow == false)
              const Positioned(
                top: 10,
                left: 10,
                child: _MapBadge(
                  icon: Icons.swipe_rounded,
                  label: 'Ginagalaw mo ang mapa',
                ),
              ),
            // Attribution (OSM/CARTO requirement)
            const Positioned(
              bottom: 6,
              left: 8,
              child: Text('© OpenStreetMap · CARTO',
                  style: TextStyle(
                      fontSize: 9, color: Colors.black45, shadows: [
                    Shadow(color: Colors.white, blurRadius: 3),
                  ])),
            ),
          ]),
        ),
        Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          color: Colors.white,
          child: Row(children: [
            Icon(
                _locOk ? Icons.gps_fixed_rounded : Icons.gps_off_rounded,
                size: 16,
                color: _locOk ? AppTheme.success : AppTheme.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                p == null
                    ? (_gpsErr ?? 'Naghahanap ng GPS fix…')
                    : '${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'
                        '  •  ±${p.accuracy.toStringAsFixed(0)}m'
                        '  •  ${(p.speed * 3.6).toStringAsFixed(1)} km/h',
                style: const TextStyle(
                    fontSize: 11.5, color: AppTheme.muted),
              ),
            ),
            if (pts.isNotEmpty)
              Text('${pts.length} pts',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.ink)),
          ]),
        ),
      ]),
    );
  }

  Marker _pin(LatLng at, IconData glyph, Color bg) {
    return Marker(
      point: at,
      width: 30,
      height: 30,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: .25),
                blurRadius: 4,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Icon(glyph, size: 15, color: Colors.white),
      ),
    );
  }
}

class _MapBadge extends StatelessWidget {
  const _MapBadge({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .92),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: AppTheme.midnight),
        const SizedBox(width: 6),
        Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w800)),
      ]),
    );
  }
}
