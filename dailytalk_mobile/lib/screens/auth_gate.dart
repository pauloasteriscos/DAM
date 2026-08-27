import 'package:flutter/material.dart';

import '../state/app_locale_controller.dart';
import '../state/app_session_controller.dart';
import 'login_page.dart';
import 'main_navigation.dart';

/// Decide se a app abre na navegação principal ou na entrada inicial.
///
/// O estado de sessão é centralizado em [AppSessionController].
/// Assim, o modo teste deixa de ser um parâmetro isolado de uma página e passa
/// a ser um estado global observado por toda a aplicação.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    Future.microtask(_initializeSession);
  }

  Future<void> _initializeSession() async {
    final session = AppSessionController.instance;
    await session.checkStoredSession();

    final appLanguageCode = session.currentUser?.preferences.appLanguageCode;
    if (appLanguageCode != null) {
      await AppLocaleController.instance.setLanguageCode(
        appLanguageCode,
        persist: true,
      );
    }
  }

  void _handleAuthenticated() {
    AppSessionController.instance.markAuthenticated();
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);

    if (session.isChecking) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B22),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (session.isAuthenticated) {
      return const MainNavigation();
    }

    return LoginPage(onAuthenticated: _handleAuthenticated);
  }
}
