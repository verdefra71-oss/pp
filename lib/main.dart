import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

// ==========================================
// MAIN ENTRY POINT
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inizializza il motore SQLite FFI su desktop (Windows/Linux/macOS)
  if (!kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  await NotificationService().init();
  await DatabaseHelper.instance.createAutomaticBackup();
  
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E88E5),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardTheme(
          elevation: 2,
          margin: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}

// ==========================================
// SERVIZIO NOTIFICHE CROSS-PLATFORM
// ==========================================
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();

  Future<AndroidFlutterLocalNotificationsPlugin?> _android() async {
    if (!kIsWeb && Platform.isAndroid) {
      return _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    }
    return null;
  }

  Future<bool> richiediPermessi() async {
    if (!kIsWeb && Platform.isAndroid) {
      final android = await _android();
      if (android == null) return false;
      final notifiche = await android.requestNotificationsPermission() ?? false;
      await android.requestExactAlarmsPermission();
      return notifiche;
    }
    return true; // Restituisce sempre true su Windows
  }

  Future<bool> notificheAbilitate() async {
    if (!kIsWeb && Platform.isAndroid) {
      final android = await _android();
      if (android == null) return false;
      return await android.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  Future<void> init() async {
    tz_data.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Rome'));
    } catch (_) {}

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      windows: WindowsInitializationSettings(appId: 'com.example.preventivi_app'),
      macOS: DarwinInitializationSettings(),
      iOS: DarwinInitializationSettings(),
    );

    await _notifications.initialize(settings);
    await richiediPermessi();
  }

  Future<void> mostraNotificaValido({
    required int id,
    required String titolo,
    required String corpo,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'channel_preventivi',
        'Notifiche Preventivi',
        importance: Importance.high,
        priority: Priority.high,
      ),
      windows: WindowsNotificationDetails(),
    );

    await _notifications.show(id, titolo, corpo, details);
  }
}

// ==========================================
// GESTIONE DATABASE & BACKUP
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

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE preventivi (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        numero TEXT NOT NULL,
        cliente TEXT NOT NULL,
        data TEXT NOT NULL,
        scadenza TEXT NOT NULL,
        totale REAL NOT NULL,
        note TEXT,
        stato TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE voci_preventivo (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        preventivo_id INTEGER NOT NULL,
        descrizione TEXT NOT NULL,
        quantita REAL NOT NULL,
        prezzo_unitario REAL NOT NULL,
        totale REAL NOT NULL,
        FOREIGN KEY (preventivo_id) REFERENCES preventivi (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<int> insertPreventivo(Map<String, dynamic> row, List<Map<String, dynamic>> voci) async {
    final db = await instance.database;
    return await db.transaction((txn) async {
      int id = await txn.insert('preventivi', row);
      for (var voce in voci) {
        voce['preventivo_id'] = id;
        await txn.insert('voci_preventivo', voce);
      }
      return id;
    });
  }

  Future<List<Map<String, dynamic>>> getPreventivi() async {
    final db = await instance.database;
    return await db.query('preventivi', orderBy: 'id DESC');
  }

  Future<void> deletePreventivo(int id) async {
    final db = await instance.database;
    await db.delete('preventivi', where: 'id = ?', whereArgs: [id]);
    await db.delete('voci_preventivo', where: 'preventivo_id = ?', whereArgs: [id]);
  }

  Future<void> createAutomaticBackup() async {
    try {
      final dbPath = await getDatabasesPath();
      final path = p.join(dbPath, 'preventivi.db');
      final dbFile = File(path);

      if (await dbFile.exists()) {
        final docsDir = await getApplicationDocumentsDirectory();
        final backupPath = p.join(docsDir.path, 'preventivi_backup_auto.db');
        await dbFile.copy(backupPath);
      }
    } catch (e) {
      debugPrint("Errore durante il backup automatico: $e");
    }
  }
}

// ==========================================
// GENERAZIONE E STAMPA PDF
// ==========================================
class PdfService {
  static Future<Uint8List> generaPreventivoPdf(Map<String, dynamic> preventivo, List<Map<String, dynamic>> voci) async {
    final pdf = pw.Document();
    final euroFormat = NumberFormat.currency(locale: 'it_IT', symbol: '€');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crosspw: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('PREVENTIVO', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                    pw.Text('N° ${preventivo['numero']}', style: const pw.TextStyle(fontSize: 16)),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 12),
                pw.Text('Cliente: ${preventivo['cliente']}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.Text('Data: ${preventivo['data']}'),
                pw.Text('Scadenza: ${preventivo['scadenza']}'),
                pw.SizedBox(height: 20),
                pw.TableHelper.fromTextArray(
                  headers: ['Descrizione', 'Q.tà', 'Prezzo Unit.', 'Totale'],
                  data: voci.map((v) => [
                    v['descrizione'],
                    v['quantita'].toString(),
                    euroFormat.format(v['prezzo_unitario']),
                    euroFormat.format(v['totale']),
                  ]).toList(),
                  headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                  cellAlignment: pw.Alignment.centerLeft,
                ),
                pw.SizedBox(height: 20),
                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Totale: ${euroFormat.format(preventivo['totale'])}',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    return pdf.save();
  }
}

// ==========================================
// SCHERMATA PRINCIPALE (HOME)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _preventivi = [];

  @override
  void initState() {
    super.initState();
    _caricaPreventivi();
  }

  Future<void> _caricaPreventivi() async {
    final data = await DatabaseHelper.instance.getPreventivi();
    setState(() {
      _preventivi = data;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestione Preventivi'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _caricaPreventivi,
          )
        ],
      ),
      body: _preventivi.isEmpty
          ? const Center(child: Text('Nessun preventivo trovato.'))
          : ListView.builder(
              itemCount: _preventivi.length,
              itemBuilder: (ctx, index) {
                final item = _preventivi[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text('${item['id']}'),
                    ),
                    title: Text('${item['cliente']} (${item['numero']})'),
                    subtitle: Text('Scadenza: ${item['scadenza']}'),
                    trailing: Text(
                      '€ ${(item['totale'] as double).toStringAsFixed(2)}',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    onLongPress: () async {
                      await DatabaseHelper.instance.deletePreventivo(item['id']);
                      _caricaPreventivi();
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const NuovoPreventivoScreen()),
          );
          _caricaPreventivi();
        },
        label: const Text('Nuovo Preventivo'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}

// ==========================================
// CREAZIONE NUOVO PREVENTIVO
// ==========================================
class NuovoPreventivoScreen extends StatefulWidget {
  const NuovoPreventivoScreen({super.key});

  @override
  State<NuovoPreventivoScreen> createState() => _NuovoPreventivoScreenState();
}

class _NuovoPreventivoScreenState extends State<NuovoPreventivoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clienteController = TextEditingController();
  final _numeroController = TextEditingController(text: 'PREV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}');

  final List<Map<String, dynamic>> _voci = [];
  final _descVoceController = TextEditingController();
  final _qtyController = TextEditingController(text: '1');
  final _prezzoController = TextEditingController(text: '0.0');

  double get _totaleCalcolato {
    return _voci.fold(0.0, (sum, item) => sum + (item['totale'] as double));
  }

  void _aggiungiVoce() {
    final desc = _descVoceController.text.trim();
    final qty = double.tryParse(_qtyController.text) ?? 1.0;
    final prezzo = double.tryParse(_prezzoController.text) ?? 0.0;

    if (desc.isNotEmpty && prezzo > 0) {
      setState(() {
        _voci.add({
          'descrizione': desc,
          'quantita': qty,
          'prezzo_unitario': prezzo,
          'totale': qty * prezzo,
        });
        _descVoceController.clear();
        _qtyController.text = '1';
        _prezzoController.text = '0.0';
      });
    }
  }

  Future<void> _salvaPreventivo() async {
    if (_formKey.currentState!.validate() && _voci.isNotEmpty) {
      final ora = DateTime.now();
      final dataStr = DateFormat('yyyy-MM-dd').format(ora);
      final scadenzaStr = DateFormat('yyyy-MM-dd').format(ora.add(const Duration(days: 30)));

      final preventivo = {
        'numero': _numeroController.text,
        'cliente': _clienteController.text,
        'data': dataStr,
        'scadenza': scadenzaStr,
        'totale': _totaleCalcolato,
        'note': '',
        'stato': 'In Attesa',
      };

      final id = await DatabaseHelper.instance.insertPreventivo(preventivo, _voci);

      await NotificationService().mostraNotificaValido(
        id: id,
        titolo: 'Preventivo Creato',
        corpo: 'Creato preventivo per ${_clienteController.text}',
      );

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo Preventivo')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _numeroController,
                decoration: const InputDecoration(labelText: 'Numero Preventivo'),
                validator: (v) => v!.isEmpty ? 'Campo obbligatorio' : null,
              ),
              TextFormField(
                controller: _clienteController,
                decoration: const InputDecoration(labelText: 'Nome Cliente'),
                validator: (v) => v!.isEmpty ? 'Campo obbligatorio' : null,
              ),
              const SizedBox(height: 20),
              const Text('Aggiungi Voci', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _descVoceController,
                      decoration: const InputDecoration(labelText: 'Descrizione'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 1,
                    child: TextField(
                      controller: _qtyController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Q.tà'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _prezzoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Prezzo €'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle, color: Colors.blue),
                    onPressed: _aggiungiVoce,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ..._voci.map((v) => ListTile(
                    title: Text(v['descrizione']),
                    subtitle: Text('Q.tà: ${v['quantita']} x €${v['prezzo_unitario']}'),
                    trailing: Text('€${(v['totale'] as double).toStringAsFixed(2)}'),
                  )),
              const Divider(),
              Alignment(
                alignment: Alignment.centerRight,
                child: Text(
                  'Totale: € ${_totaleCalcolato.toStringAsFixed(2)}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _salvaPreventivo,
                child: const Text('Salva Preventivo'),
              )
            ],
          ),
        ),
      ),
    );
  }
}

