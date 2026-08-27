import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../config/app_config.dart';
import 'jose_utils.dart';

/// Material criptográfico persistente associado a uma instalação DailyTalk.
///
/// DEV e PRD usam identificadores, chaves e sequências diferentes. A aplicação
/// de produção mantém os nomes históricos; DEV usa o sufixo `_dev`.
///
/// As chaves privadas nunca são incluídas em pedidos de rede. Nesta primeira
/// implementação multiplataforma, os bytes privados são protegidos pelo
/// armazenamento seguro do sistema através de flutter_secure_storage.
class DeviceKeyMaterial {
  const DeviceKeyMaterial({
    required this.installationId,
    required this.signingKeyPair,
    required this.agreementKeyPair,
  });

  final String installationId;
  final SimpleKeyPairData signingKeyPair;
  final SimpleKeyPairData agreementKeyPair;

  Map<String, dynamic> get signingPublicJwk => {
    'kty': 'OKP',
    'crv': 'Ed25519',
    'x': base64UrlEncodeBytes(signingKeyPair.publicKey.bytes),
  };

  Map<String, dynamic> get agreementPublicJwk => {
    'kty': 'OKP',
    'crv': 'X25519',
    'x': base64UrlEncodeBytes(agreementKeyPair.publicKey.bytes),
  };
}

class DeviceKeyService {
  DeviceKeyService({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _secureStorage;

  String _key(String base) => '$base${AppConfig.storageKeySuffix}';

  String get _installationIdKey => _key('dailytalk_device_installation_id_v1');
  String get _signingBundleKey => _key('dailytalk_device_ed25519_bundle_v1');
  String get _agreementBundleKey => _key('dailytalk_device_x25519_bundle_v1');
  String get _sequenceKey => _key('dailytalk_secure_sync_sequence_v1');

  // Migrações também ficam limitadas ao ambiente atual.
  String get _legacySigningPrivateKey =>
      _key('dailytalk_device_ed25519_private_v1');
  String get _legacySigningPublicKey =>
      _key('dailytalk_device_ed25519_public_v1');
  String get _legacyAgreementPrivateKey =>
      _key('dailytalk_device_x25519_private_v1');
  String get _legacyAgreementPublicKey =>
      _key('dailytalk_device_x25519_public_v1');

  Future<void> _sequenceQueue = Future<void>.value();

  Future<DeviceKeyMaterial> loadOrCreate() async {
    final installationId = await _loadOrCreateInstallationId();
    final signingPair = await _loadOrCreatePair(
      bundleStorageKey: _signingBundleKey,
      legacyPrivateStorageKey: _legacySigningPrivateKey,
      legacyPublicStorageKey: _legacySigningPublicKey,
      generateKeyPair: () => Ed25519().newKeyPair(),
      type: KeyPairType.ed25519,
    );
    final agreementPair = await _loadOrCreatePair(
      bundleStorageKey: _agreementBundleKey,
      legacyPrivateStorageKey: _legacyAgreementPrivateKey,
      legacyPublicStorageKey: _legacyAgreementPublicKey,
      generateKeyPair: () => X25519().newKeyPair(),
      type: KeyPairType.x25519,
    );

    return DeviceKeyMaterial(
      installationId: installationId,
      signingKeyPair: signingPair,
      agreementKeyPair: agreementPair,
    );
  }

  Future<Map<String, dynamic>> registrationPayload() async {
    final material = await loadOrCreate();

    return {
      'installationId': material.installationId,
      'name': _deviceName,
      'platform': _platformName,
      'appVersion': AppConfig.appVersion,
      'signingPublicJwk': material.signingPublicJwk,
      'agreementPublicJwk': material.agreementPublicJwk,
    };
  }

  /// Reserva monotonamente o próximo número de sequência neste isolate.
  ///
  /// O encadeamento impede duas sincronizações simultâneas de reutilizarem o
  /// mesmo valor. O servidor continua a aplicar a proteção final anti-replay.
  Future<int> nextSyncSequence() {
    final operation = _sequenceQueue.then((_) async {
      final raw = await _secureStorage.read(key: _sequenceKey);
      final current = int.tryParse(raw ?? '') ?? 0;
      final next = current + 1;
      await _secureStorage.write(key: _sequenceKey, value: next.toString());
      return next;
    });

    _sequenceQueue = operation.then<void>((_) {}, onError: (_) {});
    return operation;
  }

  Future<String> _loadOrCreateInstallationId() async {
    final existing = await _secureStorage.read(key: _installationIdKey);
    if (existing != null && existing.length >= 16) {
      return existing;
    }

    final generated = randomBase64Url(32);
    await _secureStorage.write(key: _installationIdKey, value: generated);
    return generated;
  }

  Future<SimpleKeyPairData> _loadOrCreatePair({
    required String bundleStorageKey,
    required String legacyPrivateStorageKey,
    required String legacyPublicStorageKey,
    required Future<SimpleKeyPair> Function() generateKeyPair,
    required KeyPairType<KeyPairData, PublicKey> type,
  }) async {
    final bundle = await _secureStorage.read(key: bundleStorageKey);
    if (bundle != null && bundle.isNotEmpty) {
      return _decodeKeyBundle(bundle, type);
    }

    final legacyPrivate = await _secureStorage.read(
      key: legacyPrivateStorageKey,
    );
    final legacyPublic = await _secureStorage.read(key: legacyPublicStorageKey);
    if (legacyPrivate != null || legacyPublic != null) {
      if (legacyPrivate == null || legacyPublic == null) {
        throw StateError(
          'O material criptográfico do dispositivo está incompleto. '
          'Não foi substituído automaticamente para evitar perder a sessão.',
        );
      }

      final migrated = SimpleKeyPairData(
        base64UrlDecodeBytes(legacyPrivate),
        publicKey: SimplePublicKey(
          base64UrlDecodeBytes(legacyPublic),
          type: type,
        ),
        type: type,
      );
      await _writeKeyBundle(bundleStorageKey, migrated);
      await Future.wait([
        _secureStorage.delete(key: legacyPrivateStorageKey),
        _secureStorage.delete(key: legacyPublicStorageKey),
      ]);
      return migrated;
    }

    final pair = await generateKeyPair();
    final extracted = await pair.extract();
    await _writeKeyBundle(bundleStorageKey, extracted);
    return extracted;
  }

  Future<void> _writeKeyBundle(
    String storageKey,
    SimpleKeyPairData pair,
  ) async {
    await _secureStorage.write(
      key: storageKey,
      value: jsonEncode({
        'version': 1,
        'private': base64UrlEncodeBytes(pair.bytes),
        'public': base64UrlEncodeBytes(pair.publicKey.bytes),
      }),
    );
  }

  SimpleKeyPairData _decodeKeyBundle(
    String encoded,
    KeyPairType<KeyPairData, PublicKey> type,
  ) {
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map ||
          decoded['version'] != 1 ||
          decoded['private'] is! String ||
          decoded['public'] is! String) {
        throw const FormatException('Formato de chave inválido.');
      }

      final privateBytes = base64UrlDecodeBytes(decoded['private'] as String);
      final publicBytes = base64UrlDecodeBytes(decoded['public'] as String);
      if (privateBytes.isEmpty || publicBytes.isEmpty) {
        throw const FormatException('Chave vazia.');
      }

      return SimpleKeyPairData(
        privateBytes,
        publicKey: SimplePublicKey(publicBytes, type: type),
        type: type,
      );
    } catch (error) {
      throw StateError(
        'O material criptográfico do dispositivo está corrompido e não foi '
        'substituído automaticamente: $error',
      );
    }
  }

  String get _platformName {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform.name;
  }

  String get _deviceName => 'DailyTalk ${_platformName.toUpperCase()}';
}
