import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import '../services/journey_tracker.dart';
import '../services/pdf_report_service.dart';

/// One-click PDF export + share/print.
class PdfPreviewScreen extends StatefulWidget {
  const PdfPreviewScreen({super.key});
  @override
  State<PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<PdfPreviewScreen> {
  Uint8List? _pdf;
  final name = TextEditingController(text: '');
  final empId = TextEditingController(text: '');
  final company = TextEditingController(text: '');

  Future<void> _generate() async {
    final j = context.read<JourneyTracker>().current;
    if (j == null) return;
    final bytes = await PdfReportService.build(
      journey: j,
      userName: name.text.isEmpty ? 'Juan Dela Cruz' : name.text,
      employeeId: empId.text.isEmpty ? 'EMP-0001' : empId.text,
      company: company.text.isEmpty ? 'Sample Corp' : company.text,
      timestampHash: DateTime.now().toIso8601String().hashCode.toRadixString(16),
    );
    setState(() => _pdf = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delay Report (PDF)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Full name')),
          TextField(controller: empId, decoration: const InputDecoration(labelText: 'Employee ID')),
          TextField(controller: company, decoration: const InputDecoration(labelText: 'Company')),
          const SizedBox(height: 12),
          FilledButton.icon(
            icon: const Icon(Icons.picture_as_pdf),
            label: const Text('Generate PDF'),
            onPressed: _generate,
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _pdf == null
                ? const Center(child: Text('No PDF yet. Start a journey first.'))
                : PdfPreview(build: (_) async => _pdf!),
          ),
        ]),
      ),
    );
  }
}
