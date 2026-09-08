import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import '../models/balloon_section.dart';

/// Mostra l'immagine usata per il calcolo e la ricostruisce con palloncini
/// distribuiti sulla forma realmente presente nell'immagine.
class BalloonStructureView extends StatefulWidget {
  const BalloonStructureView({
    super.key,
    required this.sections,
    required this.widthCm,
    required this.heightCm,
    required this.imagePath,
  });

  final List<BalloonSection> sections;
  final double widthCm;
  final double heightCm;
  final String imagePath;

  @override
  State<BalloonStructureView> createState() => _BalloonStructureViewState();
}

class _BalloonStructureViewState extends State<BalloonStructureView> {
  late Future<_ShapeData> _shapeFuture;

  @override
  void initState() {
    super.initState();
    _shapeFuture = _loadShape();
  }

  @override
  void didUpdateWidget(covariant BalloonStructureView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imagePath != widget.imagePath || oldWidget.sections != widget.sections) {
      _shapeFuture = _loadShape();
    }
  }

  Future<_ShapeData> _loadShape() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final source = img.decodeImage(bytes);
    if (source == null) throw Exception('Immagine non leggibile.');

    final small = img.copyResize(source, width: 96, height: 96);
    final mask = <bool>[];
    var foreground = 0;

    for (final p in small) {
      final r = p.r.toDouble();
      final g = p.g.toDouble();
      final b = p.b.toDouble();
      final maxC = math.max(r, math.max(g, b));
      final minC = math.min(r, math.min(g, b));
      final saturation = maxC == 0 ? 0 : (maxC - minC) / maxC;
      final luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b;

      // Ignora lo sfondo bianco e il watermark molto chiaro. Mantiene
      // sia le zone scure sia quelle colorate del soggetto.
      final isSubject = luminance < 225 || saturation > 0.12;
      mask.add(isSubject);
      if (isSubject) foreground++;
    }

    if (foreground < 80) {
      // Fallback: usa una maschera morbida centrale se l'immagine è troppo chiara.
      for (var i = 0; i < mask.length; i++) {
        final x = i % 96;
        final y = i ~/ 96;
        final dx = (x - 48) / 42;
        final dy = (y - 48) / 42;
        mask[i] = dx * dx + dy * dy < 1;
      }
    }

    return _ShapeData(mask: mask, width: 96, height: 96);
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.sections.fold<int>(0, (sum, s) => sum + s.count);
    if (total <= 0) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFD4AF37), width: 2),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Icon(Icons.visibility, color: Color(0xFFD4AF37)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'VERIFICA STRUTTURA CON I PALLONCINI',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                'I palloncini seguono la forma del disegno caricato. Totale: $total',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 10),
              FutureBuilder<_ShapeData>(
                future: _shapeFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const AspectRatio(
                      aspectRatio: 1,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('Impossibile creare l’anteprima della struttura.'),
                    );
                  }

                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.file(File(widget.imagePath), fit: BoxFit.contain),
                          CustomPaint(
                            painter: _BalloonOverlayPainter(
                              shape: snapshot.data!,
                              sections: widget.sections,
                              total: total,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
              const Text(
                'L’immagine originale resta visibile come riferimento; i palloncini sono sovrapposti alla sagoma riconosciuta.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.black54),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: widget.sections.map((s) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(s.colorValue),
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text('${s.colorName}: ${s.count}'),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _ShapeData {
  const _ShapeData({required this.mask, required this.width, required this.height});
  final List<bool> mask;
  final int width;
  final int height;
}

class _BalloonOverlayPainter extends CustomPainter {
  _BalloonOverlayPainter({
    required this.shape,
    required this.sections,
    required this.total,
  });

  final _ShapeData shape;
  final List<BalloonSection> sections;
  final int total;

  @override
  void paint(Canvas canvas, Size size) {
    final points = <Offset>[];
    final target = math.min(total, 220);
    final step = math.max(3, (math.sqrt((shape.width * shape.height) / target)).round());

    for (var y = 1; y < shape.height - 1; y += step) {
      for (var x = 1; x < shape.width - 1; x += step) {
        if (!_isInside(x, y)) continue;
        final nearEdge = !_isInside(x - 1, y) || !_isInside(x + 1, y) || !_isInside(x, y - 1) || !_isInside(x, y + 1);
        if (nearEdge || ((x + y) % 2 == 0)) {
          points.add(Offset(
            (x + .5) / shape.width * size.width,
            (y + .5) / shape.height * size.height,
          ));
        }
      }
    }

    if (points.length < target) {
      for (var y = 1; y < shape.height - 1 && points.length < target; y++) {
        for (var x = 1; x < shape.width - 1 && points.length < target; x++) {
          if (_isInside(x, y) && (x + y) % 3 == 0) {
            points.add(Offset(
              (x + .5) / shape.width * size.width,
              (y + .5) / shape.height * size.height,
            ));
          }
        }
      }
    }

    if (points.isEmpty) return;
    points.shuffle(math.Random(7));

    var cursor = 0;
    for (final section in sections) {
      final amount = ((target * section.count) / total).round();
      final color = Color(section.colorValue);
      for (var i = 0; i < amount && cursor < points.length && cursor < target; i++) {
        _drawBalloon(canvas, points[cursor++], color, size);
      }
    }

    while (cursor < target && cursor < points.length) {
      _drawBalloon(canvas, points[cursor++], Color(sections.last.colorValue), size);
    }
  }

  bool _isInside(int x, int y) {
    if (x < 0 || y < 0 || x >= shape.width || y >= shape.height) return false;
    return shape.mask[y * shape.width + x];
  }

  void _drawBalloon(Canvas canvas, Offset center, Color color, Size size) {
    final radius = math.max(7.0, math.min(15.0, size.width / 38));
    final rect = Rect.fromCenter(center: center, width: radius * 1.35, height: radius * 1.65);

    final shadow = Paint()..color = Colors.black.withValues(alpha: .22);
    canvas.drawOval(rect.shift(const Offset(1.5, 2)), shadow);

    final body = Paint()..color = color.withValues(alpha: .94);
    canvas.drawOval(rect, body);

    final shine = Paint()..color = Colors.white.withValues(alpha: .68);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * .25, -radius * .28),
        width: radius * .25,
        height: radius * .42,
      ),
      shine,
    );

    final knot = Path()
      ..moveTo(center.dx - radius * .12, center.dy + radius * .78)
      ..lineTo(center.dx + radius * .12, center.dy + radius * .78)
      ..lineTo(center.dx, center.dy + radius * 1.02)
      ..close();
    canvas.drawPath(knot, body);
  }

  @override
  bool shouldRepaint(covariant _BalloonOverlayPainter oldDelegate) => true;
}
