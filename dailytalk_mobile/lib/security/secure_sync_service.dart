import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../data/storage/auth_token_storage.dart';
import 'auth_session_service.dart';
import 'compact_jose_service.dart';
import 'device_key_service.dart';
import 'jose_utils.dart';

class SecureSyncService {
  SecureSyncService({
    http.Client? client,
    AuthSessionService? authSessionService,
    AuthTokenStorage? tokenStorage,
    DeviceKeyService? deviceKeyService,
    CompactJoseService? joseService,
  }) : _client = client ?? http.Client(),
       _joseService = joseService ?? const CompactJoseService() {
    _tokenStorage = tokenStorage ?? AuthTokenStorage();
    _deviceKeyService = deviceKeyService ?? DeviceKeyService();
    _authSessionService =
        authSessionService ??
        AuthSessionService(
          tokenStorage: _tokenStorage,
          deviceKeyService: _deviceKeyService,
        );
  }

  final http.Client _client;
  final CompactJoseService _joseService;
  late final AuthSessionService _authSessionService;
  late final AuthTokenStorage _tokenStorage;
  late final DeviceKeyService _deviceKeyService;

  Future<Map<String, dynamic>> synchronizeProgress(
    List<Map<String, dynamic>> items,
  ) async {
    if (items.isEmpty) {
      return const {'results': <Map<String, dynamic>>[]};
    }
    if (items.length > 50) {
      throw ArgumentError.value(
        items.length,
        'items',
        'Máximo de 50 itens por lote.',
      );
    }

    final deviceId = await _tokenStorage.readDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      // Converte silenciosamente uma sessão antiga antes de criar o lote.
      await _authSessionService.ensureAccessToken();
    }
    final currentDeviceId = await _tokenStorage.readDeviceId();
    if (currentDeviceId == null || currentDeviceId.isEmpty) {
      throw const SessionReauthenticationRequiredException();
    }

    final material = await _deviceKeyService.loadOrCreate();
    final serverKeys = await _loadServerKeys();
    final issuedAt = DateTime.now().toUtc();
    final batch = <String, dynamic>{
      'version': 1,
      'batchId': randomBase64Url(24),
      'deviceId': currentDeviceId,
      'issuedAt': issuedAt.toIso8601String(),
      'expiresAt': issuedAt.add(const Duration(minutes: 2)).toIso8601String(),
      'sequence': await _deviceKeyService.nextSyncSequence(),
      'items': items,
    };
    final batchPayload = utf8Bytes(jsonEncode(batch));
    if (batchPayload.length > 256 * 1024) {
      throw const FormatException(
        'O lote de sincronização excede o limite seguro de 256 KB.',
      );
    }

    final signed = await _joseService.sign(
      payload: batchPayload,
      privateKeyPair: material.signingKeyPair,
      keyId: currentDeviceId,
      type: 'dailytalk-sync+jws',
    );
    final envelope = await _joseService.encrypt(
      plaintext: utf8Bytes(signed),
      recipientPublicKey: serverKeys.agreementPublicKey,
      recipientKeyId: serverKeys.agreementKeyId,
      senderParty: currentDeviceId,
      recipientParty: serverKeys.agreementKeyId,
      type: 'dailytalk-sync+jwe',
    );
    final uri = Uri.parse('${AppConfig.apiBaseUrl}/sync/progress');
    final response = await _client
        .post(
          uri,
          headers: await _authSessionService.authenticatedHeaders(
            method: 'POST',
            uri: uri,
          ),
          body: jsonEncode({'envelope': envelope}),
        )
        .timeout(AppConfig.apiTimeout);
    final responseMap = _decodeResponse(response);
    final responseEnvelope = responseMap['envelope']?.toString();
    if (responseEnvelope == null || responseEnvelope.isEmpty) {
      throw const FormatException('A API não devolveu o envelope de resposta.');
    }

    final signedResponse = await _joseService.decrypt(
      compact: responseEnvelope,
      recipientPrivateKeyPair: material.agreementKeyPair,
      expectedRecipientKeyId: currentDeviceId,
      expectedSenderParty: serverKeys.agreementKeyId,
      expectedRecipientParty: currentDeviceId,
      expectedType: 'dailytalk-sync-response+jwe',
    );
    final payload = await _joseService.verify(
      compact: utf8.decode(signedResponse),
      publicKey: serverKeys.signingPublicKey,
      expectedKeyId: serverKeys.signingKeyId,
      expectedType: 'dailytalk-sync-response+jws',
    );
    final decoded = jsonDecode(utf8.decode(payload));
    if (decoded is! Map) {
      throw const FormatException('Resposta segura de sincronização inválida.');
    }
    final result = Map<String, dynamic>.from(decoded);

    if (result['batchId'] != batch['batchId'] ||
        result['deviceId'] != currentDeviceId ||
        result['sequence'] != batch['sequence']) {
      throw const FormatException('Resposta segura não corresponde ao pedido.');
    }

    return result;
  }

  Future<_ServerSyncKeys> _loadServerKeys() async {
    final signingX = AppConfig.syncServerSigningPublicX.trim();
    final agreementX = AppConfig.syncServerAgreementPublicX.trim();

    if (signingX.isNotEmpty && agreementX.isNotEmpty) {
      return _ServerSyncKeys(
        signingKeyId: AppConfig.syncServerSigningKeyId,
        agreementKeyId: AppConfig.syncServerAgreementKeyId,
        signingPublicKey: SimplePublicKey(
          base64UrlDecodeBytes(signingX),
          type: KeyPairType.ed25519,
        ),
        agreementPublicKey: SimplePublicKey(
          base64UrlDecodeBytes(agreementX),
          type: KeyPairType.x25519,
        ),
      );
    }

    if (AppConfig.isProductionApi || !AppConfig.allowUnpinnedSyncKeys) {
      throw StateError(
        'As chaves públicas de sincronização não estão fixadas neste build.',
      );
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/security/sync-keys');
    final response = await _client
        .get(uri, headers: AppConfig.environmentHeaders)
        .timeout(AppConfig.apiTimeout);
    final decoded = _decodeResponse(response);
    final signing = decoded['signingKey'];
    final agreement = decoded['agreementKey'];
    if (signing is! Map || agreement is! Map) {
      throw const FormatException('Chaves públicas do servidor inválidas.');
    }

    return _ServerSyncKeys(
      signingKeyId:
          signing['kid']?.toString() ?? AppConfig.syncServerSigningKeyId,
      agreementKeyId:
          agreement['kid']?.toString() ?? AppConfig.syncServerAgreementKeyId,
      signingPublicKey: SimplePublicKey(
        base64UrlDecodeBytes(signing['x'].toString()),
        type: KeyPairType.ed25519,
      ),
      agreementPublicKey: SimplePublicKey(
        base64UrlDecodeBytes(agreement['x'].toString()),
        type: KeyPairType.x25519,
      ),
    );
  }

  Map<String, dynamic> _decodeResponse(http.Response response) {
    AppConfig.assertResponseEnvironment(response.headers);

    final decoded = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(response.body);
    if (decoded is! Map) {
      throw const FormatException('Resposta inválida da API.');
    }
    final map = Map<String, dynamic>.from(decoded);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        map['error']?.toString() ?? 'Erro HTTP ${response.statusCode}.',
      );
    }
    return map;
  }
}

class _ServerSyncKeys {
  const _ServerSyncKeys({
    required this.signingKeyId,
    required this.agreementKeyId,
    required this.signingPublicKey,
    required this.agreementPublicKey,
  });

  final String signingKeyId;
  final String agreementKeyId;
  final SimplePublicKey signingPublicKey;
  final SimplePublicKey agreementPublicKey;
}
