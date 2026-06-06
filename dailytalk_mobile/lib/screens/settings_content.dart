import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/facades/activity_workflow_facade.dart';
import '../state/app_session_controller.dart';
import '../widgets/dailytalk_support_dialogs.dart';
import 'account_page.dart';
import 'create_activity_page.dart';
import 'language_selection_page.dart';
import 'login_form_page.dart';
import 'my_activities_page.dart';
import 'private_notes_page.dart';
import 'profile_selection_page.dart';
import 'register_page.dart';

/// Conteúdo da página de Ajustes.
///
/// Em modo teste, esta página distingue preferências locais de funcionalidades
/// que dependem de conta. Assim, o utilizador não é bloqueado em opções como
/// idioma/perfil, mas recebe feedback claro quando algo exige autenticação.
class SettingsContent extends StatelessWidget {
  const SettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session.isTestMode) ...[
          _buildTestModeInfoCard(),
          const SizedBox(height: 18),
        ],

        _buildSectionTitle('Conta e preferências'),

        _SettingsButton(
          icon: Icons.account_circle_outlined,
          title: 'Conta',
          description: session.isAuthenticated
              ? 'Ver dados do perfil autenticado e terminar sessão.'
              : 'Entrar ou criar conta para guardar progresso e sincronizar.',
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
          description: session.isAuthenticated
              ? 'Escolher entre Estudante, Anfitrião ou Professor.'
              : 'Escolher perfil localmente durante o modo teste.',
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
          description: session.isAuthenticated
              ? 'Choose your language and the language you want to learn.'
              : 'Alterar idiomas localmente durante o modo teste.',
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
          description: session.isAuthenticated
              ? 'Criar uma atividade com base nas tuas dificuldades.'
              : 'Funcionalidade disponível depois de entrares na conta.',
          onTap: () {
            if (!session.isAuthenticated) {
              _showAuthenticationRequiredDialog(context);
              return;
            }

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
          description: session.isAuthenticated
              ? 'Ver atividades criadas por ti e o seu estado de aprovação.'
              : 'Disponível com conta, para associar atividades ao teu perfil.',
          onTap: () {
            if (!session.isAuthenticated) {
              _showAuthenticationRequiredDialog(context);
              return;
            }

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
          description: session.isAuthenticated
              ? 'Atualizar dados e enviar submissões pendentes quando houver ligação.'
              : 'Entra para sincronizar o progresso com a tua conta.',
          onTap: () {
            if (!session.isAuthenticated) {
              _showAuthenticationRequiredDialog(context);
              return;
            }

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

  Widget _buildTestModeInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.lightBlueAccent.withValues(alpha: 0.34)),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: Colors.lightBlueAccent),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              'Modo teste ativo. Podes alterar idioma e perfil localmente; para sincronizar, entra ou cria conta.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.76),
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 4),
      child: AppText(
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

  /// Mostra um diálogo claro quando a funcionalidade exige conta.
  void _showAuthenticationRequiredDialog(BuildContext context) {
    final session = AppSessionScope.read(context);

    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10232D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const AppText(
            'Conta necessária',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: AppText(
            'Esta funcionalidade precisa de conta para guardar e sincronizar os teus dados.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.76),
              height: 1.4,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const AppText('Continuar a testar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => RegisterPage(
                      onAuthenticated: () => session.markAuthenticated(),
                    ),
                  ),
                );
              },
              child: const AppText('Criar conta'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (context) => LoginFormPage(
                      onAuthenticated: () => session.markAuthenticated(),
                    ),
                  ),
                );
              },
              child: const AppText('Entrar'),
            ),
          ],
        );
      },
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

      // O ecrã pode ter sido removido enquanto a operação assíncrona decorria.
      // Neste caso, não devemos reutilizar o BuildContext nem mostrar feedback.
      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: AppText(
            '${context.tr(result.message)} '
            '${context.tr('Sincronizadas')}: ${result.syncedCount}. '
            '${context.tr('Falhas')}: ${result.failedCount}.',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) return;

      messenger.showSnackBar(
        SnackBar(content: AppText('Erro ao sincronizar: $error')),
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
                    AppText(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    AppText(
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
