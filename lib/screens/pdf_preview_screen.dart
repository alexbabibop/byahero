import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';

import '../models/journey.dart';
import '../services/journey_tracker.dart';
import '../services/pdf_report_service.dart';
import '../theme/app_theme.dart';

/// PDF delay report. Puwedeng pumili ng isang nasesave na byahe (mula sa
/// Trips tab) o ang pinakahuling aktibong trip.
class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({super.key, this.journey});

  final Journey? journey;

  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  Uint8List? _pdf;
  final name = TextEditingController();
  final empId = TextEditingController();
  final company = TextEditingController();

  @override
  void dispose() {
    name.dispose();
    empId.dispose();
    company.dispose();
    super.dispose();
  }

  Journey? get _target => widget.journey ?? context.read<JourneyTracker>().current;

  Future<void> _generate() async {
    final j = _target;
    if (j == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Walang byahe na i-export. Start muna ang trip.')));
      return;
    }
    final bytes = await PdfReportService.build(
      journey: j,
      userName: name.text.trim().isEmpty ? 'Juan Dela Cruz' : name.text.trim(),
      employeeId:
          empId.text.trim().isEmpty ? 'EMP-0001' : empId.text.trim(),
      company: company.text.trim().isEmpty ? 'Sample Corp' : company.text.trim(),
      timestampHash: DateTime.now().toIso8601String().hashCode.toRadixString(16),
    );
    if (!mounted) return;
    setState(() => _pdf = bytes);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nagawa ang PDF! I-share or i-print gamit ang toolbar.')));
  }

  @override
  Widget build(BuildContext context) {
    final j = _target;
    return Scaffold(
      appBar: AppBar(title: const Text('Delay Report (PDF)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('DETAILS NG EMPLOYEE',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.muted,
                        letterSpacing: .8)),
                const SizedBox(height: 12),
                TextField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                        labelText: 'Full name', prefixIcon: Icon(Icons.person))),
                const SizedBox(height: 10),
                TextField(
                  controller: empId,
                  decoration: const InputDecoration(
                      labelText: 'Employee ID', prefixIcon: Icon(Icons.badge)),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: company,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      labelText: 'Company', prefixIcon: Icon(Icons.business)),
                ),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            label: Text(j == null
                ? 'Walang trip — Start muna'
                : 'Generate PDF Report'),
            onPressed: j == null ? null : _generate,
          ),
          const SizedBox(height: 16),
          if (_pdf == null)
            Container(
              height: 220,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.line),
              ),
              child: const Text(
                'Lalabas dito ang preview ng PDF.\nPagkatapos, i-share o i-print.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.muted, fontSize: 13),
              ),
            )
          else
            SizedBox(
              height: 520,
              child: PdfPreview(build: (_) async => _pdf!),
            ),
        ],
      ),
    );
  }
}
