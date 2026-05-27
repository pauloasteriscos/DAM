import 'package:flutter/material.dart';

import '../data/repositories/auth_repository.dart';
import 'reset_password_page.dart';

/// Página inicial do fluxo de recuperação de palavra-passe.
///
/// Esta versão mantém o fluxo funcional já existente, mas aproxima a tela
/// da identidade visual aplicada ao login e à criação de conta:
/// - fundo escuro com gradiente;
/// - ícone de recuperação em destaque moderado;
/// - campo de email com estilo consistente;
/// - botão principal em gradiente azul;
/// - rodapé visual decorativo.
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({
    super.key,
    this.initialEmail,
  });

  final String? initialEmail;

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authRepository = AuthRepository();

  bool _isLoading = false;
  String? _errorMessage;

  static const Color _backgroundColor = Color(0xFF061823);
  static const Color _fieldColor = Color(0xFF071D2A);
  static const Color _accentColor = Color(0xFF35C8FF);

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestReset() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      final result = await _authRepository.requestPasswordReset(email: email);

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResetPasswordPage(
            email: email,
            initialResetToken: result.debugResetToken,
          ),
        ),
      );
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
    final screenHeight = MediaQuery.sizeOf(context).height;
    final isCompact = screenHeight < 760;

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 0,
        title: const Text(
          'Recuperar palavra-passe',
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w500,
          ),
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
                  isCompact ? 16 : 28,
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
                          _buildRecoveryBadge(isCompact: isCompact),

                          SizedBox(height: isCompact ? 18 : 22),

                          const Text(
                            'Esqueceste a palavra-passe?',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              height: 1.15,
                            ),
                          ),

                          const SizedBox(height: 10),

                          Text(
                            'Indica o email da tua conta para receberes um código temporário e redefinires o acesso.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.74),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                          ),

                          SizedBox(height: isCompact ? 24 : 30),

                          _buildEmailField(),

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

  Widget _buildRecoveryBadge({required bool isCompact}) {
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
            colors: [
              Color(0xFF52D8FF),
              Color(0xFF168CFF),
            ],
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
            Icons.lock_reset_outlined,
            color: _accentColor,
            size: 46,
          ),
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      keyboardType: TextInputType.emailAddress,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w500,
      ),
      cursorColor: _accentColor,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Indica o email.';
        }

        if (!value.contains('@')) {
          return 'Indica um email válido.';
        }

        return null;
      },
      decoration: InputDecoration(
        labelText: 'Email',
        labelStyle: TextStyle(
          color: Colors.white.withValues(alpha: 0.66),
          fontSize: 18,
          fontWeight: FontWeight.w500,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Icon(
            Icons.email_outlined,
            color: Colors.white.withValues(alpha: 0.72),
            size: 27,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 58,
          minHeight: 58,
        ),
        filled: true,
        fillColor: _fieldColor.withValues(alpha: 0.82),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 20,
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
            color: _accentColor,
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
          onPressed: _isLoading ? null : _requestReset,
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
                  Icons.send_outlined,
                  size: 24,
                ),
          label: Text(
            _isLoading ? 'A enviar...' : 'Enviar código por email',
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