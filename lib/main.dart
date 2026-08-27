import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz_data;
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();
  runApp(const PreventiviApp());
}

class PreventiviApp extends StatelessWidget {
  const PreventiviApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gestione Preventivi',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1E3A8A)),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(
          border: OutlineInputBorder(),
        ),
        cardTheme: const CardThemeData(margin: EdgeInsets.zero),
      ),
      home: const DashboardScreen(),
    );
  }
}

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('preventivi_full.db');
    return _database!;
  }

  Future<Database> _initDB(String fileName) async {
    final dbPath = await getDatabasesPath();

    return openDatabase(
      p.join(dbPath, fileName),
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
CREATE TABLE clienti (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL,
  email TEXT,
  telefono TEXT,
  indirizzo TEXT
)
''');

        await db.execute('''
CREATE TABLE prodotti (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  nome TEXT NOT NULL,
  prezzo REAL NOT NULL
)
''');

        await db.execute('''
CREATE TABLE preventivi (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  numero TEXT NOT NULL,
  data TEXT NOT NULL,
  cliente TEXT NOT NULL,
  totale REAL NOT NULL,
  iva_percentuale REAL NOT NULL DEFAULT 0,
  numero_rate INTEGER NOT NULL,
  articoli TEXT NOT NULL DEFAULT '[]'
)
''');

        await db.execute('''
CREATE TABLE rate (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  preventivo_id INTEGER NOT NULL,
  cliente TEXT NOT NULL,
  importo REAL NOT NULL,
  data_scadenza TEXT NOT NULL,
  pagata INTEGER NOT NULL DEFAULT 0
)
''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            "ALTER TABLE preventivi ADD COLUMN articoli TEXT NOT NULL DEFAULT '[]'",
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            "ALTER TABLE preventivi ADD COLUMN iva_percentuale REAL NOT NULL DEFAULT 0",
          );
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> getClienti() async {
    return (await database).query('clienti', orderBy: 'nome COLLATE NOCASE');
  }

  Future<List<Map<String, dynamic>>> getPreventivi() async {
    return (await database).query('preventivi', orderBy: 'id DESC');
  }

  Future<List<Map<String, dynamic>>> getProdotti() async {
    return (await database).query('prodotti', orderBy: 'nome COLLATE NOCASE');
  }

  Future<List<Map<String, dynamic>>> getRate() async {
    return (await database).query('rate', orderBy: 'data_scadenza');
  }

  Future<int> insertProdotto({
    required String nome,
    required double prezzo,
  }) async {
    return (await database).insert('prodotti', {
      'nome': nome,
      'prezzo': prezzo,
    });
  }

  Future<int> updateProdotto({
    required int id,
    required String nome,
    required double prezzo,
  }) async {
    return (await database).update(
      'prodotti',
      {'nome': nome, 'prezzo': prezzo},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteProdotto(int id) async {
    return (await database).delete(
      'prodotti',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> insertCliente({
    required String nome,
    String email = '',
    String telefono = '',
    String indirizzo = '',
  }) async {
    return (await database).insert('clienti', {
      'nome': nome,
      'email': email,
      'telefono': telefono,
      'indirizzo': indirizzo,
    });
  }

  Future<int> updateCliente({
    required int id,
    required String nome,
    String email = '',
    String telefono = '',
    String indirizzo = '',
  }) async {
    return (await database).update(
      'clienti',
      {
        'nome': nome,
        'email': email,
        'telefono': telefono,
        'indirizzo': indirizzo,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deleteCliente(int id) async {
    return (await database).delete(
      'clienti',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<String> prossimoNumeroPreventivo() async {
    final db = await database;
    final rows = await db.rawQuery('SELECT COUNT(*) AS n FROM preventivi');
    final n = (rows.first['n'] as int? ?? 0) + 1;
    return 'PREV-${DateTime.now().year}-${n.toString().padLeft(4, '0')}';
  }

  Future<int> insertPreventivo({
    required String numero,
    required String cliente,
    required double totale,
    required double ivaPercentuale,
    required int numeroRate,
    required List<Map<String, dynamic>> articoli,
  }) async {
    return (await database).insert('preventivi', {
      'numero': numero,
      'data': DateTime.now().toIso8601String(),
      'cliente': cliente,
      'totale': totale,
      'iva_percentuale': ivaPercentuale,
      'numero_rate': numeroRate,
      'articoli': jsonEncode(articoli),
    });
  }

  Future<int> updatePreventivo({
    required int id,
    required String cliente,
    required double totale,
    required double ivaPercentuale,
    required int numeroRate,
    required List<Map<String, dynamic>> articoli,
  }) async {
    return (await database).update(
      'preventivi',
      {
        'cliente': cliente,
        'totale': totale,
        'iva_percentuale': ivaPercentuale,
        'numero_rate': numeroRate,
        'articoli': jsonEncode(articoli),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> insertRata({
    required int preventivoId,
    required String cliente,
    required double importo,
    required DateTime dataScadenza,
  }) async {
    await (await database).insert('rate', {
      'preventivo_id': preventivoId,
      'cliente': cliente,
      'importo': importo,
      'data_scadenza': dataScadenza.toIso8601String(),
      'pagata': 0,
    });
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() => _instance;

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz_data.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Rome'));

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _notifications.initialize(settings);

    final android = _notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();

    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();
  }

  Future<void> programmaNotificaRata({
    required int id,
    required String cliente,
    required double importo,
    required DateTime dataScadenza,
  }) async {
    final when = tz.TZDateTime.from(dataScadenza, tz.local);

    if (when.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _notifications.zonedSchedule(
      id,
      'Rata in scadenza',
      'Oggi scade la rata di €${importo.toStringAsFixed(2)} per $cliente.',
      when,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'rate_channel',
          'Notifiche Rate',
          channelDescription: 'Avvisi per le scadenze dei pagamenti rateali',
          importance: Importance.max,
          priority: Priority.high,
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}

class PdfGenerator {
  static Future<void> generaECondividiPreventivo({
    required String numero,
    required String cliente,
    required List<Map<String, dynamic>> articoli,
    required int numeroRate,
    required double ivaPercentuale,
  }) async {
    final pdf = pw.Document();
    pw.MemoryImage? logo;

    try {
      final bytes = await rootBundle.load('assets/logo.png');
      logo = pw.MemoryImage(Uint8List.fromList(bytes.buffer.asUint8List()));
    } catch (_) {}

    final totale = articoli.fold<double>(
      0,
      (sum, x) => sum + (x['prezzo'] as num).toDouble(),
    );

    final iva = totale * ivaPercentuale / (100 + ivaPercentuale);
    final imponibile = totale - iva;
    final quota = numeroRate > 0 ? totale / numeroRate : totale;
    final data = DateFormat('dd/MM/yyyy').format(DateTime.now());

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                logo != null
                    ? pw.Image(logo, width: 150)
                    : pw.Text(
                        'PREVENTIVI',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      'PREVENTIVO',
                      style: pw.TextStyle(
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text('N. $numero'),
                    pw.Text('Data: $data'),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 25),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(12),
              color: PdfColors.grey100,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'CLIENTE',
                    style: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.blue900,
                    ),
                  ),
                  pw.SizedBox(height: 5),
                  pw.Text(
                    cliente,
                    style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Prodotto / Servizio', 'Prezzo (€)'],
              data: articoli
                  .map(
                    (x) => [
                      x['nome'],
                      '€ ${(x['prezzo'] as num).toDouble().toStringAsFixed(2)}',
                    ],
                  )
                  .toList(),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.white,
              ),
              headerDecoration: const pw.BoxDecoration(
                color: PdfColors.blue900,
              ),
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerRight,
              },
            ),
            pw.SizedBox(height: 18),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Imponibile: € ${imponibile.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 12,
                  color: PdfColors.grey700,
                ),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'IVA ${ivaPercentuale.toStringAsFixed(0)}%: € ${iva.toStringAsFixed(2)}',
                style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700),
              ),
            ),
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'TOTALE: € ${totale.toStringAsFixed(2)}',
                style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              ),
            ),
            if (numeroRate > 1) ...[
              pw.SizedBox(height: 25),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue900),
                ),
                child: pw.Text(
                  '$numeroRate rate mensili da € ${quota.toStringAsFixed(2)} ciascuna.',
                ),
              ),
            ],
            pw.Spacer(),
            pw.Divider(),
            pw.Text(
              'Documento generato da Gestione Preventivi.',
              style: const pw.TextStyle(
                fontSize: 9,
                color: PdfColors.grey600,
              ),
            ),
          ],
        ),
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'Preventivo_$numero.pdf',
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int preventivi = 0;
  int clienti = 0;
  int prodotti = 0;
  int rate = 0;
  bool loading = true;

  @override
  void initState() {
    super.initState();
    caricaStatistiche();
  }

  Future<void> caricaStatistiche() async {
    final db = DatabaseHelper.instance;

    final results = await Future.wait([
      db.getPreventivi(),
      db.getClienti(),
      db.getProdotti(),
      db.getRate(),
    ]);

    if (!mounted) return;

    setState(() {
      preventivi = results[0].length;
      clienti = results[1].length;
      prodotti = results[2].length;
      rate = results[3].length;
      loading = false;
    });
  }

  Future<void> apri(Widget pagina) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => pagina),
    );
    caricaStatistiche();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Preventivi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: primary,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: caricaStatistiche,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: primary,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.asset(
                        'assets/logo.png',
                        width: double.infinity,
                        height: 150,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.high,
                      ),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Gestione Preventivi',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 25,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    const Text(
                      'Crea, salva e condividi i tuoi preventivi.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: primary,
                        ),
                        onPressed: () =>
                            apri(const NuovoPreventivoScreen()),
                        icon: const Icon(Icons.add),
                        label: const Text(
                          'NUOVO PREVENTIVO',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    Icons.receipt_long,
                    'Preventivi',
                    preventivi,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    Icons.people_alt_outlined,
                    'Clienti',
                    clienti,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    Icons.inventory_2_outlined,
                    'Prodotti',
                    prodotti,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _statCard(
                    Icons.payments_outlined,
                    'Rate',
                    rate,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            const Text(
              'Gestione',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            _menuTile(
              Icons.receipt_long,
              'Lista preventivi',
              'Visualizza i preventivi salvati',
              () => apri(const ListaPreventiviScreen()),
            ),
            _menuTile(
              Icons.people_alt_outlined,
              'Clienti',
              'Gestisci l’anagrafica clienti',
              () => apri(const ClientiScreen()),
            ),
            _menuTile(
              Icons.inventory_2_outlined,
              'Prodotti / Servizi',
              'Gestisci prodotti e prezzi',
              () => apri(const ProdottiScreen()),
            ),
            _menuTile(
              Icons.payments_outlined,
              'Rate e scadenze',
              'Controlla le rate programmate',
              () => apri(const RateScreen()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statCard(IconData icon, String label, int value) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        child: Column(
          children: [
            Icon(
              icon,
              size: 30,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 7),
            Text(
              loading ? '…' : '$value',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(label),
          ],
        ),
      ),
    );
  }

  Widget _menuTile(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 9),
      child: ListTile(
        leading: CircleAvatar(child: Icon(icon)),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class NuovoPreventivoScreen extends StatefulWidget {
  const NuovoPreventivoScreen({super.key});

  @override
  State<NuovoPreventivoScreen> createState() => _NuovoPreventivoScreenState();
}

class _NuovoPreventivoScreenState extends State<NuovoPreventivoScreen> {
  final clienteController = TextEditingController();
  final prodottoController = TextEditingController();
  final prezzoController = TextEditingController();

  List<Map<String, dynamic>> clienti = [];
  List<Map<String, dynamic>> prodotti = [];
  Map<String, dynamic>? clienteSelezionato;
  bool caricamentoAnagrafiche = true;
  final List<Map<String, dynamic>> articoli = [];
  int numeroRate = 1;
  double ivaPercentuale = 22;
  bool busy = false;

  double get imponibile => articoli.fold<double>(
        0,
        (sum, x) => sum + (x['prezzo'] as num).toDouble(),
      );

  double get iva => imponibile * ivaPercentuale / 100;
  double get totale => imponibile + iva;

  @override
  void initState() {
    super.initState();
    _caricaAnagrafiche();
  }

  Future<void> _caricaAnagrafiche() async {
    final db = DatabaseHelper.instance;
    final risultati = await Future.wait([db.getClienti(), db.getProdotti()]);
    if (!mounted) return;
    setState(() {
      clienti = risultati[0];
      prodotti = risultati[1];
      caricamentoAnagrafiche = false;
    });
  }

  Future<void> _nuovoCliente() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ClientiScreen()),
    );
    await _caricaAnagrafiche();
  }

  void _selezionaCliente(Map<String, dynamic> cliente) {
    setState(() {
      clienteSelezionato = cliente;
      clienteController.text = cliente['nome'].toString();
    });
  }

  void _aggiungiProdottoDaAnagrafica(Map<String, dynamic> prodotto) {
    setState(() {
      articoli.add({
        'nome': prodotto['nome'].toString(),
        'prezzo': (prodotto['prezzo'] as num).toDouble(),
        'prodotto_id': prodotto['id'],
      });
      prodottoController.clear();
      prezzoController.clear();
    });
  }

  void aggiungiProdottoManuale() {
    final nome = prodottoController.text.trim();
    final prezzo = double.tryParse(
      prezzoController.text.trim().replaceAll(',', '.'),
    );
    if (nome.isEmpty || prezzo == null || prezzo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci descrizione e prezzo validi.')),
      );
      return;
    }
    setState(() {
      articoli.add({'nome': nome, 'prezzo': prezzo});
      prodottoController.clear();
      prezzoController.clear();
    });
  }

  Future<void> generaPreventivo() async {
    if (busy) return;
    final cliente = clienteController.text.trim();
    if (cliente.isEmpty || articoli.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona un cliente e almeno un prodotto/servizio.')),
      );
      return;
    }
    setState(() => busy = true);
    try {
      final db = DatabaseHelper.instance;
      final numero = await db.prossimoNumeroPreventivo();
      final id = await db.insertPreventivo(
        numero: numero,
        cliente: cliente,
        totale: totale,
        ivaPercentuale: ivaPercentuale,
        numeroRate: numeroRate,
        articoli: articoli,
      );
      final esistente = clienti.any((c) =>
          c['nome'].toString().toLowerCase() == cliente.toLowerCase());
      if (!esistente) await db.insertCliente(nome: cliente);

      if (numeroRate > 1) {
        final base = totale / numeroRate;
        double somma = 0;
        for (int i = 1; i <= numeroRate; i++) {
          final data = DateTime(DateTime.now().year, DateTime.now().month + i,
              DateTime.now().day, 9);
          final importo = i == numeroRate
              ? double.parse((totale - somma).toStringAsFixed(2))
              : double.parse(base.toStringAsFixed(2));
          somma += importo;
          await db.insertRata(
            preventivoId: id,
            cliente: cliente,
            importo: importo,
            dataScadenza: data,
          );
          await NotificationService().programmaNotificaRata(
            id: id * 100 + i,
            cliente: cliente,
            importo: importo,
            dataScadenza: data,
          );
        }
      }
      await PdfGenerator.generaECondividiPreventivo(
        numero: numero,
        cliente: cliente,
        articoli: articoli,
        numeroRate: numeroRate,
        ivaPercentuale: ivaPercentuale,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Preventivo $numero salvato.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  void dispose() {
    clienteController.dispose();
    prodottoController.dispose();
    prezzoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuovo Preventivo', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: caricamentoAnagrafiche
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Autocomplete<Map<String, dynamic>>(
                  displayStringForOption: (c) => c['nome'].toString(),
                  optionsBuilder: (value) {
                    final q = value.text.trim().toLowerCase();
                    if (q.isEmpty) return clienti;
                    return clienti.where((c) => c['nome'].toString().toLowerCase().contains(q));
                  },
                  onSelected: _selezionaCliente,
                  fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                    clienteController.value = controller.value;
                    controller.addListener(() {
                      clienteController.value = controller.value;
                    });
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        labelText: clienti.isEmpty ? 'Nessun cliente: inserisci nome' : 'Cerca e seleziona cliente',
                        prefixIcon: const Icon(Icons.person),
                        suffixIcon: IconButton(
                          tooltip: 'Nuovo cliente',
                          onPressed: _nuovoCliente,
                          icon: const Icon(Icons.person_add_alt_1),
                        ),
                      ),
                      onChanged: (v) {
                        if (clienteSelezionato != null && v != clienteSelezionato!['nome']) {
                          setState(() => clienteSelezionato = null);
                        }
                      },
                    );
                  },
                ),
                if (clienteSelezionato != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text('Cliente collegato all’anagrafica', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600)),
                  ),
                const SizedBox(height: 24),
                const Text('Prodotti / Servizi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (prodotti.isNotEmpty)
                  Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (p) => p['nome'].toString(),
                    optionsBuilder: (value) {
                      final q = value.text.trim().toLowerCase();
                      if (q.isEmpty) return prodotti;
                      return prodotti.where((p) => p['nome'].toString().toLowerCase().contains(q));
                    },
                    onSelected: _aggiungiProdottoDaAnagrafica,
                    fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        labelText: 'Cerca prodotto / servizio salvato',
                        prefixIcon: Icon(Icons.inventory_2_outlined),
                      ),
                    ),
                  ),
                if (prodotti.isNotEmpty) const SizedBox(height: 10),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 2, child: TextField(controller: prodottoController, decoration: const InputDecoration(labelText: 'Descrizione manuale'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: prezzoController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prezzo €'))),
                  const SizedBox(width: 8),
                  IconButton.filled(onPressed: aggiungiProdottoManuale, icon: const Icon(Icons.add)),
                ]),
                const SizedBox(height: 12),
                if (articoli.isNotEmpty)
                  Card(child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: articoli.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) => ListTile(
                      leading: Icon(articoli[i].containsKey('prodotto_id') ? Icons.link : Icons.edit_note),
                      title: Text(articoli[i]['nome'].toString()),
                      subtitle: Text(articoli[i].containsKey('prodotto_id') ? 'Da Prodotti / Servizi' : 'Inserito manualmente'),
                      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('€ ${(articoli[i]['prezzo'] as num).toDouble().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => articoli.removeAt(i))),
                      ]),
                    ),
                  )),
                const SizedBox(height: 12),
                Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  const Text('Riepilogo totale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Imponibile'), Text('€ ${imponibile.toStringAsFixed(2)}')]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Aliquota IVA'),
                    DropdownButton<double>(value: ivaPercentuale, items: const [0, 4, 5, 10, 22].map((v) => DropdownMenuItem<double>(value: v.toDouble(), child: Text('${v.toStringAsFixed(0)}%'))).toList(), onChanged: (v) => setState(() => ivaPercentuale = v ?? 22)),
                  ]),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('IVA ${ivaPercentuale.toStringAsFixed(0)}%'), Text('€ ${iva.toStringAsFixed(2)}')]),
                  const Divider(),
                  Align(alignment: Alignment.centerRight, child: Text('TOTALE: € ${totale.toStringAsFixed(2)}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
                ]))),
                const Divider(height: 32),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  const Text('Numero rate mensili', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  DropdownButton<int>(value: numeroRate, items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} ${i == 0 ? 'rata' : 'rate'}')),), onChanged: (v) { if (v != null) setState(() => numeroRate = v); }),
                ]),
                if (numeroRate > 1) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Rata indicativa: € ${(totale / numeroRate).toStringAsFixed(2)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
                const SizedBox(height: 24),
                SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: busy ? null : generaPreventivo, icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.picture_as_pdf), label: Text(busy ? 'SALVATAGGIO...' : 'GENERA PDF E PROGRAMMA RATE'))),
              ]),
            ),
    );
  }
}

class ListaPreventiviScreen extends StatefulWidget {
  const ListaPreventiviScreen({super.key});

  @override
  State<ListaPreventiviScreen> createState() =>
      _ListaPreventiviScreenState();
}

class _ListaPreventiviScreenState extends State<ListaPreventiviScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> preventivi = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
    _carica();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() => loading = true);
    final data = await DatabaseHelper.instance.getPreventivi();

    if (mounted) {
      setState(() {
        preventivi = data;
        loading = false;
      });
    }
  }

  Future<void> _elimina(Map<String, dynamic> preventivo) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare preventivo?'),
        content: Text(
          'Vuoi eliminare ${preventivo['numero']} '
          'del cliente "${preventivo['cliente']}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULLA'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );

    if (ok == true) {
      final db = await DatabaseHelper.instance.database;

      await db.delete(
        'rate',
        where: 'preventivo_id = ?',
        whereArgs: [preventivo['id']],
      );

      await db.delete(
        'preventivi',
        where: 'id = ?',
        whereArgs: [preventivo['id']],
      );

      await _carica();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preventivo eliminato.')),
        );
      }
    }
  }

  void _mostraDettagli(Map<String, dynamic> x) {
    final data = DateTime.parse(x['data']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    radius: 25,
                    child: Icon(Icons.receipt_long),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      x['numero'],
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 28),
              _detailRow(Icons.person_outline, 'Cliente', x['cliente']),
              _detailRow(
                Icons.calendar_today_outlined,
                'Data',
                DateFormat('dd/MM/yyyy').format(data),
              ),
              _detailRow(
                Icons.payments_outlined,
                'Totale',
                '€ ${(x['totale'] as num).toStringAsFixed(2)}',
              ),
              _detailRow(
                Icons.event_repeat,
                'Rate',
                '${x['numero_rate']} '
                '${x['numero_rate'] == 1 ? 'rata' : 'rate'}',
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);

                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ModificaPreventivoScreen(preventivo: x),
                          ),
                        ).then((_) => _carica());
                      },
                      icon: const Icon(Icons.edit),
                      label: const Text('MODIFICA'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await _elimina(x);
                        if (ctx.mounted) Navigator.pop(ctx);
                      },
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('ELIMINA'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await PdfGenerator.generaECondividiPreventivo(
                      numero: x['numero'],
                      cliente: x['cliente'],
                      articoli: _articoliDaPreventivo(x),
                      numeroRate: x['numero_rate'],
                      ivaPercentuale: (x['iva_percentuale'] as num?)?.toDouble() ?? 0,
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('RIGENERA / CONDIVIDI PDF'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Map<String, dynamic>> _articoliDaPreventivo(
    Map<String, dynamic> x,
  ) {
    try {
      final raw = jsonDecode((x['articoli'] ?? '[]').toString());

      return (raw as List).map((e) {
        return {
          'nome': e['nome'].toString(),
          'prezzo': (e['prezzo'] as num).toDouble(),
        };
      }).toList();
    } catch (_) {
      return [];
    }
  }

  Widget _detailRow(
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 22,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          Expanded(
            child: Text(value, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();

    final filtrati = preventivi.where((x) {
      if (q.isEmpty) return true;

      final numero = (x['numero'] ?? '').toString().toLowerCase();
      final cliente = (x['cliente'] ?? '').toString().toLowerCase();

      return numero.contains(q) || cliente.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Lista Preventivi',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            onPressed: _carica,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: 'Cerca numero o cliente',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _search.clear,
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (filtrati.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${filtrati.length} '
                        '${filtrati.length == 1 ? 'preventivo' : 'preventivi'}',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (filtrati.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            q.isEmpty
                                ? 'Nessun preventivo salvato.'
                                : 'Nessun preventivo trovato.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ...filtrati.map((x) {
                    final data = DateTime.parse(x['data']);

                    return Card(
                      margin: const EdgeInsets.only(bottom: 9),
                      child: ListTile(
                        onTap: () => _mostraDettagli(x),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        leading: const CircleAvatar(
                          child: Icon(Icons.receipt_long),
                        ),
                        title: Text(
                          x['numero'],
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '${x['cliente']}\n'
                            '${DateFormat('dd/MM/yyyy').format(data)} • '
                            '${x['numero_rate']} '
                            '${x['numero_rate'] == 1 ? 'rata' : 'rate'}',
                          ),
                        ),
                        isThreeLine: true,
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '€ ${(x['totale'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Icon(
                              Icons.chevron_right,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class ModificaPreventivoScreen extends StatefulWidget {
  final Map<String, dynamic> preventivo;
  const ModificaPreventivoScreen({super.key, required this.preventivo});

  @override
  State<ModificaPreventivoScreen> createState() => _ModificaPreventivoScreenState();
}

class _ModificaPreventivoScreenState extends State<ModificaPreventivoScreen> {
  late final TextEditingController clienteController;
  final prodottoController = TextEditingController();
  final prezzoController = TextEditingController();
  List<Map<String, dynamic>> clienti = [];
  List<Map<String, dynamic>> prodotti = [];
  Map<String, dynamic>? clienteSelezionato;
  late List<Map<String, dynamic>> articoli;
  late int numeroRate;
  bool caricamentoAnagrafiche = true;
  bool busy = false;

  double get imponibile => articoli.fold<double>(0, (sum, x) => sum + (x['prezzo'] as num).toDouble());
  double get iva => imponibile * ivaPercentuale / 100;
  double get totale => imponibile + iva;

  @override
  void initState() {
    super.initState();
    clienteController = TextEditingController(text: widget.preventivo['cliente'].toString());
    numeroRate = (widget.preventivo['numero_rate'] as num).toInt();
    ivaPercentuale = (widget.preventivo['iva_percentuale'] as num?)?.toDouble() ?? 0;
    try {
      final raw = jsonDecode((widget.preventivo['articoli'] ?? '[]').toString());
      articoli = (raw as List).map((e) => {'nome': e['nome'].toString(), 'prezzo': (e['prezzo'] as num).toDouble(), if (e['prodotto_id'] != null) 'prodotto_id': e['prodotto_id']}).toList();
    } catch (_) { articoli = []; }
    _caricaAnagrafiche();
  }

  Future<void> _caricaAnagrafiche() async {
    final db = DatabaseHelper.instance;
    final risultati = await Future.wait([db.getClienti(), db.getProdotti()]);
    if (!mounted) return;
    final nome = clienteController.text.trim().toLowerCase();
    setState(() {
      clienti = risultati[0];
      prodotti = risultati[1];
      clienteSelezionato = clienti.cast<Map<String, dynamic>?>().firstWhere((c) => c!['nome'].toString().toLowerCase() == nome, orElse: () => null);
      caricamentoAnagrafiche = false;
    });
  }

  Future<void> _nuovoCliente() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientiScreen()));
    await _caricaAnagrafiche();
  }

  void _selezionaCliente(Map<String, dynamic> cliente) {
    setState(() { clienteSelezionato = cliente; clienteController.text = cliente['nome'].toString(); });
  }

  void _aggiungiProdotto(Map<String, dynamic> prodotto) {
    setState(() {
      articoli.add({'nome': prodotto['nome'].toString(), 'prezzo': (prodotto['prezzo'] as num).toDouble(), 'prodotto_id': prodotto['id']});
    });
  }

  void aggiungiManuale() {
    final nome = prodottoController.text.trim();
    final prezzo = double.tryParse(prezzoController.text.trim().replaceAll(',', '.'));
    if (nome.isEmpty || prezzo == null || prezzo < 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Inserisci descrizione e prezzo validi.')));
      return;
    }
    setState(() { articoli.add({'nome': nome, 'prezzo': prezzo}); prodottoController.clear(); prezzoController.clear(); });
  }

  Future<void> salva() async {
    if (busy) return;
    final cliente = clienteController.text.trim();
    if (cliente.isEmpty || articoli.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Seleziona un cliente e almeno un prodotto/servizio.')));
      return;
    }
    setState(() => busy = true);
    try {
      final db = DatabaseHelper.instance;
      final id = (widget.preventivo['id'] as num).toInt();
      await db.updatePreventivo(id: id, cliente: cliente, totale: totale, ivaPercentuale: ivaPercentuale, numeroRate: numeroRate, articoli: articoli);
      final database = await db.database;
      await database.delete('rate', where: 'preventivo_id = ?', whereArgs: [id]);
      if (numeroRate > 1) {
        final base = totale / numeroRate;
        double somma = 0;
        for (int i = 1; i <= numeroRate; i++) {
          final data = DateTime(DateTime.now().year, DateTime.now().month + i, DateTime.now().day, 9);
          final importo = i == numeroRate ? double.parse((totale - somma).toStringAsFixed(2)) : double.parse(base.toStringAsFixed(2));
          somma += importo;
          await db.insertRata(preventivoId: id, cliente: cliente, importo: importo, dataScadenza: data);
          await NotificationService().programmaNotificaRata(id: id * 100 + i, cliente: cliente, importo: importo, dataScadenza: data);
        }
      }
      await PdfGenerator.generaECondividiPreventivo(numero: widget.preventivo['numero'], cliente: cliente, articoli: articoli, numeroRate: numeroRate, ivaPercentuale: ivaPercentuale);
      if (mounted) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preventivo modificato e PDF rigenerato.'))); Navigator.pop(context); }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Errore: $e')));
    } finally { if (mounted) setState(() => busy = false); }
  }

  @override
  void dispose() { clienteController.dispose(); prodottoController.dispose(); prezzoController.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Modifica ${widget.preventivo['numero']}'), backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Colors.white),
      body: caricamentoAnagrafiche
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Cliente', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Autocomplete<Map<String, dynamic>>(
                initialValue: TextEditingValue(text: clienteController.text),
                displayStringForOption: (c) => c['nome'].toString(),
                optionsBuilder: (value) {
                  final q = value.text.trim().toLowerCase();
                  if (q.isEmpty) return clienti;
                  return clienti.where((c) => c['nome'].toString().toLowerCase().contains(q));
                },
                onSelected: _selezionaCliente,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  return TextField(controller: controller, focusNode: focusNode, textCapitalization: TextCapitalization.words, decoration: InputDecoration(labelText: clienti.isEmpty ? 'Nessun cliente: inserisci nome' : 'Cerca e seleziona cliente', prefixIcon: const Icon(Icons.person), suffixIcon: IconButton(tooltip: 'Nuovo cliente', onPressed: _nuovoCliente, icon: const Icon(Icons.person_add_alt_1))), onChanged: (v) { clienteController.text = v; if (clienteSelezionato != null && v != clienteSelezionato!['nome']) setState(() => clienteSelezionato = null); });
                },
              ),
              if (clienteSelezionato != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Cliente collegato all’anagrafica', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
              const SizedBox(height: 24),
              const Text('Prodotti / Servizi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              if (prodotti.isNotEmpty) Autocomplete<Map<String, dynamic>>(
                displayStringForOption: (p) => p['nome'].toString(),
                optionsBuilder: (value) { final q = value.text.trim().toLowerCase(); if (q.isEmpty) return prodotti; return prodotti.where((p) => p['nome'].toString().toLowerCase().contains(q)); },
                onSelected: _aggiungiProdotto,
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) => TextField(controller: controller, focusNode: focusNode, decoration: const InputDecoration(labelText: 'Cerca prodotto / servizio salvato', prefixIcon: Icon(Icons.inventory_2_outlined))),
              ),
              if (prodotti.isNotEmpty) const SizedBox(height: 10),
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: TextField(controller: prodottoController, decoration: const InputDecoration(labelText: 'Descrizione manuale'))), const SizedBox(width: 8), Expanded(child: TextField(controller: prezzoController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Prezzo €'))), const SizedBox(width: 8), IconButton.filled(onPressed: aggiungiManuale, icon: const Icon(Icons.add))]),
              const SizedBox(height: 12),
              if (articoli.isNotEmpty) Card(child: ListView.separated(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: articoli.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) => ListTile(leading: Icon(articoli[i].containsKey('prodotto_id') ? Icons.link : Icons.edit_note), title: Text(articoli[i]['nome'].toString()), subtitle: Text(articoli[i].containsKey('prodotto_id') ? 'Da Prodotti / Servizi' : 'Inserito manualmente'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('€ ${(articoli[i]['prezzo'] as num).toDouble().toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => setState(() => articoli.removeAt(i))) ]))),
              const SizedBox(height: 12),
              Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const Text('Riepilogo totale', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Imponibile'), Text('€ ${imponibile.toStringAsFixed(2)}')]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Aliquota IVA'), DropdownButton<double>(value: ivaPercentuale, items: const [0, 4, 5, 10, 22].map((v) => DropdownMenuItem<double>(value: v.toDouble(), child: Text('${v.toStringAsFixed(0)}%'))).toList(), onChanged: (v) => setState(() => ivaPercentuale = v ?? 22))]),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('IVA ${ivaPercentuale.toStringAsFixed(0)}%'), Text('€ ${iva.toStringAsFixed(2)}')]),
                const Divider(),
                Align(alignment: Alignment.centerRight, child: Text('TOTALE: € ${totale.toStringAsFixed(2)}', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold))),
              ]))),
              const Divider(height: 32),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Numero rate mensili', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), DropdownButton<int>(value: numeroRate, items: List.generate(12, (i) => DropdownMenuItem(value: i + 1, child: Text('${i + 1} ${i == 0 ? 'rata' : 'rate'}'))), onChanged: (v) { if (v != null) setState(() => numeroRate = v); })]),
              if (numeroRate > 1) Padding(padding: const EdgeInsets.only(top: 8), child: Text('Rata indicativa: € ${(totale / numeroRate).toStringAsFixed(2)}', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.w600))),
              const SizedBox(height: 24),
              SizedBox(width: double.infinity, height: 56, child: FilledButton.icon(onPressed: busy ? null : salva, icon: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save), label: Text(busy ? 'SALVATAGGIO...' : 'SALVA E RIGENERA PDF'))),
            ])),
    );
  }
}

class ClientiScreen extends StatefulWidget {
  const ClientiScreen({super.key});

  @override
  State<ClientiScreen> createState() => _ClientiScreenState();
}

class _ClientiScreenState extends State<ClientiScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> clienti = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _carica();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() => loading = true);
    final data = await DatabaseHelper.instance.getClienti();

    if (mounted) {
      setState(() {
        clienti = data;
        loading = false;
      });
    }
  }

  Future<void> _formCliente([Map<String, dynamic>? cliente]) async {
    final nome = TextEditingController(text: cliente?['nome'] ?? '');
    final telefono =
        TextEditingController(text: cliente?['telefono'] ?? '');
    final email = TextEditingController(text: cliente?['email'] ?? '');
    final indirizzo =
        TextEditingController(text: cliente?['indirizzo'] ?? '');
    final key = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cliente == null ? 'Nuovo cliente' : 'Modifica cliente',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nome,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Nome / Ragione Sociale',
                    prefixIcon: Icon(Icons.person),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Inserisci il nome'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: telefono,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Telefono',
                    prefixIcon: Icon(Icons.phone),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: indirizzo,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Indirizzo',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (!key.currentState!.validate()) return;

                      if (cliente == null) {
                        await DatabaseHelper.instance.insertCliente(
                          nome: nome.text.trim(),
                          telefono: telefono.text.trim(),
                          email: email.text.trim(),
                          indirizzo: indirizzo.text.trim(),
                        );
                      } else {
                        await DatabaseHelper.instance.updateCliente(
                          id: cliente['id'],
                          nome: nome.text.trim(),
                          telefono: telefono.text.trim(),
                          email: email.text.trim(),
                          indirizzo: indirizzo.text.trim(),
                        );
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      await _carica();
                    },
                    icon: const Icon(Icons.save),
                    label: Text(
                      cliente == null
                          ? 'SALVA CLIENTE'
                          : 'SALVA MODIFICHE',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nome.dispose();
    telefono.dispose();
    email.dispose();
    indirizzo.dispose();
  }

  Future<void> _elimina(Map<String, dynamic> c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare cliente?'),
        content: Text('Vuoi eliminare "${c['nome']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULLA'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await DatabaseHelper.instance.deleteCliente(c['id']);
      await _carica();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();

    final filtrati = clienti.where((c) {
      return '${c['nome']} ${c['telefono']} ${c['email']}'
          .toLowerCase()
          .contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clienti'),
        actions: [
          IconButton(
            onPressed: _carica,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formCliente(),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo cliente'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                children: [
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: 'Cerca cliente',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _search.clear,
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (filtrati.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.people_alt_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            q.isEmpty
                                ? 'Nessun cliente salvato.'
                                : 'Nessun cliente trovato.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ...filtrati.map((c) {
                    final dettagli = [
                      if ((c['telefono'] ?? '').toString().isNotEmpty)
                        c['telefono'],
                      if ((c['email'] ?? '').toString().isNotEmpty)
                        c['email'],
                      if ((c['indirizzo'] ?? '').toString().isNotEmpty)
                        c['indirizzo'],
                    ].join('\n');

                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: const CircleAvatar(
                          child: Icon(Icons.person),
                        ),
                        title: Text(
                          c['nome'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(dettagli),
                        isThreeLine: true,
                        trailing: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'edit') {
                              _formCliente(c);
                            } else {
                              _elimina(c);
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                leading: Icon(Icons.edit),
                                title: Text('Modifica'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                leading: Icon(Icons.delete_outline),
                                title: Text('Elimina'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class ProdottiScreen extends StatefulWidget {
  const ProdottiScreen({super.key});

  @override
  State<ProdottiScreen> createState() => _ProdottiScreenState();
}

class _ProdottiScreenState extends State<ProdottiScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> prodotti = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    _carica();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _carica() async {
    setState(() => loading = true);
    final data = await DatabaseHelper.instance.getProdotti();

    if (mounted) {
      setState(() {
        prodotti = data;
        loading = false;
      });
    }
  }

  Future<void> _formProdotto([Map<String, dynamic>? prodotto]) async {
    final nome = TextEditingController(text: prodotto?['nome'] ?? '');

    final prezzo = TextEditingController(
      text: prodotto == null
          ? ''
          : (prodotto['prezzo'] as num).toStringAsFixed(2),
    );

    final key = GlobalKey<FormState>();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
        ),
        child: Form(
          key: key,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prodotto == null
                      ? 'Nuovo prodotto / servizio'
                      : 'Modifica prodotto / servizio',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: nome,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Nome prodotto / servizio',
                    prefixIcon: Icon(Icons.inventory_2_outlined),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Inserisci il nome'
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: prezzo,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Prezzo €',
                    prefixIcon: Icon(Icons.euro),
                  ),
                  validator: (v) {
                    final value = double.tryParse(
                      (v ?? '').trim().replaceAll(',', '.'),
                    );

                    if (value == null || value < 0) {
                      return 'Inserisci un prezzo valido';
                    }

                    return null;
                  },
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton.icon(
                    onPressed: () async {
                      if (!key.currentState!.validate()) return;

                      final value = double.parse(
                        prezzo.text.trim().replaceAll(',', '.'),
                      );

                      if (prodotto == null) {
                        await DatabaseHelper.instance.insertProdotto(
                          nome: nome.text.trim(),
                          prezzo: value,
                        );
                      } else {
                        await DatabaseHelper.instance.updateProdotto(
                          id: prodotto['id'],
                          nome: nome.text.trim(),
                          prezzo: value,
                        );
                      }

                      if (ctx.mounted) Navigator.pop(ctx);
                      await _carica();
                    },
                    icon: const Icon(Icons.save),
                    label: Text(
                      prodotto == null
                          ? 'SALVA PRODOTTO'
                          : 'SALVA MODIFICHE',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    nome.dispose();
    prezzo.dispose();
  }

  Future<void> _elimina(Map<String, dynamic> prodotto) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminare prodotto?'),
        content: Text('Vuoi eliminare "${prodotto['nome']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ANNULLA'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ELIMINA'),
          ),
        ],
      ),
    );

    if (ok == true) {
      await DatabaseHelper.instance.deleteProdotto(prodotto['id']);
      await _carica();
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();

    final filtrati = prodotti.where((prodotto) {
      return (prodotto['nome'] ?? '')
          .toString()
          .toLowerCase()
          .contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prodotti / Servizi'),
        actions: [
          IconButton(
            onPressed: _carica,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _formProdotto(),
        icon: const Icon(Icons.add),
        label: const Text('Nuovo prodotto / servizio'),
      ),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _carica,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
                children: [
                  TextField(
                    controller: _search,
                    decoration: InputDecoration(
                      labelText: 'Cerca prodotto / servizio',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _search.text.isEmpty
                          ? null
                          : IconButton(
                              onPressed: _search.clear,
                              icon: const Icon(Icons.clear),
                            ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (q.isEmpty && filtrati.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        '${filtrati.length} prodotti / servizi',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  if (filtrati.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(40),
                      child: Column(
                        children: [
                          Icon(
                            Icons.inventory_2_outlined,
                            size: 64,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            q.isEmpty
                                ? 'Nessun prodotto o servizio salvato.'
                                : 'Nessun prodotto trovato.',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          if (q.isEmpty)
                            OutlinedButton.icon(
                              onPressed: () => _formProdotto(),
                              icon: const Icon(Icons.add),
                              label: const Text(
                                'Aggiungi il primo prodotto',
                              ),
                            ),
                        ],
                      ),
                    ),
                  ...filtrati.map((prodotto) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 4,
                        ),
                        leading: const CircleAvatar(
                          child: Icon(Icons.inventory_2_outlined),
                        ),
                        title: Text(
                          prodotto['nome'],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: const Text('Prezzo di listino'),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '€ ${(prodotto['prezzo'] as num).toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'edit') {
                                  _formProdotto(prodotto);
                                } else {
                                  _elimina(prodotto);
                                }
                              },
                              itemBuilder: (_) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    leading: Icon(Icons.edit),
                                    title: Text('Modifica'),
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    leading: Icon(Icons.delete_outline),
                                    title: Text('Elimina'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

class RateScreen extends StatelessWidget {
  const RateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rate e scadenze'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: DatabaseHelper.instance.getRate(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final rate = snapshot.data!;

          if (rate.isEmpty) {
            return const _EmptyState(
              icon: Icons.payments_outlined,
              text: 'Nessuna rata programmata.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: rate.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final x = rate[index];

              final data = DateTime.parse(
                x['data_scadenza'],
              );

              final pagata = x['pagata'] == 1;

              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      pagata
                          ? Icons.check
                          : Icons.schedule,
                    ),
                  ),
                  title: Text(
                    x['cliente'],
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(
                    'Scadenza: '
                    '${DateFormat('dd/MM/yyyy').format(data)}',
                  ),
                  trailing: Text(
                    '€ ${(x['importo'] as num).toStringAsFixed(2)}',
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 15),
            Text(
              text,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
