import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/balloon_project.dart';

class StorageService {
  static const _key = 'balloon_projects';

  Future<List<BalloonProject>> loadProjects() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw
        .map((e) => BalloonProject.fromJson(jsonDecode(e)))
        .toList();
  }

  Future<void> saveProject(BalloonProject project) async {
    final projects = await loadProjects();
    final index = projects.indexWhere((p) => p.id == project.id);
    if (index >= 0) {
      projects[index] = project;
    } else {
      projects.insert(0, project);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      projects.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }

  Future<void> deleteProject(String id) async {
    final projects = await loadProjects();
    projects.removeWhere((p) => p.id == id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      projects.map((p) => jsonEncode(p.toJson())).toList(),
    );
  }
}
