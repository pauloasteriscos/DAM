import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../state/app_learning_language_controller.dart';
import '../state/app_locale_controller.dart';
import '../state/app_session_controller.dart';
import '../navigation/web_entry_action.dart';
import 'login_form_page.dart';
import 'login_page.dart';
import 'main_navigation.dart';
import 'register_page.dart';

/// Decide se a app abre na navegação principal ou na entrada inicial.
///
/// O estado de sessão é centralizado em [AppSessionController].
/// Assim, o modo teste deixa de ser um parâmetro isolado de uma página e passa
/// a ser um estado global observado por toda a aplicação.
/// Política de routing da raiz.
///
/// Tanto uma conta autenticada como o modo teste pertencem à mesma
/// [MainNavigation]. Apenas o estado sem sessão regressa ao ecrã de entrada.
bool shouldShowMainNavigationForSession(AppSessionStatus status) {
  return status == AppSessionStatus.authenticated ||
      status == AppSessionStatus.testMode;
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key, this.webEntryAction});

  final WebEntryAction? webEntryAction;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _authenticatedPreferencesReady = false;
  WebEntryAction? _pendingWebEntryAction;

  @override
  void initState() {
    super.initState();
    _pendingWebEntryAction =
        widget.webEntryAction ?? WebEntryAction.fromUri(Uri.base);
    Future.microtask(_initializeSession);
  }

  Future<void> _initializeSession() async {
    final session = AppSessionController.instance;
    await session.checkStoredSession();

    if (session.isAuthenticated) {
      final shouldClearDirectAuthAction =
          _pendingWebEntryAction == WebEntryAction.login ||
          _pendingWebEntryAction == WebEntryAction.register;
      _pendingWebEntryAction = null;
      if (shouldClearDirectAuthAction) {
        _clearWebEntryActionFromBrowserUrl();
      }
    } else if (session.isUnauthenticated &&
        _pendingWebEntryAction == WebEntryAction.test) {
      _pendingWebEntryAction = null;
      session.startTestMode();
    }
    final currentUser = session.currentUser;
    if (currentUser != null) {
      // O perfil autenticado é a fonte remota das preferências. Sincronizamos
      // ambos os eixos antes de construir a MainNavigation para evitar que a
      // bandeira/percurso usem uma cache local antiga enquanto as atividades
      // já apresentam o learningLanguageCode devolvido pela API.
      await AppLocaleController.instance.setLanguageCode(
        currentUser.preferences.appLanguageCode,
        persist: true,
      );
      await AppLearningLanguageController.instance.setLanguageCode(
        currentUser.preferences.learningLanguageCode,
        persist: true,
      );
    }

    if (!mounted) {
      return;
    }

    setState(() {
      _authenticatedPreferencesReady = true;
    });
  }

  void _handleAuthenticated() {
    final shouldClearDirectAuthAction =
        _pendingWebEntryAction == WebEntryAction.login ||
        _pendingWebEntryAction == WebEntryAction.register;
    _pendingWebEntryAction = null;
    if (shouldClearDirectAuthAction) {
      _clearWebEntryActionFromBrowserUrl();
    }
    AppSessionController.instance.markAuthenticated();
  }

  void _clearWebEntryActionFromBrowserUrl() {
    SystemNavigator.routeInformationUpdated(
      uri: WebEntryAction.withoutAction(Uri.base),
      replace: true,
    );
  }

  void _returnToEntryMenu() {
    if (!mounted) {
      return;
    }

    setState(() {
      _pendingWebEntryAction = null;
    });
    _clearWebEntryActionFromBrowserUrl();
  }

  Widget _buildDirectEntryNavigator(WebEntryAction action) {
    return Navigator(
      onGenerateInitialRoutes: (navigator, initialRouteName) {
        final Widget directPage = switch (action) {
          WebEntryAction.login => LoginFormPage(
            onAuthenticated: _handleAuthenticated,
          ),
          WebEntryAction.register => RegisterPage(
            onAuthenticated: _handleAuthenticated,
          ),
          WebEntryAction.test => throw StateError(
            'Test mode is routed directly by AuthGate.',
          ),
        };

        return <Route<dynamic>>[
          MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'entry-menu'),
            builder: (_) => LoginPage(onAuthenticated: _handleAuthenticated),
          ),
          MaterialPageRoute<void>(
            settings: RouteSettings(name: action.name),
            builder: (_) => PopScope<void>(
              onPopInvokedWithResult: (didPop, result) {
                if (!didPop) {
                  return;
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _returnToEntryMenu();
                });
              },
              child: directPage,
            ),
          ),
        ];
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final session = AppSessionScope.watch(context);

    if (session.isChecking ||
        (session.isAuthenticated && !_authenticatedPreferencesReady)) {
      return const Scaffold(
        backgroundColor: Color(0xFF0D1B22),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (shouldShowMainNavigationForSession(session.status)) {
      return const MainNavigation();
    }

    if (session.isUnauthenticated &&
        (_pendingWebEntryAction == WebEntryAction.login ||
            _pendingWebEntryAction == WebEntryAction.register)) {
      return _buildDirectEntryNavigator(_pendingWebEntryAction!);
    }

    return LoginPage(onAuthenticated: _handleAuthenticated);
  }
}
