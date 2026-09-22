import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final cams = await availableCameras();
    if (cams.isEmpty) return;
    _ctrl = CameraController(cams.first, ResolutionPreset.medium);
    await _ctrl!.initialize();
    if (mounted) setState(() {});
  }

  Future<void> _capture() async {
    if (_ctrl == null || !_ctrl!.value.isInitialized) return;
    final pos = await Geolocator.getCurrentPosition();
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
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Proof captured! SHA256: ${hash.substring(0, 16)}...')));
    // TODO: upload stamped bytes sa Firebase Storage + save hash sa journey.
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proof Camera (Live only)')),
      body: Column(children: [
        Expanded(
          child: _ctrl != null && _ctrl!.value.isInitialized
              ? CameraPreview(_ctrl!)
              : const Center(child: CircularProgressIndicator()),
        ),
        if (_hash != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Hash: $_hash',
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace')),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            icon: const Icon(Icons.camera_alt),
            label: const Text('Capture Proof'),
            onPressed: _capture,
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
