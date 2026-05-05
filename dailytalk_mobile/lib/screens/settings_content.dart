import 'package:flutter/material.dart';

import 'create_activity_page.dart';
import 'language_selection_page.dart';
import 'my_activities_page.dart';

/// Conteúdo da página de Ajustes.
///
/// Concentra opções secundárias da aplicação, incluindo idioma,
/// comunidade, criação de atividades, ajuda e sincronização.
class SettingsContent extends StatelessWidget {
  const SettingsContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SettingsButton(
          icon: Icons.language,
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
        const SizedBox(height: 12),
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
        const SizedBox(height: 12),
        _SettingsButton(
          icon: Icons.sync,
          title: 'Sincronizar',
          description:
              'Atualizar dados e enviar submissões pendentes quando houver ligação.',
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Sincronização será implementada com a fila sync_queue.',
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 12),
        _SettingsButton(
          icon: Icons.help_outline,
          title: 'Ajuda',
          description: 'Ver instruções rápidas de utilização.',
          onTap: () {
            _showHelpDialog(context);
          },
        ),
        const SizedBox(height: 12),
        _SettingsButton(
          icon: Icons.info_outline,
          title: 'Sobre',
          description: 'Informação sobre o DailyTalk.pt.',
          onTap: () {
            _showAboutDialog(context);
          },
        ),
      ],
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF14252D),
          title: const Text('Ajuda', style: TextStyle(color: Colors.white)),
          content: const Text(
            'Usa a Home para acompanhar o teu percurso.\n\n'
            'Em Praticar, responde a atividades predefinidas.\n\n'
            'Em Resultados, acompanha o teu desempenho.\n\n'
            'A criação de atividades é uma opção secundária, disponível no menu superior e nos Ajustes.',
            style: TextStyle(color: Colors.white70, height: 1.4),
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

  void _showAboutDialog(BuildContext context) {
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
              'A aplicação inclui atividades criadas pela equipa DailyTalk.pt e '
              'também poderá incluir atividades propostas pela comunidade.\n\n'
              'Quem cria atividades úteis poderá ganhar pontos, aumentar a reputação '
              'como ajudante da comunidade e desbloquear itens de personalização.',
              style: TextStyle(color: Colors.white70, height: 1.4),
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

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF14252D),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Row(
            children: [
              Icon(icon, color: Colors.lightBlueAccent, size: 34),
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
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white54),
            ],
          ),
        ),
      ),
    );
  }
}
