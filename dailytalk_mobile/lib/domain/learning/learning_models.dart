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

/// Conteúdo executável, imutável e tipado de uma revisão de atividade.
///
/// O tipo do payload é deliberadamente separado da UI. Widgets podem adaptar
/// estes dados sem depender de mapas dinâmicos ou de bancos hardcoded.
sealed class ActivityExecution {
  const ActivityExecution();

  LearningActivityType get activityType;
}

final class VocabularyActivityExecution extends ActivityExecution {
  VocabularyActivityExecution({
    required Iterable<VocabularyExecutionItem> items,
  }) : items = List<VocabularyExecutionItem>.unmodifiable(items) {
    _requireNonEmpty(this.items, 'items', 'vocabulário');
    _ensureUniqueStrings(
      this.items.map((item) => item.id),
      'Vocabulary item id',
    );
  }

  final List<VocabularyExecutionItem> items;

  @override
  LearningActivityType get activityType => LearningActivityType.vocabulary;
}

final class VocabularyExecutionItem {
  VocabularyExecutionItem({required String id, required this.text})
    : id = _validatedExecutionId(id, 'id');

  final String id;
  final LocalizedText text;
}

final class DialogueActivityExecution extends ActivityExecution {
  DialogueActivityExecution({
    required this.scenarioTitle,
    required this.scenarioDescription,
    required Iterable<DialogueExecutionTurn> turns,
  }) : turns = List<DialogueExecutionTurn>.unmodifiable(turns) {
    _requireNonEmpty(this.turns, 'turns', 'diálogo');
    _ensureUniqueStrings(this.turns.map((turn) => turn.id), 'Dialogue turn id');
  }

  final LocalizedText scenarioTitle;
  final LocalizedText scenarioDescription;
  final List<DialogueExecutionTurn> turns;

  @override
  LearningActivityType get activityType => LearningActivityType.dialogue;
}

final class DialogueExecutionTurn {
  DialogueExecutionTurn({
    required String id,
    required this.partnerMessage,
    required this.prompt,
    required this.correctReply,
    required Iterable<LocalizedText> distractors,
  }) : id = _validatedExecutionId(id, 'id'),
       distractors = List<LocalizedText>.unmodifiable(distractors) {
    _requireNonEmpty(this.distractors, 'distractors', 'turno de diálogo');
  }

  final String id;
  final LocalizedText partnerMessage;
  final LocalizedText prompt;
  final LocalizedText correctReply;
  final List<LocalizedText> distractors;
}

final class SpeechActivityExecution extends ActivityExecution {
  SpeechActivityExecution({required Iterable<SpeechExecutionPrompt> prompts})
    : prompts = List<SpeechExecutionPrompt>.unmodifiable(prompts) {
    _requireNonEmpty(this.prompts, 'prompts', 'fala');
    _ensureUniqueStrings(
      this.prompts.map((prompt) => prompt.id),
      'Speech prompt id',
    );
  }

  final List<SpeechExecutionPrompt> prompts;

  @override
  LearningActivityType get activityType => LearningActivityType.speech;
}

final class SpeechExecutionPrompt {
  SpeechExecutionPrompt({required String id, required this.text})
    : id = _validatedExecutionId(id, 'id');

  final String id;
  final LocalizedText text;
}

final class QuizActivityExecution extends ActivityExecution {
  QuizActivityExecution({required Iterable<QuizExecutionQuestion> questions})
    : questions = List<QuizExecutionQuestion>.unmodifiable(questions) {
    _requireNonEmpty(this.questions, 'questions', 'quiz');
    _ensureUniqueStrings(
      this.questions.map((question) => question.id),
      'Quiz question id',
    );
  }

  final List<QuizExecutionQuestion> questions;

  @override
  LearningActivityType get activityType => LearningActivityType.quiz;
}

final class QuizExecutionQuestion {
  QuizExecutionQuestion({
    required String id,
    required this.category,
    required this.scenario,
    required this.prompt,
    required this.correctAnswer,
    required Iterable<LocalizedText> distractors,
  }) : id = _validatedExecutionId(id, 'id'),
       distractors = List<LocalizedText>.unmodifiable(distractors) {
    _requireNonEmpty(this.distractors, 'distractors', 'pergunta de quiz');
  }

  final String id;
  final LocalizedText category;
  final LocalizedText scenario;
  final LocalizedText prompt;
  final LocalizedText correctAnswer;
  final List<LocalizedText> distractors;
}

final class ReviewActivityExecution extends ActivityExecution {
  ReviewActivityExecution({required Iterable<ReviewExecutionCard> cards})
    : cards = List<ReviewExecutionCard>.unmodifiable(cards) {
    _requireNonEmpty(this.cards, 'cards', 'revisão');
    _ensureUniqueStrings(this.cards.map((card) => card.id), 'Review card id');
  }

  final List<ReviewExecutionCard> cards;

  @override
  LearningActivityType get activityType => LearningActivityType.review;
}

final class ReviewExecutionCard {
  ReviewExecutionCard({
    required String id,
    required this.category,
    required this.context,
    required this.text,
  }) : id = _validatedExecutionId(id, 'id');

  final String id;
  final LocalizedText category;
  final LocalizedText context;
  final LocalizedText text;
}

String _validatedExecutionId(String value, String name) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(value, name, 'não pode estar vazio');
  }
  return trimmed;
}

void _requireNonEmpty<T>(List<T> values, String name, String context) {
  if (values.isEmpty) {
    throw ArgumentError.value(
      values,
      name,
      '$context deve conter pelo menos um item',
    );
  }
}

void _ensureUniqueStrings(Iterable<String> ids, String label) {
  final unique = <String>{};
  for (final id in ids) {
    if (!unique.add(id)) {
      throw ArgumentError('$label duplicado: $id.');
    }
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
    this.execution,
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
  final ActivityExecution? execution;
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
      final execution = revision.execution;
      if (execution != null && execution.activityType != type) {
        throw ArgumentError(
          'A execução da revisão ${revision.id} é ${execution.activityType.name}, '
          'mas a atividade $id é ${type.name}.',
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
