import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../models/lesson_item.dart';

/// Widget responsável por desenhar a forma geométrica da atividade,
/// juntamente com o ícone central.
class LessonBadge extends StatelessWidget {
  const LessonBadge({
    super.key,
    required this.shape,
    required this.icon,
    required this.fillColor,
    required this.borderColor,
    required this.enabled,
    this.size = 90,
  });

  final NodeShape shape;
  final IconData icon;
  final Color fillColor;
  final Color borderColor;
  final bool enabled;
  final double size;

  @override
  Widget build(BuildContext context) {
    final effectiveFillColor = enabled ? fillColor : Colors.grey.shade700;
    final effectiveBorderColor = enabled ? borderColor : Colors.grey.shade800;
    final effectiveIconColor = enabled ? Colors.white : Colors.white38;

    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: ShapeNodePainter(
          shape: shape,
          fillColor: effectiveFillColor,
          borderColor: effectiveBorderColor,
        ),
        child: Center(
          child: Icon(
            icon,
            color: effectiveIconColor,
            size: 34,
          ),
        ),
      ),
    );
  }
}

/// Painter responsável por desenhar as formas geométricas.
class ShapeNodePainter extends CustomPainter {
  ShapeNodePainter({
    required this.shape,
    required this.fillColor,
    required this.borderColor,
  });

  final NodeShape shape;
  final Color fillColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _buildPath(size);

    // Sombra da forma para dar profundidade visual.
    canvas.drawShadow(
      path,
      Colors.black.withValues(alpha: 0.25),
      6,
      false,
    );

    // Preenchimento da forma.
    final fillPaint = Paint()
      ..color = fillColor
      ..style = PaintingStyle.fill;

    // Contorno da forma.
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, borderPaint);
  }

  /// Decide qual o path a desenhar com base no tipo de forma.
  Path _buildPath(Size size) {
    switch (shape) {
      case NodeShape.circle:
        return Path()
          ..addOval(
            Rect.fromCircle(
              center: Offset(size.width / 2, size.height / 2),
              radius: size.width / 2 - 4,
            ),
          );

      case NodeShape.roundedSquare:
        return Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(6, 6, size.width - 12, size.height - 12),
              const Radius.circular(18),
            ),
          );

      case NodeShape.diamond:
        return _diamondPath(size);

      case NodeShape.pentagon:
        return _polygonPath(size, sides: 5);

      case NodeShape.hexagon:
        return _polygonPath(size, sides: 6);

      case NodeShape.star:
        return _starPath(size, points: 5);
    }
  }

  /// Desenha um losango.
  Path _diamondPath(Size size) {
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final padding = 8.0;

    return Path()
      ..moveTo(centerX, padding)
      ..lineTo(size.width - padding, centerY)
      ..lineTo(centerX, size.height - padding)
      ..lineTo(padding, centerY)
      ..close();
  }

  /// Desenha um polígono regular com o número de lados indicado.
  Path _polygonPath(Size size, {required int sides}) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    final rotation = -math.pi / 2;

    for (int i = 0; i < sides; i++) {
      final angle = rotation + (2 * math.pi * i / sides);
      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

  /// Desenha uma estrela com o número de pontas indicado.
  Path _starPath(Size size, {required int points}) {
    final path = Path();
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2 - 6;
    final innerRadius = outerRadius * 0.45;
    final rotation = -math.pi / 2;

    for (int i = 0; i < points * 2; i++) {
      final isOuter = i.isEven;
      final radius = isOuter ? outerRadius : innerRadius;
      final angle = rotation + (math.pi * i / points);

      final x = center.dx + radius * math.cos(angle);
      final y = center.dy + radius * math.sin(angle);

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.close();
    return path;
  }

  @override
  bool shouldRepaint(covariant ShapeNodePainter oldDelegate) {
    return oldDelegate.shape != shape ||
        oldDelegate.fillColor != fillColor ||
        oldDelegate.borderColor != borderColor;
  }
}