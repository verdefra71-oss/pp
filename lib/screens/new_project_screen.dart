import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/balloon_project.dart';
import '../models/balloon_section.dart';
import '../services/image_analysis_service.dart';
import '../services/storage_service.dart';
import '../widgets/balloon_structure_view.dart';
import 'project_detail_screen.dart';

class NewProjectScreen extends StatefulWidget {
  const NewProjectScreen({super.key});

  @override
  State<NewProjectScreen> createState() => _NewProjectScreenState();
}

class _NewProjectScreenState extends State<NewProjectScreen> {
  final picker = ImagePicker();
  final analyzer = ImageAnalysisService();
  final storage = StorageService();
  final nameController = TextEditingController(text: 'Nuovo progetto');
  final widthController = TextEditingController(text: '120');
  final heightController = TextEditingController(text: '180');

  File? imageFile;
  List<BalloonSection> sections = [];
  bool analyzing = false;

  Future<void> _pick(ImageSource source) async {
    final x = await picker.pickImage(source: source, imageQuality: 90);
    if (x == null) return;
    setState(() => imageFile = File(x.path));
  }

  Future<void> _analyze() async {
    if (imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Prima carica un disegno o una foto.')),
      );
      return;
    }
    setState(() => analyzing = true);
    try {
      final result = await analyzer.analyze(imageFile!);
      if (!mounted) return;
      setState(() => sections = result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Errore analisi: $e')),
      );
    } finally {
      if (mounted) setState(() => analyzing = false);
    }
  }

  Future<void> _create() async {
    if (sections.isEmpty) {
      await _analyze();
      if (sections.isEmpty) return;
    }
    final project = BalloonProject(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: nameController.text.trim().isEmpty ? 'Progetto' : nameController.text.trim(),
      widthCm: double.tryParse(widthController.text.replaceAll(',', '.')) ?? 120,
      heightCm: double.tryParse(heightController.text.replaceAll(',', '.')) ?? 180,
      imagePath: imageFile!.path,
      sections: sections,
      createdAt: DateTime.now(),
    );
    await storage.saveProject(project);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ProjectDetailScreen(project: project)),
    );
  }

  @override
  void dispose() {
    nameController.dispose();
    widthController.dispose();
    heightController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuovo progetto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Nome progetto')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: TextField(controller: widthController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Larghezza cm'))),
            const SizedBox(width: 12),
            Expanded(child: TextField(controller: heightController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Altezza cm'))),
          ]),
          const SizedBox(height: 16),
          Container(
            height: 260,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.black12),
            ),
            clipBehavior: Clip.antiAlias,
            child: imageFile == null
                ? const Center(child: Text('Nessuna immagine caricata'))
                : Image.file(imageFile!, fit: BoxFit.contain),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo), label: const Text('Galleria'))),
            const SizedBox(width: 8),
            Expanded(child: OutlinedButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.camera_alt), label: const Text('Fotocamera'))),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: analyzing ? null : _analyze,
            icon: analyzing ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.auto_awesome),
            label: Text(analyzing ? 'Analisi in corso...' : 'ANALIZZA DISEGNO'),
          ),
          if (sections.isNotEmpty) ...[
            const SizedBox(height: 16),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RISULTATO DEL CALCOLO',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Il calcolo è terminato. Qui sotto puoi verificare visivamente come verrà composta la struttura con i palloncini.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    BalloonStructureView(
                      sections: sections,
                      widthCm: double.tryParse(widthController.text.replaceAll(',', '.')) ?? 120,
                      heightCm: double.tryParse(heightController.text.replaceAll(',', '.')) ?? 180,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('Dettaglio calcolo: ${sections.length} sezioni', style: Theme.of(context).textTheme.titleMedium),
            ...sections.map((s) => ListTile(
              leading: CircleAvatar(backgroundColor: Color(s.colorValue)),
              title: Text(s.name),
              subtitle: Text('${s.colorName} • ${s.areaPercent.toStringAsFixed(1)}% • ${s.count} palloncini'),
            )),
            const SizedBox(height: 8),
            FilledButton.icon(onPressed: _create, icon: const Icon(Icons.check), label: const Text('CREA PROGETTO')),
          ],
        ],
      ),
    );
  }
}
