import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/journey.dart';
import '../services/journey_tracker.dart';
import '../theme/app_theme.dart';

/// Main tracker UI: One-tap Start/Pause/Resume/End + Vehicle selector
/// + live stats + geofence confirm dialog.
class HomeTrackerScreen extends StatelessWidget {
  const HomeTrackerScreen({super.key});

  String _dur(Duration d) =>
      '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';

  String _statusText(JourneyTracker t) {
    if (t.current == null) return 'Ready';
    switch (t.state) {
      case JourneyState.active:
        return 'On trip • ${t.mode.label}';
      case JourneyState.paused:
        return 'Paused';
      case JourneyState.finished:
        return 'Trip done';
      case JourneyState.idle:
        return 'Ready';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracker = context.watch<JourneyTracker>();
    tracker.onDestinationReached = () {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Nasa destination ka na?'),
          content: Text(
              'Pumasok ka sa 100m radius ng ${tracker.current?.destLabel ?? 'destination'}. I-end ang trip?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Hindi pa')),
            FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  tracker.endJourney();
                },
                child: const Text('End Trip')),
          ],
        ),
      );
    };

    final j = tracker.current;
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [
          Icon(Icons.directions_bus_filled_rounded, color: Colors.amber),
          SizedBox(width: 8),
          Text('ByaHero'),
        ]),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: j == null ? Colors.white24 : Colors.green,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: j == null ? Colors.grey[300]! : Colors.white,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(_statusText(tracker),
                  style: const TextStyle(fontSize: 12, color: Colors.white)),
            ]),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.midnight, Color(0xFF5C1414)],
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: tracker.mode.color,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.navigation_rounded,
                      color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Ikaw ang bida',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900)),
                      Text('sa byahe mo.',
                          style: TextStyle(
                              color: Colors.white70, fontSize: 14)),
                    ],
                  ),
                ),
              ]),
            ),
            const SizedBox(height: 14),
            // Vehicle selector
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Nasaan ka ngayon?',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<VehicleMode>(
                      value: tracker.mode,
                      decoration: const InputDecoration(
                          labelText: 'Vehicle / Status'),
                      items: VehicleMode.values
                          .map((m) => DropdownMenuItem(
                                value: m,
                                child: Row(children: [
                                  Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                          color: m.color,
                                          shape: BoxShape.circle)),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(m.label)),
                                ]),
                              ))
                          .toList(),
                      onChanged: (m) {
                        if (m != null) tracker.setMode(m);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            if (j == null) ...[
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow_rounded, size: 28),
                label: const Text('Start Journey'),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text('Location disclosure'),
                      content: const Text(
                        'Kokolektahin ng ByaHero ang precise location mo habang active ang journey para sa commute tracking at delay proof. Naka-store ito sa Firebase account mo at hindi ibinebenta.',
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('Cancel')),
                        FilledButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text('I agree — Start')),
                      ],
                    ),
                  );
                  if (ok != true) return;
                  try {
                    await tracker.startJourney(
                        destLat: 14.5547,
                        destLng: 121.0244,
                        destLabel: 'DOE BGC (sample)');
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(e.toString()),
                        duration: const Duration(seconds: 6)));
                  }
                },
              ),
              if (tracker.lastError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(tracker.lastError!,
                      style:
                          const TextStyle(color: Colors.red, fontSize: 12)),
                ),
              const SizedBox(height: 10),
              const Row(children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Hihingi ng Location permission pag-start. Auto-detect ang pila at destination.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ),
              ]),
            ] else ...[
              // Stats grid
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.05,
                children: [
                  _stat(context, 'Total', _dur(j.totalTime), Icons.timer),
                  _stat(context, 'Pila', _dur(j.waitingTime),
                      Icons.hourglass_bottom, highlight: true),
                  _stat(context, 'Points', '${j.points.length}',
                      Icons.route),
                ],
              ),
              const SizedBox(height: 6),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Moving: ${_dur(j.movingTime)}',
                          style: const TextStyle(fontSize: 13)),
                      if (j.autoLogs.isNotEmpty) ...[
                        const Divider(),
                        const Text('Trip timeline',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        ...j.autoLogs.map((l) => Padding(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 3),
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  const Icon(Icons.place,
                                      size: 14, color: AppTheme.brandRed),
                                  const SizedBox(width: 6),
                                  Expanded(
                                      child: Text(l,
                                          style: const TextStyle(
                                              fontSize: 12))),
                                ],
                              ),
                            )),
                      ] else
                        const Text(
                            'Walang auto-stop pa. Kapag huminto ka ng 3+ min, lalabas dito.',
                            style:
                                TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(children: [
                if (tracker.isActive)
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.pause),
                      label: const Text('Pause'),
                      onPressed: tracker.pauseJourney,
                    ),
                  ),
                if (tracker.isPaused)
                  Expanded(
                    child: FilledButton.icon(
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Resume'),
                      onPressed: tracker.resumeJourney,
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                        backgroundColor: AppTheme.brandRed),
                    icon: const Icon(Icons.stop_rounded),
                    label: const Text('End Trip'),
                    onPressed: () => tracker.endJourney(),
                  ),
                ),
              ]),
              if (tracker.state == JourneyState.finished)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Text(
                    'Trip saved! Pila: ${_dur(j.waitingTime)} / Total: ${_dur(j.totalTime)}. Export PDF mula sa report screen.',
                    style: TextStyle(
                        color: Colors.green.shade800, fontSize: 12),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _stat(
      BuildContext context, String label, String value, IconData icon,
      {bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: highlight ? AppTheme.brandRed : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: highlight ? AppTheme.brandRed : const Color(0xFFE7DFD3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon,
              size: 20,
              color: highlight ? Colors.white : AppTheme.brandRed),
          const SizedBox(height: 4),
          Text(value,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  color: highlight ? Colors.white : Colors.black87)),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  color: highlight ? Colors.white70 : Colors.grey)),
        ],
      ),
    );
  }
}
