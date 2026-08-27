import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/api/dailytalk_api_service.dart';
import '../data/facades/activity_workflow_facade.dart';
import '../models/app_status.dart';
import '../state/app_event_notifier.dart';
import '../state/app_session_controller.dart';

/// Conteúdo da página "Meus Resultados".
///
/// A página carrega resultados locais e também o histórico remoto associado
/// ao utilizador autenticado. Assim, uma atividade feita na Web pode aparecer
/// no Android, e vice-versa, desde que ambos usem a mesma conta e API.
class ResultsContent extends StatefulWidget {
  const ResultsContent({super.key});

  @override
  State<ResultsContent> createState() => _ResultsContentState();
}

class _ResultsContentState extends State<ResultsContent> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, Object?>> _results = [];

  @override
  void initState() {
    super.initState();

    AppEventNotifier.instance.addListener(_handleAppEvent);

    // Carrega automaticamente quando a página é criada.
    Future.microtask(_loadResults);
  }

  @override
  void dispose() {
    AppEventNotifier.instance.removeListener(_handleAppEvent);
    super.dispose();
  }

  /// Chamado quando algum evento global da app ocorre.
  ///
  /// Exemplo:
  /// - submissão concluída;
  /// - sincronização concluída;
  /// - resultados alterados.
  void _handleAppEvent() {
    if (_isLoading) {
      return;
    }

    _loadResults();
  }

  Future<void> _loadResults() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final facade = await ActivityWorkflowFacade.create();
      final localResults = await facade.loadRecentResults();
      final remoteResults = AppSessionController.instance.isAuthenticated
          ? await DailyTalkApiService().getMySubmissions()
          : <Map<String, dynamic>>[];

      final normalizedRemoteResults = remoteResults
          .map(_normalizeRemoteSubmission)
          .toList();

      if (!mounted) {
        return;
      }

      setState(() {
        _results = [
          ...normalizedRemoteResults,
          ...localResults.map(_normalizeLocalResult),
        ];
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
          _isLoading = false;
        });
      }
    }
  }

  Map<String, Object?> _normalizeRemoteSubmission(Map<String, dynamic> item) {
    final remoteActivityId = item['remote_activity_id']?.toString();

    return <String, Object?>{
      'title': remoteActivityId == null || remoteActivityId.isEmpty
          ? 'Atividade remota'
          : 'Atividade remota: $remoteActivityId',
      'type': item['activity_type']?.toString() ?? '-',
      'score': item['score'],
      'feedback_text': item['feedback']?.toString() ?? 'Sem feedback.',
      'created_at': item['created_at']?.toString() ?? '-',
      'sync_status': SubmissionSyncStatus.synced.databaseValue,
      'origin': 'Cloud/API',
      'remote_activity_id': remoteActivityId,
      'answer_text': item['answer_text']?.toString(),
      'native_language_code': item['native_language_code']?.toString(),
      'target_language_code': item['target_language_code']?.toString(),
    };
  }

  Map<String, Object?> _normalizeLocalResult(Map<String, Object?> item) {
    return <String, Object?>{...item, 'origin': 'Local'};
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);

    return Column(
      children: [
        if (!session.isAuthenticated) ...[
          _buildTestModeInfoCard(),
          const SizedBox(height: 14),
        ],
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _loadResults,
            icon: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: AppText(
              _isLoading ? 'A carregar...' : 'Atualizar resultados',
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ),

        const SizedBox(height: 18),

        if (_errorMessage != null) _buildErrorBox(),

        if (_results.isEmpty && !_isLoading && _errorMessage == null)
          _buildEmptyState(),

        if (_results.isNotEmpty) _buildResultsList(),
      ],
    );
  }

  Widget _buildTestModeInfoCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightBlue.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.lightBlueAccent.withValues(alpha: 0.34),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.visibility_outlined, color: Colors.lightBlueAccent),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              'Modo teste: são mostrados apenas resultados locais. Entra para sincronizar histórico entre dispositivos.',
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: const AppText(
        'Ainda não há resultados disponíveis. '
        'Submete uma atividade para consultar o histórico local.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
    );
  }

  Widget _buildResultsList() {
    return Column(
      children: _results.map((result) {
        final title = result['title']?.toString() ?? 'Atividade';
        final type = result['type']?.toString() ?? '-';
        final score = result['score']?.toString() ?? '-';
        final feedback = result['feedback_text']?.toString() ?? 'Sem feedback.';
        final createdAt = result['created_at']?.toString() ?? '-';
        final origin = result['origin']?.toString() ?? 'Local';
        final answerText = result['answer_text']?.toString();
        final nativeLanguageCode = result['native_language_code']?.toString();
        final targetLanguageCode = result['target_language_code']?.toString();

        final syncStatus = SubmissionSyncStatus.tryFromDatabase(
          result['sync_status']?.toString(),
        );
        final syncStatusLabel = syncStatus?.label ?? 'Não disponível';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF14252D),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: AppText(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  _OriginChip(label: origin),
                ],
              ),

              const SizedBox(height: 8),

              AppText(
                'Tipo: $type',
                style: const TextStyle(color: Colors.white70),
              ),

              if (nativeLanguageCode != null || targetLanguageCode != null) ...[
                const SizedBox(height: 6),
                AppText(
                  'Idiomas: ${nativeLanguageCode ?? '-'} → ${targetLanguageCode ?? '-'}',
                  style: const TextStyle(color: Colors.white70),
                ),
              ],

              const SizedBox(height: 6),

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
                feedback,
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),

              if (answerText != null && answerText.isNotEmpty) ...[
                const SizedBox(height: 8),
                AppText(
                  'Resposta: $answerText',
                  style: const TextStyle(color: Colors.white60, height: 1.4),
                ),
              ],

              const SizedBox(height: 8),

              AppText(
                'Estado: $syncStatusLabel',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),

              const SizedBox(height: 8),

              AppText(
                'Data: $createdAt',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
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

class _OriginChip extends StatelessWidget {
  const _OriginChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white24),
      ),
      child: AppText(
        label,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
