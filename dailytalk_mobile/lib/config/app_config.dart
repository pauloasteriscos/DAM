/// Configurações globais da aplicação.
class AppConfig {
  /// Permite executar a app sem backend durante a Sprint.
  ///
  /// Para testar com API mock:
  /// flutter run --dart-define=DAILYTALK_USE_MOCK_API=true
  static const bool useMockApi = bool.fromEnvironment(
    'DAILYTALK_USE_MOCK_API',
    defaultValue: false,
  );

  /// Permite forçar manualmente a URL da API.
  ///
  /// Quando este valor é indicado por `--dart-define`, ele tem prioridade
  /// sobre a deteção automática do ambiente.
  ///
  /// Exemplo:
  /// flutter run -d chrome \
  ///   --dart-define=DAILYTALK_API_BASE_URL=http://localhost:8787/api
  static const String _apiBaseUrlOverride = String.fromEnvironment(
    'DAILYTALK_API_BASE_URL',
    defaultValue: '',
  );

  /// Porta usada pela API local quando a app Web está a correr em localhost.
  ///
  /// Por defeito, corresponde à porta habitual do `wrangler dev`.
  static const int _localApiPort = int.fromEnvironment(
    'DAILYTALK_LOCAL_API_PORT',
    defaultValue: 8787,
  );

  /// URL base da API.
  ///
  /// Regras:
  /// - se `DAILYTALK_API_BASE_URL` for definido, usa esse valor;
  /// - se a app estiver em `dailytalk.pt`, usa a API de produção;
  /// - se a app Web estiver em `localhost` ou `localhost`, usa a API local;
  /// - se estiver noutro domínio Web, usa o mesmo domínio com `/api`;
  /// - em Android/desktop, onde não existe host Web, usa produção por defeito.
  static String get apiBaseUrl {
    if (_apiBaseUrlOverride.trim().isNotEmpty) {
      return _normalizeApiBaseUrl(_apiBaseUrlOverride);
    }

    final currentUri = Uri.base;
    final host = currentUri.host.toLowerCase();
    final scheme = currentUri.scheme == 'http' ? 'http' : 'https';

    if (host == 'dailytalk.pt' || host == 'www.dailytalk.pt') {
      return 'https://dailytalk.pt/api';
    }

    if (host == 'localhost' || host == 'localhost') {
      return '$scheme://$host:$_localApiPort/api';
    }

    if (host.isNotEmpty &&
        (currentUri.scheme == 'http' || currentUri.scheme == 'https')) {
      final port = currentUri.hasPort ? ':${currentUri.port}' : '';
      return '$scheme://$host$port/api';
    }

    return 'https://dailytalk.pt/api';
  }

  static String _normalizeApiBaseUrl(String value) {
    final trimmed = value.trim();

    if (trimmed.endsWith('/')) {
      return trimmed.substring(0, trimmed.length - 1);
    }

    return trimmed;
  }

  static const Duration apiTimeout = Duration(seconds: 10);
}
