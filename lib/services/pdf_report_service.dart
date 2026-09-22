import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/journey.dart';

/// One-click A4 PDF Incident & Delay Report (PRD Sec C).
class PdfReportService {
  static Future<Uint8List> build({
    required Journey journey,
    required String userName,
    required String employeeId,
    required String company,
    Uint8List? proofPhoto,
    String? timestampHash,
  }) async {
    final doc = pw.Document();
    final fmt = DateFormat('MMM d, yyyy h:mm a');
    String dur(Duration d) =>
        '${d.inHours}h ${d.inMinutes.remainder(60)}m ${d.inSeconds.remainder(60)}s';

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('ByaHero — Delay Verification Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('Ikaw ang bida sa byahe mo.',
                style: const pw.TextStyle(fontSize: 10)),
            pw.Divider(),
            pw.Text('Employee: $userName  |  ID: $employeeId  |  Company: $company'),
            pw.Text(
                'Trip: ${fmt.format(journey.startedAt)} — ${journey.endedAt != null ? fmt.format(journey.endedAt!) : 'ongoing'}'),
            if (journey.destLabel != null) pw.Text('Destination: ${journey.destLabel}'),
            pw.SizedBox(height: 8),
            pw.Text('Time Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            pw.Bullet(text: 'Total travel: ${dur(journey.totalTime)}'),
            pw.Bullet(text: 'Waiting in line: ${dur(journey.waitingTime)}'),
            pw.Bullet(text: 'Moving: ${dur(journey.movingTime)}'),
            pw.Bullet(text: 'Route points: ${journey.points.length}'),
            if (journey.autoLogs.isNotEmpty) ...[
              pw.SizedBox(height: 8),
              pw.Text('Auto-detected stops:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ...journey.autoLogs.map((l) => pw.Bullet(text: l)),
            ],
            if (proofPhoto != null) ...[
              pw.SizedBox(height: 8),
              pw.Text('Watermarked proof photo:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Image(pw.MemoryImage(proofPhoto), width: 400),
            ],
            pw.Spacer(),
            pw.Divider(),
            pw.Text('Timestamp hash: ${timestampHash ?? '—'}',
                style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 24),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: const [
                pw.Text('____________________\nEmployee signature'),
                pw.Text('____________________\nSupervisor / HR'),
              ],
            ),
          ],
        ),
      ),
    );
    return doc.save();
  }
}
