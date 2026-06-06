import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/dao/app_settings_dao.dart';
import '../data/database/app_database.dart';
import '../data/facades/activity_workflow_facade.dart';
import '../models/practice_activity.dart';
import '../models/user_profile.dart';
import '../state/app_event_notifier.dart';
import '../state/app_session_controller.dart';

/// Conteúdo da página "Praticar".
///
/// Esta página representa o foco principal da aplicação:
/// praticar atividades já existentes/predefinidas.
///
/// A atividade apresentada considera o perfil selecionado:
/// - Estudante;
/// - Anfitrião;
/// - Professor.
class PracticeContent extends StatefulWidget {
  const PracticeContent({super.key});

  @override
  State<PracticeContent> createState() => _PracticeContentState();
}

class _PracticeContentState extends State<PracticeContent> {
  final _formKey = GlobalKey<FormState>();
  final _answerController = TextEditingController();

  bool _isLoadingProfile = true;
  bool _isSubmitting = false;

  String? _errorMessage;
  Map<String, dynamic>? _result;

  UserProfileType _selectedProfile = UserProfileType.student;

  int _lastProfileVersion = AppEventNotifier.instance.profileVersion;

  @override
  void initState() {
    super.initState();

    AppEventNotifier.instance.addListener(_handleAppEvent);
    _loadSelectedProfile();
  }

  @override
  void dispose() {
    AppEventNotifier.instance.removeListener(_handleAppEvent);
    _answerController.dispose();
    super.dispose();
  }

  /// Recarrega o perfil quando a aplicação notifica alteração de perfil.
  void _handleAppEvent() {
    final currentProfileVersion = AppEventNotifier.instance.profileVersion;

    if (currentProfileVersion != _lastProfileVersion) {
      _lastProfileVersion = currentProfileVersion;
      _loadSelectedProfile();
    }
  }

  /// Lê o perfil atualmente guardado em app_settings.
  Future<void> _loadSelectedProfile() async {
    try {
      final db = await AppDatabase.instance.database;
      final settingsDao = AppSettingsDao(db);

      final selectedProfile = await settingsDao.getSelectedProfile();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedProfile = selectedProfile;
        _isLoadingProfile = false;
        _result = null;
        _errorMessage = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _errorMessage = error.toString();
        _isLoadingProfile = false;
      });
    }
  }

  /// Atividade prática atual conforme o perfil selecionado.
  PracticeActivity get _currentActivity {
    return PracticeActivityBank.firstForProfile(_selectedProfile);
  }

  /// Título geral apresentado na página.
  String get _practiceTitle {
    switch (_selectedProfile) {
      case UserProfileType.student:
        return 'Prática para Estudante';
      case UserProfileType.host:
        return 'Prática para Anfitrião';
      case UserProfileType.teacher:
        return 'Prática para Professor';
    }
  }

  Future<void> _submitPracticeAnswer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final activity = _currentActivity;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final facade = await ActivityWorkflowFacade.create();

      final result = await facade.submitPracticeAnswer(
        strategy: activity.strategy,
        answerText: _answerController.text.trim(),
        nativeLanguageCode: 'pt-PT',
        targetLanguageCode: 'it-IT',
        remoteActivityIdOverride: activity.remoteActivityId,
        titleOverride: activity.title,
        scenarioOverride: activity.scenario.databaseValue,
        difficultyOverride: activity.difficulty,
        userProfile: _selectedProfile,
        syncWithRemote: AppSessionController.instance.isAuthenticated,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _result = result;
      });
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
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingProfile) {
      return const Center(child: CircularProgressIndicator());
    }

    final activity = _currentActivity;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        children: [
          _buildProfileHeader(activity),
          const SizedBox(height: 18),
          _buildQuestionCard(activity),
          const SizedBox(height: 18),
          if (_errorMessage != null) _buildErrorBox(),
          if (_result != null) _buildResultBox(),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(PracticeActivity activity) {
    return Column(
      children: [
        Icon(
          activity.strategy.icon,
          color: activity.strategy.fillColor,
          size: 58,
        ),
        const SizedBox(height: 12),
        AppText(
          _practiceTitle,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        AppText(
          'Perfil: ${_selectedProfile.label}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.lightBlueAccent,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        AppText(
          'Cenário: ${activity.scenario.label}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 15),
        ),
        const SizedBox(height: 12),
        AppText(
          activity.title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 19,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        AppText(
          activity.description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, height: 1.4),
        ),
      ],
    );
  }

  Widget _buildQuestionCard(PracticeActivity activity) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const AppText(
            'Desafio',
            style: TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          AppText(
            activity.question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 19,
              height: 1.35,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _answerController,
            minLines: 3,
            maxLines: 5,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: context.tr('A tua resposta'),
              alignLabelWithHint: true,
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: context.tr(activity.answerHint),
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF0D1B22),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.white24),
              ),
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return context.tr('Escreve uma resposta antes de submeter.');
              }

              return null;
            },
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _submitPracticeAnswer,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: AppText(
                _isSubmitting ? 'A submeter...' : 'Submeter resposta',
                style: const TextStyle(fontSize: 17),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBox() {
    final score = _result?['score']?.toString() ?? '-';
    final feedback = _result?['feedback']?.toString() ?? 'Sem feedback.';
    final syncStatus =
        _result?['sync_status_label']?.toString() ??
        _result?['sync_status']?.toString() ??
        'desconhecido';

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.greenAccent),
      ),
      child: Column(
        children: [
          const Icon(Icons.check_circle, color: Colors.greenAccent, size: 44),
          const SizedBox(height: 10),
          const AppText(
            'Resposta submetida',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            'Pontuação: $score',
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            'Estado: $syncStatus',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 8),
          AppText(
            feedback,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: AppText(
        _errorMessage!,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
