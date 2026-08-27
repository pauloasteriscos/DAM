import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/facades/activity_workflow_facade.dart';
import '../state/app_session_controller.dart';

/// Página de execução/submissão da atividade.
///
/// Nesta Sprint 2, a atividade ainda é simplificada:
/// - mostra a URL devolvida pelo deploy;
/// - permite escrever uma resposta;
/// - submete via serviço mockado/POST /submit;
/// - guarda o resultado localmente em SQLite.
///
/// O fluxo de submissão é delegado para ActivityWorkflowFacade,
/// reduzindo o acoplamento desta tela com API, DAO, SQLite e Repository.
///
/// Nesta versão, o ecrã foi ajustado para a identidade visual do DailyTalk.pt,
/// mantendo a função principal: executar a atividade e submeter uma resposta.
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

  static const Color _backgroundColor = Color(0xFF061823);
  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _fieldColor = Color(0xFF061823);
  static const Color _accentColor = Color(0xFF35C8FF);

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
      final facade = await ActivityWorkflowFacade.create();

      final result = await facade.submitAnswerForRemoteActivity(
        remoteActivityId: widget.remoteActivityId,
        activityType: widget.activityType,
        answerText: _answerController.text.trim(),
        nativeLanguageCode: 'pt-PT',
        targetLanguageCode: 'it-IT',
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 760;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: const AppText(
          'Atividade',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w500),
        ),
      ),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.25,
                  colors: [
                    Color(0xFF103653),
                    Color(0xFF061823),
                    Color(0xFF041019),
                  ],
                ),
              ),
            ),
          ),

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: isCompact ? 160 : 205,
            child: IgnorePointer(
              child: Opacity(
                opacity: isCompact ? 0.42 : 0.54,
                child: Image.asset(
                  'assets/branding/dailytalk_login_footer.png',
                  fit: BoxFit.fitWidth,
                  alignment: Alignment.bottomCenter,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
          ),

          SafeArea(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                22,
                isCompact ? 10 : 18,
                22,
                isCompact ? 40 : 54,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: Column(
                    children: [
                      _buildActivityInfoCard(isCompact: isCompact),
                      const SizedBox(height: 16),
                      _buildSubmissionCard(),
                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        _buildErrorBox(),
                      ],
                      if (_result != null) ...[
                        const SizedBox(height: 16),
                        _buildResultCard(),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityInfoCard({required bool isCompact}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildStatusBadge(
            icon: Icons.play_circle_fill,
            color: _accentColor,
            isCompact: isCompact,
          ),
          const SizedBox(height: 16),
          const AppText(
            'Desafio pronto',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          AppText(
            'A atividade foi preparada. Lê o enunciado, responde e submete para receber feedback.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.72),
              fontSize: 15,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoChip('Tipo', widget.activityType),
          const SizedBox(height: 14),
          _buildUrlBox(),
        ],
      ),
    );
  }

  Widget _buildSubmissionCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  color: Colors.white.withValues(alpha: 0.74),
                  size: 26,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: AppText(
                    'Resposta da atividade',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _answerController,
              minLines: 3,
              maxLines: 5,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              cursorColor: _accentColor,
              decoration: _inputDecoration(),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return context.tr('Escreve uma resposta antes de submeter.');
                }

                return null;
              },
            ),
            const SizedBox(height: 18),
            _buildPrimaryButton(),
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
        color: Colors.greenAccent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.58)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.check_circle_outline,
            color: Colors.greenAccent,
            size: 52,
          ),
          const SizedBox(height: 12),
          const AppText(
            'Resultado guardado',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _buildMetricChip('Pontuação', '${score ?? '-'}'),
              _buildMetricChip('Estado', syncStatus),
            ],
          ),
          const SizedBox(height: 14),
          AppText(
            feedback,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge({
    required IconData icon,
    required Color color,
    required bool isCompact,
  }) {
    final badgeSize = isCompact ? 78.0 : 88.0;

    return Container(
      width: badgeSize,
      height: badgeSize,
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
            blurRadius: 20,
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
        child: Icon(icon, color: color, size: 46),
      ),
    );
  }

  Widget _buildInfoChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _accentColor.withValues(alpha: 0.42)),
      ),
      child: AppText(
        '${context.tr(label)}: $value',
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _accentColor,
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildMetricChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: AppText(
        '${context.tr(label)}: $value',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildUrlBox() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: _fieldColor.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
      ),
      child: Column(
        children: [
          AppText(
            'URL devolvida pelo deploy',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          SelectableText(
            widget.activityUrl,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _accentColor,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration() {
    return InputDecoration(
      labelText: context.tr('Escreve a tua resposta'),
      alignLabelWithHint: true,
      labelStyle: TextStyle(
        color: Colors.white.withValues(alpha: 0.66),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
      hintText: context.tr('Ex.: resposta ao diálogo, quiz ou atividade...'),
      hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.34)),
      filled: true,
      fillColor: _fieldColor.withValues(alpha: 0.78),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 17),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(22)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.25,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: _accentColor, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.35),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      width: double.infinity,
      height: 58,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: _isSubmitting
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
          boxShadow: _isSubmitting
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
          onPressed: _isSubmitting ? null : _submitAnswer,
          icon: _isSubmitting
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined, size: 24),
          label: AppText(
            _isSubmitting ? 'A submeter...' : 'Submeter resposta',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
