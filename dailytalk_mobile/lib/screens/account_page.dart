import 'package:flutter/material.dart';

import '../data/repositories/auth_repository.dart';
import '../models/auth_user.dart';
import 'auth_gate.dart';

/// Página de conta do utilizador autenticado.
///
/// Esta versão mantém a funcionalidade existente, mas aproxima o ecrã da
/// identidade visual do DailyTalk.pt: fundo com gradiente, cartões arredondados,
/// ícones neutros e ações claramente diferenciadas.
class AccountPage extends StatefulWidget {
  const AccountPage({super.key});

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final AuthRepository _authRepository = AuthRepository();

  late Future<AuthUser?> _userFuture;

  static const Color _backgroundColor = Color(0xFF061823);
  static const Color _cardColor = Color(0xFF071D2A);
  static const Color _accentColor = Color(0xFF35C8FF);

  @override
  void initState() {
    super.initState();
    _userFuture = _loadCurrentUser();
  }

  Future<AuthUser?> _loadCurrentUser() async {
    try {
      return await _authRepository.getCurrentUser();
    } catch (_) {
      await _authRepository.logout();
      return null;
    }
  }

  Future<void> _logout() async {
    await _authRepository.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthGate()),
      (route) => false,
    );
  }

  Future<void> _goToLogin() async {
    await _authRepository.logout();

    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const AuthGate()),
      (route) => false,
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
        title: const Text(
          'Conta',
          style: TextStyle(
            fontSize: 26,
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

          FutureBuilder<AuthUser?>(
            future: _userFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(
                  child: CircularProgressIndicator(
                    color: _accentColor,
                  ),
                );
              }

              final user = snapshot.data;

              if (user == null) {
                return _buildMissingSessionState();
              }

              return SafeArea(
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
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _buildProfileCard(user: user, isCompact: isCompact),
                          const SizedBox(height: 18),
                          _buildLogoutButton(),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMissingSessionState() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: _cardDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCircleIcon(
                    icon: Icons.lock_outline,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Sessão não encontrada',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'A sessão guardada neste dispositivo não é válida. Inicia sessão novamente.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.72),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildLoginButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileCard({
    required AuthUser user,
    required bool isCompact,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isCompact ? 18 : 22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildCircleIcon(
            icon: Icons.account_circle_outlined,
            color: _accentColor,
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            user.email,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.68),
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 20),
          _InfoRow(
            icon: Icons.person_pin_circle_outlined,
            label: 'Perfil',
            value: user.preferences.selectedProfile,
          ),
          _InfoRow(
            icon: Icons.language_outlined,
            label: 'Idioma da app',
            value: user.preferences.appLanguageCode,
          ),
          _InfoRow(
            icon: Icons.translate,
            label: 'Idioma de aprendizagem',
            value: user.preferences.learningLanguageCode,
          ),
        ],
      ),
    );
  }

  Widget _buildCircleIcon({
    required IconData icon,
    required Color color,
  }) {
    return Container(
      width: 88,
      height: 88,
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
        child: Icon(
          icon,
          color: color,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      height: 56,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, size: 23),
        label: const Text(
          'Terminar sessão',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.redAccent,
          backgroundColor: _backgroundColor.withValues(alpha: 0.46),
          side: BorderSide(
            color: Colors.redAccent.withValues(alpha: 0.75),
            width: 1.4,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
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
              color: const Color(0xFF168CFF).withValues(alpha: 0.30),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: _goToLogin,
          icon: const Icon(Icons.login, size: 23),
          label: const Text(
            'Ir para login',
            style: TextStyle(
              fontSize: 16,
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.10),
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: Colors.white.withValues(alpha: 0.68),
            size: 23,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.64),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
