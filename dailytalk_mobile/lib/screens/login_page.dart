import 'package:flutter/material.dart';

import '../data/repositories/auth_repository.dart';
import 'forgot_password_page.dart';
import 'register_page.dart';

/// Página de login do DailyTalk.pt.
///
/// Esta versão reforça a identidade visual da aplicação logo no ecrã inicial:
/// - apresenta a marca DailyTalk.pt com mascote e ícones associados à fala;
/// - comunica rapidamente que é um serious game de aprendizagem de idiomas;
/// - mantém a ação principal de entrada visível e a criação de conta destacada.
class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    required this.onAuthenticated,
  });

  final VoidCallback onAuthenticated;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();

  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

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
      await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) {
        return;
      }

      widget.onAuthenticated();
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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RegisterPage(
          onAuthenticated: widget.onAuthenticated,
        ),
      ),
    );
  }

  void _openForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ForgotPasswordPage(
          initialEmail: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 720;

    return Scaffold(
      backgroundColor: const Color(0xFF061823),
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
          /// campos, botões ou navegação.
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
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildBrandHeader(isCompact: isCompact),

                        SizedBox(height: isCompact ? 18 : 28),

                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Indica o email.';
                            }

                            if (!value.contains('@')) {
                              return 'Indica um email válido.';
                            }

                            return null;
                          },
                        ),

                        const SizedBox(height: 12),

                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            tooltip: _obscurePassword
                                ? 'Mostrar password'
                                : 'Ocultar password',
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
                              return 'Indica a password.';
                            }

                            return null;
                          },
                        ),

                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _isLoading ? null : _openForgotPassword,
                            style: TextButton.styleFrom(
                              foregroundColor: const Color(0xFF35B9FF),
                            ),
                            child: const Text('Esqueci a palavra-passe'),
                          ),
                        ),

                        if (_errorMessage != null) ...[
                          const SizedBox(height: 10),
                          _buildErrorBox(_errorMessage!),
                        ],

                        SizedBox(height: isCompact ? 14 : 22),

                        _buildPrimaryButton(),

                        const SizedBox(height: 16),

                        _buildSecondaryButton(),
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

  /// Cabeçalho visual do login.
  ///
  /// Usa um asset único para manter a identidade visual consistente entre
  /// Android e Web, enquanto o texto principal continua acessível e editável
  /// diretamente no Flutter.
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
                color: Color(0xFF35B9FF),
                size: 82,
              );
            },
          ),
        ),

        SizedBox(height: isCompact ? 4 : 8),

        /// FittedBox evita a quebra desta frase em telemóveis estreitos.
        const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            'Serious game para aprendizagem de idiomas',
            textAlign: TextAlign.center,
            maxLines: 1,
            style: TextStyle(
              color: Color(0xFF35C8FF),
              fontSize: 16.5,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
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
      cursorColor: const Color(0xFF35C8FF),
      decoration: InputDecoration(
        labelText: label,
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
        fillColor: const Color(0xFF071D2A).withValues(alpha: 0.78),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: 0.20),
            width: 1.35,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(
            color: Color(0xFF35C8FF),
            width: 1.8,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.35,
          ),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(
            color: Colors.redAccent,
            width: 1.8,
          ),
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
                  colors: [
                    Color(0xFF49D7FF),
                    Color(0xFF168CFF),
                  ],
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
              : const Icon(
                  Icons.login,
                  size: 24,
                ),
          label: Text(
            _isLoading ? 'A entrar...' : 'Entrar',
            style: const TextStyle(
              fontSize: 19,
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

  Widget _buildSecondaryButton() {
    return SizedBox(
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _openRegister,
        icon: const Icon(
          Icons.person_add_alt_1_outlined,
          size: 22,
        ),
        label: const Text(
          'Criar conta',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: const Color(0xFF35C8FF),
          disabledForegroundColor: Colors.white38,
          backgroundColor: const Color(0xFF061823).withValues(alpha: 0.42),
          side: BorderSide(
            color: const Color(0xFF35C8FF).withValues(alpha: 0.95),
            width: 1.5,
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
        border: Border.all(
          color: Colors.redAccent.withValues(alpha: 0.85),
        ),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Colors.redAccent,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}