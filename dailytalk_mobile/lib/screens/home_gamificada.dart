import 'package:flutter/material.dart';

import '../models/lesson_item.dart';
import '../widgets/lesson_node.dart';
import '../widgets/top_overflow_menu.dart';

/// Tela inicial gamificada do DailyTalk.pt.
///
/// Esta tela dá prioridade ao percurso de prática do utilizador.
/// O foco principal é o mapa de atividades já disponíveis.
class HomeGamificada extends StatelessWidget {
  const HomeGamificada({super.key});

  /// Lista temporária de atividades.
  ///
  /// Mais tarde estas atividades poderão vir do SQLite/backend.
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
            _buildHeader(),
            _buildCompactProgressCard(),
            _buildMapTitle(),

            // O mapa recebe a maior parte da área disponível.
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(
                  top: 4,
                  bottom: 18,
                ),
                child: Column(
                  children: [
                    _buildActivityMap(context, lessons),
                    const SizedBox(height: 12),
                    _buildShortcutsPanel(context),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Cabeçalho superior com logo, nome da app e menu.
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 10, 8),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF06345C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.lightBlue.withValues(alpha: 0.35),
              ),
            ),
            child: const Icon(
              Icons.menu_book,
              color: Colors.amber,
              size: 30,
            ),
          ),

          const SizedBox(width: 12),

          const Expanded(
            child: Text(
              'DailyTalk.pt',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),

          const TopOverflowMenu(),
        ],
      ),
    );
  }

  /// Cartão azul superior, agora mais compacto.
  Widget _buildCompactProgressCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        decoration: BoxDecoration(
          color: Colors.lightBlue,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1264B0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'UNIDADE 5',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  const Text(
                    'Tema: Comunicação e amizades',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 25,
                      fontWeight: FontWeight.bold,
                      height: 1.18,
                    ),
                  ),

                  const SizedBox(height: 8),

                  const Text(
                    '3 de 6 atividades concluídas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 10),

                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: 0.5,
                      minHeight: 8,
                      backgroundColor: const Color(0xFF0D4D7A),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Colors.greenAccent.shade400,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            Container(
              width: 66,
              height: 66,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: 34,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Título visual da área principal de atividades.
  Widget _buildMapTitle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(
            Icons.auto_awesome,
            color: Colors.lightBlueAccent,
            size: 18,
          ),
          SizedBox(width: 8),
          Text(
            'MAPA DE ATIVIDADES',
            style: TextStyle(
              color: Colors.white,
              fontSize: 15,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(width: 8),
          Icon(
            Icons.auto_awesome,
            color: Colors.lightBlueAccent,
            size: 18,
          ),
        ],
      ),
    );
  }

  /// Mapa vertical gamificado.
  Widget _buildActivityMap(
    BuildContext context,
    List<LessonItem> lessons,
  ) {
    return Column(
      children: List.generate(lessons.length, (index) {
        final lesson = lessons[index];

        // Alterna entre esquerda e direita para simular um percurso.
        final alignLeft = index % 2 == 0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Align(
            alignment: alignLeft ? Alignment.centerLeft : Alignment.centerRight,
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
    );
  }

  /// Painel compacto de atalhos e feedback.
  ///
  /// Fica abaixo do mapa para não competir com a área principal.
  Widget _buildShortcutsPanel(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF10232D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: Colors.lightBlue.withValues(alpha: 0.35),
          ),
        ),
        child: Column(
          children: [
            const Text(
              'ATALHOS / FEEDBACK',
              style: TextStyle(
                color: Colors.lightBlueAccent,
                fontSize: 13,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),

            const SizedBox(height: 10),

            Row(
              children: [
                Expanded(
                  child: _ShortcutButton(
                    icon: Icons.emoji_events,
                    title: 'Conquistas',
                    subtitle: 'Badges e pontos',
                    onTap: () => _showShortcutMessage(
                      context,
                      'Conquistas serão detalhadas na área de Resultados.',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShortcutButton(
                    icon: Icons.bar_chart,
                    title: 'Progresso',
                    subtitle: 'Evolução',
                    onTap: () => _showShortcutMessage(
                      context,
                      'O progresso será apresentado com métricas de aprendizagem.',
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: _ShortcutButton(
                    icon: Icons.feedback_outlined,
                    title: 'Feedback',
                    subtitle: 'Opinião',
                    onTap: () => _showShortcutMessage(
                      context,
                      'O feedback ajudará a melhorar as atividades.',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _ShortcutButton(
                    icon: Icons.help_outline,
                    title: 'Ajuda rápida',
                    subtitle: 'Dicas',
                    onTap: () => _showShortcutMessage(
                      context,
                      'A ajuda rápida explicará como usar a aplicação.',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showShortcutMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }
}

/// Botão compacto usado no painel de atalhos.
class _ShortcutButton extends StatelessWidget {
  const _ShortcutButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF0D1B22),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 72,
          ),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.lightBlue.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: Colors.lightBlueAccent,
                  size: 28,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 11,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}