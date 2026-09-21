import 'dart:convert';

import 'domain_ids.dart';
import 'learning_lexical_contract.dart';

enum LearningLexicalContractErrorCode {
  invalidJson,
  invalidRoot,
  unexpectedField,
  missingField,
  invalidFieldType,
  unsupportedSchemaVersion,
  invalidContent,
}

final class LearningLexicalContractException implements Exception {
  const LearningLexicalContractException({
    required this.code,
    required this.location,
    required this.message,
  });

  final LearningLexicalContractErrorCode code;
  final String location;
  final String message;

  @override
  String toString() => '${code.name} em $location: $message';
}

/// Codec estrito para o sidecar editorial de coerência lexical.
///
/// O sidecar permanece independente do schema executável das atividades.
/// Assim podemos evoluir a validação pedagógica sem alterar o runtime nem
/// transformar esta regra em pré-requisito de progressão.
final class LearningLexicalContractCodec {
  const LearningLexicalContractCodec();

  LearningLexicalContract decodeString(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw LearningLexicalContractException(
        code: LearningLexicalContractErrorCode.invalidJson,
        location: r'$root',
        message: error.message,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw const LearningLexicalContractException(
        code: LearningLexicalContractErrorCode.invalidRoot,
        location: r'$root',
        message: 'o contrato deve ser um objeto JSON',
      );
    }
    return decode(decoded);
  }

  LearningLexicalContract decode(Map<String, dynamic> source) {
    _allowOnly(source, const <String>{
      'schemaVersion',
      'learningPathId',
      'activities',
    }, r'$root');

    final schemaVersion = _integer(source, 'schemaVersion', r'$root');
    if (schemaVersion != 1) {
      throw LearningLexicalContractException(
        code: LearningLexicalContractErrorCode.unsupportedSchemaVersion,
        location: r'$root.schemaVersion',
        message: 'versão $schemaVersion não suportada',
      );
    }

    final activitiesValue = source['activities'];
    if (activitiesValue is! List) {
      throw const LearningLexicalContractException(
        code: LearningLexicalContractErrorCode.invalidFieldType,
        location: r'$root.activities',
        message: 'era esperada uma lista',
      );
    }

    try {
      return LearningLexicalContract(
        schemaVersion: schemaVersion,
        learningPathId: LearningPathId(
          _string(source, 'learningPathId', r'$root'),
        ),
        activities: activitiesValue.asMap().entries.map((entry) {
          final location =
              r'$root.activities['
              '${entry.key}]';
          final value = entry.value;
          if (value is! Map<String, dynamic>) {
            throw LearningLexicalContractException(
              code: LearningLexicalContractErrorCode.invalidFieldType,
              location: location,
              message: 'era esperado um objeto',
            );
          }
          _allowOnly(value, const <String>{
            'activityId',
            'introduces',
            'practises',
            'reinforces',
          }, location);
          return LearningLexicalActivityContract(
            activityId: ActivityId(_string(value, 'activityId', location)),
            introduces: _strings(value, 'introduces', location),
            practises: _strings(value, 'practises', location),
            reinforces: _strings(value, 'reinforces', location),
          );
        }),
      );
    } on LearningLexicalContractException {
      rethrow;
    } on ArgumentError catch (error) {
      throw LearningLexicalContractException(
        code: LearningLexicalContractErrorCode.invalidContent,
        location: r'$root',
        message: error.message?.toString() ?? error.toString(),
      );
    }
  }

  String encodeString(LearningLexicalContract contract, {bool pretty = false}) {
    final encoded = <String, dynamic>{
      'schemaVersion': contract.schemaVersion,
      'learningPathId': contract.learningPathId.value,
      'activities': contract.activities
          .map(
            (activity) => <String, dynamic>{
              'activityId': activity.activityId.value,
              'introduces': activity.introduces.toList()..sort(),
              'practises': activity.practises.toList()..sort(),
              'reinforces': activity.reinforces.toList()..sort(),
            },
          )
          .toList(growable: false),
    };

    return pretty
        ? const JsonEncoder.withIndent('  ').convert(encoded)
        : jsonEncode(encoded);
  }

  static void _allowOnly(
    Map<String, dynamic> source,
    Set<String> allowed,
    String location,
  ) {
    for (final key in source.keys) {
      if (!allowed.contains(key)) {
        throw LearningLexicalContractException(
          code: LearningLexicalContractErrorCode.unexpectedField,
          location: '$location.$key',
          message: 'campo não suportado',
        );
      }
    }
  }

  static String _string(
    Map<String, dynamic> source,
    String key,
    String location,
  ) {
    if (!source.containsKey(key)) {
      throw LearningLexicalContractException(
        code: LearningLexicalContractErrorCode.missingField,
        location: '$location.$key',
        message: 'campo obrigatório em falta',
      );
    }
    final value = source[key];
    if (value is! String) {
      throw LearningLexicalContractException(
        code: LearningLexicalContractErrorCode.invalidFieldType,
        location: '$location.$key',
        message: 'era esperado texto',
      );
    }
    return value;
  }

  static int _integer(
    Map<String, dynamic> source,
    String key,
    String location,
  ) {
    if (!source.containsKey(key)) {
      throw LearningLexicalContractException(
        code: LearningLexicalContractErrorCode.missingField,
        location: '$location.$key',
        message: 'campo obrigatório em falta',
      );
    }
    final value = source[key];
    if (value is! int) {
      throw LearningLexicalContractException(
        code: LearningLexicalContractErrorCode.invalidFieldType,
        location: '$location.$key',
        message: 'era esperado inteiro',
      );
    }
    return value;
  }

  static List<String> _strings(
    Map<String, dynamic> source,
    String key,
    String location,
  ) {
    final value = source[key];
    if (value == null) return const <String>[];
    if (value is! List) {
      throw LearningLexicalContractException(
        code: LearningLexicalContractErrorCode.invalidFieldType,
        location: '$location.$key',
        message: 'era esperada uma lista',
      );
    }

    final result = <String>[];
    for (var index = 0; index < value.length; index++) {
      final item = value[index];
      if (item is! String) {
        throw LearningLexicalContractException(
          code: LearningLexicalContractErrorCode.invalidFieldType,
          location: '$location.$key[$index]',
          message: 'era esperado texto',
        );
      }
      result.add(item);
    }
    return result;
  }
}
