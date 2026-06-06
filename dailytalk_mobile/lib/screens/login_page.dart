import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import 'login_form_page.dart';
import '../state/app_session_controller.dart';
import 'main_navigation.dart';
import 'register_page.dart';

/// Ecrã inicial do DailyTalk.pt.
///
/// Esta página deixou de apresentar imediatamente os campos de autenticação.
/// O objetivo é responder melhor à primeira decisão do utilizador:
/// - experimentar a aplicação sem conta;
/// - entrar numa conta existente;
/// - criar uma nova conta.
///
/// Assim, a ação principal fica visível sem scroll e o formulário de login
/// passa para uma página própria, preparada para integrações futuras como SSO.
class LoginPage extends StatelessWidget {
  const LoginPage({
    super.key,
    required this.onAuthenticated,
  });

  final VoidCallback onAuthenticated;

  static const Color _backgroundColor = Color(0xFF061823);
  static const Color _accentColor = Color(0xFF35C8FF);

  void _openTestMode(BuildContext context) {
    AppSessionScope.read(context).startTestMode();

    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => MainNavigation(
          onAuthenticated: onAuthenticated,
        ),
      ),
    );
  }

  void _openLoginForm(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => LoginFormPage(
          onAuthenticated: onAuthenticated,
        ),
      ),
    );
  }

  void _openRegister(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => RegisterPage(
          onAuthenticated: onAuthenticated,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 720;

    return Scaffold(
      backgroundColor: _backgroundColor,
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

          /// Rodapé decorativo.
          ///
          /// Mantém a composição visual do ecrã, mas não interfere com
          /// botões ou navegação.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: isCompact ? 220 : 180,
            child: IgnorePointer(
              child: Opacity(
                opacity: isCompact ? 0.78 : 0.62,
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
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.fromLTRB(
                  24,
                  isCompact ? 0 : 8,
                  24,
                  isCompact ? 88 : 64,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildBrandHeader(isCompact: isCompact),

                      SizedBox(height: isCompact ? 24 : 32),

                      _buildPrimaryButton(
                        icon: Icons.play_arrow_rounded,
                        label: 'Testar agora',
                        onPressed: () => _openTestMode(context),
                      ),

                      const SizedBox(height: 14),

                      _buildFilledSecondaryButton(
                        icon: Icons.login,
                        label: 'Entrar',
                        onPressed: () => _openLoginForm(context),
                      ),

                      const SizedBox(height: 14),

                      _buildOutlinedButton(
                        icon: Icons.person_add_alt_1_outlined,
                        label: 'Criar conta',
                        onPressed: () => _openRegister(context),
                      ),

                      SizedBox(height: isCompact ? 18 : 24),

                      _buildInfoAppText(),
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

  /// Cabeçalho visual da página inicial.
  ///
  /// Usa o mesmo asset do login anterior para preservar a identidade visual
  /// já validada no protótipo.
  Widget _buildBrandHeader({required bool isCompact}) {
    return Column(
      children: [
        SizedBox(
          height: isCompact ? 215 : 275,
          width: double.infinity,
          child: Image.asset(
            'assets/branding/dailytalk_login_hero.png',
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.record_voice_over,
                color: _accentColor,
                size: 82,
              );
            },
          ),
        ),

        SizedBox(height: isCompact ? 4 : 8),

        /// FittedBox evita a quebra desta frase em telemóveis estreitos.
        const FittedBox(
          fit: BoxFit.scaleDown,
          child: AppText(
            'Serious game para aprendizagem de idiomas',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: _accentColor,
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),

        const SizedBox(height: 8),

        AppText(
          'Pratica diálogos antes da mobilidade escolar',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.76),
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 56,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          gradient: const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF49D7FF),
              Color(0xFF168CFF),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF168CFF).withValues(alpha: 0.34),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, size: 26),
          label: AppText(
            label,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
            ),
          ),
          style: ElevatedButton.styleFrom(
            elevation: 0,
            shadowColor: Colors.transparent,
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilledSecondaryButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: AppText(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: FilledButton.styleFrom(
          foregroundColor: Colors.white,
          backgroundColor: const Color(0xFF0B2B3C).withValues(alpha: 0.92),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
            side: BorderSide(
              color: Colors.white.withValues(alpha: 0.18),
              width: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOutlinedButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: AppText(
          label,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: _accentColor,
          backgroundColor: _backgroundColor.withValues(alpha: 0.42),
          side: BorderSide(
            color: _accentColor.withValues(alpha: 0.95),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoAppText() {
    return AppText(
      'Podes experimentar sem conta. Para guardar progresso e sincronizar, entra ou cria uma conta.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withValues(alpha: 0.68),
        fontSize: 13.5,
        fontWeight: FontWeight.w500,
        height: 1.35,
      ),
    );
  }
}
