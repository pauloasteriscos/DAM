import 'package:flutter/widgets.dart';

import '../data/repositories/auth_repository.dart';
import '../models/auth_user.dart';

/// Estados globais possíveis da sessão.
///
/// O modo teste é tratado como um estado válido da aplicação, não como erro.
/// Isto permite que as telas reajam corretamente quando não existe sessão,
/// mantendo a experiência de demonstração sem forçar autenticação imediata.
enum AppSessionStatus { checking, unauthenticated, testMode, authenticated }

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
  String? _testModeProgressAccountId;
  int _testModeSequence = 0;

  AppSessionStatus get status => _status;
  AuthUser? get currentUser => _currentUser;

  /// Identificador local usado pelo motor de progresso.
  ///
  /// Em sessão autenticada corresponde à conta real. Em modo teste é um
  /// identificador efémero, válido apenas enquanto esta execução da aplicação
  /// permanecer ativa. Nunca deve ser enviado ao backend.
  String? get learningProgressAccountId {
    if (isAuthenticated) {
      final accountId = _currentUser?.id.trim();

      if (accountId != null && accountId.isNotEmpty) {
        return accountId;
      }

      return null;
    }

    if (isTestMode) {
      return _testModeProgressAccountId;
    }

    return null;
  }

  bool get isChecking => _status == AppSessionStatus.checking;
  bool get isAuthenticated => _status == AppSessionStatus.authenticated;
  bool get isTestMode => _status == AppSessionStatus.testMode;
  bool get isUnauthenticated => _status == AppSessionStatus.unauthenticated;

  /// Valida a sessão guardada no dispositivo.
  ///
  /// Uma falha de rede ou expiração técnica não elimina a sessão local.
  /// O utilizador continua a aceder aos dados em cache e a renovação é tentada
  /// silenciosamente quando a ligação estiver disponível.
  Future<void> checkStoredSession() async {
    _testModeProgressAccountId = null;
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
      // Nunca terminar a sessão automaticamente por falhas transitórias.
      // Sem utilizador em cache, a aplicação apresenta o ecrã inicial, mas os
      // tokens e as chaves permanecem guardados para recuperação posterior.
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
    _testModeProgressAccountId = _createTestModeProgressAccountId();
    _setStatus(AppSessionStatus.testMode);
  }

  /// Marca a sessão como autenticada após login ou registo.
  void markAuthenticated([AuthUser? user]) {
    if (user != null) {
      _currentUser = user;
    }

    _testModeProgressAccountId = null;
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
      // Mantém o utilizador atual e tenta novamente mais tarde.
      notifyListeners();
    }
  }

  /// Termina a sessão e regressa ao estado sem autenticação.
  Future<void> logout() async {
    await _authRepository.logout();
    _currentUser = null;
    _testModeProgressAccountId = null;
    _setStatus(AppSessionStatus.unauthenticated);
  }

  String _createTestModeProgressAccountId() {
    _testModeSequence += 1;

    return 'guest-session:'
        '${DateTime.now().toUtc().microsecondsSinceEpoch}:'
        '$_testModeSequence';
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
    final scope = context.dependOnInheritedWidgetOfExactType<AppSessionScope>();

    assert(
      scope != null,
      'AppSessionScope não encontrado na árvore de widgets.',
    );

    return scope!.notifier!;
  }

  static AppSessionController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AppSessionScope>();

    assert(
      element != null,
      'AppSessionScope não encontrado na árvore de widgets.',
    );

    final scope = element!.widget as AppSessionScope;
    return scope.notifier!;
  }
}
