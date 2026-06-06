import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../models/lesson_item.dart';
import '../widgets/lesson_node.dart';
import '../widgets/top_overflow_menu.dart';

import 'vocabulary_pairs_page.dart';
import 'dialogue_page.dart';
import 'revision_page.dart';
import 'quiz_page.dart';
import 'login_form_page.dart';

/// Tela inicial gamificada do DailyTalk.pt.
///
/// Esta tela dá prioridade ao percurso de prática do utilizador.
/// O foco principal é o mapa de atividades já disponíveis.
class HomeGamificada extends StatelessWidget {
  const HomeGamificada({
    super.key,
    this.isTestMode = false,
    this.onAuthenticated,
  });

  /// Indica se a Home foi aberta a partir do botão "Testar agora".
  ///
  /// Em modo teste, o utilizador consegue experimentar as atividades, mas a
  /// interface informa que o progresso da sessão não será sincronizado.
  final bool isTestMode;

  /// Callback usado quando o utilizador decide entrar a partir do modo teste.
  final VoidCallback? onAuthenticated;

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
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Em orientação horizontal a altura útil é muito menor.
            // Nesses casos, a Home passa a ser totalmente deslocável para
            // evitar RenderFlex overflow junto à barra de navegação inferior.
            final useCompactLandscapeLayout = constraints.maxHeight < 520;

            if (useCompactLandscapeLayout) {
              return SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(
                  children: [
                    _buildHeader(compact: true),
                    if (isTestMode) _buildTestModeBanner(context, compact: true),
                    _buildCompactProgressCard(compact: true),
                    _buildMapTitle(compact: true),
                    _buildActivityMap(
                      context,
                      lessons,
                      compact: true,
                    ),
                    const SizedBox(height: 10),
                    _buildShortcutsPanel(context),
                  ],
                ),
              );
            }

            return Column(
              children: [
                _buildHeader(),
                if (isTestMode) _buildTestModeBanner(context),
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
            );
          },
        ),
      ),
    );
  }

  /// Cabeçalho superior com logo, nome da app e menu.
  Widget _buildHeader({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        compact ? 6 : 8,
        10,
        compact ? 4 : 8,
      ),
      child: Row(
        children: [
          Container(
            width: compact ? 34 : 42,
            height: compact ? 34 : 42,
            decoration: BoxDecoration(
              color: const Color(0xFF06345C),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.lightBlue.withValues(alpha: 0.35),
              ),
            ),
            child: Icon(
              Icons.menu_book,
              color: Colors.amber,
              size: compact ? 23 : 28,
            ),
          ),

          SizedBox(width: compact ? 10 : 12),

          Expanded(
            child: AppText(
              'DailyTalk.pt',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 24 : 28,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),

          const TopOverflowMenu(),
        ],
      ),
    );
  }


  /// Aviso compacto apresentado quando o utilizador está a experimentar sem conta.
  ///
  /// A informação continua visível, mas deixa de competir com o mapa de
  /// atividades. O objetivo é informar sem quebrar a experiência gamificada.
  Widget _buildTestModeBanner(BuildContext context, {bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        compact ? 0 : 2,
        16,
        compact ? 4 : 6,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: compact ? 6 : 8,
        ),
        decoration: BoxDecoration(
          color: const Color(0xFF0B2B3C).withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: Colors.lightBlueAccent.withValues(alpha: 0.45),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.visibility_outlined,
              color: Colors.lightBlueAccent,
              size: 18,
            ),

            const SizedBox(width: 8),

            Expanded(
              child: AppText(
                'Modo teste · progresso não guardado',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.88),
                  fontSize: compact ? 12 : 12.5,
                  height: 1.2,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),

            const SizedBox(width: 6),

            TextButton(
              onPressed: () => _goToAuthentication(context),
              style: TextButton.styleFrom(
                foregroundColor: Colors.lightBlueAccent,
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: TextStyle(
                  fontSize: compact ? 12 : 12.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
              child: const AppText('Entrar'),
            ),
          ],
        ),
      ),
    );
  }

  /// Abre a tela de login a partir do modo teste.
  ///
  /// O botão usa o rótulo curto "Entrar" para caber na faixa compacta,
  /// mas o destino é a página "Aceder à tua conta".
  void _goToAuthentication(BuildContext context) {
    final callback = onAuthenticated;

    if (callback == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Volta ao ecrã inicial para entrar ou criar conta.',
          ),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => LoginFormPage(
          onAuthenticated: callback,
        ),
      ),
    );
  }

  /// Cartão azul superior, agora mais compacto.
  Widget _buildCompactProgressCard({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        compact ? 6 : 8,
        16,
        compact ? 6 : 10,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          18,
          compact ? 10 : 14,
          18,
          compact ? 10 : 14,
        ),
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
                    child: const AppText(
                      'UNIDADE 5',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  SizedBox(height: compact ? 6 : 10),

                  AppText(
                    'Tema: Comunicação e amizades',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 21 : 25,
                      fontWeight: FontWeight.bold,
                      height: 1.18,
                    ),
                  ),

                  SizedBox(height: compact ? 5 : 8),

                  AppText(
                    '3 de 6 atividades concluídas',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: compact ? 13 : 15,
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

            SizedBox(width: compact ? 10 : 12),

            Container(
              width: compact ? 52 : 66,
              height: compact ? 52 : 66,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                color: Colors.white,
                size: compact ? 28 : 34,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Título visual da área principal de atividades.
  Widget _buildMapTitle({bool compact = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        compact ? 2 : 6,
        16,
        compact ? 0 : 4,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.auto_awesome,
            color: Colors.lightBlueAccent,
            size: compact ? 16 : 18,
          ),
          const SizedBox(width: 8),
          AppText(
            'MAPA DE ATIVIDADES',
            style: TextStyle(
              color: Colors.white,
              fontSize: compact ? 13 : 15,
              letterSpacing: 1.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.auto_awesome,
            color: Colors.lightBlueAccent,
            size: compact ? 16 : 18,
          ),
        ],
      ),
    );
  }

  /// Mapa vertical gamificado.
///
/// No mobile, o mapa acompanha a largura disponível.
/// Na Web/desktop, a largura máxima é limitada para evitar que os nós
/// fiquem demasiado afastados nas extremidades do ecrã.
Widget _buildActivityMap(
  BuildContext context,
  List<LessonItem> lessons, {
  bool compact = false,
}) {
  return Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(
        // Ajusta este valor se quiseres o mapa mais aberto ou mais compacto.
        // 760 mantém os nós alternados, mas visualmente próximos no Web.
        maxWidth: 760,
      ),
      child: Column(
        children: List.generate(lessons.length, (index) {
          final lesson = lessons[index];

          // Alterna entre esquerda e direita para simular um percurso.
          final alignLeft = index % 2 == 0;

          return Padding(
            padding: EdgeInsets.symmetric(vertical: compact ? 8 : 14),
            child: Align(
              alignment:
                  alignLeft ? Alignment.centerLeft : Alignment.centerRight,
              child: Padding(
                padding: EdgeInsets.only(
                  left: alignLeft ? (compact ? 28 : 42) : 0,
                  right: alignLeft ? 0 : (compact ? 28 : 42),
                ),
                child: LessonNode(
                  lesson: lesson,
                  onTap: () {
                    if (lesson.type == LessonType.vocabulario) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const VocabularyPairsPage(),
                        ),
                      );
                      return;
                    }

                    if (lesson.type == LessonType.dialogo) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const DialoguePage(),
                        ),
                      );
                      return;
                    }

                    if (lesson.type == LessonType.quiz) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const QuizPage(),
                        ),
                      );
                      return;
                    }

                    if (lesson.type == LessonType.revisao) {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const RevisionPage(),
                        ),
                      );
                      return;
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: AppText(
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
            const AppText(
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
        content: AppText(message),
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
                      AppText(
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
                      AppText(
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