import 'dart:collection';

import 'domain_ids.dart';

/// Contrato editorial, separado do runtime, que explicita o léxico trabalhado
/// por cada atividade.
///
/// O contrato não impõe uma sequência de execução ao aluno. Atividades
/// paralelas continuam disponíveis conforme a projeção de progressão; a
/// validação apenas garante coerência de conteúdo dentro da etapa.
final class LearningLexicalContract {
  LearningLexicalContract({
    required this.schemaVersion,
    required this.learningPathId,
    required Iterable<LearningLexicalActivityContract> activities,
  }) : activities = List<LearningLexicalActivityContract>.unmodifiable(
         activities,
       ) {
    if (schemaVersion != 1) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'apenas a versão 1 é suportada',
      );
    }
  }

  final int schemaVersion;
  final LearningPathId learningPathId;
  final List<LearningLexicalActivityContract> activities;
}

/// Declara o papel lexical de uma atividade.
///
/// - [introduces]: itens apresentados explicitamente ao aluno;
/// - [practises]: itens usados em prática guiada;
/// - [reinforces]: itens retomados para consolidação.
final class LearningLexicalActivityContract {
  LearningLexicalActivityContract({
    required this.activityId,
    Iterable<String> introduces = const <String>[],
    Iterable<String> practises = const <String>[],
    Iterable<String> reinforces = const <String>[],
  }) : introduces = UnmodifiableSetView(
         introduces.map(_validateLexicalId).toSet(),
       ),
       practises = UnmodifiableSetView(
         practises.map(_validateLexicalId).toSet(),
       ),
       reinforces = UnmodifiableSetView(
         reinforces.map(_validateLexicalId).toSet(),
       );

  final ActivityId activityId;
  final Set<String> introduces;
  final Set<String> practises;
  final Set<String> reinforces;

  Set<String> get consumed =>
      UnmodifiableSetView(<String>{...practises, ...reinforces});
}

final RegExp _lexicalIdPattern = RegExp(r'^[a-z0-9]+(?:[._-][a-z0-9]+)*$');

String _validateLexicalId(String raw) {
  final value = raw.trim();
  if (value.isEmpty) {
    throw ArgumentError.value(raw, 'lexicalId', 'não pode estar vazio');
  }
  if (value.length > 120) {
    throw ArgumentError.value(
      raw,
      'lexicalId',
      'não pode ultrapassar 120 caracteres',
    );
  }
  if (!_lexicalIdPattern.hasMatch(value)) {
    throw ArgumentError.value(
      raw,
      'lexicalId',
      'deve usar minúsculas, números, ponto, hífen ou underscore',
    );
  }
  return value;
}
