import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('it_IT');
  final store = FinanceStore();
  await store.load();
  runApp(FamilyFinanceApp(store: store));
}

class Movement {
  final String id;
  final DateTime date;
  final String description;
  final double amount;
  final bool income;
  final String category;
  final String account;

  Movement({
    required this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.income,
    required this.category,
    required this.account,
  });

  Map<String, dynamic> toJson() => {
    'id': id, 'date': date.toIso8601String(), 'description': description,
    'amount': amount, 'income': income, 'category': category, 'account': account,
  };

  factory Movement.fromJson(Map<String, dynamic> j) => Movement(
    id: j['id'],
    date: DateTime.parse(j['date']),
    description: j['description'],
    amount: (j['amount'] as num).toDouble(),
    income: j['income'],
    category: j['category'],
    account: j['account'] ?? 'Conto corrente',
  );
}

class FinanceStore extends ChangeNotifier {
  final List<Movement> movements = [];
  final List<String> categories = [
    'Stipendio','Extra','Alimentari','Casa','Bollette','Trasporti',
    'Salute','Abbigliamento','Scuola','Svago','Vacanze','Altro'
  ];
  final List<String> accounts = ['Conto corrente','Carta','Contanti','Altro'];
  DateTime selectedMonth = DateTime(DateTime.now().year, DateTime.now().month);

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('movements');
    if (raw != null) {
      movements.addAll((jsonDecode(raw) as List).map((e) => Movement.fromJson(e)));
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('movements', jsonEncode(movements.map((e) => e.toJson()).toList()));
    notifyListeners();
  }

  List<Movement> get monthMovements => movements.where((m) =>
    m.date.year == selectedMonth.year && m.date.month == selectedMonth.month).toList()
    ..sort((a,b) => b.date.compareTo(a.date));

  double get income => monthMovements.where((m)=>m.income).fold(0, (s,m)=>s+m.amount);
  double get expense => monthMovements.where((m)=>!m.income).fold(0, (s,m)=>s+m.amount);
  double get balance => income-expense;

  void refresh() => notifyListeners();

  Future<void> addMovement(Movement m) async {
    movements.add(m);
    await save();
  }

  Future<void> deleteMovement(String id) async {
    movements.removeWhere((m)=>m.id==id);
    await save();
  }
}

class FamilyFinanceApp extends StatelessWidget {
  final FinanceStore store;
  const FamilyFinanceApp({super.key, required this.store});

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: store,
    builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Contabilità Familiare',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF5267B8)),
        scaffoldBackgroundColor: const Color(0xFFF6F7FB),
        cardTheme: const CardThemeData(
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
        ),
      ),
      home: HomePage(store: store),
    ),
  );
}

class HomePage extends StatefulWidget {
  final FinanceStore store;
  const HomePage({super.key, required this.store});
  @override State<HomePage> createState()=>_HomePageState();
}

class _HomePageState extends State<HomePage> {
  int index=0;
  @override
  Widget build(BuildContext context) {
    final pages=[
      Dashboard(store: widget.store),
      MovementsPage(store: widget.store),
      ReportPage(store: widget.store),
      const MorePage(),
    ];
    return Scaffold(
      body: SafeArea(child: pages[index]),
      floatingActionButton: index==1 ? FloatingActionButton.extended(
        onPressed: ()=>showAddMovement(context, widget.store),
        icon: const Icon(Icons.add), label: const Text('Movimento'),
      ):null,
      bottomNavigationBar: NavigationBar(
        selectedIndex:index,
        onDestinationSelected:(v)=>setState(()=>index=v),
        destinations: const [
          NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
          NavigationDestination(icon:Icon(Icons.swap_vert),label:'Movimenti'),
          NavigationDestination(icon:Icon(Icons.bar_chart_outlined),label:'Resoconto'),
          NavigationDestination(icon:Icon(Icons.more_horiz),label:'Altro'),
        ],
      ),
    );
  }
}

String italianMonthYear(DateTime date) {
  const months = [
    'gennaio', 'febbraio', 'marzo', 'aprile', 'maggio', 'giugno',
    'luglio', 'agosto', 'settembre', 'ottobre', 'novembre', 'dicembre',
  ];
  return '${months[date.month - 1]} ${date.year}';
}

class Dashboard extends StatelessWidget {
  final FinanceStore store;
  const Dashboard({super.key,required this.store});

  @override
  Widget build(BuildContext context) {
    final fmt=NumberFormat.currency(locale:'it_IT',symbol:'€ ');
    final month=italianMonthYear(store.selectedMonth);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20,20,20,90),
      children:[
        Row(children:[
          Expanded(child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            const Text('La mia famiglia',style:TextStyle(fontSize:15,color:Colors.black54)),
            Text(month[0].toUpperCase()+month.substring(1),style:const TextStyle(fontSize:27,fontWeight:FontWeight.w800)),
          ])),
          IconButton(onPressed:()=>_pickMonth(context),icon:const Icon(Icons.calendar_month_outlined))
        ]),
        const SizedBox(height:18),
        Card(
          color: const Color(0xFF5267B8),
          child: Padding(padding:const EdgeInsets.all(22),child:Column(
            crossAxisAlignment:CrossAxisAlignment.start,children:[
              const Text('Disponibilità del mese',style:TextStyle(color:Colors.white70)),
              const SizedBox(height:5),
              Text(fmt.format(store.balance),style:const TextStyle(color:Colors.white,fontSize:34,fontWeight:FontWeight.w800)),
              const SizedBox(height:20),
              Row(children:[
                Expanded(child:_mini('Entrate',fmt.format(store.income),Icons.arrow_downward)),
                Expanded(child:_mini('Spese',fmt.format(store.expense),Icons.arrow_upward)),
              ])
            ]))
        ),
        const SizedBox(height:18),
        Row(children:[
          Expanded(child:_action(context,'Entrata',Icons.add_circle_outline, true)),
          const SizedBox(width:12),
          Expanded(child:_action(context,'Spesa',Icons.remove_circle_outline, false)),
        ]),
        const SizedBox(height:22),
        const Text('Ultimi movimenti',style:TextStyle(fontSize:20,fontWeight:FontWeight.w800)),
        const SizedBox(height:10),
        if(store.monthMovements.isEmpty)
          _empty()
        else
          ...store.monthMovements.take(5).map((m)=>MovementTile(m:m,store:store)),
      ],
    );
  }

  Widget _mini(String t,String v,IconData i)=>Row(children:[
    Icon(i,color:Colors.white70,size:18),const SizedBox(width:7),
    Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(t,style:const TextStyle(color:Colors.white70,fontSize:12)),
      Text(v,style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700))
    ])
  ]);

  Widget _action(BuildContext c,String t,IconData i,bool income)=>OutlinedButton.icon(
    onPressed:()=>showAddMovement(c,store,income:income),icon:Icon(i),label:Text(t),
    style:OutlinedButton.styleFrom(padding:const EdgeInsets.symmetric(vertical:16))
  );

  Widget _empty()=>const Card(child:Padding(padding:EdgeInsets.all(25),child:Center(child:Text('Nessun movimento questo mese.'))));

  void _pickMonth(BuildContext context) async {
    final d=await showDatePicker(context:context,initialDate:store.selectedMonth,firstDate:DateTime(2020),lastDate:DateTime(2100));
    if(d!=null){store.selectedMonth=DateTime(d.year,d.month);store.refresh();}
  }
}

class MovementsPage extends StatelessWidget {
  final FinanceStore store;
  const MovementsPage({super.key,required this.store});
  @override Widget build(BuildContext context)=>ListView(
    padding:const EdgeInsets.fromLTRB(20,20,20,100),
    children:[
      const Text('Movimenti',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),
      const SizedBox(height:6),
      Text(italianMonthYear(store.selectedMonth),style:const TextStyle(color:Colors.black54)),
      const SizedBox(height:16),
      ...store.monthMovements.map((m)=>Dismissible(
        key:ValueKey(m.id),background:Container(decoration:BoxDecoration(color:Colors.redAccent,borderRadius:BorderRadius.circular(18)),alignment:Alignment.centerLeft,padding:const EdgeInsets.only(left:20),child:const Icon(Icons.delete,color:Colors.white)),
        direction:DismissDirection.endToStart,
        onDismissed:(_)=>store.deleteMovement(m.id),
        child:MovementTile(m:m,store:store)
      )),
      if(store.monthMovements.isEmpty)_empty(),
    ]
  );
  Widget _empty()=>const Card(child:Padding(padding:EdgeInsets.all(28),child:Center(child:Text('Nessun movimento registrato.'))));
}

class MovementTile extends StatelessWidget {
  final Movement m; final FinanceStore store;
  const MovementTile({super.key,required this.m,required this.store});
  @override Widget build(BuildContext context){
    final fmt=NumberFormat.currency(locale:'it_IT',symbol:'€ ');
    return Card(margin:const EdgeInsets.only(bottom:9),child:ListTile(
      leading:CircleAvatar(child:Icon(m.income?Icons.south_west:Icons.north_east)),
      title:Text(m.description,style:const TextStyle(fontWeight:FontWeight.w700)),
      subtitle:Text('${m.category} • ${DateFormat('dd/MM').format(m.date)} • ${m.account}'),
      trailing:Text('${m.income?'+':'-'}${fmt.format(m.amount)}',style:TextStyle(fontWeight:FontWeight.w800,color:m.income?Colors.green.shade700:Colors.red.shade700)),
    ));
  }
}

class ReportPage extends StatelessWidget {
  final FinanceStore store;
  const ReportPage({super.key,required this.store});

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat.currency(locale:'it_IT',symbol:'€ ');
    final data = <String,double>{};
    for (final m in store.monthMovements) {
      if (!m.income) data[m.category] = (data[m.category] ?? 0) + m.amount;
    }
    final sorted = data.entries.toList()
      ..sort((a,b) => b.value.compareTo(a.value));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('Resoconto',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),
        const SizedBox(height:6),
        Text(italianMonthYear(store.selectedMonth)),
        const SizedBox(height:18),
        Row(children:[
          Expanded(child:_summary('Entrate',fmt.format(store.income),Icons.trending_down,Colors.green)),
          const SizedBox(width:10),
          Expanded(child:_summary('Spese',fmt.format(store.expense),Icons.trending_up,Colors.red)),
        ]),
        const SizedBox(height:18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                const Text('Andamento',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
                const SizedBox(height:20),
                SizedBox(
                  height:210,
                  child: BarChart(
                    BarChartData(
                      borderData: FlBorderData(show:false),
                      gridData: const FlGridData(show:false),
                      titlesData: FlTitlesData(
                        rightTitles: const AxisTitles(sideTitles:SideTitles(showTitles:false)),
                        topTitles: const AxisTitles(sideTitles:SideTitles(showTitles:false)),
                        leftTitles: const AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:42)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles:true,
                            getTitlesWidget:(v,meta) => Padding(
                              padding: const EdgeInsets.only(top:8),
                              child: Text(v == 0 ? 'Entrate' : 'Spese'),
                            ),
                          ),
                        ),
                      ),
                      barGroups:[
                        BarChartGroupData(x:0,barRods:[BarChartRodData(toY:store.income,width:35,borderRadius:BorderRadius.circular(5))]),
                        BarChartGroupData(x:1,barRods:[BarChartRodData(toY:store.expense,width:35,borderRadius:BorderRadius.circular(5))]),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height:18),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children:[
                const Text('Spese per categoria',style:TextStyle(fontSize:19,fontWeight:FontWeight.w800)),
                const SizedBox(height:12),
                if (sorted.isEmpty)
                  const Text('Nessuna spesa nel mese.')
                else
                  ...sorted.take(8).map((e)=>Padding(
                    padding: const EdgeInsets.symmetric(vertical:6),
                    child: Row(children:[
                      Expanded(child:Text(e.key)),
                      Text(fmt.format(e.value),style:const TextStyle(fontWeight:FontWeight.w700)),
                    ]),
                  )),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summary(String t,String v,IconData i,Color c) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment:CrossAxisAlignment.start,
        children:[
          Icon(i,color:c),
          const SizedBox(height:8),
          Text(t,style:const TextStyle(color:Colors.black54)),
          Text(v,style:const TextStyle(fontSize:18,fontWeight:FontWeight.w800)),
        ],
      ),
    ),
  );
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});
  @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(20),children:[
    const Text('Altro',style:TextStyle(fontSize:28,fontWeight:FontWeight.w800)),
    const SizedBox(height:18),
    const Card(child:Column(children:[
      ListTile(leading:Icon(Icons.category_outlined),title:Text('Categorie'),subtitle:Text('Personalizza le categorie')),
      Divider(height:1),
      ListTile(leading:Icon(Icons.account_balance_outlined),title:Text('Conti e carte'),subtitle:Text('Gestisci dove si trovano i soldi')),
      Divider(height:1),
      ListTile(leading:Icon(Icons.repeat),title:Text('Movimenti ricorrenti'),subtitle:Text('Prepara le spese mensili')),
      Divider(height:1),
      ListTile(leading:Icon(Icons.savings_outlined),title:Text('Budget'),subtitle:Text('Imposta limiti di spesa')),
      Divider(height:1),
      ListTile(leading:Icon(Icons.backup_outlined),title:Text('Backup e ripristino'),subtitle:Text('Funzione prevista nella prossima versione')),
    ]))
  ]);
}

Future<void> showAddMovement(BuildContext context, FinanceStore store,{bool? income}) async {
  final desc=TextEditingController();
  final amount=TextEditingController();
  bool isIncome=income??false;
  String category=store.categories.first;
  String account=store.accounts.first;
  await showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,builder:(ctx)=>StatefulBuilder(builder:(ctx,setState)=>Padding(
    padding:EdgeInsets.only(left:20,right:20,bottom:MediaQuery.of(ctx).viewInsets.bottom+20,top:5),
    child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text(isIncome?'Nuova entrata':'Nuova spesa',style:const TextStyle(fontSize:25,fontWeight:FontWeight.w800)),
      const SizedBox(height:15),
      SegmentedButton<bool>(segments:const [ButtonSegment(value:false,label:Text('Spesa'),icon:Icon(Icons.remove)),ButtonSegment(value:true,label:Text('Entrata'),icon:Icon(Icons.add))],selected:{isIncome},onSelectionChanged:(s)=>setState(()=>isIncome=s.first)),
      const SizedBox(height:12),
      TextField(controller:desc,decoration:const InputDecoration(labelText:'Descrizione',prefixIcon:Icon(Icons.edit_outlined))),
      const SizedBox(height:10),
      TextField(controller:amount,keyboardType:const TextInputType.numberWithOptions(decimal:true),decoration:const InputDecoration(labelText:'Importo',prefixIcon:Icon(Icons.euro))),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(initialValue:category,decoration:const InputDecoration(labelText:'Categoria'),items:store.categories.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>category=v!)),
      const SizedBox(height:10),
      DropdownButtonFormField<String>(initialValue:account,decoration:const InputDecoration(labelText:'Conto / carta'),items:store.accounts.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),onChanged:(v)=>setState(()=>account=v!)),
      const SizedBox(height:18),
      SizedBox(width:double.infinity,child:FilledButton.icon(
        onPressed:() async {
          final value=double.tryParse(amount.text.replaceAll(',','.'));
          if(desc.text.trim().isEmpty||value==null||value<=0)return;
          await store.addMovement(Movement(id:DateTime.now().microsecondsSinceEpoch.toString(),date:DateTime.now(),description:desc.text.trim(),amount:value,income:isIncome,category:category,account:account));
          if(ctx.mounted)Navigator.pop(ctx);
        },icon:const Icon(Icons.check),label:const Padding(padding:EdgeInsets.symmetric(vertical:14),child:Text('Salva movimento'))
      ))
    ]))
  )));
}
