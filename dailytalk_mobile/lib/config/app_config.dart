import 'package:flutter/foundation.dart';

enum AppEnvironment { development, production }

/// Configuração central e automática de ambiente.
///
/// A aplicação trabalha em modo fail-closed:
/// - dailytalk.pt / www.dailytalk.pt -> PRD;
/// - localhost / 127.0.0.1 -> DEV;
/// - qualquer outro host Web -> execução recusada.
///
/// Não existe fallback de DEV para PRD nem de PRD para DEV.
class AppConfig {
  static const String _productionApiBaseUrl = 'https://dailytalk.pt/api';
  static const String _productionApplicationBaseUrl = 'https://dailytalk.pt';
  static const int _localApiPort = 8787;
  static const int _localWebPort = 5555;

  static const String environmentHeaderName = 'X-DailyTalk-Environment';
  static const String environmentResponseHeaderName = 'x-dailytalk-environment';

  /// Permite executar a app sem backend durante testes isolados.
  static const bool useMockApi = bool.fromEnvironment(
    'DAILYTALK_USE_MOCK_API',
    defaultValue: false,
  );

  static AppEnvironment get environment {
    if (kIsWeb) {
      return _webEnvironment(Uri.base);
    }

    // Em aplicações nativas, o tipo de build determina o ambiente.
    // Release nunca contacta DEV; debug/profile nunca contacta PRD.
    return kReleaseMode
        ? AppEnvironment.production
        : AppEnvironment.development;
  }

  static String get environmentCode =>
      environment == AppEnvironment.production ? 'PRD' : 'DEV';

  static bool get isProductionApi => environment == AppEnvironment.production;

  static bool get isDevelopmentApi => environment == AppEnvironment.development;

  /// URL base da API determinada automaticamente e sem fallback cruzado.
  static String get apiBaseUrl {
    if (kIsWeb) {
      final currentUri = Uri.base;
      final detectedEnvironment = _webEnvironment(currentUri);

      if (detectedEnvironment == AppEnvironment.production) {
        return _productionApiBaseUrl;
      }

      return 'http://${currentUri.host}:$_localApiPort/api';
    }

    if (environment == AppEnvironment.production) {
      return _productionApiBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      // Alias do host para o emulador Android.
      return 'http://10.0.2.2:$_localApiPort/api';
    }

    return 'http://127.0.0.1:$_localApiPort/api';
  }

  /// Base da aplicação usada para URLs devolvidas pela API em cada ambiente.
  static String get applicationBaseUrl {
    if (kIsWeb) {
      final currentUri = Uri.base;
      final detectedEnvironment = _webEnvironment(currentUri);

      if (detectedEnvironment == AppEnvironment.production) {
        return _productionApplicationBaseUrl;
      }

      return 'http://${currentUri.host}:$_localWebPort';
    }

    if (environment == AppEnvironment.production) {
      return _productionApplicationBaseUrl;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:$_localWebPort';
    }

    return 'http://127.0.0.1:$_localWebPort';
  }

  static AppEnvironment _webEnvironment(Uri currentUri) {
    final host = currentUri.host.toLowerCase();
    final scheme = currentUri.scheme.toLowerCase();

    if (host == 'dailytalk.pt' || host == 'www.dailytalk.pt') {
      if (scheme != 'https') {
        throw StateError(
          'O ambiente PRD só pode ser utilizado através de HTTPS.',
        );
      }

      return AppEnvironment.production;
    }

    if (host == 'localhost' || host == '127.0.0.1') {
      if (scheme != 'http' && scheme != 'https') {
        throw StateError('Esquema inválido para o ambiente DEV.');
      }

      return AppEnvironment.development;
    }

    throw StateError(
      'Host não autorizado para o DailyTalk: $host. '
      'A aplicação recusou escolher automaticamente outro ambiente.',
    );
  }

  /// Cabeçalho obrigatório em todos os pedidos da aplicação.
  static Map<String, String> get environmentHeaders => {
    environmentHeaderName: environmentCode,
  };

  static Map<String, String> get jsonHeaders => {
    'Content-Type': 'application/json',
    ...environmentHeaders,
  };

  /// Confirma que uma URI pertence ao mesmo ambiente da aplicação.
  static void assertApiUri(Uri uri) {
    final host = uri.host.toLowerCase();
    final isProductionHost =
        host == 'dailytalk.pt' || host == 'www.dailytalk.pt';
    final isDevelopmentHost =
        host == 'localhost' || host == '127.0.0.1' || host == '10.0.2.2';

    if (isProductionApi) {
      if (!isProductionHost || uri.scheme.toLowerCase() != 'https') {
        throw StateError(
          'A aplicação PRD recusou um endereço que não pertence a PRD: $uri',
        );
      }
      return;
    }

    if (!isDevelopmentHost || uri.scheme.toLowerCase() != 'http') {
      throw StateError(
        'A aplicação DEV recusou um endereço que não pertence a DEV: $uri',
      );
    }
  }

  /// Valida o ambiente declarado pela resposta da API.
  ///
  /// Uma resposta PRD recebida por DEV, ou o inverso, é rejeitada antes de
  /// qualquer dado ser processado ou guardado localmente.
  static void assertResponseEnvironment(Map<String, String> responseHeaders) {
    final received = responseHeaders[environmentResponseHeaderName]
        ?.trim()
        .toUpperCase();

    if (received == null || received.isEmpty) {
      throw StateError(
        'A API não identificou o ambiente da resposta. '
        'A resposta foi rejeitada por segurança.',
      );
    }

    if (received != environmentCode) {
      throw StateError(
        'Resposta de ambiente incompatível: esperado $environmentCode, '
        'recebido $received. Nenhum dado foi aceite.',
      );
    }
  }

  /// Mantém os dados PRD nos nomes históricos e cria um espaço separado DEV.
  /// Assim, atualizações de produção preservam sessões e progresso existentes.
  static String get storageKeySuffix => isProductionApi ? '' : '_dev';

  static String get localDatabaseName =>
      isProductionApi ? 'dailytalk_mobile.db' : 'dailytalk_mobile_dev.db';

  /// Versão enviada no registo do dispositivo para auditoria.
  static const String appVersion = String.fromEnvironment(
    'DAILYTALK_APP_VERSION',
    defaultValue: '1.0.0',
  );

  /// Chaves públicas do servidor fixadas no build de produção.
  ///
  /// O script dailytalk-api/scripts/generate-sync-keys.mjs imprime os valores
  /// a fornecer por --dart-define. Em produção, a sincronização segura falha
  /// de forma fechada se estas chaves não estiverem configuradas.
  static const String syncServerSigningPublicX = String.fromEnvironment(
    'DAILYTALK_SYNC_SIGNING_PUBLIC_X',
    defaultValue: '',
  );

  static const String syncServerAgreementPublicX = String.fromEnvironment(
    'DAILYTALK_SYNC_AGREEMENT_PUBLIC_X',
    defaultValue: '',
  );

  static const String syncServerSigningKeyId = String.fromEnvironment(
    'DAILYTALK_SYNC_SIGNING_KEY_ID',
    defaultValue: 'sync-sign-v1',
  );

  static const String syncServerAgreementKeyId = String.fromEnvironment(
    'DAILYTALK_SYNC_AGREEMENT_KEY_ID',
    defaultValue: 'sync-enc-v1',
  );

  /// Apenas para DEV. Em PRD, chaves não fixadas são sempre recusadas.
  static const bool allowUnpinnedSyncKeys = bool.fromEnvironment(
    'DAILYTALK_ALLOW_UNPINNED_SYNC_KEYS',
    defaultValue: false,
  );

  static const Duration apiTimeout = Duration(seconds: 10);
}
