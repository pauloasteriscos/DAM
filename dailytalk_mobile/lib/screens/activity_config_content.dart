import 'package:flutter/material.dart';

import '../data/api/dailytalk_api_service.dart';
import '../data/dao/activity_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/activity_repository.dart';
import 'activity_display_page.dart';

/// Conteúdo real da página de configuração da atividade.
///
/// Este widget é colocado dentro do PlaceholderPage,
/// para manter a estrutura visual já existente e apenas acrescentar funcionalidade.
class ActivityConfigContent extends StatefulWidget {
  const ActivityConfigContent({super.key});

  @override
  State<ActivityConfigContent> createState() => _ActivityConfigContentState();
}

class _ActivityConfigContentState extends State<ActivityConfigContent> {
  final _formKey = GlobalKey<FormState>();

  final _scenarioController = TextEditingController(
    text: 'sala de aula',
  );

  String _languageCode = 'pt-PT';
  String _difficulty = 'Média';
  String _activityType = 'dialogo';

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _scenarioController.dispose();
    super.dispose();
  }

  /// Constrói o repositório que coordena API + SQLite.
  Future<ActivityRepository> _buildRepository() async {
    final db = await AppDatabase.instance.database;

    return ActivityRepository(
      apiService: DailyTalkApiService(),
      activityDao: ActivityDao(db),
    );
  }

  /// Valida o formulário, cria a atividade localmente,
  /// executa o deploy e abre a página de exibição da atividade.
  Future<void> _startActivity() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final repository = await _buildRepository();

      final remoteActivityId = 'DT-${DateTime.now().millisecondsSinceEpoch}';

      final activityUrl = await repository.createAndDeployActivity(
        remoteActivityId: remoteActivityId,
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
            activityUrl: activityUrl,
          ),
        ),
      );
    } catch (error) {
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
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _buildTextField(),
            const SizedBox(height: 16),

            _buildDropdown(
              label: 'Idioma',
              value: _languageCode,
              icon: Icons.language,
              items: const {
                'pt-PT': 'Português',
                'en-US': 'English',
                'es-ES': 'Español',
                'fr-FR': 'Français',
              },
              onChanged: (value) {
                setState(() {
                  _languageCode = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            _buildDropdown(
              label: 'Dificuldade',
              value: _difficulty,
              icon: Icons.speed,
              items: const {
                'Inicial': 'Inicial',
                'Média': 'Média',
                'Avançada': 'Avançada',
              },
              onChanged: (value) {
                setState(() {
                  _difficulty = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            _buildDropdown(
              label: 'Tipo de atividade',
              value: _activityType,
              icon: Icons.category,
              items: const {
                'vocabulario': 'Vocabulário',
                'audio': 'Áudio',
                'dialogo': 'Diálogo',
                'quiz': 'Quiz',
              },
              onChanged: (value) {
                setState(() {
                  _activityType = value!;
                });
              },
            ),

            const SizedBox(height: 22),

            if (_errorMessage != null) _buildErrorBox(),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _startActivity,
                icon: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(
                  _isLoading ? 'A iniciar...' : 'Iniciar atividade',
                  style: const TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Campo textual para o cenário da atividade.
  Widget _buildTextField() {
    return TextFormField(
      controller: _scenarioController,
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        label: 'Cenário',
        hint: 'Ex.: sala de aula',
        icon: Icons.edit,
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Informe o cenário da atividade.';
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
      dropdownColor: const Color(0xFF14252D),
      style: const TextStyle(color: Colors.white),
      decoration: _inputDecoration(
        label: label,
        icon: icon,
      ),
      items: items.entries.map((entry) {
        return DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value),
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
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      labelStyle: const TextStyle(color: Colors.white70),
      hintStyle: const TextStyle(color: Colors.white38),
      prefixIconColor: Colors.lightBlue,
      filled: true,
      fillColor: const Color(0xFF0D1B22),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.white24),
      ),
    );
  }

  /// Caixa visual para apresentar erros de validação, rede ou deploy.
  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.redAccent,
        ),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(
          color: Colors.redAccent,
        ),
      ),
    );
  }
}