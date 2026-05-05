import 'package:flutter/material.dart';

import '../models/lesson_item.dart';
import '../strategies/activity_strategy.dart';
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
    final strategy = ActivityStrategyFactory.fromLessonType(lesson.type);

    final icon = lesson.status == LessonStatus.locked
        ? Icons.lock
        : strategy.icon;

    return Column(
      children: [
        GestureDetector(
          onTap: enabled ? onTap : null,
          child: LessonBadge(
            shape: strategy.shape,
            icon: icon,
            fillColor: strategy.fillColor,
            borderColor: _borderColorForStatus(lesson.status),
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