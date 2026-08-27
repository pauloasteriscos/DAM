import 'package:cryptography/cryptography.dart';

import 'device_key_service.dart';
import 'jose_utils.dart';

class DpopService {
  DpopService({DeviceKeyService? deviceKeyService})
    : _deviceKeyService = deviceKeyService ?? DeviceKeyService();

  final DeviceKeyService _deviceKeyService;

  Future<String> createProof({
    required String method,
    required Uri uri,
    String? accessToken,
  }) async {
    final material = await _deviceKeyService.loadOrCreate();
    final header = {
      'typ': 'dpop+jwt',
      'alg': 'EdDSA',
      'jwk': material.signingPublicJwk,
    };
    final claims = <String, dynamic>{
      'jti': randomBase64Url(24),
      'htm': method.toUpperCase(),
      'htu': normalizedHtu(uri),
      'iat': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    };

    if (accessToken != null && accessToken.isNotEmpty) {
      claims['ath'] = await sha256Base64Url(utf8Bytes(accessToken));
    }

    final protectedPart = base64UrlJson(header);
    final payloadPart = base64UrlJson(claims);
    final signingInput = utf8Bytes('$protectedPart.$payloadPart');
    final signature = await Ed25519().sign(
      signingInput,
      keyPair: material.signingKeyPair,
    );

    return '$protectedPart.$payloadPart.${base64UrlEncodeBytes(signature.bytes)}';
  }
}
