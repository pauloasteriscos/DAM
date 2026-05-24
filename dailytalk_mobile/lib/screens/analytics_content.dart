import 'package:flutter/material.dart';

import '../data/facades/activity_workflow_facade.dart';
import '../models/communication_scenario.dart';
import '../models/user_profile.dart';

/// Conteúdo da página "Análises".
///
/// Nesta fase, apresenta análises pedagógicas locais,
/// agregadas por perfil, cenário e tipo de atividade.
///
/// Importante:
/// - não guarda dados sensíveis;
/// - não apresenta alergias reais;
/// - não apresenta restrições alimentares reais;
/// - apenas usa dados pedagógicos de desempenho.
class AnalyticsContent extends StatefulWidget {
  const AnalyticsContent({super.key});

  @override
  State<AnalyticsContent> createState() => _AnalyticsContentState();
}

class _AnalyticsContentState extends State<AnalyticsContent> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, Object?>> _analytics = [];

  @override
  void initState() {
    super.initState();

    // Carrega as análises automaticamente ao abrir a aba.
    Future.microtask(_loadAnalytics);
  }

  /// Carrega as análises pedagógicas locais através da Facade.
  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final facade = await ActivityWorkflowFacade.create();
      final analytics = await facade.loadPedagogicalAnalytics();

      if (!mounted) {
        return;
      }

      setState(() {
        _analytics = analytics;
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
        _buildPrivacyInfo(),
        const SizedBox(height: 18),

        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _loadAnalytics,
            icon: _isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            label: Text(
              _isLoading ? 'A carregar...' : 'Atualizar análises',
              style: const TextStyle(fontSize: 17),
            ),
          ),
        ),

        const SizedBox(height: 18),

        if (_errorMessage != null) _buildErrorBox(),

        if (!_isLoading && _analytics.isEmpty && _errorMessage == null)
          _buildEmptyState(),

        if (_analytics.isNotEmpty) _buildAnalyticsList(),
      ],
    );
  }

  /// Cartão informativo sobre o tipo de dados apresentados.
  Widget _buildPrivacyInfo() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.lightBlue.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.lightBlueAccent),
      ),
      child: const Column(
        children: [
          Icon(Icons.insights, color: Colors.lightBlueAccent, size: 42),
          SizedBox(height: 10),
          Text(
            'Análises pedagógicas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Estas análises usam apenas dados de desempenho, como perfil, '
            'cenário, tipo de atividade, tentativas e pontuação. '
            'Não guardam dados sensíveis.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ],
      ),
    );
  }

  /// Estado vazio apresentado quando ainda não existem dados.
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14252D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: const Text(
        'Ainda não existem dados pedagógicos suficientes. '
        'Submete algumas atividades na página Praticar para gerar análises.',
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.white70, height: 1.4),
      ),
    );
  }

  /// Lista de análises pedagógicas agregadas.
  Widget _buildAnalyticsList() {
    return Column(
      children: _analytics.map((item) {
        final profile = UserProfileType.fromDatabase(
          item['profile']?.toString(),
        );

        final scenario = CommunicationScenario.fromDatabase(
          item['scenario']?.toString(),
        );

        final activityType = item['activity_type']?.toString() ?? '-';
        final totalAttempts = item['total_attempts']?.toString() ?? '0';
        final totalErrors = item['total_errors']?.toString() ?? '0';

        final averageScoreValue = item['average_score'];
        final averageScore = averageScoreValue is num
            ? averageScoreValue.toStringAsFixed(1)
            : averageScoreValue?.toString() ?? '0';

        final lastScoreValue = item['last_score'];
        final lastScore = lastScoreValue is num
            ? lastScoreValue.toStringAsFixed(1)
            : lastScoreValue?.toString() ?? '-';

        final updatedAt = item['updated_at']?.toString() ?? '-';

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF14252D),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${profile.label} — ${scenario.label}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Tipo de atividade: $activityType',
                style: const TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 6),

              Text(
                'Tentativas: $totalAttempts',
                style: const TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 6),

              Text(
                'Erros estimados: $totalErrors',
                style: const TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 6),

              Text(
                'Última pontuação: $lastScore',
                style: const TextStyle(color: Colors.white70),
              ),

              const SizedBox(height: 6),

              Text(
                'Pontuação média: $averageScore',
                style: const TextStyle(
                  color: Colors.lightBlueAccent,
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Atualizado em: $updatedAt',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  /// Caixa visual para apresentar erros de carregamento.
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
      child: Text(
        _errorMessage!,
        style: const TextStyle(color: Colors.redAccent),
      ),
    );
  }
}
