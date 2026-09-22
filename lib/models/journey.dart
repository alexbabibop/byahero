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
}

enum JourneyState { idle, active, paused, finished }

class Journey {
  final String id;
  final String userId;
  final DateTime startedAt;
  DateTime? endedAt;
  double? destLat;
  double? destLng;
  String? destLabel;
  final List<RoutePoint> points = [];
  final List<String> autoLogs = [];

  Journey({required this.id, required this.userId, required this.startedAt});

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
  Duration get movingTime => totalTime - waitingTime - timeInMode(VehicleMode.paused);

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
