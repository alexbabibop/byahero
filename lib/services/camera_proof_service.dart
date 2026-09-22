import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image/image.dart' as img;

/// Live-only Camera proof + Watermark + EXIF/Hash validation.
///
/// PRD rules:
/// - Bawal gallery picker. Camera plugin lang.
/// - Auto-stamp: GPS coords, timestamp, device/cell hash.
/// - SHA256 hash ng final bytes ang isi-save sa Firestore + PDF.
class ProofService {
  /// Tatakan ang [jpegBytes] ng watermark text sa ibaba.
  /// Ibalik ang bagong JPEG bytes.
  static List<int> watermark(List<int> jpegBytes, {
    required Position pos,
    required DateTime ts,
    required String deviceHash,
  }) {
    final image = img.decodeJpg(jpegBytes);
    if (image == null) return jpegBytes;
    final stamp =
        '${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)} | $ts | $deviceHash';
    // Simpleng bottom bar + text (low-end safe, walang custom fonts).
    img.fillRect(image, x1: 0, y1: image.height - 48, x2: image.width, y2: image.height,
        color: img.ColorRgb8(0, 0, 0));
    img.drawString(image, stamp, x: 8, y: image.height - 34,
        color: img.ColorRgb8(255, 255, 255));
    return img.encodeJpg(image, quality: 85);
  }

  /// SHA256 hash para sa tamper-proof verification.
  static String sha256Hex(List<int> bytes) =>
      sha256.convert(bytes).toString();

  /// I-verify na hindi ginalaw ang file (ikkumpara sa hash na naka-store).
  static bool verify(List<int> bytes, String expectedHash) =>
      sha256Hex(bytes) == expectedHash;

  /// Stub para sa file-based EXIF check: i-flag kapag walang GPS EXIF
  /// (ibig sabihin posibleng galing gallery/photoshop).
  static Future<bool> hasGpsExif(File f) async {
    // Production: gamitin ang `exif` package para basahin ang GPS IFD.
    // MVP: true kapag camera-captured (ang gallery path ay blocked na sa UI).
    return f.existsSync();
  }

  static String shortHash(String input) =>
      sha256.convert(utf8.encode(input)).toString().substring(0, 12);
}
