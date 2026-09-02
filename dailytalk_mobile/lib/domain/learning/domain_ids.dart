/// Identificadores tipados do domínio de aprendizagem.
///
/// Os identificadores são estáveis, não contêm significado mutável e não
/// dependem de Flutter, SQLite ou da API.
abstract base class DomainId {
  DomainId._(String rawValue, String fieldName)
    : value = _validate(rawValue, fieldName);

  static final RegExp _allowedFormat = RegExp(
    r'^[a-z0-9]+(?:[._-][a-z0-9]+)*$',
  );

  final String value;

  static String _validate(String rawValue, String fieldName) {
    final value = rawValue.trim();

    if (value.isEmpty) {
      throw ArgumentError.value(rawValue, fieldName, 'não pode estar vazio');
    }

    if (value.length > 80) {
      throw ArgumentError.value(
        rawValue,
        fieldName,
        'não pode ultrapassar 80 caracteres',
      );
    }

    if (!_allowedFormat.hasMatch(value)) {
      throw ArgumentError.value(
        rawValue,
        fieldName,
        'deve usar letras minúsculas, números, ponto, hífen ou underscore',
      );
    }

    return value;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other.runtimeType == runtimeType &&
          other is DomainId &&
          other.value == value;

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() => value;
}

final class LearningPathId extends DomainId {
  LearningPathId(String value) : super._(value, 'learningPathId');
}

final class JourneyId extends DomainId {
  JourneyId(String value) : super._(value, 'journeyId');
}

final class StageId extends DomainId {
  StageId(String value) : super._(value, 'stageId');
}

final class PathElementId extends DomainId {
  PathElementId(String value) : super._(value, 'pathElementId');
}

final class ActivityId extends DomainId {
  ActivityId(String value) : super._(value, 'activityId');
}

final class RevisionId extends DomainId {
  RevisionId(String value) : super._(value, 'revisionId');
}

final class CompetencyId extends DomainId {
  CompetencyId(String value) : super._(value, 'competencyId');
}
