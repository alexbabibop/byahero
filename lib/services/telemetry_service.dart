import 'package:battery_plus/battery_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Hardware Telemetry auto-attached sa bawat bug report (PRD Sec 4).
class TelemetryService {
  static Future<Map<String, dynamic>> collect({String? stacktrace, String severity = 'medium'}) async {
    final device = DeviceInfoPlugin();
    final battery = Battery();
    String brand = 'unknown', model = 'unknown', os = 'unknown', api = 'unknown';
    try {
      final a = await device.androidInfo;
      brand = a.brand;
      model = a.model;
      os = 'Android ${a.version.release}';
      api = '${a.version.sdkInt}';
    } catch (_) {}
    int level = -1;
    try {
      level = await battery.batteryLevel;
    } catch (_) {}
    String appV = 'unknown';
    try {
      appV = (await PackageInfo.fromPlatform()).version;
    } catch (_) {}

    return {
      'brand': brand,
      'model': model,
      'os': os,
      'apiLevel': api,
      'batteryLevel': level,
      'appVersion': appV,
      'severity': severity,
      'stacktrace': stacktrace ?? '',
      // Crash grouping key: unang 3 linya ng stacktrace.
      'groupHash': (stacktrace ?? '').split('\n').take(3).join('\n').hashCode.toString(),
    };
  }
}
