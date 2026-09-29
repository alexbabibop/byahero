import 'dart:convert';

import 'package:flutter/material.dart';

/// Vehicle modes + route colors, ayon sa PRD spec.
enum VehicleMode {
  lakad('Lakad', Color(0xFF2BA84A)),
  jeep('Jeepney / Modern Jeep', Color(0xFF1E88E5)),
  bus('Bus / P2P Bus', Color(0xFFD62828)),
  private('Private / Taxi / Angkas', Color(0xFF212121)),
  nakapila('Nakapila / Waiting / Idle', Color(0xFFF9C80E)),
  paused('Paused / Meeting', Color(0xFF7B1FA2));

  final String label;
  final Color color;
  const VehicleMode(this.label, this.color);
}

class RoutePoint {
  final double lat;
  final double lng;
  final DateTime timestamp;
  final VehicleMode mode;
  final double speedKmh;

  RoutePoint({
    required this.lat,
    required this.lng,
    required this.timestamp,
    required this.mode,
    this.speedKmh = 0,
  });

  Map<String, dynamic> toJson() => {
        'lat': lat,
        'lng': lng,
        'ts': timestamp.toIso8601String(),
        'mode': mode.name,
        'speedKmh': speedKmh,
      };

  factory RoutePoint.fromJson(Map<String, dynamic> m) => RoutePoint(
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        timestamp: DateTime.parse(m['ts'] as String),
        mode: VehicleMode.values.firstWhere(
          (v) => v.name == m['mode'],
          orElse: () => VehicleMode.bus,
        ),
        speedKmh: (m['speedKmh'] as num?)?.toDouble() ?? 0,
      );
}

enum JourneyState { idle, active, paused, finished }

class Journey {
  final String id;
  String userId; // mutable: guest → uid kapag nag-login
  final DateTime startedAt;
  DateTime? endedAt;
  double? destLat;
  double? destLng;
  String? destLabel;
  final List<RoutePoint> points = [];
  final List<String> autoLogs = [];

  Journey({required this.id, required this.userId, required this.startedAt});

  /// Reconstruction mula sa local (sqflite) row.
  factory Journey.fromStorage(Map<String, dynamic> m) {
    final j = Journey(
      id: m['id'] as String,
      userId: m['user_id'] as String,
      startedAt:
          DateTime.fromMillisecondsSinceEpoch(m['started_at'] as int),
    )
      ..endedAt = m['ended_at'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(m['ended_at'] as int)
      ..destLat = (m['dest_lat'] as num?)?.toDouble()
      ..destLng = (m['dest_lng'] as num?)?.toDouble()
      ..destLabel = m['dest_label'] as String?;
    final pts = (jsonDecode(m['points'] as String) as List).toList();
    j.points.addAll(
        pts.map((e) => RoutePoint.fromJson(e as Map<String, dynamic>)));
    final logs = (jsonDecode(m['auto_logs'] as String) as List).toList();
    j.autoLogs.addAll(logs.cast<String>());
    return j;
  }

  Map<String, dynamic> toStorage({required int synced}) => {
        'id': id,
        'user_id': userId,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'dest_lat': destLat,
        'dest_lng': destLng,
        'dest_label': destLabel,
        'points': jsonEncode(points.map((p) => p.toJson()).toList()),
        'auto_logs': jsonEncode(autoLogs),
        'synced': synced,
      };

  Duration get totalTime =>
      (endedAt ?? DateTime.now()).difference(startedAt);

  Duration timeInMode(VehicleMode mode) {
    if (points.length < 2) return Duration.zero;
    var total = Duration.zero;
    for (var i = 1; i < points.length; i++) {
      if (points[i - 1].mode == mode) {
        total += points[i].timestamp.difference(points[i - 1].timestamp);
      }
    }
    return total;
  }

  Duration get waitingTime => timeInMode(VehicleMode.nakapila);

  /// Moving = kabuuang oras MINUS ang nakatira sa pila at naka-pause.
  /// Walang segomento (= <2 points) ay hindi pa natutukoy — ibinabalik
  /// zero para hindi lumabas ang maling malaking bilang.
  Duration get movingTime {
    if (points.length < 2) return Duration.zero;
    final rest = waitingTime + timeInMode(VehicleMode.paused);
    final d = totalTime - rest;
    return d.isNegative ? Duration.zero : d;
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'destLat': destLat,
        'destLng': destLng,
        'destLabel': destLabel,
        'points': points.map((p) => p.toJson()).toList(),
        'autoLogs': autoLogs,
        'waitingSec': waitingTime.inSeconds,
        'movingSec': movingTime.inSeconds,
        'totalSec': totalTime.inSeconds,
      };
}
