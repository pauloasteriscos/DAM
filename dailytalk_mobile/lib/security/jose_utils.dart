import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

Uint8List utf8Bytes(String value) => Uint8List.fromList(utf8.encode(value));

String base64UrlEncodeBytes(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List base64UrlDecodeBytes(String value) {
  final normalized = value.padRight((value.length + 3) ~/ 4 * 4, '=');
  return Uint8List.fromList(base64Url.decode(normalized));
}

String base64UrlJson(Object? value) =>
    base64UrlEncodeBytes(utf8Bytes(jsonEncode(value)));

Map<String, dynamic> parseBase64UrlJson(String value) {
  final decoded = utf8.decode(base64UrlDecodeBytes(value));
  final json = jsonDecode(decoded);
  if (json is! Map) {
    throw const FormatException('Objeto JOSE inválido.');
  }
  return Map<String, dynamic>.from(json);
}

Uint8List concatBytes(Iterable<List<int>> parts) {
  final length = parts.fold<int>(0, (total, part) => total + part.length);
  final result = Uint8List(length);
  var offset = 0;

  for (final part in parts) {
    result.setRange(offset, offset + part.length, part);
    offset += part.length;
  }

  return result;
}

Uint8List uint32BigEndian(int value) {
  final bytes = Uint8List(4);
  ByteData.sublistView(bytes).setUint32(0, value, Endian.big);
  return bytes;
}

Uint8List lengthPrefixed(List<int> value) =>
    concatBytes([uint32BigEndian(value.length), value]);

Future<Uint8List> sha256Bytes(List<int> value) async {
  final hash = await Sha256().hash(value);
  return Uint8List.fromList(hash.bytes);
}

Future<String> sha256Base64Url(List<int> value) async =>
    base64UrlEncodeBytes(await sha256Bytes(value));

String randomBase64Url(int byteLength) {
  final random = Random.secure();
  return base64UrlEncodeBytes(
    List<int>.generate(byteLength, (_) => random.nextInt(256)),
  );
}

String normalizedHtu(Uri uri) => '${uri.scheme}://${uri.authority}${uri.path}';

Future<Uint8List> concatKdfA256Gcm({
  required List<int> sharedSecret,
  required List<int> partyUInfo,
  required List<int> partyVInfo,
}) {
  final otherInfo = concatBytes([
    lengthPrefixed(utf8Bytes('A256GCM')),
    lengthPrefixed(partyUInfo),
    lengthPrefixed(partyVInfo),
    uint32BigEndian(256),
  ]);

  return sha256Bytes(
    concatBytes([uint32BigEndian(1), sharedSecret, otherInfo]),
  );
}
