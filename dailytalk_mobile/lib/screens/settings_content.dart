import 'package:flutter/material.dart';

import '../data/facades/activity_workflow_facade.dart';
import 'account_page.dart';
import 'create_activity_page.dart';
import 'language_selection_page.dart';
import 'my_activities_page.dart';
import 'profile_selection_page.dart';
import 'private_notes_page.dart';
import '../widgets/dailytalk_support_dialogs.dart';

/// Conteúdo da página de Ajustes.
///
/// Concentra opções secundárias da aplicação, mantendo a navegação simples
/// e agrupando funcionalidades por intenção: perfil, aprendizagem,
/// privacidade/sincronização e apoio.
class SettingsContent extends StatelessWidget {
  const SettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSectionTitle('Conta e preferências'),

        _SettingsButton(
          icon: Icons.account_circle_outlined,
          title: 'Conta',
          description: 'Ver dados do perfil autenticado e terminar sessão.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountPage()),
            );
          },
        ),

        const SizedBox(height: 12),

        _SettingsButton(
          icon: Icons.person_pin_circle_outlined,
          title: 'Perfil',
          description: 'Escolher entre Estudante, Anfitrião ou Professor.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ProfileSelectionPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        _SettingsButton(
          icon: Icons.translate,
          title: 'Language',
          description:
              'Choose your language and the language you want to learn.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const LanguageSelectionPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Atividades'),

        _SettingsButton(
          icon: Icons.add_circle_outline,
          title: 'Criar atividade',
          description: 'Criar uma atividade com base nas tuas dificuldades.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const CreateActivityPage(),
              ),
            );
          },
        ),

        const SizedBox(height: 12),

        _SettingsButton(
          icon: Icons.folder_special_outlined,
          title: 'Minhas atividades',
          description:
              'Ver atividades criadas por ti e o seu estado de aprovação.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const MyActivitiesPage()),
            );
          },
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Privacidade e dados'),

        _SettingsButton(
          icon: Icons.lock_outline,
          title: 'Notas privadas',
          description:
              'Guardar notas opcionais apenas neste dispositivo, sem sincronização.',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const PrivateNotesPage()),
            );
          },
        ),

        const SizedBox(height: 12),

        _SettingsButton(
          icon: Icons.sync,
          title: 'Sincronizar',
          description:
              'Atualizar dados e enviar submissões pendentes quando houver ligação.',
          onTap: () {
            _syncPendingSubmissions(context);
          },
        ),

        const SizedBox(height: 22),
        _buildSectionTitle('Apoio'),

        _SettingsButton(
          icon: Icons.help_outline,
          title: 'Ajuda',
          description: 'Ver instruções rápidas de utilização.',
          onTap: () {
            DailyTalkSupportDialogs.showHelp(context);
          },
        ),

        const SizedBox(height: 12),

        _SettingsButton(
          icon: Icons.info_outline,
          title: 'Sobre',
          description: 'Informação sobre o DailyTalk.pt.',
          onTap: () {
            DailyTalkSupportDialogs.showAbout(context);
          },
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.74),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  /// Executa a sincronização de submissões pendentes através da Facade.
  ///
  /// A Facade delega a operação para o Command responsável pela sincronização.
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
        SnackBar(content: Text('Erro ao sincronizar: $error')),
      );
    }
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton({
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _accentColor = Color(0xFF35C8FF);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _cardColor.withValues(alpha: 0.82),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.14),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _accentColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _accentColor.withValues(alpha: 0.26),
                  ),
                ),
                child: Icon(icon, color: _accentColor, size: 29),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.70),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons.chevron_right,
                color: Colors.white.withValues(alpha: 0.46),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
