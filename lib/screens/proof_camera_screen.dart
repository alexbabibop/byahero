import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../services/camera_proof_service.dart';
import '../services/mock_detector.dart';
import '../theme/app_theme.dart';

/// Live-only camera: WALANG gallery picker dito (PRD Anti-Daya).
class ProofCameraScreen extends StatefulWidget {
  const ProofCameraScreen({super.key});
  @override
  State<ProofCameraScreen> createState() => _ProofCameraScreenState();
}

class _ProofCameraScreenState extends State<ProofCameraScreen> {
  CameraController? _ctrl;
  String? _hash;
  Uint8List? _shot;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() {
      _error = null;
      _ctrl?.dispose();
      _ctrl = null;
    });
    try {
      // Runtime camera permission (manifest pa lang ang meron tayo).
      var st = await Permission.camera.status;
      if (!st.isGranted) st = await Permission.camera.request();
      if (!st.isGranted) {
        setState(() => _error = st.isPermanentlyDenied
            ? 'Naka-block ang Camera. Buksan: Settings → Apps → ByaHero → Permissions → Camera → Allow.'
            : 'Kailangan ng Camera permission para sa proof photo.');
        return;
      }
      final cams = await availableCameras();
      if (cams.isEmpty) {
        setState(() => _error = 'Walang nakitang camera sa device na ito.');
        return;
      }
      _ctrl = CameraController(cams.first, ResolutionPreset.medium);
      await _ctrl!.initialize();
    } catch (e) {
      setState(() => _error = 'Hindi mabuksan ang camera: $e');
      return;
    }
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    if (_ctrl == null || !_ctrl!.value.isInitialized || _busy) return;
    setState(() => _busy = true);
    try {
      final pos = await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 15));
      try {
        MockDetector.assertReal(pos);
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
        return;
      }
      final shot = await _ctrl!.takePicture();
      final raw = await shot.readAsBytes();
      final stamped = ProofService.watermark(raw,
          pos: pos, ts: DateTime.now(), deviceHash: 'device-hash-stub');
      final hash = ProofService.sha256Hex(stamped);
      setState(() {
        _hash = hash;
        _shot = stamped;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Proof captured! SHA256: ${hash.substring(0, 16)}...')));
      // TODO: upload stamped bytes sa Firebase Storage + save hash sa journey.
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Capture failed: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ready = _ctrl != null && _ctrl!.value.isInitialized;
    return Scaffold(
      appBar: AppBar(title: const Text('Proof Camera')),
      body: Column(children: [
        Expanded(
          child: _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.videocam_off,
                            size: 48, color: AppTheme.muted),
                        const SizedBox(height: 12),
                        Text(_error!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: AppTheme.ink)),
                        const SizedBox(height: 14),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Retry'),
                          onPressed: _init,
                        ),
                      ],
                    ),
                  ),
                )
              : ready
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: CameraPreview(_ctrl!),
                    )
                  : const Center(child: CircularProgressIndicator()),
        ),
        if (_shot != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(_shot!,
                        width: 64, height: 64, fit: BoxFit.cover),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Naka-save ang proof',
                            style: TextStyle(fontWeight: FontWeight.w800)),
                        const SizedBox(height: 2),
                        Text(
                          'SHA256: ${_hash!.substring(0, 24)}...',
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              color: AppTheme.muted),
                        ),
                      ],
                    ),
                  ),
                ]),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.camera_alt_rounded),
            label: Text(_busy ? 'Capturing…' : 'Capture Proof'),
            onPressed: ready && !_busy ? _capture : null,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Bawal gallery — live camera lang (anti-daya).',
              style: TextStyle(fontSize: 12, color: AppTheme.muted)),
        ),
      ]),
    );
  }
}
