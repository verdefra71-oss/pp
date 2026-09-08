import 'package:flutter/material.dart';
import 'projects_screen.dart';
import 'new_project_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('🎈 Balloon Designer')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    const Text('Dal disegno allo schema',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      'Carica un’immagine, analizza i colori e ottieni '
                      'una prima stima delle sezioni e dei palloncini.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NewProjectScreen()),
                      ),
                      icon: const Icon(Icons.add_photo_alternate_outlined),
                      label: const Text('NUOVO PROGETTO'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ProjectsScreen()),
              ),
              icon: const Icon(Icons.folder_outlined),
              label: const Text('I MIEI PROGETTI'),
            ),
          ],
        ),
      ),
    );
  }
}
