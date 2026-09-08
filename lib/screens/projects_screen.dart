import 'package:flutter/material.dart';

import '../models/balloon_project.dart';
import '../services/storage_service.dart';
import 'project_detail_screen.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  final StorageService _storage = StorageService();
  List<BalloonProject> _projects = <BalloonProject>[];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final projects = await _storage.loadProjects();
    if (!mounted) return;
    setState(() => _projects = projects);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('I miei progetti')),
      body: _projects.isEmpty
          ? const Center(child: Text('Nessun progetto salvato.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _projects.length,
              itemBuilder: (context, index) {
                final project = _projects[index];
                return Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.celebration),
                    ),
                    title: Text(project.name),
                    subtitle: Text(
                      '${project.widthCm.toStringAsFixed(0)} × '
                      '${project.heightCm.toStringAsFixed(0)} cm • '
                      '${project.totalBalloons} palloncini',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              ProjectDetailScreen(project: project),
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
