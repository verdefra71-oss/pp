import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/balloon_section.dart';

/// Anteprima visiva della struttura calcolata.
/// I palloncini sono disposti come una vera composizione: arco/garland
/// verticale, con le sezioni mantenute nello stesso ordine del calcolo.
class BalloonStructureView extends StatelessWidget {
  const BalloonStructureView({
    super.key,
    required this.sections,
    required this.widthCm,
    required this.heightCm,
  });

  final List<BalloonSection> sections;
  final double widthCm;
  final double heightCm;

  @override
  Widget build(BuildContext context) {
    final total = sections.fold<int>(0, (sum, s) => sum + s.count);
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
                      'ANTEPRIMA REALE DELLA STRUTTURA',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Dimensioni: ${widthCm.toStringAsFixed(0)} × ${heightCm.toStringAsFixed(0)} cm  •  $total palloncini',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
              AspectRatio(
                aspectRatio: 0.82,
                child: CustomPaint(
                  painter: _StructurePainter(sections),
                  child: const SizedBox.expand(),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: sections.map((s) {
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

class _StructurePainter extends CustomPainter {
  _StructurePainter(this.sections);
  final List<BalloonSection> sections;

  @override
  void paint(Canvas canvas, Size size) {
    final total = sections.fold<int>(0, (sum, s) => sum + s.count);
    if (total <= 0) return;

    final bg = Paint()..color = const Color(0xFFF8F8F8);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(12)),
      bg,
    );

    // Telaio della struttura.
    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = const Color(0xFF9E9E9E);
    final path = Path();
    final left = size.width * .18;
    final right = size.width * .82;
    final top = size.height * .12;
    final bottom = size.height * .91;
    path.moveTo(left, bottom);
    path.lineTo(left, top + size.height * .18);
    path.cubicTo(left, top, right, top, right, top + size.height * .18);
    path.lineTo(right, bottom);
    canvas.drawPath(path, frame);

    // Distribuiamo esattamente i conteggi calcolati lungo il telaio.
    final positions = <Offset>[];
    final rows = math.max(8, math.min(28, (size.height / 25).round()));
    for (var i = 0; i < rows; i++) {
      final t = i / math.max(rows - 1, 1);
      final y = bottom - t * (bottom - top);
      final arch = math.sin(math.pi * math.min(t * 1.35, 1.0));
      final center = size.width / 2;
      final half = (right - left) / 2 * arch;
      if (i < rows * .72) {
        // Due colonne laterali.
        positions.add(Offset(left + 5, y));
        positions.add(Offset(right - 5, y));
      } else {
        // Parte superiore curva.
        positions.add(Offset(center - half, y));
        positions.add(Offset(center + half, y));
        if (i.isEven) positions.add(Offset(center, y));
      }
    }

    // Aggiunge posizioni intermedie per strutture molto dense.
    while (positions.length < math.min(total, 120)) {
      final t = (positions.length % 20) / 19;
      final y = bottom - t * (bottom - top);
      positions.add(Offset(
        size.width * (.22 + .56 * t),
        y,
      ));
    }

    final visible = math.min(total, positions.length);
    var cursor = 0;
    for (final section in sections) {
      final amount = ((visible * section.count) / total).round();
      final color = Color(section.colorValue);
      for (var i = 0; i < amount && cursor < visible; i++) {
        _drawBalloon(canvas, positions[cursor++], color, size);
      }
    }

    // Se gli arrotondamenti lasciano qualche posizione, riempiamo con l'ultimo colore.
    final fallbackColor = Color(sections.last.colorValue);
    while (cursor < visible) {
      _drawBalloon(canvas, positions[cursor++], fallbackColor, size);
    }

    if (total > visible) {
      final tp = TextPainter(
        text: TextSpan(
          text: '+${total - visible} palloncini mostrati in scala ridotta',
          style: const TextStyle(fontSize: 11, color: Colors.black54),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(12, size.height - 24));
    }
  }

  void _drawBalloon(Canvas canvas, Offset center, Color color, Size size) {
    final radius = math.max(7.0, math.min(12.0, size.width / 24));
    final body = Paint()..color = color;
    final rect = Rect.fromCenter(
      center: center,
      width: radius * 1.55,
      height: radius * 1.9,
    );
    canvas.drawOval(rect, body);

    final knot = Path()
      ..moveTo(center.dx - radius * .16, center.dy + radius * .78)
      ..lineTo(center.dx + radius * .16, center.dy + radius * .78)
      ..lineTo(center.dx, center.dy + radius * 1.08)
      ..close();
    canvas.drawPath(knot, body);

    final shine = Paint()..color = Colors.white.withValues(alpha: .62);
    canvas.drawOval(
      Rect.fromCenter(
        center: center.translate(-radius * .27, -radius * .32),
        width: radius * .30,
        height: radius * .48,
      ),
      shine,
    );

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .7
      ..color = Colors.black.withValues(alpha: .18);
    canvas.drawOval(rect, outline);
  }

  @override
  bool shouldRepaint(covariant _StructurePainter oldDelegate) => true;
}
