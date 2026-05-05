import 'package:flutter/material.dart';

import '../data/api/dailytalk_api_service.dart';
import '../data/dao/activity_dao.dart';
import '../data/dao/submission_dao.dart';
import '../data/database/app_database.dart';
import '../data/repositories/submission_repository.dart';

/// Página de execução/submissão da atividade.
///
/// Nesta Sprint 2, a atividade ainda é simplificada:
/// - mostra a URL devolvida pelo deploy;
/// - permite escrever uma resposta;
/// - submete via serviço mockado/POST /submit;
/// - guarda o resultado localmente em SQLite.
class ActivityDisplayPage extends StatefulWidget {
  const ActivityDisplayPage({
    super.key,
    required this.activityUrl,
    required this.remoteActivityId,
    required this.activityType,
  });

  final String activityUrl;
  final String remoteActivityId;
  final String activityType;

  @override
  State<ActivityDisplayPage> createState() => _ActivityDisplayPageState();
}

class _ActivityDisplayPageState extends State<ActivityDisplayPage> {
  final _formKey = GlobalKey<FormState>();

  final _answerController = TextEditingController(
    text: 'Resposta de teste para a atividade DailyTalk.',
  );

  bool _isSubmitting = false;
  String? _errorMessage;
  Map<String, dynamic>? _result;

  @override
  void dispose() {
    _answerController.dispose();
    super.dispose();
  }

  Future<void> _submitAnswer() async {
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

      final activity = await activityDao.getByRemoteActivityId(
        widget.remoteActivityId,
      );

      if (activity == null) {
        throw Exception('Atividade local não encontrada.');
      }

      final localActivityId = activity['id'] as int;

      final repository = SubmissionRepository(
        apiService: DailyTalkApiService(),
        submissionDao: submissionDao,
      );

      final result = await repository.submitAnswer(
        activityId: localActivityId,
        remoteActivityId: widget.remoteActivityId,
        activityType: widget.activityType,
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
    return Scaffold(
      backgroundColor: const Color(0xFF0D1B22),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D1B22),
        foregroundColor: Colors.white,
        title: const Text('Atividade'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              _buildActivityInfoCard(),
              const SizedBox(height: 18),
              _buildSubmissionCard(),
              const SizedBox(height: 18),
              if (_errorMessage != null) _buildErrorBox(),
              if (_result != null) _buildResultCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActivityInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white12,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.play_circle_fill,
            color: Colors.lightBlue,
            size: 78,
          ),
          const SizedBox(height: 18),
          const Text(
            'Atividade iniciada com sucesso.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Tipo: ${widget.activityType}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'URL devolvida pelo deploy:',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            widget.activityUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.lightBlueAccent,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard() {
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
            const Text(
              'Resposta da atividade',
              style: TextStyle(
                color: Colors.white,
                fontSize: 21,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _answerController,
              minLines: 3,
              maxLines: 5,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Escreve a tua resposta',
                alignLabelWithHint: true,
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: 'Ex.: resposta ao diálogo, quiz ou atividade...',
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
                onPressed: _isSubmitting ? null : _submitAnswer,
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
      ),
    );
  }

  Widget _buildResultCard() {
    final score = _result?['score'];
    final feedback = _result?['feedback']?.toString() ?? 'Sem feedback.';
    final syncStatus =
    _result?['sync_status_label']?.toString() ??
    _result?['sync_status']?.toString() ??
    'desconhecido';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.green.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.greenAccent,
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle,
            color: Colors.greenAccent,
            size: 52,
          ),
          const SizedBox(height: 12),
          const Text(
            'Resultado guardado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Pontuação: ${score ?? '-'}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Estado: $syncStatus',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 12),
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