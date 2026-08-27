import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

import '../data/repositories/auth_repository.dart';
import '../state/app_locale_controller.dart';
import '../state/app_session_controller.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

/// Página de autenticação do DailyTalk.pt.
///
/// Esta página concentra o login real por email/password e deixa preparada
/// a zona de autenticação por serviços padrão, como Google Account.
/// Nesta versão de protótipo, o botão Google apenas apresenta feedback
/// informativo, porque a integração SSO ainda não está implementada.
class LoginFormPage extends StatefulWidget {
  const LoginFormPage({super.key, required this.onAuthenticated});

  final VoidCallback onAuthenticated;

  @override
  State<LoginFormPage> createState() => _LoginFormPageState();
}

class _LoginFormPageState extends State<LoginFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  static const Color _backgroundColor = Color(0xFF061823);
  static const Color _fieldColor = Color(0xFF071D2A);
  static const Color _accentColor = Color(0xFF35C8FF);

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      await AppLocaleScope.read(
        context,
      ).setLanguageCode(user.preferences.appLanguageCode, persist: true);

      if (!mounted) {
        return;
      }

      AppSessionScope.read(context).markAuthenticated(user);
      widget.onAuthenticated();

      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
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

  void _openRegister() {
    // Substitui a página de login pelo registo para evitar uma pilha de
    // navegação desnecessária caso o utilizador crie conta com sucesso.
    Navigator.pushReplacement(
      context,
      MaterialPageRoute<void>(
        builder: (context) =>
            RegisterPage(onAuthenticated: widget.onAuthenticated),
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (context) => ForgotPasswordPage(
          initialEmail: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
        ),
      ),
    );
  }

  void _showGooglePrototypeMessage() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF10232D),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          title: const Row(
            children: [
              Icon(Icons.info_outline, color: _accentColor),
              SizedBox(width: 10),
              Expanded(
                child: AppText(
                  'Integração futura',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          content: AppText(
            'Nesta versão de protótipo, o acesso com Google Account ainda não está disponível. '
            'A funcionalidade está prevista para uma versão futura, permitindo uma autenticação mais rápida e segura.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.82),
              height: 1.35,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const AppText(
                'Compreendi',
                style: TextStyle(
                  color: _accentColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        );
      },
    );
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
          'Entrar',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
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
                opacity: isCompact ? 0.52 : 0.62,
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
                  isCompact ? 8 : 18,
                  22,
                  isCompact ? 36 : 48,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBrandBadge(isCompact: isCompact),

                        SizedBox(height: isCompact ? 14 : 18),

                        const AppText(
                          'Aceder à tua conta',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            height: 1.15,
                          ),
                        ),

                        const SizedBox(height: 8),

                        AppText(
                          'Guarda progresso, resultados e sincroniza entre dispositivos.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 14.5,
                            fontWeight: FontWeight.w500,
                            height: 1.35,
                          ),
                        ),

                        SizedBox(height: isCompact ? 22 : 30),

                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return context.tr('Indica o email.');
                            }

                            if (!value.contains('@')) {
                              return context.tr('Indica um email válido.');
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 14),

                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            tooltip: context.tr(
                              _obscurePassword
                                  ? 'Mostrar password'
                                  : 'Ocultar password',
                            ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: Colors.white.withValues(alpha: 0.78),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return context.tr('Indica a password.');
                            }

                            return null;
                          },
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _openForgotPassword,
                            style: TextButton.styleFrom(
                              foregroundColor: _accentColor,
                            ),
                            child: const AppText('Esqueci a palavra-passe'),
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          _buildErrorBox(_errorMessage!),
                        ],

                        SizedBox(height: isCompact ? 14 : 22),

                        _buildPrimaryButton(),

                        const SizedBox(height: 18),

                        _buildDivider(),

                        const SizedBox(height: 18),

                        _buildGoogleButton(),

                        const SizedBox(height: 18),

                        TextButton(
                          onPressed: _isLoading ? null : _openRegister,
                          style: TextButton.styleFrom(
                            foregroundColor: _accentColor,
                          ),
                          child: const AppText(
                            'Ainda não tem conta? Criar conta',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ],
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

  Widget _buildBrandBadge({required bool isCompact}) {
    return Center(
      child: Container(
        width: isCompact ? 84 : 98,
        height: isCompact ? 84 : 98,
        decoration: BoxDecoration(
          color: const Color(0xFF071D2A).withValues(alpha: 0.88),
          shape: BoxShape.circle,
          border: Border.all(
            color: _accentColor.withValues(alpha: 0.55),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _accentColor.withValues(alpha: 0.18),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipOval(
          child: Image.asset(
            'assets/branding/dailytalk_mascot.png',
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.record_voice_over,
                color: _accentColor,
                size: 44,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
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
          color: Colors.white.withValues(alpha: 0.68),
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.76),
            size: 25,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 54,
          minHeight: 52,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: _fieldColor.withValues(alpha: 0.78),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
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
      height: 56,
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
          onPressed: _isLoading ? null : _login,
          icon: _isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.login, size: 24),
          label: AppText(
            _isLoading ? 'A entrar...' : 'Entrar',
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
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

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.22))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: AppText(
            'ou',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.62),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(child: Divider(color: Colors.white.withValues(alpha: 0.22))),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _showGooglePrototypeMessage,
        icon: const Icon(Icons.account_circle_outlined, size: 22),
        label: const AppText(
          'Continuar com Google',
          style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white38,
          backgroundColor: _backgroundColor.withValues(alpha: 0.42),
          side: BorderSide(
            color: Colors.white.withValues(alpha: 0.26),
            width: 1.35,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
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
