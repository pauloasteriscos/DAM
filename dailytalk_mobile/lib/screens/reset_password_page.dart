import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/repositories/auth_repository.dart';

/// Página final do fluxo de recuperação de palavra-passe.
///
/// Mantém a lógica original de validação e alteração da palavra-passe,
/// mas usa a mesma identidade visual aplicada ao login, criação de conta
/// e recuperação de palavra-passe.
class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.email,
    this.initialResetToken,
  });

  final String email;
  final String? initialResetToken;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authRepository = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String? _errorMessage;

  static const Color _backgroundColor = Color(0xFF061823);
  static const Color _fieldColor = Color(0xFF071D2A);
  static const Color _accentColor = Color(0xFF35C8FF);

  @override
  void initState() {
    super.initState();
    _tokenController.text = widget.initialResetToken ?? '';
  }

  @override
  void dispose() {
    _tokenController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authRepository.resetPassword(
        email: widget.email,
        resetToken: _tokenController.text.trim(),
        newPassword: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'Palavra-passe alterada com sucesso. Inicia sessão novamente.',
          ),
        ),
      );

      Navigator.of(context).popUntil((route) => route.isFirst);
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
    final debugToken = widget.initialResetToken;
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
          'Nova palavra-passe',
          style: TextStyle(fontSize: 23, fontWeight: FontWeight.w500),
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
            height: isCompact ? 170 : 210,
            child: IgnorePointer(
              child: Opacity(
                opacity: isCompact ? 0.50 : 0.60,
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
                  22,
                  isCompact ? 10 : 20,
                  22,
                  isCompact ? 42 : 56,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildPasswordBadge(isCompact: isCompact),

                          SizedBox(height: isCompact ? 16 : 20),

                          const AppText(
                            'Define uma nova palavra-passe',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),

                          const SizedBox(height: 10),

                          AppText(
                            debugToken != null && debugToken.isNotEmpty
                                ? context.tr(
                                    'Conta: {email}\nUsa o código temporário abaixo para concluir o teste de recuperação.',
                                    parameters: <String, Object?>{
                                      'email': widget.email,
                                    },
                                  )
                                : context.tr(
                                    'Conta: {email}',
                                    parameters: <String, Object?>{
                                      'email': widget.email,
                                    },
                                  ),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.72),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),

                          if (debugToken != null && debugToken.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildDebugTokenBox(debugToken),
                          ],

                          SizedBox(height: isCompact ? 22 : 28),

                          _buildTextField(
                            controller: _tokenController,
                            label: 'Código de recuperação',
                            icon: Icons.pin_outlined,
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return context.tr(
                                  'Indica o código de recuperação.',
                                );
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          _buildTextField(
                            controller: _passwordController,
                            label: 'Nova password',
                            icon: Icons.lock_outline,
                            obscureText: _obscurePassword,
                            suffixIcon: _buildVisibilityButton(
                              obscure: _obscurePassword,
                              onPressed: () {
                                setState(() {
                                  _obscurePassword = !_obscurePassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value == null || value.length < 6) {
                                return context.tr(
                                  'A password deve ter pelo menos 6 caracteres.',
                                );
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 14),

                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirmar password',
                            icon: Icons.lock_reset_outlined,
                            obscureText: _obscureConfirmPassword,
                            suffixIcon: _buildVisibilityButton(
                              obscure: _obscureConfirmPassword,
                              onPressed: () {
                                setState(() {
                                  _obscureConfirmPassword =
                                      !_obscureConfirmPassword;
                                });
                              },
                            ),
                            validator: (value) {
                              if (value != _passwordController.text) {
                                return context.tr(
                                  'As passwords não coincidem.',
                                );
                              }

                              return null;
                            },
                          ),

                          if (_errorMessage != null) ...[
                            const SizedBox(height: 14),
                            _buildErrorBox(_errorMessage!),
                          ],

                          SizedBox(height: isCompact ? 22 : 28),

                          _buildPrimaryButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordBadge({required bool isCompact}) {
    final badgeSize = isCompact ? 82.0 : 96.0;

    return Center(
      child: Container(
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
              color: _accentColor.withValues(alpha: 0.28),
              blurRadius: 22,
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
            Icons.password_outlined,
            color: _accentColor,
            size: 46,
          ),
        ),
      ),
    );
  }

  Widget _buildDebugTokenBox(String debugToken) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.orangeAccent.withValues(alpha: 0.76)),
      ),
      child: SelectableText(
        context.tr(
          'Versão de protótipo\nNo plano gratuito da Cloudflare, o servidor não envia emails de recuperação. Para permitir testar o fluxo, o código temporário é apresentado aqui.\n\nCódigo: {code}',
          parameters: <String, Object?>{'code': debugToken},
        ),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: Colors.orangeAccent,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
      ),
    );
  }

  Widget _buildVisibilityButton({
    required bool obscure,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: context.tr(obscure ? 'Mostrar password' : 'Ocultar password'),
      icon: Icon(
        obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        color: Colors.white.withValues(alpha: 0.74),
      ),
      onPressed: onPressed,
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      validator: validator,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: _accentColor,
      decoration: InputDecoration(
        labelText: context.tr(label),
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.66),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.72),
            size: 27,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 58,
          minHeight: 58,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _fieldColor.withValues(alpha: 0.82),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(28)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.20),
            width: 1.35,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: _accentColor, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.35),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: Colors.redAccent, width: 1.8),
        ),
      ),
    );
  }

  Widget _buildPrimaryButton() {
    return SizedBox(
      height: 60,
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
                  colors: [Color(0xFF49D7FF), Color(0xFF168CFF)],
                ),
          boxShadow: _isLoading
              ? []
              : [
                  BoxShadow(
                    color: const Color(0xFF168CFF).withValues(alpha: 0.34),
                    blurRadius: 22,
                    offset: const Offset(0, 9),
                  ),
                ],
        ),
        child: ElevatedButton.icon(
          onPressed: _isLoading ? null : _resetPassword,
          icon: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.save_outlined, size: 24),
          label: AppText(
            _isLoading ? 'A guardar...' : 'Alterar palavra-passe',
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

  Widget _buildErrorBox(String message) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.85)),
      ),
      child: AppText(
        message,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
