import 'package:flutter/material.dart';

import '../screens/language_selection_page.dart';

/// Menu superior de três pontos.
///
/// Este menu concentra ações globais da aplicação,
/// como seleção de idioma, sincronização, ajuda e informação sobre a app.
class TopOverflowMenu extends StatelessWidget {
  const TopOverflowMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TopMenuAction>(
      icon: const Icon(
        Icons.more_vert,
        color: Colors.white,
        size: 30,
      ),
      color: const Color(0xFF14252D),
      onSelected: (action) {
        switch (action) {
          case _TopMenuAction.language:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSelectionPage(),
              ),
            );
            break;

          case _TopMenuAction.sync:
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Sincronização será implementada nesta área.'),
              ),
            );
            break;

          case _TopMenuAction.help:
            _showHelpDialog(context);
            break;

          case _TopMenuAction.about:
            _showAboutDailyTalkDialog(context);
            break;
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: _TopMenuAction.language,
            child: _MenuItemContent(
              icon: Icons.language,
              text: 'Language',
            ),
          ),
          PopupMenuItem(
            value: _TopMenuAction.sync,
            child: _MenuItemContent(
              icon: Icons.sync,
              text: 'Sincronizar',
            ),
          ),
          PopupMenuItem(
            value: _TopMenuAction.help,
            child: _MenuItemContent(
              icon: Icons.help_outline,
              text: 'Ajuda',
            ),
          ),
          PopupMenuItem(
            value: _TopMenuAction.about,
            child: _MenuItemContent(
              icon: Icons.info_outline,
              text: 'Sobre',
            ),
          ),
        ];
      },
    );
  }

  /// Mostra uma ajuda curta para o utilizador final.
  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14252D),
          title: const Text(
            'Ajuda',
            style: TextStyle(color: Colors.white),
          ),
          content: const Text(
            'Usa a Home para acompanhar o teu percurso de atividades.\n\n'
            'Em Atividade, podes configurar uma nova prática escolhendo o cenário, '
            'o idioma, a dificuldade e o tipo de exercício.\n\n'
            'Em Resultados, poderás acompanhar o teu progresso. '
            'Em Análises, professores poderão consultar métricas de aprendizagem.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }

  /// Mostra informação sobre a aplicação para o utilizador final.
  ///
  /// Este texto evita linguagem académica ou técnica e foca-se no valor
  /// da aplicação para alunos, jogadores e comunidade.
  void _showAboutDailyTalkDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14252D),
          title: const Text(
            'Sobre o DailyTalk.pt',
            style: TextStyle(color: Colors.white),
          ),
          content: const SingleChildScrollView(
            child: Text(
              'O DailyTalk.pt ajuda-te a praticar comunicação em situações reais '
              'do quotidiano escolar, através de atividades de vocabulário, áudio, '
              'diálogos, quizzes e desafios.\n\n'
              'A aplicação inclui atividades criadas pela equipa DailyTalk.pt e, '
              'progressivamente, também poderá incluir atividades criadas pela comunidade.\n\n'
              'Cada jogador pode propor atividades com base nas suas próprias dificuldades. '
              'Essas atividades poderão ser analisadas antes de ficarem disponíveis para '
              'outros utilizadores, garantindo que são úteis, seguras e adequadas.\n\n'
              'As atividades bem avaliadas pela comunidade podem ganhar destaque, subir '
              'no topo das recomendações e ajudar mais jogadores.\n\n'
              'Quem cria atividades úteis poderá ganhar pontos, aumentar a sua reputação '
              'como ajudante da comunidade e desbloquear itens de personalização, como '
              'skins e outros elementos visuais.\n\n'
              'Atividades rejeitadas ou sinalizadas poderão ser revistas pela equipa '
              'mantenedora, podendo ser corrigidas, reformuladas ou removidas.',
              style: TextStyle(
                color: Colors.white70,
                height: 1.4,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
  }
}

/// Ações disponíveis no menu superior.
enum _TopMenuAction {
  language,
  sync,
  help,
  about,
}

/// Conteúdo visual de cada item do menu.
class _MenuItemContent extends StatelessWidget {
  const _MenuItemContent({
    required this.icon,
    required this.text,
  });

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          icon,
          color: Colors.white70,
          size: 22,
        ),
        const SizedBox(width: 12),
        Text(
          text,
          style: const TextStyle(
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}