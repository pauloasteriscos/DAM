import 'package:flutter/material.dart';

import '../models/lesson_item.dart';
import '../widgets/lesson_node.dart';
import '../widgets/top_overflow_menu.dart';

/// Tela inicial gamificada do DailyTalk.pt.
class HomeGamificada extends StatelessWidget {
  const HomeGamificada({super.key});

  /// Lista temporária de atividades.
  /// Mais tarde estas atividades poderão vir do SQLite.
  List<LessonItem> _buildLessons() {
    return const [
      LessonItem(
        title: 'Vocabulário',
        type: LessonType.vocabulario,
        status: LessonStatus.completed,
      ),
      LessonItem(
        title: 'Áudio',
        type: LessonType.audio,
        status: LessonStatus.completed,
      ),
      LessonItem(
        title: 'Diálogo',
        type: LessonType.dialogo,
        status: LessonStatus.current,
      ),
      LessonItem(
        title: 'Quiz',
        type: LessonType.quiz,
        status: LessonStatus.available,
      ),
      LessonItem(
        title: 'Revisão',
        type: LessonType.revisao,
        status: LessonStatus.available,
      ),
      LessonItem(
        title: 'Desafio Final',
        type: LessonType.desafioFinal,
        status: LessonStatus.locked,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final lessons = _buildLessons();

    return SafeArea(
      child: Container(
        color: const Color(0xFF0D1B22),
        child: Column(
          children: [
           const SizedBox(height: 16),

Padding(
  padding: const EdgeInsets.symmetric(horizontal: 16),
  child: Row(
    children: [
      const SizedBox(width: 48),

      const Expanded(
        child: Text(
          'DailyTalk.pt',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 34,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      const SizedBox(
        width: 48,
        child: Align(
          alignment: Alignment.centerRight,
          child: TopOverflowMenu(),
        ),
      ),
    ],
  ),
),

const SizedBox(height: 24),

            // Cartão superior da unidade atual.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.lightBlue,
                  borderRadius: BorderRadius.circular(22),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'UNIDADE 5',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Tema: Comunicação e amizades',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        height: 1.35,
                      ),
                    ),
                    SizedBox(height: 16),
                    Text(
                      '3 de 6 atividades concluídas',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Percurso gamificado com scroll vertical.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: 8,
                  bottom: 24,
                ),
                child: Column(
                  children: List.generate(lessons.length, (index) {
                    final lesson = lessons[index];

                    // Alterna entre esquerda e direita para simular
                    // um caminho gamificado.
                    final alignLeft = index % 2 == 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Align(
                        alignment: alignLeft
                            ? Alignment.centerLeft
                            : Alignment.centerRight,
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: alignLeft ? 52 : 0,
                            right: alignLeft ? 0 : 52,
                          ),
                          child: LessonNode(
                            lesson: lesson,
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Abrir atividade: ${lesson.title}',
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}