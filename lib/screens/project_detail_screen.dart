import 'dart:io';
import 'package:flutter/material.dart';
import '../models/balloon_project.dart';
import '../services/pdf_service.dart';
import '../services/storage_service.dart';

class ProjectDetailScreen extends StatefulWidget {
  const ProjectDetailScreen({super.key, required this.project});
  final BalloonProject project;

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final storage = StorageService();
  final pdf = PdfService();

  Future<void> _save() async {
    await storage.saveProject(widget.project);
    if (mounted) setState(() {});
  }

  Future<void> _editSection(int index) async {
    final s = widget.project.sections[index];
    final controller = TextEditingController(text: '${s.count}');
    final result = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(s.name),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Numero palloncini'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annulla')),
          FilledButton(
            onPressed: () => Navigator.pop(context, int.tryParse(controller.text)),
            child: const Text('Salva'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result > 0) {
      setState(() => s.count = result);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.project;
    return Scaffold(
      appBar: AppBar(
        title: Text(p.name),
        actions: [
          IconButton(
            tooltip: 'PDF',
            onPressed: () => pdf.shareProject(p),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (File(p.imagePath).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.file(File(p.imagePath), height: 260, fit: BoxFit.contain),
            ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                children: [
                  Text('${p.widthCm.toStringAsFixed(0)} × ${p.heightCm.toStringAsFixed(0)} cm',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text('Totale stimato: ${p.totalBalloons} palloncini',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...p.sections.asMap().entries.map((entry) {
            final i = entry.key;
            final s = entry.value;
            return Card(
              child: ListTile(
                leading: CircleAvatar(backgroundColor: Color(s.colorValue)),
                title: Text(s.name),
                subtitle: Text('${s.colorName} • ${s.areaPercent.toStringAsFixed(1)}% • ${s.balloonSize}"'),
                trailing: Text('${s.count}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                onTap: () => _editSection(i),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text(
            'Tocca una sezione per modificare la quantità. '
            'La stima automatica è un punto di partenza: la quantità reale '
            'dipende dalla tecnica, dal tipo di palloncino e dalla densità.',
          ),
        ],
      ),
    );
  }
}
