import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = FamilyStore();
  await store.load();
  runApp(FamilyApp(store: store));
}

class Txn {
  String id, date, description, category, account, note;
  double amount;
  bool income;
  Txn({required this.id, required this.date, required this.description, required this.amount, required this.income, required this.category, required this.account, this.note = ''});
  Map<String, dynamic> toJson() => {'id': id, 'date': date, 'description': description, 'amount': amount, 'income': income, 'category': category, 'account': account, 'note': note};
  factory Txn.fromJson(Map<String, dynamic> j) => Txn(
    id: j['id']?.toString() ?? '', date: j['date']?.toString() ?? '', description: j['description']?.toString() ?? '',
    amount: (j['amount'] as num?)?.toDouble() ?? 0, income: j['income'] == true,
    category: j['category']?.toString() ?? 'Altro', account: j['account']?.toString() ?? 'Contanti', note: j['note']?.toString() ?? '',
  );
}

class Budget {
  String category;
  double limit;
  Budget(this.category, this.limit);
  Map<String, dynamic> toJson() => {'category': category, 'limit': limit};
  factory Budget.fromJson(Map<String, dynamic> j) => Budget(j['category']?.toString() ?? 'Altro', (j['limit'] as num?)?.toDouble() ?? 0);
}

class Recurring {
  String name, category;
  double amount;
  int day;
  Recurring(this.name, this.amount, this.category, this.day);
  Map<String, dynamic> toJson() => {'name': name, 'amount': amount, 'category': category, 'day': day};
  factory Recurring.fromJson(Map<String, dynamic> j) => Recurring(j['name']?.toString() ?? '', (j['amount'] as num?)?.toDouble() ?? 0, j['category']?.toString() ?? 'Altro', (j['day'] as num?)?.toInt() ?? 1);
}

class FamilyStore extends ChangeNotifier {
  final List<Txn> txns = [];
  final List<Budget> budgets = [];
  final List<Recurring> recurring = [];
  final List<String> accounts = ['Banca', 'Carta', 'Contanti'];
  final List<String> categories = const [
    'Mutuo/affitto', 'Luce', 'Gas', 'Acqua', 'Telefono/Internet', 'Auto', 'Carburante', 'Assicurazione',
    'Alimentari', 'Casa', 'Scuola', 'Vacanze', 'Regali', 'Tempo libero', 'Salute', 'Abbigliamento',
    'Abbonamenti', 'Tasse', 'Spese impreviste', 'Altro'
  ];
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    try {
      final t = _prefs!.getString('txns');
      if (t != null) txns.addAll((jsonDecode(t) as List).map((e) => Txn.fromJson(Map<String, dynamic>.from(e))));
      final b = _prefs!.getString('budgets');
      if (b != null) budgets.addAll((jsonDecode(b) as List).map((e) => Budget.fromJson(Map<String, dynamic>.from(e))));
      final r = _prefs!.getString('recurring');
      if (r != null) recurring.addAll((jsonDecode(r) as List).map((e) => Recurring.fromJson(Map<String, dynamic>.from(e))));
    } catch (_) {
      txns.clear(); budgets.clear(); recurring.clear();
    }
  }

  Future<void> save() async {
    await _prefs?.setString('txns', jsonEncode(txns.map((e) => e.toJson()).toList()));
    await _prefs?.setString('budgets', jsonEncode(budgets.map((e) => e.toJson()).toList()));
    await _prefs?.setString('recurring', jsonEncode(recurring.map((e) => e.toJson()).toList()));
    notifyListeners();
  }
  void add(Txn t) { txns.add(t); save(); }
  void remove(Txn t) { txns.remove(t); save(); }
  double income(String ym) => txns.where((t) => t.income && t.date.startsWith(ym)).fold<double>(0, (s, t) => s + t.amount);
  double expense(String ym) => txns.where((t) => !t.income && t.date.startsWith(ym)).fold<double>(0, (s, t) => s + t.amount);
  double categoryExpense(String ym, String c) => txns.where((t) => !t.income && t.date.startsWith(ym) && t.category == c).fold<double>(0, (s, t) => s + t.amount);
}

class FamilyApp extends StatelessWidget {
  final FamilyStore store;
  const FamilyApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gestione Familiare',
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.pink, scaffoldBackgroundColor: const Color(0xfffaf7f9), cardTheme: const CardThemeData(elevation: 1, margin: EdgeInsets.all(8)), inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder())),
      home: Home(store: store),
    ),
  );
}

String money(double v) => '€ ${v.toStringAsFixed(2).replaceAll('.', ',')}';
String today() { final d = DateTime.now(); return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'; }
String monthLabel(DateTime d) => '${d.month.toString().padLeft(2, '0')}/${d.year}';

class Home extends StatefulWidget {
  final FamilyStore store;
  const Home({super.key, required this.store});
  @override State<Home> createState() => _HomeState();
}
class _HomeState extends State<Home> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final pages = [Dashboard(store: widget.store), Movements(store: widget.store), Bills(store: widget.store), BudgetPage(store: widget.store), Reports(store: widget.store), MorePage(store: widget.store)];
    return Scaffold(
      body: pages[index],
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (i) => setState(() => index = i), destinations: const [
        NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
        NavigationDestination(icon: Icon(Icons.swap_vert), label: 'Movimenti'), NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Bollette'),
        NavigationDestination(icon: Icon(Icons.pie_chart_outline), label: 'Budget'), NavigationDestination(icon: Icon(Icons.bar_chart), label: 'Report'), NavigationDestination(icon: Icon(Icons.more_horiz), label: 'Altro')]),
      floatingActionButton: (index == 0 || index == 1) ? FloatingActionButton.extended(onPressed: () => showTxn(context, widget.store), icon: const Icon(Icons.add), label: const Text('Movimento')) : null,
    );
  }
}

class Dashboard extends StatelessWidget {
  final FamilyStore store;
  const Dashboard({super.key, required this.store});
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final ym = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    final inc = store.income(ym), exp = store.expense(ym), bal = inc - exp;
    return Scaffold(appBar: AppBar(title: const Text('Gestione Familiare')), body: ListView(padding: const EdgeInsets.all(12), children: [
      Text('Riepilogo ${monthLabel(now)}', style: Theme.of(context).textTheme.titleLarge), const SizedBox(height: 8),
      Row(children: [metric('Entrate', money(inc), Colors.green, Icons.arrow_downward), metric('Spese', money(exp), Colors.red, Icons.arrow_upward)]),
      Row(children: [metric('Disponibile', money(bal), bal >= 0 ? Colors.blue : Colors.red, Icons.account_balance_wallet), metric('Movimenti', '${store.txns.where((t) => t.date.startsWith(ym)).length}', Colors.orange, Icons.list_alt)]),
      Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Spese per categoria', style: Theme.of(context).textTheme.titleMedium), const SizedBox(height: 8),
        ...store.categories.map((c) { final v = store.categoryExpense(ym, c); if (v == 0) return const SizedBox.shrink(); final pct = exp == 0 ? 0.0 : (v / exp).clamp(0.0, 1.0).toDouble(); return Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(c), Text(money(v))]), LinearProgressIndicator(value: pct)])); }),
      ]))),
      Card(child: ListTile(leading: const Icon(Icons.lightbulb_outline), title: const Text('Consiglio del mese'), subtitle: Text(bal >= 0 ? 'Hai un saldo positivo di ${money(bal)}. Controlla il budget per aumentare il risparmio.' : 'Le spese superano le entrate di ${money(-bal)}. Controlla soprattutto le categorie extra.'))),
    ]));
  }
}
Widget metric(String title, String value, Color color, IconData icon) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, color: color), Text(title), Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))]))));

class Movements extends StatefulWidget { final FamilyStore store; const Movements({super.key, required this.store}); @override State<Movements> createState() => _MovementsState(); }
class _MovementsState extends State<Movements> {
  String filter = 'Tutti';
  @override Widget build(BuildContext context) {
    final list = widget.store.txns.where((t) => (filter == 'Tutti' || (filter == 'Entrate' ? t.income : !t.income))).toList()..sort((a, b) => b.date.compareTo(a.date));
    return Scaffold(appBar: AppBar(title: const Text('Movimenti'), actions: [IconButton(onPressed: () => showSearch(context: context, delegate: TxnSearch(widget.store)), icon: const Icon(Icons.search)), PopupMenuButton<String>(onSelected: (v) => setState(() => filter = v), itemBuilder: (_) => const [PopupMenuItem(value: 'Tutti', child: Text('Tutti')), PopupMenuItem(value: 'Entrate', child: Text('Entrate')), PopupMenuItem(value: 'Uscite', child: Text('Uscite'))])]), body: list.isEmpty ? const Center(child: Text('Nessun movimento. Premi + per inserirne uno.')) : ListView.builder(itemCount: list.length, itemBuilder: (c, i) { final t = list[i]; return Card(child: ListTile(leading: CircleAvatar(child: Icon(t.income ? Icons.add : Icons.remove)), title: Text(t.description), subtitle: Text('${t.date} • ${t.category} • ${t.account}'), trailing: Text('${t.income ? '+' : '-'} ${money(t.amount)}', style: TextStyle(color: t.income ? Colors.green : Colors.red, fontWeight: FontWeight.bold)), onTap: () => showTxn(context, widget.store, existing: t))); }));
  }
}
class TxnSearch extends SearchDelegate<String> {
  final FamilyStore store; TxnSearch(this.store);
  @override List<Widget>? buildActions(BuildContext c) => [IconButton(onPressed: () => query = '', icon: const Icon(Icons.clear))];
  @override Widget? buildLeading(BuildContext c) => IconButton(onPressed: () => close(c, ''), icon: const Icon(Icons.arrow_back));
  @override Widget buildResults(BuildContext c) => _results();
  @override Widget buildSuggestions(BuildContext c) => _results();
  Widget _results() { final l = store.txns.where((t) => t.description.toLowerCase().contains(query.toLowerCase()) || t.category.toLowerCase().contains(query.toLowerCase())).toList(); return ListView(children: l.map((t) => ListTile(title: Text(t.description), subtitle: Text(t.category), trailing: Text(money(t.amount)))).toList()); }
}

class Bills extends StatelessWidget {
  final FamilyStore store; const Bills({super.key, required this.store});
  @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Bollette e ricorrenti'), actions: [IconButton(onPressed: () => showRecurring(context, store), icon: const Icon(Icons.add))]), body: ListView(padding: const EdgeInsets.all(8), children: [Card(child: const ListTile(leading: Icon(Icons.info_outline), title: Text('Spese ricorrenti'), subtitle: Text('Imposta importo e giorno di scadenza per mutuo, luce, gas, telefono, auto e altre spese.'))), ...store.recurring.map((r) => Card(child: ListTile(leading: const Icon(Icons.event_repeat), title: Text(r.name), subtitle: Text('${r.category} • giorno ${r.day}'), trailing: Text(money(r.amount)))))]);
}

class BudgetPage extends StatefulWidget { final FamilyStore store; const BudgetPage({super.key, required this.store}); @override State<BudgetPage> createState() => _BudgetPageState(); }
class _BudgetPageState extends State<BudgetPage> {
  @override Widget build(BuildContext context) { final now = DateTime.now(), ym = '${now.year}-${now.month.toString().padLeft(2, '0')}'; return Scaffold(appBar: AppBar(title: const Text('Budget mensile'), actions: [IconButton(onPressed: () => showBudget(context, widget.store), icon: const Icon(Icons.add))]), body: ListView(children: widget.store.budgets.map((b) { final used = widget.store.categoryExpense(ym, b.category), pct = b.limit == 0 ? 0.0 : (used / b.limit).clamp(0.0, 1.0).toDouble(); return Card(child: ListTile(title: Text(b.category), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const SizedBox(height: 6), LinearProgressIndicator(value: pct), const SizedBox(height: 4), Text('${money(used)} di ${money(b.limit)}')]), trailing: Icon(used <= b.limit ? Icons.check_circle : Icons.warning, color: used <= b.limit ? Colors.green : Colors.red))); }).toList()); }
}

class Reports extends StatelessWidget { final FamilyStore store; const Reports({super.key, required this.store}); @override Widget build(BuildContext context) { final now = DateTime.now(); return Scaffold(appBar: AppBar(title: const Text('Report')), body: ListView(padding: const EdgeInsets.all(12), children: [for (int i = 0; i < 6; i++) ...reportMonth(store, DateTime(now.year, now.month - i, 1))])); } }
List<Widget> reportMonth(FamilyStore s, DateTime d) { final ym = '${d.year}-${d.month.toString().padLeft(2, '0')}', i = s.income(ym), e = s.expense(ym); return [Card(child: ListTile(title: Text(monthLabel(d)), subtitle: Text('Entrate ${money(i)} • Spese ${money(e)}'), trailing: Text(money(i - e), style: TextStyle(color: i >= e ? Colors.green : Colors.red, fontWeight: FontWeight.bold))))]; }

class MorePage extends StatelessWidget { final FamilyStore store; const MorePage({super.key, required this.store}); @override Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Altro')), body: ListView(children: [ListTile(leading: const Icon(Icons.account_balance), title: const Text('Conti'), subtitle: Text(store.accounts.join(' • ')), onTap: () => showAccounts(context, store)), ListTile(leading: const Icon(Icons.sync), title: const Text('Sincronizzazione banca'), subtitle: const Text('Open Banking predisposto • importazione CSV disponibile'), onTap: () => showBank(context, store)), ListTile(leading: const Icon(Icons.backup), title: const Text('Backup'), subtitle: const Text('Esporta i dati dell’app in formato JSON'), onTap: () => showBackup(context, store)), ListTile(leading: const Icon(Icons.category), title: const Text('Categorie'), subtitle: Text('${store.categories.length} categorie disponibili')), ListTile(leading: const Icon(Icons.settings), title: const Text('Impostazioni'), onTap: () => showAbout(context))])); }

Future<void> showTxn(BuildContext context, FamilyStore store, {Txn? existing}) async {
  final desc = TextEditingController(text: existing?.description ?? '');
  final amount = TextEditingController(text: existing == null ? '' : existing.amount.toStringAsFixed(2));
  final note = TextEditingController(text: existing?.note ?? '');
  final dateController = TextEditingController(text: existing?.date ?? today());
  bool income = existing?.income ?? false;
  String cat = existing?.category ?? store.categories.first;
  String account = existing?.account ?? 'Banca';
  await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(title: Text(existing == null ? 'Nuovo movimento' : 'Modifica movimento'), content: SizedBox(width: 420, child: SingleChildScrollView(child: Column(children: [
    TextField(controller: desc, decoration: const InputDecoration(labelText: 'Descrizione')), const SizedBox(height: 10),
    TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Importo (€)')), const SizedBox(height: 10),
    SwitchListTile(value: income, onChanged: (v) => set(() => income = v), title: const Text('È un’entrata')),
    DropdownButtonFormField<String>(initialValue: cat, decoration: const InputDecoration(labelText: 'Categoria'), items: store.categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) set(() => cat = v); }), const SizedBox(height: 10),
    DropdownButtonFormField<String>(initialValue: account, decoration: const InputDecoration(labelText: 'Conto'), items: store.accounts.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(), onChanged: (v) { if (v != null) set(() => account = v); }), const SizedBox(height: 10),
    TextField(controller: dateController, decoration: const InputDecoration(labelText: 'Data (AAAA-MM-GG)')), const SizedBox(height: 10), TextField(controller: note, decoration: const InputDecoration(labelText: 'Nota')),
  ]))), actions: [if (existing != null) TextButton(onPressed: () { store.remove(existing); Navigator.pop(ctx); }, child: const Text('Elimina', style: TextStyle(color: Colors.red))), TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')), FilledButton(onPressed: () { final v = double.tryParse(amount.text.replaceAll(',', '.')); if (desc.text.trim().isEmpty || v == null || v <= 0) return; if (existing != null) { existing.description = desc.text.trim(); existing.amount = v; existing.income = income; existing.category = cat; existing.account = account; existing.date = dateController.text.trim(); existing.note = note.text; store.save(); } else { store.add(Txn(id: DateTime.now().microsecondsSinceEpoch.toString(), date: dateController.text.trim(), description: desc.text.trim(), amount: v, income: income, category: cat, account: account, note: note.text)); } Navigator.pop(ctx); }, child: const Text('Salva'))]));
}

Future<void> showBudget(BuildContext context, FamilyStore s) async { final amount = TextEditingController(); String c = s.categories.first; await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(title: const Text('Nuovo budget'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(initialValue: c, items: s.categories.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) set(() => c = v); }, decoration: const InputDecoration(labelText: 'Categoria')), const SizedBox(height: 10), TextField(controller: amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Limite mensile (€)'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')), FilledButton(onPressed: () { final v = double.tryParse(amount.text.replaceAll(',', '.')); if (v == null || v <= 0) return; s.budgets.removeWhere((b) => b.category == c); s.budgets.add(Budget(c, v)); s.save(); Navigator.pop(ctx); }, child: const Text('Salva'))]))); }

Future<void> showRecurring(BuildContext context, FamilyStore s) async { final n = TextEditingController(), a = TextEditingController(), dayController = TextEditingController(text: '1'); String c = s.categories.first; await showDialog<void>(context: context, builder: (ctx) => StatefulBuilder(builder: (ctx, set) => AlertDialog(title: const Text('Spesa ricorrente'), content: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: n, decoration: const InputDecoration(labelText: 'Nome')), const SizedBox(height: 8), TextField(controller: a, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Importo')), const SizedBox(height: 8), DropdownButtonFormField<String>(initialValue: c, items: s.categories.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) { if (v != null) set(() => c = v); }, decoration: const InputDecoration(labelText: 'Categoria')), const SizedBox(height: 8), TextField(controller: dayController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Giorno del mese'))]), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annulla')), FilledButton(onPressed: () { final v = double.tryParse(a.text.replaceAll(',', '.')); final day = int.tryParse(dayController.text) ?? 1; if (n.text.trim().isEmpty || v == null || v <= 0) return; s.recurring.add(Recurring(n.text.trim(), v, c, day.clamp(1, 31).toInt())); s.save(); Navigator.pop(ctx); }, child: const Text('Salva'))]))); }

Future<void> showAccounts(BuildContext context, FamilyStore s) async => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Conti'), content: Column(mainAxisSize: MainAxisSize.min, children: s.accounts.map((a) => ListTile(leading: Icon(a == 'Contanti' ? Icons.payments : Icons.account_balance), title: Text(a))).toList()), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi'))]));
Future<void> showBank(BuildContext context, FamilyStore s) async => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Sincronizzazione banca'), content: const Text('La prima versione è predisposta per Open Banking e per l’importazione dei movimenti. Il collegamento diretto richiede un provider Open Banking e l’autorizzazione della banca. Per sicurezza l’app non memorizza password o PIN bancari.\n\nIn questa versione puoi continuare a registrare i movimenti manualmente; la sincronizzazione automatica sarà collegata a un provider nella fase successiva.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi'))]));
Future<void> showBackup(BuildContext context, FamilyStore s) async { final data = jsonEncode({'version': 1, 'exportedAt': DateTime.now().toIso8601String(), 'transactions': s.txns.map((e) => e.toJson()).toList(), 'budgets': s.budgets.map((e) => e.toJson()).toList(), 'recurring': s.recurring.map((e) => e.toJson()).toList()}); await showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Backup JSON'), content: SizedBox(width: 500, height: 300, child: SingleChildScrollView(child: SelectableText(data))), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Chiudi'))])); }
Future<void> showAbout(BuildContext context) async => showDialog<void>(context: context, builder: (ctx) => AlertDialog(title: const Text('Gestione Familiare'), content: const Text('Versione 1.0.1\nBilancio familiare, budget, bollette, contanti e conti bancari.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))]));
