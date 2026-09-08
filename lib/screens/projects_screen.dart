import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final storage = StorageService();
  var loading = true;
  var projects = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await storage.loadProjects();
    if (!mounted) return;
    setState(() {
      projects = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('I miei progetti')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : projects.isEmpty
              ? const Center(child: Text('Nessun progetto salvato.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: projects.length,
                  itemBuilder: (context, i) {
                    final p = projects[i];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(child: Icon(Icons.balloon)),
                        title: Text(p.name),
                        subtitle: Text(
                          '${p.heightCm.toStringAsFixed(0)} cm • '
                          '${p.totalBalloons} palloncini',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ProjectDetailScreen(project: p),
                            ),
                          );
                          _load();
                        },
                      ),
                    );
                  },
                ),
    );
  }
}
