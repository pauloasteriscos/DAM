import 'package:flutter/material.dart';

import '../data/repositories/auth_repository.dart';
import 'login_page.dart';
import 'main_navigation.dart';

/// Decide se a app abre no login ou na navegação principal.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthRepository _authRepository = AuthRepository();

  bool _isLoading = true;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    final authenticated = await _authRepository.isLoggedIn();

    if (!mounted) {
      return;
    }

    setState(() {
      _isAuthenticated = authenticated;
      _isLoading = false;
    });
  }

  void _handleAuthenticated() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B22),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_isAuthenticated) {
      return const MainNavigation();
    }

    return LoginPage(onAuthenticated: _handleAuthenticated);
  }
}
