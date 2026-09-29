import 'package:byahero/models/journey.dart';
import 'package:flutter_test/flutter_test.dart';

/// QA: storage round-trip (sqflite is mocked out — logic lang ang sinuri),
/// model math, at theme consistency.
void main() {
  group('Journey math', () {
    /// (segundo, mode) — ang mode ay siyang SUMUSAKLAP sa segment na
    /// mula sa point i hanggang point i+1 ( gaya ng totoong GPS stream).
    Journey mk(List<(int, VehicleMode)> segs) {
      final start = DateTime(2026, 1, 1, 7);
      final j = Journey(id: 'j1', userId: 'guest', startedAt: start);
      var t = start;
      for (final (sec, mode) in segs) {
        j.points.add(RoutePoint(
            lat: 14.5, lng: 121.0, timestamp: t, mode: mode, speedKmh: 20));
        t = t.add(Duration(seconds: sec));
      }
      // Dulo ng huling segment.
      j.points.add(RoutePoint(
          lat: 14.5,
          lng: 121.0,
          timestamp: t,
          mode: segs.last.$2,
          speedKmh: 20));
      j.endedAt = t;
      return j;
    }

    test('totalTime = endedAt - startedAt', () {
      final j = mk([(60, VehicleMode.bus), (120, VehicleMode.bus)]);
      expect(j.totalTime.inSeconds, 180);
    });

    test('waitingTime is only the nakapila legs', () {
      final j = mk([
        (60, VehicleMode.bus),
        (300, VehicleMode.nakapila),
        (60, VehicleMode.bus),
      ]);
      expect(j.waitingTime.inSeconds, 300);
    });

    test('movingTime excludes queue + paused', () {
      final j = mk([
        (60, VehicleMode.bus),
        (300, VehicleMode.nakapila),
        (40, VehicleMode.paused),
        (60, VehicleMode.bus),
      ]);
      expect(j.waitingTime.inSeconds, 300);
      expect(j.movingTime.inSeconds, 120);
    });

    test('zero points => zero mode times (no crash, no bogus number)', () {
      final j =
          Journey(id: 'j2', userId: 'guest', startedAt: DateTime(2026, 1, 1));
      expect(j.waitingTime.inSeconds, 0);
      expect(j.movingTime.inSeconds, 0);
    });

    test('one segment => lahat moving', () {
      final j = mk([(30, VehicleMode.bus)]);
      expect(j.points.length, 2);
      expect(j.movingTime.inSeconds, 30);
    });
  });

  group('Storage round-trip', () {
    test('toStorage/fromStorage keeps every field', () {
      final start = DateTime(2026, 2, 3, 6, 30);
      final j = Journey(id: 'abc', userId: 'guest', startedAt: start)
        ..endedAt = start.add(const Duration(minutes: 12))
        ..destLat = 14.5547
        ..destLng = 121.0244
        ..destLabel = 'Pin sa mapa';
      j.points.add(RoutePoint(
          lat: 14.5,
          lng: 121.0,
          timestamp: start.add(const Duration(minutes: 2)),
          mode: VehicleMode.jeep,
          speedKmh: 12.5));
      j.autoLogs.add('Probably stopped near 14.5 at 06:32');

      final row = j.toStorage(synced: 0);
      final back = Journey.fromStorage(row);

      expect(back.id, 'abc');
      expect(back.userId, 'guest');
      expect(back.startedAt, start);
      expect(back.endedAt, start.add(const Duration(minutes: 12)));
      expect(back.destLat, 14.5547);
      expect(back.destLng, 121.0244);
      expect(back.destLabel, 'Pin sa mapa');
      expect(back.points.length, 1);
      expect(back.points.first.mode, VehicleMode.jeep);
      expect(back.points.first.speedKmh, 12.5);
      expect(back.autoLogs.first, 'Probably stopped near 14.5 at 06:32');
      expect(row['synced'], 0);
    });

    test('interrupted trip survives without endedAt', () {
      final start = DateTime(2026, 2, 3, 6, 30);
      final j = Journey(id: 'x', userId: 'guest', startedAt: start);
      final back = Journey.fromStorage(j.toStorage(synced: 0));
      expect(back.endedAt, isNull);
    });

    test('unknown mode falls back to bus (corrupt data safe)', () {
      final start = DateTime(2026, 2, 3);
      final j = Journey(id: 'y', userId: 'guest', startedAt: start)
        ..endedAt = start;
      final row = j.toStorage(synced: 0);
      // corrupt the mode name
      const pts = '[{"lat":14.5,"lng":121.0,"ts":"2026-02-03T06:30:00.000","mode":"ufo","speedKmh":1}]';
      final back = Journey.fromStorage({...row, 'points': pts});
      expect(back.points.first.mode, VehicleMode.bus);
    });
  });

  group('Firestore payload', () {
    test('toJson has the fields the report/analytics need', () {
      final start = DateTime(2026, 3, 1, 8);
      final j = Journey(id: 'f1', userId: 'uid123', startedAt: start)
        ..endedAt = start.add(const Duration(minutes: 30));
      final data = j.toJson();
      expect(data['userId'], 'uid123');
      expect(data['totalSec'], 1800);
      expect(data.containsKey('waitingSec'), isTrue);
      expect(data.containsKey('points'), isTrue);
      expect(data.containsKey('autoLogs'), isTrue);
    });
  });
}
