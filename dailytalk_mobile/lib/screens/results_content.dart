import 'package:flutter/material.dart';

import '../data/facades/activity_workflow_facade.dart';
import '../models/app_status.dart';
import '../state/app_event_notifier.dart';

/// Conteúdo da página "Meus Resultados".
///
/// Nesta Sprint 2, a página permite carregar resultados
/// guardados localmente após submissão de atividades.
///
/// Agora também observa eventos da aplicação:
/// quando uma submissão ou sincronização altera os resultados,
/// esta página recarrega automaticamente.
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

      final results = await facade.loadRecentResults();

      if (!mounted) {
        return;
      }

      setState(() {
        _results = results;
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
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
            label: Text(
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

  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: const Text(
        'Ainda não há resultados disponíveis. '
        'Submete uma atividade para consultar o histórico.',
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
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Tipo: $type',
                style: const TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 6),

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
                style: const TextStyle(color: Colors.white70, height: 1.4),
              ),

              const SizedBox(height: 8),

              Text(
                'Estado: $syncStatusLabel',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),

              const SizedBox(height: 8),

              Text(
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}