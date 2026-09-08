import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/balloon_project.dart';

class PdfService {
  Future<void> shareProject(BalloonProject project) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(
            'BALLOON DESIGNER',
            style: pw.TextStyle(
              fontSize: 22,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            project.name,
            style: const pw.TextStyle(fontSize: 18),
          ),
          pw.SizedBox(height: 12),
          pw.Text(
            'Dimensioni: '
            '${project.widthCm.toStringAsFixed(0)} x '
            '${project.heightCm.toStringAsFixed(0)} cm',
          ),
          pw.Text(
            'Totale stimato: ${project.totalBalloons} palloncini',
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: const [
              'Sezione',
              'Colore',
              'Area',
              'Misura',
              'Quantità',
            ],
            data: project.sections
                .map(
                  (s) => [
                    s.name,
                    s.colorName,
                    '${s.areaPercent.toStringAsFixed(1)}%',
                    '${s.balloonSize.toStringAsFixed(0)} cm',
                    '${s.count}',
                  ],
                )
                .toList(),
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Nota: il calcolo è una stima iniziale e va verificato '
            'in base al tipo di palloncino, alla tecnica e alla densità '
            'di costruzione.',
            style: const pw.TextStyle(fontSize: 9),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await doc.save(),
      filename: '${_safeFileName(project.name)}.pdf',
    );
  }

  String _safeFileName(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '_');
    return cleaned.isEmpty ? 'balloon_project' : cleaned;
  }
}
