import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/camera_proof_service.dart';
import '../services/mock_detector.dart';

/// Live-only camera: WALANG gallery picker dito (PRD Anti-Daya).
class ProofCameraScreen extends StatefulWidget {
  const ProofCameraScreen({super.key});
  @override
  State<ProofCameraScreen> createState() => _ProofCameraScreenState();
}

class _ProofCameraScreenState extends State<ProofCameraScreen> {
  CameraController? _ctrl;
  String? _hash;
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
      setState(() => _hash = hash);
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
      appBar: AppBar(title: const Text('Proof Camera (Live only)')),
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
                            size: 48, color: Colors.grey),
                        const SizedBox(height: 12),
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          icon: const Icon(Icons.refresh),
                          label: const Text('Retry'),
                          onPressed: _init,
                        ),
                      ],
                    ),
                  ),
                )
              : ready
                  ? CameraPreview(_ctrl!)
                  : const Center(child: CircularProgressIndicator()),
        ),
        if (_hash != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Hash: $_hash',
                style:
                    const TextStyle(fontSize: 10, fontFamily: 'monospace')),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: _busy
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : const Icon(Icons.camera_alt),
            label: Text(_busy ? 'Capturing...' : 'Capture Proof'),
            onPressed: ready && !_busy ? _capture : null,
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Bawal gallery — live camera lang (anti-daya).',
              style: TextStyle(fontSize: 12, color: Colors.grey)),
        ),
      ]),
    );
  }
}
