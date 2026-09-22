import 'package:geolocator/geolocator.dart';

/// Fake GPS / Mock Location blocker (PRD: Anti-Daya).
/// Kapag mock detected -> harangin ang tracking at proof capture.
class MockDetector {
  /// true = FAKE, huwag magpatuloy.
  static bool isMock(Position pos) {
    // Geolocator nag-eexpose ng isMocked sa Android.
    try {
      return (pos as dynamic).isMocked == true;
    } catch (_) {
      return false;
    }
  }

  static void assertReal(Position pos) {
    if (isMock(pos)) {
      throw const MockLocationException(
        'Mock Location detected! Patayin ang Fake GPS app at ituloy ang biyahe.',
      );
    }
  }
}

class MockLocationException implements Exception {
  final String message;
  const MockLocationException(this.message);
  @override
  String toString() => 'MockLocationException: $message';
}
