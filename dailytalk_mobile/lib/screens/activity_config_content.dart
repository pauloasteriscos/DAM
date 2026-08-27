import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/facades/activity_workflow_facade.dart';
import '../strategies/activity_strategy.dart';
import 'activity_display_page.dart';

/// Conteúdo real da página de configuração da atividade.
///
/// Este widget é colocado dentro do PlaceholderPage,
/// para manter a estrutura visual já existente e apenas acrescentar funcionalidade.
///
/// Nesta versão, a configuração foi redesenhada para ficar coerente com a
/// identidade visual aplicada ao login, criação de conta e seleção de idiomas.
class ActivityConfigContent extends StatefulWidget {
  const ActivityConfigContent({super.key});

  @override
  State<ActivityConfigContent> createState() => _ActivityConfigContentState();
}

class _ActivityConfigContentState extends State<ActivityConfigContent> {
  final _formKey = GlobalKey<FormState>();

  final _scenarioController = TextEditingController(text: 'sala de aula');

  String _languageCode = 'pt-PT';
  String _difficulty = 'Média';
  String _activityType = 'dialogo';

  bool _isLoading = false;
  String? _errorMessage;

  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _fieldColor = Color(0xFF061823);
  static const Color _accentColor = Color(0xFF35C8FF);

  @override
  void dispose() {
    _scenarioController.dispose();
    super.dispose();
  }

  /// Valida o formulário, cria a atividade localmente,
  /// executa o deploy e abre a página de exibição da atividade.
  ///
  /// A criação, persistência local e deploy são delegados à Facade,
  /// evitando que esta tela conheça diretamente API, DAO e Repository.
  Future<void> _startActivity() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final facade = await ActivityWorkflowFacade.create();

      final launchResult = await facade.createAndDeployActivity(
        title: 'DailyTalk - ${_scenarioController.text.trim()}',
        type: _activityType,
        scenario: _scenarioController.text.trim(),
        languageCode: _languageCode,
        difficulty: _difficulty,
      );

      if (!mounted) {
        return;
      }

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ActivityDisplayPage(
            activityUrl: launchResult.activityUrl,
            remoteActivityId: launchResult.remoteActivityId,
            activityType: launchResult.activityType,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(),
            const SizedBox(height: 20),

            _buildTextField(),
            const SizedBox(height: 14),

            _buildDropdown(
              label: 'Idioma a praticar',
              value: _languageCode,
              icon: Icons.language,
              items: const {
                'pt-PT': 'Português',
                'en-US': 'English',
                'es-ES': 'Español',
                'fr-FR': 'Français',
                'it-IT': 'Italiano',
                'de-DE': 'Deutsch',
              },
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _languageCode = value;
                });
              },
            ),

            const SizedBox(height: 14),

            _buildDropdown(
              label: 'Dificuldade',
              value: _difficulty,
              icon: Icons.speed_outlined,
              items: const {
                'Inicial': 'Inicial',
                'Média': 'Média',
                'Avançada': 'Avançada',
              },
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _difficulty = value;
                });
              },
            ),

            const SizedBox(height: 14),

            _buildDropdown(
              label: 'Tipo de atividade',
              value: _activityType,
              icon: Icons.category_outlined,
              items: ActivityStrategyFactory.creationOptions,
              onChanged: (value) {
                if (value == null) {
                  return;
                }

                setState(() {
                  _activityType = value;
                });
              },
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              _buildErrorBox(),
            ],

            const SizedBox(height: 22),

            _buildPrimaryButton(),
          ],
        ),
      ),
    );
  }

  /// Cabeçalho do cartão de configuração.
  ///
  /// Explica rapidamente o objetivo do formulário antes de o utilizador
  /// preencher o cenário e as opções da atividade.
  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF52D8FF), Color(0xFF168CFF)],
            ),
            boxShadow: [
              BoxShadow(
                color: _accentColor.withValues(alpha: 0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Container(
            margin: const EdgeInsets.all(5),
            decoration: const BoxDecoration(
              color: Color(0xFF092333),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.tune_outlined,
              color: _accentColor,
              size: 30,
            ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText(
                'Configura o desafio',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 6),
              AppText(
                'Escolhe o contexto, o idioma, a dificuldade e o tipo de atividade antes de começar.',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.70),
                  fontSize: 14,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Campo textual para o cenário da atividade.
  Widget _buildTextField() {
    return TextFormField(
      controller: _scenarioController,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: _accentColor,
      decoration: _inputDecoration(
        label: 'Cenário',
        hint: 'Ex.: sala de aula',
        icon: Icons.edit_outlined,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return context.tr('Indica o cenário da atividade.');
        }

        return null;
      },
    );
  }

  /// Dropdown reutilizável para idioma, dificuldade e tipo de atividade.
  Widget _buildDropdown({
    required String label,
    required String value,
    required IconData icon,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      dropdownColor: const Color(0xFF102A38),
      iconEnabledColor: Colors.white.withValues(alpha: 0.74),
      style: const TextStyle(
        color: Colors.white,
        fontSize: 17,
        fontWeight: FontWeight.w500,
      ),
      decoration: _inputDecoration(label: label, icon: icon),
      items: items.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: AppText(entry.value),
        );
      }).toList(),
      onChanged: onChanged,
    );
  }

  /// Decoração padrão dos campos do formulário.
  InputDecoration _inputDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: context.tr(label),
      hintText: hint == null ? null : context.tr(hint),
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.66),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.34)),
      prefixIcon: Padding(
        padding: const EdgeInsets.only(left: 14, right: 8),
        child: Icon(
          icon,
          color: Colors.white.withValues(alpha: 0.72),
          size: 25,
        ),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 56, minHeight: 56),
      filled: true,
      fillColor: _fieldColor.withValues(alpha: 0.78),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.25,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: _accentColor, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.35),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(24),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  /// Botão principal para iniciar a atividade configurada.
  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: _isLoading
              ? LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.22),
                    Colors.white.withValues(alpha: 0.14),
                  ],
                )
              : const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0xFF49D7FF), Color(0xFF168CFF)],
                ),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF168CFF).withValues(alpha: 0.30),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _startActivity,
          icon: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.play_arrow, size: 25),
          label: AppText(
            _isLoading ? 'A iniciar...' : 'Iniciar atividade',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  /// Caixa visual para apresentar erros de validação, rede ou deploy.
  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.85)),
      ),
      child: AppText(
        _errorMessage!,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: _cardColor.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: Colors.white.withValues(alpha: 0.14),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.18),
          blurRadius: 18,
          offset: const Offset(0, 9),
        ),
      ],
    );
  }
}
