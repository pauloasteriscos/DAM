import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'jose_utils.dart';

class CompactJoseService {
  const CompactJoseService();

  Future<String> sign({
    required List<int> payload,
    required SimpleKeyPairData privateKeyPair,
    required String keyId,
    required String type,
  }) async {
    final protectedPart = base64UrlJson({
      'alg': 'EdDSA',
      'typ': type,
      'kid': keyId,
    });
    final payloadPart = base64UrlEncodeBytes(payload);
    final signature = await Ed25519().sign(
      utf8Bytes('$protectedPart.$payloadPart'),
      keyPair: privateKeyPair,
    );

    return '$protectedPart.$payloadPart.${base64UrlEncodeBytes(signature.bytes)}';
  }

  Future<List<int>> verify({
    required String compact,
    required SimplePublicKey publicKey,
    required String expectedKeyId,
    required String expectedType,
  }) async {
    final parts = compact.split('.');
    if (parts.length != 3 || parts.any((part) => part.isEmpty)) {
      throw const FormatException('JWS Compact inválido.');
    }

    final header = parseBase64UrlJson(parts[0]);
    if (header['alg'] != 'EdDSA' ||
        header['typ'] != expectedType ||
        header['kid'] != expectedKeyId) {
      throw const FormatException('Cabeçalho JWS não permitido.');
    }

    final valid = await Ed25519().verify(
      utf8Bytes('${parts[0]}.${parts[1]}'),
      signature: Signature(
        base64UrlDecodeBytes(parts[2]),
        publicKey: publicKey,
      ),
    );
    if (!valid) {
      throw const FormatException('Assinatura JWS inválida.');
    }

    return base64UrlDecodeBytes(parts[1]);
  }

  Future<String> encrypt({
    required List<int> plaintext,
    required SimplePublicKey recipientPublicKey,
    required String recipientKeyId,
    required String senderParty,
    required String recipientParty,
    required String type,
  }) async {
    final ephemeralPair = await X25519().newKeyPair();
    final ephemeralPublic = await ephemeralPair.extractPublicKey();
    final sharedSecret = await X25519().sharedSecretKey(
      keyPair: ephemeralPair,
      remotePublicKey: recipientPublicKey,
    );
    final sharedSecretBytes = await sharedSecret.extractBytes();
    final partyU = utf8Bytes(senderParty);
    final partyV = utf8Bytes(recipientParty);
    final contentKey = await concatKdfA256Gcm(
      sharedSecret: sharedSecretBytes,
      partyUInfo: partyU,
      partyVInfo: partyV,
    );
    final protectedPart = base64UrlJson({
      'alg': 'ECDH-ES',
      'enc': 'A256GCM',
      'typ': type,
      'cty': 'JOSE',
      'kid': recipientKeyId,
      'epk': {
        'kty': 'OKP',
        'crv': 'X25519',
        'x': base64UrlEncodeBytes(ephemeralPublic.bytes),
      },
      'apu': base64UrlEncodeBytes(partyU),
      'apv': base64UrlEncodeBytes(partyV),
    });
    final cipher = AesGcm.with256bits();
    final secretBox = await cipher.encrypt(
      plaintext,
      secretKey: SecretKey(contentKey),
      nonce: cipher.newNonce(),
      aad: utf8Bytes(protectedPart),
    );

    return [
      protectedPart,
      '',
      base64UrlEncodeBytes(secretBox.nonce),
      base64UrlEncodeBytes(secretBox.cipherText),
      base64UrlEncodeBytes(secretBox.mac.bytes),
    ].join('.');
  }

  Future<List<int>> decrypt({
    required String compact,
    required SimpleKeyPairData recipientPrivateKeyPair,
    required String expectedRecipientKeyId,
    required String expectedSenderParty,
    required String expectedRecipientParty,
    required String expectedType,
  }) async {
    final parts = compact.split('.');
    if (parts.length != 5 || parts[1].isNotEmpty) {
      throw const FormatException('JWE Compact inválido.');
    }

    final header = parseBase64UrlJson(parts[0]);
    final epk = header['epk'];
    if (header['alg'] != 'ECDH-ES' ||
        header['enc'] != 'A256GCM' ||
        header['typ'] != expectedType ||
        header['cty'] != 'JOSE' ||
        header['kid'] != expectedRecipientKeyId ||
        epk is! Map ||
        epk['kty'] != 'OKP' ||
        epk['crv'] != 'X25519') {
      throw const FormatException('Cabeçalho JWE não permitido.');
    }

    final partyU = base64UrlDecodeBytes(header['apu'].toString());
    final partyV = base64UrlDecodeBytes(header['apv'].toString());
    if (utf8.decode(partyU) != expectedSenderParty ||
        utf8.decode(partyV) != expectedRecipientParty) {
      throw const FormatException('Contexto JWE inválido.');
    }

    final ephemeralPublicKey = SimplePublicKey(
      base64UrlDecodeBytes(epk['x'].toString()),
      type: KeyPairType.x25519,
    );
    final sharedSecret = await X25519().sharedSecretKey(
      keyPair: recipientPrivateKeyPair,
      remotePublicKey: ephemeralPublicKey,
    );
    final contentKey = await concatKdfA256Gcm(
      sharedSecret: await sharedSecret.extractBytes(),
      partyUInfo: partyU,
      partyVInfo: partyV,
    );
    final secretBox = SecretBox(
      base64UrlDecodeBytes(parts[3]),
      nonce: base64UrlDecodeBytes(parts[2]),
      mac: Mac(base64UrlDecodeBytes(parts[4])),
    );

    return AesGcm.with256bits().decrypt(
      secretBox,
      secretKey: SecretKey(contentKey),
      aad: utf8Bytes(parts[0]),
    );
  }
}
