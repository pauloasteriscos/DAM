import 'package:flutter/material.dart';

import '../data/api/dailytalk_api_service.dart';
import '../data/dao/activity_dao.dart';
import '../data/dao/submission_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/submission_repository.dart';
import '../strategies/activity_strategy.dart';

/// Conteúdo da página "Praticar".
///
/// Esta página representa o foco principal da aplicação:
/// praticar atividades já existentes/predefinidas.
///
/// A lógica do tipo de atividade é delegada para uma ActivityStrategy.
class PracticeContent extends StatefulWidget {
  const PracticeContent({super.key});

  @override
  State<PracticeContent> createState() => _PracticeContentState();
}

class _PracticeContentState extends State<PracticeContent> {
  final _formKey = GlobalKey<FormState>();

  final _answerController = TextEditingController();

  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;

  /// Estratégia atualmente usada na página Praticar.
  ///
  /// Nesta fase, usamos uma atividade predefinida de diálogo.
  /// Mais tarde, esta estratégia poderá ser escolhida pelo mapa de atividades.
  final ActivityStrategy _strategy = const DialogActivityStrategy();

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitPracticeAnswer() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _result = null;
    });

    try {
      final db = await AppDatabase.instance.database;

      final activityDao = ActivityDao(db);
      final submissionDao = SubmissionDao(db);

      // Garante que a atividade predefinida existe na base local.
      final localActivityId = await activityDao.upsertActivity({
        'remote_activity_id': _strategy.predefinedRemoteActivityId,
        'title': 'Prática: ${_strategy.label}',
        'type': _strategy.type,
        'scenario': _strategy.defaultScenario,
        'language_code': 'it-IT',
        'difficulty': _strategy.defaultDifficulty,
        'source': 'predefined',
        'is_cached': 1,
        'is_active': 1,
      });

      final repository = SubmissionRepository(
        apiService: DailyTalkApiService(),
        submissionDao: submissionDao,
      );

      final result = await repository.submitAnswer(
        activityId: localActivityId,
        remoteActivityId: _strategy.predefinedRemoteActivityId,
        activityType: _strategy.type,
        answerText: _answerController.text.trim(),
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
      child: Column(
        children: [
          _buildActivityHeader(),
          const SizedBox(height: 18),
          _buildQuestionCard(),
          const SizedBox(height: 18),
          if (_errorMessage != null) _buildErrorBox(),
          if (_result != null) _buildResultBox(),
        ],
      ),
    );
  }

  Widget _buildActivityHeader() {
    return Column(
      children: [
        Icon(
          _strategy.icon,
          color: _strategy.fillColor,
          size: 58,
        ),
        const SizedBox(height: 12),
        Text(
          'Atividade predefinida: ${_strategy.label}',
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pratica uma situação simples de comunicação no contexto escolar.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionCard() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          const Text(
            'Pergunta',
            style: TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _strategy.defaultQuestion,
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
              labelText: 'A tua resposta',
              alignLabelWithHint: true,
              labelStyle: const TextStyle(color: Colors.white70),
              hintText: _strategy.answerHint,
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
                return 'Escreve uma resposta antes de submeter.';
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
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.send),
              label: Text(
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

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.greenAccent,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.greenAccent,
            size: 44,
          ),
          const SizedBox(height: 10),
          const Text(
            'Resposta submetida',
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Pontuação: $score',
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            feedback,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white70,
              height: 1.4,
            ),
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