import 'package:flutter/widgets.dart';

import '../data/repositories/auth_repository.dart';
import '../models/auth_user.dart';

/// Estados globais possíveis da sessão.
///
/// O modo teste é tratado como um estado válido da aplicação, não como erro.
/// Isto permite que as telas reajam corretamente quando não existe sessão,
/// mantendo a experiência de demonstração sem forçar autenticação imediata.
enum AppSessionStatus {
  checking,
  unauthenticated,
  testMode,
  authenticated,
}

/// Controlador global de sessão do DailyTalk.pt.
///
/// Implementa o padrão Observer através de [ChangeNotifier].
/// As telas observam este controlador para saber se a aplicação está em:
/// - modo teste;
/// - modo autenticado;
/// - sem sessão;
/// - validação inicial de sessão.
class AppSessionController extends ChangeNotifier {
  AppSessionController._();

  static final AppSessionController instance = AppSessionController._();

  final AuthRepository _authRepository = AuthRepository();

  AppSessionStatus _status = AppSessionStatus.checking;
  AuthUser? _currentUser;

  AppSessionStatus get status => _status;
  AuthUser? get currentUser => _currentUser;

  bool get isChecking => _status == AppSessionStatus.checking;
  bool get isAuthenticated => _status == AppSessionStatus.authenticated;
  bool get isTestMode => _status == AppSessionStatus.testMode;
  bool get isUnauthenticated => _status == AppSessionStatus.unauthenticated;

  /// Valida a sessão guardada no dispositivo.
  ///
  /// Se o token existir mas for inválido, a sessão local é removida para
  /// evitar que a aplicação continue num estado incoerente.
  Future<void> checkStoredSession() async {
    _setStatus(AppSessionStatus.checking);

    try {
      final user = await _authRepository.getCurrentUser();

      if (user == null) {
        _currentUser = null;
        _setStatus(AppSessionStatus.unauthenticated);
        return;
      }

      _currentUser = user;
      _setStatus(AppSessionStatus.authenticated);
    } catch (_) {
      await _authRepository.logout();
      _currentUser = null;
      _setStatus(AppSessionStatus.unauthenticated);
    }
  }

  /// Ativa o modo teste.
  ///
  /// Neste estado, o utilizador pode explorar a aplicação, alterar preferências
  /// locais e executar atividades, mas não sincroniza dados com a conta.
  void startTestMode() {
    _currentUser = null;
    _setStatus(AppSessionStatus.testMode);
  }

  /// Marca a sessão como autenticada após login ou registo.
  void markAuthenticated([AuthUser? user]) {
    if (user != null) {
      _currentUser = user;
    }

    _setStatus(AppSessionStatus.authenticated);
  }

  /// Atualiza os dados do utilizador autenticado, quando existirem.
  Future<void> refreshCurrentUser() async {
    if (!isAuthenticated) {
      return;
    }

    try {
      _currentUser = await _authRepository.getCurrentUser();
      notifyListeners();
    } catch (_) {
      await logout();
    }
  }

  /// Termina a sessão e regressa ao estado sem autenticação.
  Future<void> logout() async {
    await _authRepository.logout();
    _currentUser = null;
    _setStatus(AppSessionStatus.unauthenticated);
  }

  void _setStatus(AppSessionStatus status) {
    if (_status == status) {
      notifyListeners();
      return;
    }

    _status = status;
    notifyListeners();
  }
}

/// Escopo global que disponibiliza [AppSessionController] à árvore Flutter.
///
/// Usa [InheritedNotifier], que é uma implementação direta do padrão Observer
/// no Flutter: quando o controlador notifica alterações, os widgets que usam
/// [watch] são reconstruídos automaticamente.
class AppSessionScope extends InheritedNotifier<AppSessionController> {
  const AppSessionScope({
    super.key,
    required AppSessionController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppSessionController watch(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<AppSessionScope>();

    assert(
      scope != null,
      'AppSessionScope não encontrado na árvore de widgets.',
    );

    return scope!.notifier!;
  }

  static AppSessionController read(BuildContext context) {
    final element = context.getElementForInheritedWidgetOfExactType<AppSessionScope>();

    assert(
      element != null,
      'AppSessionScope não encontrado na árvore de widgets.',
    );

    final scope = element!.widget as AppSessionScope;
    return scope.notifier!;
  }
}
