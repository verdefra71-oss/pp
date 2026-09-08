
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const CertificazioniApp());

class CertificazioniApp extends StatelessWidget {
  const CertificazioniApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Certificazioni Elettriche',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFB08D2C)),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF8F8F8),
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Map<String, dynamic>> docs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('documents') ?? [];
    setState(() {
      docs = raw.map((e) => Map<String, dynamic>.from(jsonDecode(e))).toList();
    });
  }

  Future<void> _company() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString('company_profile');
    final initial = raw == null ? <String,dynamic>{} : Map<String,dynamic>.from(jsonDecode(raw));
    final result = await Navigator.push<Map<String,dynamic>>(context, MaterialPageRoute(
      builder: (_) => SimpleProfilePage(title: 'Dati impresa', fields: const [
        'Impresa','Sede / indirizzo','Partita IVA','CCIAA','REA','PEC','Responsabile tecnico','Abilitazione / requisiti'
      ], initial: initial),
    ));
    if (result != null) await p.setString('company_profile', jsonEncode(result));
  }

  Future<void> _clients() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getStringList('clients') ?? [];
    final result = await Navigator.push<List<Map<String,dynamic>>>(context, MaterialPageRoute(
      builder: (_) => ClientsPage(items: raw.map((e)=>Map<String,dynamic>.from(jsonDecode(e))).toList()),
    ));
    if (result != null) await p.setStringList('clients', result.map(jsonEncode).toList());
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final p = await SharedPreferences.getInstance();
    final list = p.getStringList('documents') ?? [];
    list.add(jsonEncode(data));
    await p.setStringList('documents', list);
    await _load();
  }

  Future<void> _newDoc(String type) async {
    final p = await SharedPreferences.getInstance();
    final rawCompany = p.getString('company_profile');
    final company = rawCompany == null ? <String,dynamic>{} : Map<String,dynamic>.from(jsonDecode(rawCompany));
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(builder: (_) => WizardPage(type: type, company: company)),
    );
    if (result != null) {
      await _save(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Certificazioni Elettriche',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _heroCard(),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _action('Nuova Di.Co.', Icons.verified_outlined, () => _newDoc('Di.Co.'))),
            const SizedBox(width: 12),
            Expanded(child: _action('Nuova Di.Ri.', Icons.fact_check_outlined, () => _newDoc('Di.Ri.'))),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: _action('Dati impresa', Icons.business_outlined, _company)),
            const SizedBox(width: 12),
            Expanded(child: _action('Clienti', Icons.people_outline, _clients)),
          ]),
          const SizedBox(height: 12),
          _sectionTitle('Archivio'),
          if (docs.isEmpty)
            const Card(child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('Nessuna certificazione salvata.'),
            ))
          else
            ...docs.reversed.map((d) => Card(
              child: ListTile(
                leading: const Icon(Icons.description_outlined),
                title: Text('${d['type']} • ${d['numero'] ?? ''}'),
                subtitle: Text('${d['committente'] ?? ''}\n${d['indirizzo'] ?? ''}'),
                isThreeLine: true,
                trailing: PopupMenuButton<String>(
                  onSelected: (v) async {
                    if (v == 'pdf') await PdfGenerator.generateAndShare(d);
                    if (v == 'edit') {
                      final edited = await Navigator.push<Map<String,dynamic>>(context,
                        MaterialPageRoute(builder: (_) => WizardPage(type: d['type'] ?? 'Di.Co.', initial: d)));
                      if (edited != null) {
                        final p = await SharedPreferences.getInstance();
                        final raw = p.getStringList('documents') ?? [];
                        final idx = raw.indexWhere((x) => Map<String,dynamic>.from(jsonDecode(x))['numero'] == d['numero']);
                        if (idx >= 0) { raw[idx] = jsonEncode(edited); await p.setStringList('documents', raw); await _load(); }
                      }
                    }
                  },
                  itemBuilder: (_) => const [
                    PopupMenuItem(value:'pdf',child:Text('Genera PDF')),
                    PopupMenuItem(value:'edit',child:Text('Modifica')),
                  ],
                ),
              ),
            )),
          const SizedBox(height: 16),
          _infoCard(),
        ],
      ),
    );
  }

  Widget _heroCard() => Card(
    elevation: 0,
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
        Text('Documentazione impianti elettrici',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        SizedBox(height: 8),
        Text('Compilazione guidata della Di.Co. e della Di.Ri., con PDF strutturato secondo il modello ministeriale di riferimento.'),
      ]),
    ),
  );

  Widget _action(String title, IconData icon, VoidCallback onTap) => Card(
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 22, horizontal: 12),
        child: Column(children: [
          Icon(icon, size: 32),
          const SizedBox(height: 8),
          Text(title, textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ]),
      ),
    ),
  );

  Widget _sectionTitle(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
  );

  Widget _infoCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: const Text(
        'Nota: il PDF generato è un modello digitale di compilazione e deve essere verificato dal professionista/impresa abilitata prima dell’uso. La responsabilità della dichiarazione resta in capo ai soggetti previsti dalla normativa.',
      ),
    ),
  );
}


class SignaturePad extends StatefulWidget {
  final String title;
  final void Function(Uint8List?) onSaved;
  const SignaturePad({super.key, required this.title, required this.onSaved});
  @override State<SignaturePad> createState()=>_SignaturePadState();
}
class _SignaturePadState extends State<SignaturePad> {
  final List<Offset?> points=[];
  @override Widget build(BuildContext context)=>Column(
    crossAxisAlignment:CrossAxisAlignment.start,
    children:[
      Text(widget.title,style:const TextStyle(fontWeight:FontWeight.w700)),
      const SizedBox(height:6),
      Container(
        height:150,
        decoration:BoxDecoration(border:Border.all(color:Colors.grey),borderRadius:BorderRadius.circular(8),color:Colors.white),
        child:GestureDetector(
          onPanUpdate:(d)=>setState(()=>points.add(d.localPosition)),
          onPanEnd:(_)=>setState(()=>points.add(null)),
          child:CustomPaint(painter:_SigPainter(points),size:Size.infinite),
        ),
      ),
      Row(children:[
        TextButton(onPressed:()=>setState(()=>points.clear()),child:const Text('Cancella')),
        const Spacer(),
        FilledButton(onPressed:() async {
          final recorder=PictureRecorder();
          final canvas=Canvas(recorder);
          canvas.drawRect(const Rect.fromLTWH(0,0,700,180),Paint()..color=Colors.white);
          final p=Paint()..color=Colors.black..strokeWidth=2.2..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;
          for(int i=0;i<points.length-1;i++){
            final a=points[i],b=points[i+1];
            if(a!=null&&b!=null)canvas.drawLine(a,b,p);
          }
          final img=await recorder.endRecording().toImage(700,180);
          final data=await img.toByteData(format:ImageByteFormat.png);
          widget.onSaved(data?.buffer.asUint8List());
        },child:const Text('Usa firma'))
      ])
    ]);
}
class _SigPainter extends CustomPainter {
  final List<Offset?> points;
  _SigPainter(this.points);
  @override void paint(Canvas c,Size s){
    final p=Paint()..color=Colors.black..strokeWidth=2.2..strokeCap=StrokeCap.round;
    for(int i=0;i<points.length-1;i++){final a=points[i],b=points[i+1];if(a!=null&&b!=null)c.drawLine(a,b,p);}
  }
  @override bool shouldRepaint(covariant _SigPainter old)=>true;
}

class WizardPage extends StatefulWidget {
  final String type;
  final Map<String,dynamic>? initial;
  final Map<String,dynamic>? company;
  const WizardPage({super.key, required this.type, this.initial, this.company});
  @override
  State<WizardPage> createState() => _WizardPageState();
}

class _WizardPageState extends State<WizardPage> {
  final formKey = GlobalKey<FormState>();
  int step = 0;
  final Map<String, TextEditingController> c = {};
  final Map<String, bool> checks = {};
  List<String> files = [];
  Uint8List? firmaTecnico;
  Uint8List? firmaCommittente;

  final steps = const [
    'Impresa',
    'Committente',
    'Impianto',
    'Intervento',
    'Progetto',
    'Norme',
    'Materiali',
    'Verifiche',
    'Allegati',
    'Firme',
    'Controllo'
  ];

  @override
  void initState() {
    super.initState();
    for (final key in [
      'impresa','sede_impresa','piva','cciaa','rea','pec','responsabile','abilitazione','settore',
      'committente','proprietario','cf','indirizzo','comune','destinazione',
      'potenza','tensione','descrizione','intervento','data_inizio','data_fine',
      'progettista','progetto_rif','norme','materiali','verifiche','precedente',
      'note','firma_tecnico','firma_committente'
    ]) {
      c[key] = TextEditingController();
    }
    final merged = <String,dynamic>{...?widget.company, ...?widget.initial};
    for (final e in merged.entries) {
      if (c.containsKey(e.key)) c[e.key]!.text = (e.value ?? '').toString();
    }
    if (widget.initial?['checks'] is Map) {
      checks.addAll(Map<String,dynamic>.from(widget.initial!['checks']));
    }
    if (widget.initial?['files'] is List) files = List<String>.from(widget.initial!['files']);
    if (widget.initial?['firma_tecnico_png'] != null) firmaTecnico = base64Decode(widget.initial!['firma_tecnico_png']);
    if (widget.initial?['firma_committente_png'] != null) firmaCommittente = base64Decode(widget.initial!['firma_committente_png']);
    for (final key in [
      'nuovo','trasformazione','ampliamento','manutenzione_straordinaria',
      'parziale','progetto_allegato','schema_allegato','materiali_allegato',
      'visura_allegata','dico_precedente','diRi','verifiche_ok','consegnata_documentazione'
    ]) {
      checks[key] = false;
    }
  }

  @override
  void dispose() {
    for (final x in c.values) x.dispose();
    super.dispose();
  }

  String v(String key) => c[key]!.text.trim();

  Future<void> pickFiles() async {
    final r = await FilePicker.platform.pickFiles(allowMultiple: true);
    if (r != null) {
      setState(() => files = r.files.map((e) => e.name).toList());
    }
  }

  bool _requiredProject() {
    final p = double.tryParse(v('potenza').replaceAll(',', '.')) ?? 0;
    final d = v('destinazione').toLowerCase();
    return p > 6 || d.contains('condominio') || d.contains('medic') || d.contains('esplos');
  }

  List<String> _projectFlags() {
    final flags = <String>[];
    final p = double.tryParse(v('potenza').replaceAll(',', '.')) ?? 0;
    final d = v('destinazione').toLowerCase();
    if (p > 6) flags.add('Potenza indicata superiore a 6 kW');
    if (d.contains('condominio')) flags.add('Destinazione/contesto condominiale');
    if (d.contains('medic')) flags.add('Possibile ambiente medico');
    if (d.contains('esplos')) flags.add('Possibile luogo con pericolo di esplosione');
    return flags;
  }

  void next() {
    if (step == steps.length - 1) {
      if (!formKey.currentState!.validate()) return;
      if (!checks['verifiche_ok']!) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confermare l’esito positivo delle verifiche prima di creare il documento.')),
        );
        return;
      }
      if (widget.type == 'Di.Co.' && v('norme').isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Indicare le norme tecniche effettivamente applicate.')),
        );
        return;
      }
      if (_requiredProject() && !checks['progetto_allegato']!) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Possibile caso soggetto a progetto: allegare il progetto o verificare la relativa motivazione tecnica prima di chiudere il documento.')),
        );
        return;
      }
      if (!checks['consegnata_documentazione']!) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Confermare che la documentazione sia stata predisposta per la consegna al committente.')),
        );
        return;
      }
      final now = DateTime.now();
      final data = <String, dynamic>{
        'type': widget.type,
        'numero': widget.initial?['numero'] ?? 'CERT-${DateFormat('yyyy').format(now)}-${now.millisecondsSinceEpoch % 100000}',
        'modello_normativo': 'D.M. 37/2008 – Allegato I / aggiornamenti applicabili',
        'data': DateFormat('dd/MM/yyyy').format(now),
        'files': files,
        'firma_tecnico_png': firmaTecnico == null ? null : base64Encode(firmaTecnico!),
        'firma_committente_png': firmaCommittente == null ? null : base64Encode(firmaCommittente!),
        'checks': checks,
        ...{for (final e in c.entries) e.key: e.value.text.trim()},
      };
      Navigator.pop(context, data);
      return;
    }
    setState(() => step++);
  }

  void back() {
    if (step > 0) setState(() => step--);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nuova ${widget.type}')),
      body: Form(
        key: formKey,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: LinearProgressIndicator(value: (step + 1) / steps.length),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('${step + 1}/${steps.length} • ${steps[step]}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
          Expanded(child: ListView(
            padding: const EdgeInsets.all(16),
            children: [_buildStep()],
          )),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              if (step > 0) Expanded(child: OutlinedButton(onPressed: back, child: const Text('Indietro'))),
              if (step > 0) const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: next, child: Text(step == steps.length - 1 ? 'Salva certificazione' : 'Continua'))),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget field(String key, String label, {bool required = false, int maxLines = 1, TextInputType? keyboard}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c[key],
        maxLines: maxLines,
        keyboardType: keyboard,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: required ? (x) => (x == null || x.trim().isEmpty) ? 'Campo obbligatorio' : null : null,
      ),
    );
  }

  Widget check(String key, String label) => CheckboxListTile(
    value: checks[key] ?? false,
    onChanged: (x) => setState(() => checks[key] = x ?? false),
    title: Text(label),
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
  );

  Widget _buildStep() {
    switch (step) {
      case 0:
        return Column(children: [
          field('impresa','Impresa installatrice',required:true),
          field('sede_impresa','Sede / indirizzo',required:true),
          field('piva','Partita IVA',required:true),
          field('cciaa','CCIAA'),
          field('rea','Numero REA'),
          field('pec','PEC'),
          field('responsabile','Responsabile tecnico',required:true),
          field('abilitazione','Abilitazione / requisiti tecnico-professionali'),
          field('settore','Settore di attività / lettera abilitazione'),
        ]);
      case 1:
        return Column(children: [
          field('committente','Committente',required:true),
          field('proprietario','Proprietario'),
          field('cf','Codice fiscale'),
          field('indirizzo','Ubicazione impianto / indirizzo',required:true),
          field('comune','Comune / CAP / Provincia'),
          field('destinazione','Destinazione d’uso',required:true),
        ]);
      case 2:
        return Column(children: [
          field('potenza','Potenza impegnata/prevista (kW)',required:true,keyboard:TextInputType.number),
          field('tensione','Tensione (V)',required:true),
          field('descrizione','Descrizione dell’impianto',required:true,maxLines:4),
          const SizedBox(height: 6),
          const Align(alignment: Alignment.centerLeft, child: Text('Tipologia intervento / impianto',style:TextStyle(fontWeight:FontWeight.w700))),
          check('nuovo','Nuovo impianto'),
          check('trasformazione','Trasformazione'),
          check('ampliamento','Ampliamento'),
          check('manutenzione_straordinaria','Manutenzione straordinaria'),
          check('parziale','Intervento parziale su impianto esistente'),
        ]);
      case 3:
        return Column(children: [
          field('intervento','Descrizione dettagliata dei lavori eseguiti',required:true,maxLines:6),
          field('data_inizio','Data inizio lavori'),
          field('data_fine','Data fine lavori'),
          field('precedente','Estremi documentazione precedente / impianto esistente',maxLines:3),
          field('note','Note e condizioni particolari',maxLines:4),
        ]);
      case 4:
        final required = _requiredProject();
        return Column(children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(
                  required
                    ? 'ATTENZIONE: sono presenti indicatori che richiedono una verifica specifica dell’obbligo di progetto.'
                    : 'Indicazione preliminare: la necessità del progetto va verificata sulla situazione concreta e sui requisiti dell’art. 5 del D.M. 37/2008.',
                  style:const TextStyle(fontWeight:FontWeight.w700),
                ),
                if (_projectFlags().isNotEmpty) ...[
                  const SizedBox(height:8),
                  ..._projectFlags().map((x)=>Text('• $x',style:const TextStyle(fontSize:12))),
                ],
              ]),
            ),
          ),
          field('progettista','Progettista / professionista'),
          field('progetto_rif','Estremi progetto, elaborati e riferimento',maxLines:4),
          check('progetto_allegato','Progetto/elaborati allegati'),
        ]);
      case 5:
        return Column(children: [
          field('norme','Norme tecniche applicate (CEI/UNI/altre)',required:true,maxLines:6),
          const Text('Indicare le norme effettivamente applicate al caso concreto; non usare un elenco automatico come sostituto della verifica tecnica.', style: TextStyle(fontSize: 12)),
        ]);
      case 6:
        return Column(children: [
          field('materiali','Relazione materiali e componenti impiegati',required:true,maxLines:8),
          check('materiali_allegato','Relazione materiali/componenti allegata'),
          check('schema_allegato','Schema dell’impianto allegato'),
        ]);
      case 7:
        return Column(children: [
          field('verifiche','Verifiche, prove e misure eseguite con esiti',required:true,maxLines:9),
          check('verifiche_ok','Dichiaro che le verifiche/funzionalità hanno avuto esito positivo'),
        ]);
      case 8:
        return Column(children: [
          const Text('Allegati documentali',style:TextStyle(fontWeight:FontWeight.w700,fontSize:16)),
          check('progetto_allegato','Progetto'),
          check('schema_allegato','Schema dell’impianto realizzato'),
          check('materiali_allegato','Relazione tipologica materiali'),
          check('visura_allegata','Visura / documentazione requisiti impresa'),
          check('dico_precedente','Dichiarazione precedente, se esistente'),
          check('consegnata_documentazione','Documentazione predisposta per la consegna al committente'),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed:pickFiles,icon:const Icon(Icons.attach_file),label:const Text('Seleziona allegati')),
          if (files.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...files.map((f)=>ListTile(dense:true,leading:const Icon(Icons.insert_drive_file_outlined),title:Text(f))),
          ],
        ]);
      case 9:
        return Column(children: [
          field('firma_tecnico','Nome e qualifica firmatario impresa',required:true),
          const SizedBox(height:8),
          SignaturePad(title:'Firma impresa / responsabile tecnico',onSaved:(x)=>setState(()=>firmaTecnico=x)),
          const SizedBox(height:18),
          field('firma_committente','Nome committente per presa visione/consegna',required:true),
          const SizedBox(height:8),
          SignaturePad(title:'Firma committente',onSaved:(x)=>setState(()=>firmaCommittente=x)),
        ]);
      default:
        return Column(children: [
          const Card(child:Padding(padding:EdgeInsets.all(14),child:Text('Controllo finale: verificare che tutti i dati siano esatti, che il progetto sia presente quando richiesto e che gli allegati corrispondano al lavoro eseguito.'))),
          _summary('Impresa',v('impresa')),
          _summary('Committente',v('committente')),
          _summary('Impianto',v('indirizzo')),
          _summary('Norme',v('norme')),
          _summary('Verifiche',v('verifiche')),
        ]);
    }
  }

  Widget _summary(String a,String b)=>ListTile(title:Text(a,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text(b.isEmpty?'—':b));
}


class SimpleProfilePage extends StatefulWidget {
  final String title;
  final List<String> fields;
  final Map<String,dynamic> initial;
  const SimpleProfilePage({super.key, required this.title, required this.fields, required this.initial});
  @override State<SimpleProfilePage> createState()=>_SimpleProfilePageState();
}
class _SimpleProfilePageState extends State<SimpleProfilePage> {
  final Map<String,TextEditingController> c={};
  @override void initState(){super.initState(); for(final f in widget.fields)c[f]=TextEditingController(text:(widget.initial[f]??'').toString());}
  @override void dispose(){for(final x in c.values)x.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:Text(widget.title)),
    body:ListView(padding:const EdgeInsets.all(16),children:[
      ...widget.fields.map((f)=>Padding(padding:const EdgeInsets.only(bottom:12),child:TextField(controller:c[f],decoration:InputDecoration(labelText:f,border:const OutlineInputBorder())))),
      FilledButton(onPressed:()=>Navigator.pop(context,{for(final e in c.entries)e.key:e.value.text.trim()}),child:const Text('Salva'))
    ]));
}

class ClientsPage extends StatefulWidget {
  final List<Map<String,dynamic>> items;
  const ClientsPage({super.key,required this.items});
  @override State<ClientsPage> createState()=>_ClientsPageState();
}
class _ClientsPageState extends State<ClientsPage>{
  late List<Map<String,dynamic>> items;
  @override void initState(){super.initState();items=[...widget.items];}
  Future<void> add() async {
    final r=await Navigator.push<Map<String,dynamic>>(context,MaterialPageRoute(builder:(_)=>const SimpleProfilePage(
      title:'Nuovo cliente',fields:['Nome / Ragione sociale','Codice fiscale / P.IVA','Indirizzo','Comune','Email','Telefono'],initial:{})));
    if(r!=null)setState(()=>items.add(r));
  }
  @override Widget build(BuildContext context)=>Scaffold(
    appBar:AppBar(title:const Text('Clienti')),
    floatingActionButton:FloatingActionButton(onPressed:add,child:const Icon(Icons.add)),
    body:items.isEmpty?const Center(child:Text('Nessun cliente')):ListView.builder(
      padding:const EdgeInsets.all(12),itemCount:items.length,itemBuilder:(_,i)=>Card(child:ListTile(
        title:Text(items[i]['Nome / Ragione sociale']??''),subtitle:Text('${items[i]['Indirizzo']??''} • ${items[i]['Comune']??''}'),
        trailing:IconButton(icon:const Icon(Icons.delete_outline),onPressed:()=>setState(()=>items.removeAt(i))),
      )))
  );
}

class PdfGenerator {
  static String _s(Map<String, dynamic> d, String key) => (d[key] ?? '').toString();

  static Map<String, dynamic> _checks(Map<String, dynamic> d) =>
      d['checks'] is Map ? Map<String, dynamic>.from(d['checks']) : <String, dynamic>{};

  static pw.Widget _field(String label, dynamic value, {double minHeight = 28}) => pw.Container(
        constraints: pw.BoxConstraints(minHeight: minHeight),
        padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: .6)),
        child: pw.RichText(text: pw.TextSpan(children: [
          pw.TextSpan(text: '$label\n', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
          pw.TextSpan(text: (value ?? '').toString(), style: const pw.TextStyle(fontSize: 8.5)),
        ])),
      );

  static pw.Widget _cell(String text, {bool bold = false, double size = 8}) =>
      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(text, style: pw.TextStyle(fontSize: size, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)));

  static pw.Widget _check(bool value, String label) => pw.Row(children: [
        pw.Container(width: 12, height: 12, decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: .7)), child: value ? pw.Center(child: pw.Text('X', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))) : null),
        pw.SizedBox(width: 4),
        pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 7.8))),
      ]);

  static pw.Widget _line(String label, dynamic value) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 4),
        child: pw.RichText(text: pw.TextSpan(children: [
          pw.TextSpan(text: '$label ', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
          pw.TextSpan(text: (value ?? '').toString(), style: const pw.TextStyle(fontSize: 8)),
        ])),
      );

  static pw.Widget _title(String text) => pw.Container(
        width: double.infinity,
        padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 6),
        decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: .8)),
        child: pw.Text(text, textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _section(String text) => pw.Container(
        width: double.infinity,
        margin: const pw.EdgeInsets.only(top: 7, bottom: 4),
        padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 5),
        color: PdfColors.grey200,
        child: pw.Text(text, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
      );

  static pw.Widget _footer(int page) => pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text('Allegato I – D.M. 22 gennaio 2008, n. 37', style: const pw.TextStyle(fontSize: 7)),
          pw.Text('Pagina $page', style: const pw.TextStyle(fontSize: 7)),
        ],
      );

  static Future<void> generateAndShare(Map<String, dynamic> d) async {
    final doc = pw.Document();
    final c = _checks(d);
    final isDiRi = _s(d, 'type') == 'Di.Ri.';
    final firmaTecnico = d['firma_tecnico_png'] is String && (d['firma_tecnico_png'] as String).isNotEmpty
        ? pw.MemoryImage(base64Decode(d['firma_tecnico_png'])) : null;
    final firmaCommittente = d['firma_committente_png'] is String && (d['firma_committente_png'] as String).isNotEmpty
        ? pw.MemoryImage(base64Decode(d['firma_committente_png'])) : null;

    final commonHeader = (int page) => pw.Column(children: [
          _title(isDiRi ? 'DICHIARAZIONE DI RISPONDENZA' : 'DICHIARAZIONE DI CONFORMITÀ DELL’IMPIANTO ALLA REGOLA DELL’ARTE'),
          pw.SizedBox(height: 3),
          pw.Align(alignment: pw.Alignment.centerLeft, child: pw.Text('D.M. 22 gennaio 2008, n. 37 – Allegato I', style: const pw.TextStyle(fontSize: 7))),
          pw.SizedBox(height: 4),
        ]);

    // Pagina 1: struttura anagrafica del modello ministeriale.
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        commonHeader(1),
        _line('Il sottoscritto', _s(d, 'responsabile')),
        _line('titolare o legale rappresentante dell’impresa (ragione sociale)', _s(d, 'impresa')),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.black, width: .6), columnWidths: {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)}, children: [
          pw.TableRow(children: [_cell('operante nel settore', bold: true), _cell(_s(d, 'settore'))]),
          pw.TableRow(children: [_cell('con sede in via / piazza', bold: true), _cell(_s(d, 'sede_impresa'))]),
          pw.TableRow(children: [_cell('tel. / PEC', bold: true), _cell('${_s(d, 'pec')}')]),
          pw.TableRow(children: [_cell('partita IVA', bold: true), _cell(_s(d, 'piva'))]),
          pw.TableRow(children: [_cell('iscritta nel Registro delle Imprese – C.C.I.A.A.', bold: true), _cell(_s(d, 'cciaa'))]),
          pw.TableRow(children: [_cell('REA', bold: true), _cell(_s(d, 'rea'))]),
        ]),
        _section('DATI DELL’IMMOBILE E DEL COMMITTENTE'),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.black, width: .6), columnWidths: {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)}, children: [
          pw.TableRow(children: [_field('Committente', _s(d, 'committente')), _field('Proprietario', _s(d, 'proprietario'))]),
          pw.TableRow(children: [_field('Via / piazza – numero civico', _s(d, 'indirizzo')), _field('Comune / provincia', _s(d, 'comune'))]),
          pw.TableRow(children: [_field('Codice fiscale', _s(d, 'cf')), _field('Edificio adibito ad uso', _s(d, 'destinazione'))]),
        ]),
        pw.SizedBox(height: 5),
        pw.Text('in edificio adibito ad uso:', style: const pw.TextStyle(fontSize: 8)),
        pw.SizedBox(height: 3),
        pw.Row(children: [
          pw.Expanded(child: _check(_s(d, 'destinazione').toLowerCase().contains('industr'), 'industriale')),
          pw.Expanded(child: _check(_s(d, 'destinazione').toLowerCase().contains('civil'), 'civile')),
          pw.Expanded(child: _check(_s(d, 'destinazione').toLowerCase().contains('commerc'), 'commercio')),
          pw.Expanded(child: _check(!_s(d, 'destinazione').toLowerCase().contains('industr') && !_s(d, 'destinazione').toLowerCase().contains('civil') && !_s(d, 'destinazione').toLowerCase().contains('commerc'), 'altri usi')),
        ]),
        _section('TIPO DI INTERVENTO'),
        pw.Row(children: [
          pw.Expanded(child: _check(c['nuovo'] == true, 'nuovo impianto')),
          pw.Expanded(child: _check(c['trasformazione'] == true, 'trasformazione')),
          pw.Expanded(child: _check(c['ampliamento'] == true, 'ampliamento')),
        ]),
        pw.SizedBox(height: 4),
        pw.Row(children: [
          pw.Expanded(child: _check(c['manutenzione_straordinaria'] == true, 'manutenzione straordinaria')),
          pw.Expanded(child: _check(c['parziale'] == true, 'parziale')),
          pw.Expanded(child: _check(false, 'altro')),
        ]),
        _section('DATI TECNICI DELL’IMPIANTO'),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.black, width: .6), columnWidths: {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)}, children: [
          pw.TableRow(children: [_field('Potenza / potenza impegnata', _s(d, 'potenza')), _field('Tensione', _s(d, 'tensione'))]),
          pw.TableRow(children: [_field('Descrizione dell’impianto', _s(d, 'descrizione'), minHeight: 52), _field('Intervento eseguito', _s(d, 'intervento'), minHeight: 52)]),
          pw.TableRow(children: [_field('Data inizio lavori', _s(d, 'data_inizio')), _field('Data fine lavori', _s(d, 'data_fine'))]),
        ]),
        _section('PROGETTO'),
        _line('Progettista / professionista', _s(d, 'progettista')),
        _line('Estremi progetto / elaborati', _s(d, 'progetto_rif')),
        pw.Text('L’app evidenzia i casi che possono richiedere progetto ai sensi dell’art. 5 del D.M. 37/2008; la verifica definitiva spetta al professionista competente.', style: const pw.TextStyle(fontSize: 7.2)),
        pw.Spacer(),
        _footer(1),
      ]),
    ));

    // Pagina 2: dichiarazione e allegati obbligatori del modello.
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        commonHeader(2),
        pw.Text('DICHIARA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 5),
        pw.Text(
          isDiRi
              ? 'Per quanto di propria competenza, sulla base degli accertamenti eseguiti e della documentazione disponibile, dichiara la rispondenza dell’impianto ai requisiti previsti dalla normativa applicabile, nei limiti e alle condizioni previste per la dichiarazione di rispondenza.'
              : 'sotto la propria personale responsabilità, che l’impianto è stato realizzato in modo conforme alla regola dell’arte, secondo quanto previsto dall’art. 6, tenuto conto delle condizioni di esercizio e degli usi a cui è destinato l’edificio, avendo in particolare:',
          style: const pw.TextStyle(fontSize: 8.5, lineSpacing: 2),
        ),
        if (!isDiRi) ...[
          pw.SizedBox(height: 6),
          _check(c['progetto_allegato'] == true, 'rispettato il progetto redatto ai sensi dell’art. 5'),
          pw.SizedBox(height: 4),
          _check(_s(d, 'norme').trim().isNotEmpty, 'seguito la norma tecnica applicabile all’impiego: ${_s(d, 'norme')}'),
          pw.SizedBox(height: 4),
          _check(c['materiali_allegato'] == true, 'installato componenti e materiali adatti al luogo di installazione (artt. 5 e 6)'),
          pw.SizedBox(height: 4),
          _check(c['verifiche_ok'] == true, 'controllato l’impianto ai fini della sicurezza e della funzionalità con esito positivo, eseguendo le verifiche richieste'),
        ],
        _section('ALLEGATI OBBLIGATORI'),
        _check(c['progetto_allegato'] == true, '1. Progetto ai sensi degli articoli 5 e 7 (quando previsto)'),
        pw.SizedBox(height: 4),
        _check(c['materiali_allegato'] == true, '2. Relazione con tipologie dei materiali utilizzati'),
        pw.SizedBox(height: 4),
        _check(c['schema_allegato'] == true, '3. Schema di impianto realizzato'),
        pw.SizedBox(height: 4),
        _check(c['dico_precedente'] == true, '4. Riferimento a dichiarazioni di conformità precedenti o parziali, già esistenti (se pertinenti)'),
        pw.SizedBox(height: 4),
        _check(c['visura_allegata'] == true, '5. Copia del certificato di riconoscimento dei requisiti tecnico-professionali'),
        pw.SizedBox(height: 4),
        _check(false, '6. Attestazione di conformità per impianto realizzato con materiali o sistemi non normalizzati (se applicabile)'),
        _section('ALLEGATI FACOLTATIVI'),
        _field('Elenco / note', _s(d, 'note'), minHeight: 48),
        _section('RELAZIONE MATERIALI E COMPONENTI'),
        _field('Tipologie dei materiali utilizzati', _s(d, 'materiali'), minHeight: 72),
        pw.SizedBox(height: 5),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.black, width: .6), columnWidths: {0: pw.FixedColumnWidth(28), 1: pw.FlexColumnWidth(2), 2: pw.FlexColumnWidth(1), 3: pw.FlexColumnWidth(1)}, children: [
          pw.TableRow(children: [_cell('N.', bold: true), _cell('Componente / materiale', bold: true), _cell('Marca / modello', bold: true), _cell('Riferimento', bold: true)]),
          for (int i = 1; i <= 5; i++) pw.TableRow(children: [_cell('$i'), _cell(''), _cell(''), _cell('')]),
        ]),
        pw.Spacer(),
        _footer(2),
      ]),
    ));

    // Pagina 3: verifiche, dichiarazioni conclusive, firme e note.
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(28, 24, 28, 24),
      build: (_) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        commonHeader(3),
        _section('VERIFICHE E PROVE'),
        _field('Verifiche eseguite', _s(d, 'verifiche'), minHeight: 90),
        pw.SizedBox(height: 6),
        _check(c['verifiche_ok'] == true, 'Esito positivo delle verifiche di sicurezza e funzionalità'),
        pw.SizedBox(height: 6),
        _section('DOCUMENTAZIONE CONSEGNATA'),
        _check(c['consegnata_documentazione'] == true, 'La documentazione prevista per il caso concreto è stata consegnata al committente'),
        pw.SizedBox(height: 5),
        _line('Documentazione precedente / riferimenti', _s(d, 'precedente')),
        _section('DECLINA'),
        pw.Text('ogni responsabilità per sinistri a persone o a cose derivanti da manomissione dell’impianto da parte di terzi ovvero da carenze di manutenzione o riparazione.', style: const pw.TextStyle(fontSize: 8.5)),
        pw.SizedBox(height: 10),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.black, width: .6), columnWidths: {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)}, children: [
          pw.TableRow(children: [
            _field('Luogo e data', _s(d, 'data'), minHeight: 34),
            _field('Numero documento', _s(d, 'numero'), minHeight: 34),
          ]),
        ]),
        pw.SizedBox(height: 10),
        pw.Table(border: pw.TableBorder.all(color: PdfColors.black, width: .6), columnWidths: {0: pw.FlexColumnWidth(1), 1: pw.FlexColumnWidth(1)}, children: [
          pw.TableRow(children: [
            pw.Container(height: 105, padding: const pw.EdgeInsets.all(5), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Il responsabile tecnico', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Spacer(),
              if (firmaTecnico != null) pw.Center(child: pw.Image(firmaTecnico, height: 45)),
              pw.Divider(),
              pw.Center(child: pw.Text('${_s(d, 'firma_tecnico')}\n(timbro e firma)', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
            ])),
            pw.Container(height: 105, padding: const pw.EdgeInsets.all(5), child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('Il dichiarante / committente', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
              pw.Spacer(),
              if (firmaCommittente != null) pw.Center(child: pw.Image(firmaCommittente, height: 45)),
              pw.Divider(),
              pw.Center(child: pw.Text('${_s(d, 'firma_committente')}\n(timbro e firma)', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 7))),
            ])),
          ]),
        ]),
        pw.SizedBox(height: 10),
        _section('AVVERTENZE PER IL COMMITTENTE'),
        pw.Text('Il modello dell’Allegato I è quello previsto dal D.M. 37/2008 come modificato dal D.M. 19 maggio 2010. Il presente PDF è una riproduzione digitale strutturata per l’app: non costituisce un documento emesso dall’Amministrazione e deve essere verificato, completato e sottoscritto dai soggetti abilitati prima dell’uso professionale.', style: const pw.TextStyle(fontSize: 7.5, lineSpacing: 1.5)),
        pw.SizedBox(height: 5),
        pw.Text('Riferimenti: D.M. 22 gennaio 2008, n. 37; D.M. 19 maggio 2010; eventuali successive modifiche applicabili al caso concreto.', style: const pw.TextStyle(fontSize: 7.5)),
        pw.Spacer(),
        _footer(3),
      ]),
    ));

    final bytes = await doc.save();
    await Printing.sharePdf(bytes: Uint8List.fromList(bytes), filename: '${_s(d, 'numero').isEmpty ? 'certificazione' : _s(d, 'numero')}.pdf');
  }
}
