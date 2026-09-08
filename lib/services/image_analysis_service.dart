import 'dart:io';
import 'dart:math';
import 'package:image/image.dart' as img;
import '../models/balloon_section.dart';

class ImageAnalysisService {
  /// MVP: analisi locale dell'immagine.
  /// Raggruppa i pixel in palette semplificata e stima la superficie.
  /// Non sostituisce ancora una segmentazione AI professionale.
  Future<List<BalloonSection>> analyze(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Immagine non leggibile.');
    }

    final resized = img.copyResize(decoded, width: 160);
    final buckets = <int, int>{};
    var total = 0;

    for (final p in resized) {
      final r = (p.r ~/ 64).clamp(0, 3);
      final g = (p.g ~/ 64).clamp(0, 3);
      final b = (p.b ~/ 64).clamp(0, 3);
      final key = (r << 4) | (g << 2) | b;
      buckets[key] = (buckets[key] ?? 0) + 1;
      total++;
    }

    final top = buckets.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final selected = top.take(6).toList();
    final sections = <BalloonSection>[];

    for (var i = 0; i < selected.length; i++) {
      final key = selected[i].key;
      final r = ((key >> 4) & 3) * 64 + 32;
      final g = ((key >> 2) & 3) * 64 + 32;
      final b = (key & 3) * 64 + 32;
      final area = selected[i].value / total * 100;
      final density = 0.55;
      final count = max(1, (area / 100 * 180 * density).round());

      sections.add(
        BalloonSection(
          name: 'Sezione ${i + 1}',
          colorName: _colorName(r, g, b),
          colorValue: (0xFF << 24) | (r << 16) | (g << 8) | b,
          areaPercent: area,
          balloonSize: 12,
          density: density,
          count: count,
        ),
      );
    }

    return sections;
  }

  String _colorName(int r, int g, int b) {
    if (r > 180 && g < 100 && b < 100) return 'Rosso';
    if (r > 180 && g > 140 && b < 100) return 'Giallo';
    if (g > 150 && r < 140) return 'Verde';
    if (b > 150 && r < 140) return 'Blu';
    if (r > 150 && b > 120 && g < 150) return 'Viola/Rosa';
    if (r > 180 && g > 180 && b > 180) return 'Bianco';
    if (r < 90 && g < 90 && b < 90) return 'Nero';
    return 'Misto';
  }
}
