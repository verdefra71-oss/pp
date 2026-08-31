import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestione Preventivi',
      theme: ThemeData(
        primarySwatch: Colors.amber,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

// ==========================================
// HELPER DATABASE (SQFlite Mock/Local DB)
// ==========================================
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('preventivi.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = p.join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE clienti (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        nome TEXT NOT NULL,
        indirizzo TEXT,
        telefono TEXT,
        email TEXT,
        partita_iva TEXT,
        codice_fiscale TEXT,
        parrocchia TEXT
      )
    ''');

    // Inserimento cliente di prova
    await db.insert('clienti', {
      'nome': 'Mario Rossi',
      'indirizzo': 'Via Roma 123, Milano',
      'telefono': '+39 02 1234567',
      'email': 'mario.rossi@example.com',
      'partita_iva': 'IT12345678901',
      'codice_fiscale': 'RSSMRA80A01H501U',
      'parrocchia': 'San Giovanni'
    });
  }

  Future<List<Map<String, dynamic>>> getClienti() async {
    final db = await instance.database;
    return await db.query('clienti');
  }
}

// ==========================================
// GENERATORE PDF CON SUPPORTO SIMBOLO EURO (€)
// ==========================================
class PdfGenerator {
  static Future<void> generaECondividiPreventivo({
    required String numero,
    required String cliente,
    required List<Map<String, dynamic>> articoli,
    required int numeroRate,
    required double ivaPercent,
  }) async {
    final pdf = pw.Document();
    pw.MemoryImage? logo;
    Map<String, dynamic>? datiCliente;

    // Caricamento del font Unicode con supporto al simbolo €
    final fontData = await rootBundle.load('assets/fonts/Roboto-Regular.ttf');
    final ttfFont = pw.Font.ttf(fontData);

    try {
      final bytes = await rootBundle.load('assets/logo.png');
      logo = pw.MemoryImage(Uint8List.fromList(bytes.buffer.asUint8List()));
    } catch (_) {}

    // Recupera l'anagrafica completa per stampare tutti i dati del cliente.
    try {
      final clienti = await DatabaseHelper.instance.getClienti();
      final matches = clienti.where(
        (c) => (c['nome'] ?? '').toString().trim() == cliente.trim(),
      );
      if (matches.isNotEmpty) {
        datiCliente = Map<String, dynamic>.from(matches.first);
      }
    } catch (_) {}

    final imponibile = articoli.fold<double>(
      0,
      (sum, x) {
        final prezzo = (x['prezzo'] as num?)?.toDouble() ?? 0;
        final quantita = (x['quantita'] as num?)?.toDouble() ?? 1;
        return sum + (prezzo * quantita);
      },
    );
    final iva = imponibile * ivaPercent / 100;
    final totale = imponibile + iva;
    final quota = numeroRate > 0 ? totale / numeroRate : totale;
    final data = DateFormat('dd/MM/yyyy').format(DateTime.now());

    final gold = PdfColor.fromHex('#B8860B');
    final dark = PdfColor.fromHex('#1E293B');

    String value(String key) => (datiCliente?[key] ?? '').toString().trim();

    final indirizzo = value('indirizzo');
    final telefono = value('telefono');
    final email = value('email');
    final partitaIva = value('partita_iva');
    final codiceFiscale = value('codice_fiscale');
    final parrocchia = value('parrocchia');

    final clientRows = <pw.Widget>[
      pw.Text(
        'CLIENTE',
        style: pw.TextStyle(
          font: ttfFont,
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: gold,
        ),
      ),
      pw.SizedBox(height: 5),
      pw.Text(
        cliente,
        style: pw.TextStyle(
          font: ttfFont,
          fontSize: 15,
          fontWeight: pw.FontWeight.bold,
        ),
      ),
      if (indirizzo.isNotEmpty) pw.Text('Indirizzo: $indirizzo', style: pw.TextStyle(font: ttfFont)),
      if (telefono.isNotEmpty) pw.Text('Telefono: $telefono', style: pw.TextStyle(font: ttfFont)),
      if (email.isNotEmpty) pw.Text('Email: $email', style: pw.TextStyle(font: ttfFont)),
      if (partitaIva.isNotEmpty) pw.Text('Partita IVA: $partitaIva', style: pw.TextStyle(font: ttfFont)),
      if (codiceFiscale.isNotEmpty) pw.Text('Codice Fiscale: $codiceFiscale', style: pw.TextStyle(font: ttfFont)),
      if (parrocchia.isNotEmpty) pw.Text('Parrocchia: $parrocchia', style: pw.TextStyle(font: ttfFont)),
    ];

    pdf.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: ttfFont),
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(30, 28, 30, 28),
        build: (_) => [
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null)
                pw.SizedBox(
                  width: 285,
                  height: 190,
                  child: pw.Image(logo, fit: pw.BoxFit.contain),
                )
              else
                pw.SizedBox(
                  width: 285,
                  height: 150,
                  child: pw.Text(
                    'BTS',
                    style: pw.TextStyle(
                      font: ttfFont,
                      fontSize: 38,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
              pw.SizedBox(width: 18),
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'PREVENTIVO',
                      style: pw.TextStyle(
                        font: ttfFont,
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: dark,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Divider(color: gold),
                    pw.SizedBox(height: 8),
                    pw.Text('N. $numero', style: pw.TextStyle(font: ttfFont, fontSize: 11)),
                    pw.Text('Data: $data', style: pw.TextStyle(font: ttfFont, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 12),
          pw.Container(
            width: double.infinity,
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey100,
              border: pw.Border.all(color: PdfColors.grey300),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: clientRows,
            ),
          ),
          pw.SizedBox(height: 18),
          pw.TableHelper.fromTextArray(
            headers: ['N.', 'Prodotto / Servizio', 'Q.tà', 'Prezzo unit. (€)', 'Totale (€)'],
            data: [
              for (var i = 0; i < articoli.length; i++)
                [
                  '${i + 1}',
                  (articoli[i]['nome'] ?? '').toString(),
                  ((articoli[i]['quantita'] as num?)?.toDouble() ?? 1).toStringAsFixed(2),
                  '€ ${((articoli[i]['prezzo'] as num?)?.toDouble() ?? 0).toStringAsFixed(2)}',
                  '€ ${(((articoli[i]['prezzo'] as num?)?.toDouble() ?? 0) * ((articoli[i]['quantita'] as num?)?.toDouble() ?? 1)).toStringAsFixed(2)}',
                ],
            ],
            headerStyle: pw.TextStyle(
              font: ttfFont,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            cellStyle: pw.TextStyle(font: ttfFont),
            headerDecoration: pw.BoxDecoration(color: dark),
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.center,
              3: pw.Alignment.centerRight,
              4: pw.Alignment.centerRight,
            },
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
              1: const pw.FlexColumnWidth(1),
              2: const pw.FixedColumnWidth(42),
              3: const pw.FixedColumnWidth(75),
              4: const pw.FixedColumnWidth(75),
            },
          ),
          pw.SizedBox(height: 18),
          pw.Container(
            alignment: pw.Alignment.centerRight,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('Imponibile: € ${imponibile.toStringAsFixed(2)}', style: pw.TextStyle(font: ttfFont)),
                if (ivaPercent == 0)
                  pw.Text(
                    'FUORI CAMPO IVA FCI',
                    style: pw.TextStyle(font: ttfFont, fontWeight: pw.FontWeight.bold),
                  )
                else
                  pw.Text(
                    'IVA ${ivaPercent.toStringAsFixed(0)}%: € ${iva.toStringAsFixed(2)}',
                    style: pw.TextStyle(font: ttfFont),
                  ),
                pw.SizedBox(height: 5),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: pw.BoxDecoration(
                    color: gold,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
                  ),
                  child: pw.Text(
                    'TOTALE: € ${totale.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      font: ttfFont,
                      fontSize: 16,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (numeroRate > 1) ...[
            pw.SizedBox(height: 18),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: gold),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(5)),
              ),
              child: pw.Text(
                '$numeroRate rate mensili da € ${quota.toStringAsFixed(2)} ciascuna.',
                style: pw.TextStyle(font: ttfFont),
              ),
            ),
          ],
          pw.SizedBox(height: 25),
          pw.Divider(color: gold),
          pw.SizedBox(height: 6),
          pw.Text(
            'Documento generato da Gestione Preventivi.',
            style: pw.TextStyle(font: ttfFont, fontSize: 9, color: PdfColors.grey600),
          ),
        ],
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Preventivo_$numero.pdf',
    );
  }
}

// ==========================================
// INTERFACCIA UTENTE DI ESEMPPIO
// ==========================================
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generatore Preventivi PDF'),
      ),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.picture_as_pdf),
          label: const Text('Genera Preventivo PDF'),
          onPressed: () async {
            await PdfGenerator.generaECondividiPreventivo(
              numero: '2024-001',
              cliente: 'Mario Rossi',
              articoli: [
                {'nome': 'Sviluppo Applicazione Mobile', 'quantita': 1, 'prezzo': 1500.00},
                {'nome': 'Assistenza e Manutenzione Annuale', 'quantita': 12, 'prezzo': 50.00},
              ],
              numeroRate: 3,
              ivaPercent: 22.0,
            );
          },
        ),
      ),
    );
  }
}
