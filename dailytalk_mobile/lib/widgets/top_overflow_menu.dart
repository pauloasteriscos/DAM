import 'package:flutter/material.dart';

import '../screens/account_page.dart';
import '../screens/create_activity_page.dart';
import '../screens/language_selection_page.dart';
import '../screens/my_activities_page.dart';

import '../data/facades/activity_workflow_facade.dart';
import 'dailytalk_support_dialogs.dart';

/// Menu superior de três pontos.
///
/// Este menu concentra ações globais e secundárias da aplicação.
/// A ação principal da app é praticar atividades.
/// A criação de atividades fica como opção secundária.
class TopOverflowMenu extends StatelessWidget {
  const TopOverflowMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_TopMenuAction>(
      icon: const Icon(Icons.more_vert, color: Colors.white, size: 30),
      color: const Color(0xFF14252D),
      onSelected: (action) {
        switch (action) {
          case _TopMenuAction.account:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AccountPage(),
              ),
            );
            break;

          case _TopMenuAction.language:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSelectionPage(),
              ),
            );
            break;

          case _TopMenuAction.createActivity:
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateActivityPage(),
              ),
            );
            break;

          case _TopMenuAction.myActivities:
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyActivitiesPage()),
            );
            break;

          case _TopMenuAction.help:
            DailyTalkSupportDialogs.showHelp(context);
            break;

          case _TopMenuAction.sync:
            _syncPendingSubmissions(context);
            break;

          case _TopMenuAction.about:
            DailyTalkSupportDialogs.showAbout(context);
            break;
        }
      },
      itemBuilder: (context) {
        return const [
          PopupMenuItem(
            value: _TopMenuAction.account,
            child: _MenuItemContent(icon: Icons.account_circle_outlined, text: 'Conta'),
          ),
          PopupMenuItem(
            value: _TopMenuAction.language,
            child: _MenuItemContent(icon: Icons.language, text: 'Language'),
          ),
          PopupMenuItem(
            value: _TopMenuAction.createActivity,
            child: _MenuItemContent(
              icon: Icons.add_circle_outline,
              text: 'Criar atividade',
            ),
          ),
          PopupMenuItem(
            value: _TopMenuAction.myActivities,
            child: _MenuItemContent(
              icon: Icons.folder_special_outlined,
              text: 'Minhas atividades',
            ),
          ),
          PopupMenuItem(
            value: _TopMenuAction.help,
            child: _MenuItemContent(icon: Icons.help_outline, text: 'Ajuda'),
          ),
          PopupMenuItem(
            value: _TopMenuAction.sync,
            child: _MenuItemContent(icon: Icons.sync, text: 'Sincronizar'),
          ),
          PopupMenuItem(
            value: _TopMenuAction.about,
            child: _MenuItemContent(icon: Icons.info_outline, text: 'Sobre'),
          ),
        ];
      },
    );
  }

  Future<void> _syncPendingSubmissions(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      final facade = await ActivityWorkflowFacade.create();
      final result = await facade.syncPendingSubmissions();

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '${result.message} '
            'Sincronizadas: ${result.syncedCount}. '
            'Falhas: ${result.failedCount}.',
          ),
        ),
      );
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Erro ao sincronizar: $error'),
        ),
      );
    }
  }

}

/// Ações disponíveis no menu superior.
enum _TopMenuAction {
  account,
  language,
  createActivity,
  myActivities,
  help,
  sync,
  about,
}

/// Conteúdo visual de cada item do menu.
class _MenuItemContent extends StatelessWidget {
  const _MenuItemContent({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70, size: 22),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }
}
