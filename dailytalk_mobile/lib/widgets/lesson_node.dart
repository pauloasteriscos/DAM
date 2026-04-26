import 'package:flutter/material.dart';

import '../models/lesson_item.dart';
import 'lesson_badge.dart';

/// Widget que representa cada atividade do percurso gamificado.
class LessonNode extends StatelessWidget {
  const LessonNode({
    super.key,
    required this.lesson,
    required this.onTap,
  });

  final LessonItem lesson;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = lesson.status != LessonStatus.locked;

    final fillColor = _fillColorForLessonType(lesson.type);
    final borderColor = _borderColorForStatus(lesson.status);
    final icon = lesson.status == LessonStatus.locked
        ? Icons.lock
        : _iconForLessonType(lesson.type);

    return Column(
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: LessonBadge(
            shape: _shapeForLessonType(lesson.type),
            icon: icon,
            fillColor: fillColor,
            borderColor: borderColor,
            enabled: enabled,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 120,
          child: Text(
            lesson.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: enabled ? Colors.white : Colors.white38,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  /// Define a forma geométrica de acordo com o tipo de atividade.
  NodeShape _shapeForLessonType(LessonType type) {
    switch (type) {
      case LessonType.audio:
        return NodeShape.circle;
      case LessonType.vocabulario:
        return NodeShape.roundedSquare;
      case LessonType.dialogo:
        return NodeShape.hexagon;
      case LessonType.quiz:
        return NodeShape.diamond;
      case LessonType.revisao:
        return NodeShape.pentagon;
      case LessonType.desafioFinal:
        return NodeShape.star;
    }
  }

  /// Define o ícone conforme o tipo de atividade.
  IconData _iconForLessonType(LessonType type) {
    switch (type) {
      case LessonType.audio:
        return Icons.headphones;
      case LessonType.vocabulario:
        return Icons.menu_book;
      case LessonType.dialogo:
        return Icons.chat_bubble;
      case LessonType.quiz:
        return Icons.quiz;
      case LessonType.revisao:
        return Icons.refresh;
      case LessonType.desafioFinal:
        return Icons.star;
    }
  }

  /// Define a cor base de cada tipo de atividade.
  Color _fillColorForLessonType(LessonType type) {
    switch (type) {
      case LessonType.audio:
        return Colors.blue;
      case LessonType.vocabulario:
        return Colors.orange;
      case LessonType.dialogo:
        return Colors.green;
      case LessonType.quiz:
        return Colors.purple;
      case LessonType.revisao:
        return Colors.teal;
      case LessonType.desafioFinal:
        return Colors.amber;
    }
  }

  /// Define a cor da borda consoante o estado da atividade.
  Color _borderColorForStatus(LessonStatus status) {
    switch (status) {
      case LessonStatus.completed:
        return Colors.blueGrey.shade900;
      case LessonStatus.current:
        return Colors.lightGreen.shade900;
      case LessonStatus.available:
        return Colors.blueGrey.shade800;
      case LessonStatus.locked:
        return Colors.grey.shade800;
    }
  }
}