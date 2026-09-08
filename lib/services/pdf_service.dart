import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/balloon_project.dart';

class PdfService {
  Future<void> shareProject(BalloonProject project) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text(
            'BALLOON DESIGNER',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(project.name, style: const pw.TextStyle(fontSize: 18)),
          pw.SizedBox(height: 6),
          pw.Text(
            'Dimensioni: ${project.widthCm.toStringAsFixed(0)} x '
            '${project.heightCm.toStringAsFixed(0)} cm',
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Sezione', 'Colore', 'Area', 'Misura', 'Quantità'],
            data: project.sections.map((s) => [
              s.name,
              s.colorName,
              '${s.areaPercent.toStringAsFixed(1)}%',
              '${s.balloonSize}"',
              '${s.count}',
            ]).toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'TOTALE PALLONCINI: ${project.totalBalloons}',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Nota: le quantità sono stime automatiche e vanno verificate '
            'in base alla tecnica di costruzione e alla densità desiderata.',
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${project.name.replaceAll(' ', '_')}.pdf',
    );
  }
}
