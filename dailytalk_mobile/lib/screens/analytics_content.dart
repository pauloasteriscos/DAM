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
///
/// Nesta versão, os cartões foram ajustados para manter coerência visual
/// com as restantes telas redesenhadas do DailyTalk.pt.
class AnalyticsContent extends StatefulWidget {
  const AnalyticsContent({super.key});

  @override
  State<AnalyticsContent> createState() => _AnalyticsContentState();
}

class _AnalyticsContentState extends State<AnalyticsContent> {
  bool _isLoading = false;
  String? _errorMessage;
  List<Map<String, Object?>> _analytics = [];

  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _accentColor = Color(0xFF35C8FF);

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

        _buildRefreshButton(),

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
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(
        borderColor: _accentColor.withValues(alpha: 0.36),
        color: _accentColor.withValues(alpha: 0.10),
      ),
      child: Column(
        children: [
          _buildInsightBadge(),
          const SizedBox(height: 12),
          const Text(
            'Análises pedagógicas',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Estas análises usam apenas dados de desempenho, como perfil, cenário, tipo de atividade, tentativas e pontuação. Não guardam dados sensíveis.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 14.5,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// Estado vazio apresentado quando ainda não existem dados.
  Widget _buildEmptyState() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          Icon(
            Icons.hourglass_empty,
            color: Colors.white.withValues(alpha: 0.70),
            size: 38,
          ),
          const SizedBox(height: 12),
          const Text(
            'Ainda não há dados suficientes',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Submete algumas atividades na página Praticar para gerar análises pedagógicas.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.70),
              height: 1.4,
            ),
          ),
        ],
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
          decoration: _cardDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: _accentColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: _accentColor.withValues(alpha: 0.30),
                      ),
                    ),
                    child: const Icon(
                      Icons.bar_chart,
                      color: _accentColor,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${profile.label} — ${scenario.label}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            height: 1.20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tipo de atividade: $activityType',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.62),
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              Wrap(
                spacing: 9,
                runSpacing: 9,
                children: [
                  _buildMetricChip('Tentativas', totalAttempts),
                  _buildMetricChip('Erros', totalErrors),
                  _buildMetricChip('Última', lastScore),
                  _buildMetricChip('Média', averageScore, highlighted: true),
                ],
              ),

              const SizedBox(height: 12),

              Text(
                'Atualizado em: $updatedAt',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.36),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildInsightBadge() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF52D8FF),
            Color(0xFF168CFF),
          ],
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
          Icons.insights,
          color: _accentColor,
          size: 38,
        ),
      ),
    );
  }

  Widget _buildRefreshButton() {
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
                  colors: [
                    Color(0xFF49D7FF),
                    Color(0xFF168CFF),
                  ],
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
          onPressed: _isLoading ? null : _loadAnalytics,
          icon: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.refresh,
                  size: 24,
                ),
          label: Text(
            _isLoading ? 'A carregar...' : 'Atualizar análises',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
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

  Widget _buildMetricChip(
    String label,
    String value, {
    bool highlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: highlighted
            ? _accentColor.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: highlighted
              ? _accentColor.withValues(alpha: 0.38)
              : Colors.white.withValues(alpha: 0.11),
        ),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: highlighted ? _accentColor : Colors.white.withValues(alpha: 0.82),
          fontSize: 13.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  /// Caixa visual para apresentar erros de carregamento.
  Widget _buildErrorBox() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.85),
        ),
      ),
      child: Text(
        _errorMessage!,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  BoxDecoration _cardDecoration({
    Color? color,
    Color? borderColor,
  }) {
    return BoxDecoration(
      color: color ?? _cardColor.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(
        color: borderColor ?? Colors.white.withValues(alpha: 0.14),
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
