/// Configurações globais da aplicação.
class AppConfig {
  /// Permite executar a app sem backend durante a Sprint.
  ///
  /// Para testar com API real:
  /// flutter run --dart-define=DAILYTALK_USE_MOCK_API=false
  static const bool useMockApi = bool.fromEnvironment(
    'DAILYTALK_USE_MOCK_API',
    defaultValue: false,
  );

  /// URL base da API.
  ///
  /// Produção prevista: https://dailytalk.pt/api
  /// Desenvolvimento local com Wrangler: http://127.0.0.1:8787/api
  static const String apiBaseUrl = String.fromEnvironment(
    'DAILYTALK_API_BASE_URL',
    defaultValue: 'https://dailytalk.pt/api',
  );

  static const Duration apiTimeout = Duration(seconds: 10);
}
