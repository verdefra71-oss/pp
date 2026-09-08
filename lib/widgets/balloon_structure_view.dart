import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/balloon_section.dart';

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
    if (sections.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = math.min(constraints.maxWidth, 520.0);
        final ratio = heightCm <= 0 ? 1.5 : heightCm / math.max(widthCm, 1);
        final height = (width * ratio).clamp(220.0, 520.0);

        return Column(
          children: [
            Container(
              width: width,
              height: height,
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black12, width: 2),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    offset: Offset(0, 3),
                    color: Color(0x18000000),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CustomPaint(
                painter: _BalloonStructurePainter(sections),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 12,
              runSpacing: 6,
              children: sections.map((s) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(s.colorValue),
                        border: Border.all(color: Colors.black26),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text('${s.colorName} (${s.count})'),
                  ],
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }
}

class _BalloonStructurePainter extends CustomPainter {
  _BalloonStructurePainter(this.sections);
  final List<BalloonSection> sections;

  @override
  void paint(Canvas canvas, Size size) {
    final total = sections.fold<int>(0, (sum, s) => sum + s.count);
    if (total <= 0) return;

    final frame = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = Colors.black26;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(8, 8, size.width - 16, size.height - 16),
      const Radius.circular(14),
    );
    canvas.drawRRect(rect, frame);

    final rows = math.max(5, math.min(16, (size.height / 25).round()));
    final cols = math.max(5, math.min(22, (size.width / 25).round()));
    final capacity = rows * cols;
    final visible = math.min(total, capacity);

    final positions = <Offset>[];
    for (var row = 0; row < rows; row++) {
      final y = 18 + row * ((size.height - 36) / math.max(rows - 1, 1));
      final offset = row.isOdd ? 0.5 : 0.0;
      for (var col = 0; col < cols; col++) {
        if (positions.length >= visible) break;
        final x = 18 + (col + offset) * ((size.width - 36) / cols);
        if (x <= size.width - 12) positions.add(Offset(x, y));
      }
    }

    var cursor = 0;
    for (final section in sections) {
      final amount = math.min(
        section.count,
        (visible * section.count / total).round(),
      );
      final paint = Paint()..color = Color(section.colorValue);
      final radius = math.max(
        6.0,
        math.min(12.0, math.min(size.width / cols, size.height / rows) * 0.43),
      );

      for (var i = 0; i < amount && cursor < positions.length; i++) {
        final center = positions[cursor++];
        canvas.drawCircle(center, radius, paint);

        final shine = Paint()..color = Colors.white.withValues(alpha: 0.58);
        canvas.drawCircle(
          center.translate(-radius * .32, -radius * .32),
          radius * .22,
          shine,
        );

        final outline = Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8
          ..color = Colors.black.withValues(alpha: 0.18);
        canvas.drawCircle(center, radius, outline);
      }
    }

    if (total > visible) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: '+ ${total - visible} palloncini',
          style: const TextStyle(
            color: Colors.black54,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(size.width - textPainter.width - 18, size.height - 30),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _BalloonStructurePainter oldDelegate) => true;
}
