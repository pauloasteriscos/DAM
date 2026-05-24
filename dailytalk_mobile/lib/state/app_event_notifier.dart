import 'package:flutter/foundation.dart';

/// Notificador global de eventos da aplicação.
///
/// Implementa uma forma simples de Observer:
/// - as telas interessadas registam-se como observadoras;
/// - quando uma submissão, sincronização ou mudança de perfil ocorre,
///   este notifier avisa os observadores.
class AppEventNotifier extends ChangeNotifier {
  AppEventNotifier._();

  static final AppEventNotifier instance = AppEventNotifier._();

  int _resultsVersion = 0;
  int _syncVersion = 0;
  int _profileVersion = 0;

  /// Versão lógica dos resultados.
  int get resultsVersion => _resultsVersion;

  /// Versão lógica da sincronização.
  int get syncVersion => _syncVersion;

  /// Versão lógica do perfil selecionado.
  int get profileVersion => _profileVersion;

  /// Notifica que os resultados locais foram alterados.
  void notifyResultsChanged() {
    _resultsVersion++;
    notifyListeners();
  }

  /// Notifica que uma sincronização terminou.
  void notifySyncCompleted() {
    _syncVersion++;
    notifyListeners();
  }

  /// Notifica que o perfil selecionado foi alterado.
  void notifyProfileChanged() {
    _profileVersion++;
    notifyListeners();
  }
}