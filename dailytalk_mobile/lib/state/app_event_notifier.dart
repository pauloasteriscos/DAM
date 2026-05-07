import 'package:flutter/foundation.dart';


/// Notificador global de eventos da aplicação.
///
/// Implementa uma forma simples de Observer:
/// - as telas interessadas registam-se como observadoras;
/// - quando uma submissão ou sincronização altera os resultados,
///   este notifier avisa os observadores;
/// - a página de Resultados pode recarregar automaticamente.
class AppEventNotifier extends ChangeNotifier {
  AppEventNotifier._();

  static final AppEventNotifier instance = AppEventNotifier._();

  int _resultsVersion = 0;
  int _syncVersion = 0;

  /// Versão lógica dos resultados.
  ///
  /// Aumenta sempre que uma submissão ou sincronização pode alterar
  /// o histórico apresentado ao aluno.
  int get resultsVersion => _resultsVersion;

  /// Versão lógica da sincronização.
  ///
  /// Aumenta sempre que uma operação de sincronização termina.
  int get syncVersion => _syncVersion;

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
}