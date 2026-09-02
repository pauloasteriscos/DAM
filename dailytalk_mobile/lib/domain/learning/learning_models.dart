import 'dart:collection';

import 'domain_ids.dart';
import 'learning_enums.dart';
import 'prerequisite_rule.dart';

/// Versão inteira do schema de conteúdo interpretado pela aplicação.
final class SchemaVersion {
  SchemaVersion(this.value) {
    if (value < 1) {
      throw ArgumentError.value(
        value,
        'value',
        'deve ser igual ou superior a 1',
      );
    }
  }

  final int value;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is SchemaVersion && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value.toString();
}

/// Texto traduzível indexado por locale BCP 47 simplificado, por exemplo
/// `pt-PT`, `en` ou `fr-FR`.
final class LocalizedText {
  LocalizedText(Map<String, String> values)
    : values = UnmodifiableMapView(_validatedValues(values));

  final Map<String, String> values;

  String resolve(String locale, {required String fallbackLocale}) {
    final exact = values[locale];
    if (exact != null) return exact;

    final language = locale.split('-').first;
    for (final entry in values.entries) {
      if (entry.key.split('-').first == language) return entry.value;
    }

    final fallback = values[fallbackLocale];
    if (fallback != null) return fallback;

    throw StateError(
      'Não existe tradução para $locale nem para o fallback $fallbackLocale.',
    );
  }

  static Map<String, String> _validatedValues(Map<String, String> source) {
    if (source.isEmpty) {
      throw ArgumentError.value(source, 'values', 'deve conter traduções');
    }

    final result = <String, String>{};
    for (final entry in source.entries) {
      final locale = entry.key.trim();
      final text = entry.value.trim();
      if (locale.isEmpty || text.isEmpty) {
        throw ArgumentError.value(
          source,
          'values',
          'locale e texto não podem estar vazios',
        );
      }
      result[locale] = text;
    }
    return result;
  }
}

final class Competency {
  const Competency({
    required this.id,
    required this.title,
    required this.description,
  });

  final CompetencyId id;
  final LocalizedText title;
  final LocalizedText description;
}

/// Revisão imutável do conteúdo de uma atividade.
final class ActivityRevision {
  ActivityRevision({
    required this.id,
    required this.activityId,
    required this.revisionNumber,
    required this.title,
    required this.instructions,
    required this.visibility,
    Iterable<CompetencyId> competencies = const <CompetencyId>[],
  }) : competencies = UnmodifiableSetView(Set<CompetencyId>.of(competencies)) {
    if (revisionNumber < 1) {
      throw ArgumentError.value(
        revisionNumber,
        'revisionNumber',
        'deve ser igual ou superior a 1',
      );
    }
  }

  final RevisionId id;
  final ActivityId activityId;
  final int revisionNumber;
  final LocalizedText title;
  final LocalizedText instructions;
  final ContentVisibility visibility;
  final Set<CompetencyId> competencies;
}

/// Identidade estável de uma atividade e respetivas revisões imutáveis.
final class Activity {
  Activity({
    required this.id,
    required this.type,
    required this.origin,
    required this.currentRevisionId,
    required Iterable<ActivityRevision> revisions,
  }) : revisions = List<ActivityRevision>.unmodifiable(revisions) {
    if (this.revisions.isEmpty) {
      throw ArgumentError.value(
        revisions,
        'revisions',
        'uma atividade deve possuir pelo menos uma revisão',
      );
    }

    final revisionIds = <RevisionId>{};
    for (final revision in this.revisions) {
      if (revision.activityId != id) {
        throw ArgumentError(
          'A revisão ${revision.id} pertence a ${revision.activityId}, não a $id.',
        );
      }
      if (!revisionIds.add(revision.id)) {
        throw ArgumentError('RevisionId duplicado: ${revision.id}.');
      }
    }

    if (!revisionIds.contains(currentRevisionId)) {
      throw ArgumentError.value(
        currentRevisionId,
        'currentRevisionId',
        'deve identificar uma revisão pertencente à atividade',
      );
    }
  }

  final ActivityId id;
  final LearningActivityType type;
  final ContentOrigin origin;
  final RevisionId currentRevisionId;
  final List<ActivityRevision> revisions;

  ActivityRevision get currentRevision =>
      revisions.firstWhere((revision) => revision.id == currentRevisionId);
}

final class PathElement {
  PathElement({
    required this.id,
    required this.type,
    this.activityId,
    this.prerequisites,
    this.practicePreference = PracticePreference.balanced,
  }) {
    if (type == PathElementType.activity && activityId == null) {
      throw ArgumentError(
        'Um elemento do tipo activity deve referenciar um activityId.',
      );
    }
    if (type != PathElementType.activity && activityId != null) {
      throw ArgumentError(
        'Somente elementos do tipo activity podem referenciar um activityId.',
      );
    }
  }

  final PathElementId id;
  final PathElementType type;
  final ActivityId? activityId;
  final PrerequisiteRule? prerequisites;
  final PracticePreference practicePreference;
}

final class Stage {
  Stage({
    required this.id,
    required this.title,
    required Iterable<PathElement> elements,
  }) : elements = List<PathElement>.unmodifiable(elements) {
    if (this.elements.isEmpty) {
      throw ArgumentError.value(
        elements,
        'elements',
        'uma etapa deve conter pelo menos um elemento',
      );
    }
    _ensureUnique(this.elements.map((element) => element.id), 'PathElementId');
  }

  final StageId id;
  final LocalizedText title;
  final List<PathElement> elements;
}

final class Journey {
  Journey({
    required this.id,
    required this.title,
    required Iterable<Stage> stages,
  }) : stages = List<Stage>.unmodifiable(stages) {
    if (this.stages.isEmpty) {
      throw ArgumentError.value(
        stages,
        'stages',
        'uma jornada deve conter pelo menos uma etapa',
      );
    }
    _ensureUnique(this.stages.map((stage) => stage.id), 'StageId');
  }

  final JourneyId id;
  final LocalizedText title;
  final List<Stage> stages;
}

/// Agregado principal do percurso de aprendizagem.
final class LearningPath {
  LearningPath({
    required this.id,
    required this.schemaVersion,
    required this.defaultLocale,
    required this.title,
    required Iterable<Journey> journeys,
    required Iterable<Activity> activities,
    required Iterable<Competency> competencies,
  }) : journeys = List<Journey>.unmodifiable(journeys),
       activities = List<Activity>.unmodifiable(activities),
       competencies = List<Competency>.unmodifiable(competencies) {
    if (defaultLocale.trim().isEmpty) {
      throw ArgumentError.value(
        defaultLocale,
        'defaultLocale',
        'não pode estar vazio',
      );
    }
    if (this.journeys.isEmpty) {
      throw ArgumentError.value(
        journeys,
        'journeys',
        'um percurso deve conter pelo menos uma jornada',
      );
    }

    _ensureUnique(this.journeys.map((journey) => journey.id), 'JourneyId');
    _ensureUnique(this.activities.map((activity) => activity.id), 'ActivityId');
    _ensureUnique(
      this.competencies.map((competency) => competency.id),
      'CompetencyId',
    );
  }

  final LearningPathId id;
  final SchemaVersion schemaVersion;
  final String defaultLocale;
  final LocalizedText title;
  final List<Journey> journeys;
  final List<Activity> activities;
  final List<Competency> competencies;
}

void _ensureUnique(Iterable<DomainId> ids, String label) {
  final unique = <DomainId>{};
  for (final id in ids) {
    if (!unique.add(id)) {
      throw ArgumentError('$label duplicado: $id.');
    }
  }
}
