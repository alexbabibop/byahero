import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/journey.dart';
import '../services/journey_tracker.dart';

/// Main tracker UI: One-tap Start/Pause/Resume/End + Vehicle dropdown
/// + live stats + geofence confirm dialog.
class HomeTrackerScreen extends StatelessWidget {
  const HomeTrackerScreen({super.key});

  String _dur(Duration d) =>
      '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';

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
      appBar: AppBar(title: const Text('ByaHero — Tracker')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ikaw ang bida sa byahe mo.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<VehicleMode>(
              value: tracker.mode,
              decoration: const InputDecoration(
                  labelText: 'Vehicle / Status', border: OutlineInputBorder()),
              items: VehicleMode.values
                  .map((m) => DropdownMenuItem(
                        value: m,
                        child: Row(children: [
                          Container(width: 12, height: 12,
                            decoration: BoxDecoration(color: m.color, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          Text(m.label),
                        ]),
                      ))
                  .toList(),
              onChanged: (m) {
                if (m != null) tracker.setMode(m);
              },
            ),
            const SizedBox(height: 12),
            if (j == null) ...[
              FilledButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start Journey'),
                onPressed: () => tracker.startJourney(
                  destLat: 14.5547, destLng: 121.0244, destLabel: 'DOE BGC (sample)'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Paalala: hihingi ng Location permission. May prominent disclosure bago mag-track (Play Store requirement).',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ] else ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total: ${_dur(j.totalTime)}'),
                      Text('Waiting (pila): ${_dur(j.waitingTime)}'),
                      Text('Moving: ${_dur(j.movingTime)}'),
                      Text('Points: ${j.points.length}'),
                      if (j.autoLogs.isNotEmpty) ...[
                        const Divider(),
                        ...j.autoLogs.map((l) => Text('• $l',
                            style: const TextStyle(fontSize: 12))),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(children: [
                if (tracker.isActive)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: tracker.pauseJourney,
                      child: const Text('Pause (Meeting/Errand)'),
                    ),
                  ),
                if (tracker.isPaused)
                  Expanded(
                    child: FilledButton(
                      onPressed: tracker.resumeJourney,
                      child: const Text('Resume'),
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: tracker.endJourney,
                    child: const Text('End Trip'),
                  ),
                ),
              ]),
              if (tracker.state == JourneyState.finished)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Trip saved! Waiting: ${_dur(j.waitingTime)} / Total: ${_dur(j.totalTime)}. Export PDF mula sa report screen.',
                    style: const TextStyle(color: Colors.green),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
