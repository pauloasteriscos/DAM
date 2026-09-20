import 'dart:convert';

import 'domain_ids.dart';
import 'learning_enums.dart';
import 'learning_models.dart';
import 'learning_path_validator.dart';
import 'prerequisite_rule.dart';

/// Código estável para falhas ao interpretar um pacote de conteúdo.
enum LearningContentErrorCode {
  invalidJson,
  invalidRoot,
  missingField,
  unexpectedField,
  invalidFieldType,
  invalidEnumValue,
  unsupportedSchemaVersion,
  invalidContent,
  invalidLearningPath,
}

/// Exceção de fronteira entre dados externos e o domínio de aprendizagem.
final class LearningContentException implements Exception {
  LearningContentException({
    required this.code,
    required this.location,
    required this.message,
    Iterable<LearningPathValidationIssue> validationIssues =
        const <LearningPathValidationIssue>[],
  }) : validationIssues = List<LearningPathValidationIssue>.unmodifiable(
         validationIssues,
       );

  final LearningContentErrorCode code;
  final String location;
  final String message;
  final List<LearningPathValidationIssue> validationIssues;

  @override
  String toString() => '${code.name} em $location: $message';
}

/// Serializa e interpreta pacotes de conteúdo das versões 1 e 2.
///
/// A descodificação é fail-fast para estrutura e tipos e, depois de construir
/// o agregado, executa a validação global de referências e ciclos.
final class LearningContentCodec {
  const LearningContentCodec({
    LearningPathValidator validator = const LearningPathValidator(),
  }) : _validator = validator;

  static const int latestSchemaVersion = 2;
  static const Set<int> supportedSchemaVersions = <int>{1, 2};

  final LearningPathValidator _validator;

  LearningPath decodeString(String source) {
    Object? decoded;
    try {
      decoded = jsonDecode(source);
    } on FormatException catch (error) {
      throw LearningContentException(
        code: LearningContentErrorCode.invalidJson,
        location: r'$root',
        message: error.message,
      );
    }

    if (decoded is! Map<String, dynamic>) {
      throw LearningContentException(
        code: LearningContentErrorCode.invalidRoot,
        location: r'$root',
        message: 'o pacote deve ser um objeto JSON',
      );
    }
    return decode(decoded);
  }

  LearningPath decode(Map<String, dynamic> package) {
    final reader = _JsonReader(package, r'$root');
    reader.allowOnly({
      'schemaVersion',
      'id',
      'defaultLocale',
      'title',
      'journeys',
      'activities',
      'competencies',
    });
    final schemaVersion = reader.integer('schemaVersion');
    if (!supportedSchemaVersions.contains(schemaVersion)) {
      throw LearningContentException(
        code: LearningContentErrorCode.unsupportedSchemaVersion,
        location: r'$root.schemaVersion',
        message: 'versão $schemaVersion não suportada',
      );
    }

    try {
      final path = LearningPath(
        id: LearningPathId(reader.string('id')),
        schemaVersion: SchemaVersion(schemaVersion),
        defaultLocale: reader.string('defaultLocale'),
        title: _localizedText(reader.object('title')),
        journeys: reader
            .objects('journeys')
            .map(_journey)
            .toList(growable: false),
        activities: reader
            .objects('activities')
            .map((item) => _activity(item, schemaVersion: schemaVersion))
            .toList(growable: false),
        competencies: reader
            .objects('competencies')
            .map(_competency)
            .toList(growable: false),
      );

      final validation = _validator.inspect(path);
      if (!validation.isValid) {
        throw LearningContentException(
          code: LearningContentErrorCode.invalidLearningPath,
          location: r'$root',
          message: 'o percurso contém referências ou dependências inválidas',
          validationIssues: validation.issues,
        );
      }
      return path;
    } on LearningContentException {
      rethrow;
    } on ArgumentError catch (error) {
      throw LearningContentException(
        code: LearningContentErrorCode.invalidContent,
        location: r'$root',
        message: error.message?.toString() ?? error.toString(),
      );
    }
  }

  String encodeString(LearningPath path, {bool pretty = false}) {
    final package = encode(path);
    return pretty
        ? const JsonEncoder.withIndent('  ').convert(package)
        : jsonEncode(package);
  }

  Map<String, dynamic> encode(LearningPath path) {
    if (!supportedSchemaVersions.contains(path.schemaVersion.value)) {
      throw LearningContentException(
        code: LearningContentErrorCode.unsupportedSchemaVersion,
        location: r'$root.schemaVersion',
        message: 'versão ${path.schemaVersion.value} não suportada',
      );
    }
    final validation = _validator.inspect(path);
    if (!validation.isValid) {
      throw LearningContentException(
        code: LearningContentErrorCode.invalidLearningPath,
        location: r'$root',
        message: 'o percurso contém referências ou dependências inválidas',
        validationIssues: validation.issues,
      );
    }

    return <String, dynamic>{
      'schemaVersion': path.schemaVersion.value,
      'id': path.id.value,
      'defaultLocale': path.defaultLocale,
      'title': _encodeLocalizedText(path.title),
      'journeys': path.journeys.map(_encodeJourney).toList(growable: false),
      'activities': path.activities
          .map(
            (activity) => _encodeActivity(
              activity,
              schemaVersion: path.schemaVersion.value,
            ),
          )
          .toList(growable: false),
      'competencies': path.competencies
          .map(_encodeCompetency)
          .toList(growable: false),
    };
  }

  LocalizedText _localizedText(_JsonReader reader) {
    final values = <String, String>{};
    for (final entry in reader.source.entries) {
      if (entry.value is! String) {
        throw LearningContentException(
          code: LearningContentErrorCode.invalidFieldType,
          location: '${reader.location}.${entry.key}',
          message: 'era esperado texto',
        );
      }
      values[entry.key] = entry.value as String;
    }
    return LocalizedText(values);
  }

  Competency _competency(_JsonReader reader) {
    reader.allowOnly({'id', 'title', 'description'});
    return Competency(
      id: CompetencyId(reader.string('id')),
      title: _localizedText(reader.object('title')),
      description: _localizedText(reader.object('description')),
    );
  }

  Activity _activity(_JsonReader reader, {required int schemaVersion}) {
    reader.allowOnly({
      'id',
      'type',
      'origin',
      'currentRevisionId',
      'revisions',
    });
    final type = reader.enumeration('type', LearningActivityType.values);
    return Activity(
      id: ActivityId(reader.string('id')),
      type: type,
      origin: reader.enumeration('origin', ContentOrigin.values),
      currentRevisionId: RevisionId(reader.string('currentRevisionId')),
      revisions: reader
          .objects('revisions')
          .map(
            (item) => _activityRevision(
              item,
              schemaVersion: schemaVersion,
              activityType: type,
            ),
          )
          .toList(growable: false),
    );
  }

  ActivityRevision _activityRevision(
    _JsonReader reader, {
    required int schemaVersion,
    required LearningActivityType activityType,
  }) {
    reader.allowOnly({
      'id',
      'activityId',
      'revisionNumber',
      'title',
      'instructions',
      'visibility',
      'competencies',
      if (schemaVersion >= 2) 'execution',
    });

    final execution = schemaVersion >= 2
        ? _activityExecution(reader.object('execution'), activityType)
        : null;

    return ActivityRevision(
      id: RevisionId(reader.string('id')),
      activityId: ActivityId(reader.string('activityId')),
      revisionNumber: reader.integer('revisionNumber'),
      title: _localizedText(reader.object('title')),
      instructions: _localizedText(reader.object('instructions')),
      visibility: reader.enumeration('visibility', ContentVisibility.values),
      execution: execution,
      competencies: reader
          .strings('competencies')
          .map(CompetencyId.new)
          .toList(growable: false),
    );
  }

  ActivityExecution _activityExecution(
    _JsonReader reader,
    LearningActivityType activityType,
  ) {
    final kind = reader.enumeration('kind', LearningActivityType.values);
    if (kind != activityType) {
      throw LearningContentException(
        code: LearningContentErrorCode.invalidContent,
        location: '${reader.location}.kind',
        message:
            'execution.kind=${kind.name} não corresponde ao tipo ${activityType.name}',
      );
    }

    return switch (kind) {
      LearningActivityType.vocabulary => _vocabularyExecution(reader),
      LearningActivityType.dialogue => _dialogueExecution(reader),
      LearningActivityType.speech => _speechExecution(reader),
      LearningActivityType.quiz => _quizExecution(reader),
      LearningActivityType.review => _reviewExecution(reader),
      LearningActivityType.integratedChallenge => throw LearningContentException(
        code: LearningContentErrorCode.invalidContent,
        location: reader.location,
        message:
            'integratedChallenge ainda não possui runtime executável no schema 2',
      ),
    };
  }

  VocabularyActivityExecution _vocabularyExecution(_JsonReader reader) {
    reader.allowOnly({'kind', 'items'});
    return VocabularyActivityExecution(
      items: reader.objects('items').map((item) {
        item.allowOnly({'id', 'text'});
        return VocabularyExecutionItem(
          id: item.string('id'),
          text: _localizedText(item.object('text')),
        );
      }),
    );
  }

  DialogueActivityExecution _dialogueExecution(_JsonReader reader) {
    reader.allowOnly({'kind', 'scenarioTitle', 'scenarioDescription', 'turns'});
    return DialogueActivityExecution(
      scenarioTitle: _localizedText(reader.object('scenarioTitle')),
      scenarioDescription: _localizedText(reader.object('scenarioDescription')),
      turns: reader.objects('turns').map((turn) {
        turn.allowOnly({
          'id',
          'partnerMessage',
          'prompt',
          'correctReply',
          'distractors',
        });
        return DialogueExecutionTurn(
          id: turn.string('id'),
          partnerMessage: _localizedText(turn.object('partnerMessage')),
          prompt: _localizedText(turn.object('prompt')),
          correctReply: _localizedText(turn.object('correctReply')),
          distractors: turn.objects('distractors').map(_localizedText),
        );
      }),
    );
  }

  SpeechActivityExecution _speechExecution(_JsonReader reader) {
    reader.allowOnly({'kind', 'prompts'});
    return SpeechActivityExecution(
      prompts: reader.objects('prompts').map((prompt) {
        prompt.allowOnly({'id', 'text'});
        return SpeechExecutionPrompt(
          id: prompt.string('id'),
          text: _localizedText(prompt.object('text')),
        );
      }),
    );
  }

  QuizActivityExecution _quizExecution(_JsonReader reader) {
    reader.allowOnly({'kind', 'questions'});
    return QuizActivityExecution(
      questions: reader.objects('questions').map((question) {
        question.allowOnly({
          'id',
          'category',
          'scenario',
          'prompt',
          'correctAnswer',
          'distractors',
        });
        return QuizExecutionQuestion(
          id: question.string('id'),
          category: _localizedText(question.object('category')),
          scenario: _localizedText(question.object('scenario')),
          prompt: _localizedText(question.object('prompt')),
          correctAnswer: _localizedText(question.object('correctAnswer')),
          distractors: question.objects('distractors').map(_localizedText),
        );
      }),
    );
  }

  ReviewActivityExecution _reviewExecution(_JsonReader reader) {
    reader.allowOnly({'kind', 'cards'});
    return ReviewActivityExecution(
      cards: reader.objects('cards').map((card) {
        card.allowOnly({'id', 'category', 'context', 'text'});
        return ReviewExecutionCard(
          id: card.string('id'),
          category: _localizedText(card.object('category')),
          context: _localizedText(card.object('context')),
          text: _localizedText(card.object('text')),
        );
      }),
    );
  }

  Journey _journey(_JsonReader reader) {
    reader.allowOnly({'id', 'title', 'stages'});
    return Journey(
      id: JourneyId(reader.string('id')),
      title: _localizedText(reader.object('title')),
      stages: reader.objects('stages').map(_stage).toList(growable: false),
    );
  }

  Stage _stage(_JsonReader reader) {
    reader.allowOnly({'id', 'title', 'elements'});
    return Stage(
      id: StageId(reader.string('id')),
      title: _localizedText(reader.object('title')),
      elements: reader
          .objects('elements')
          .map(_pathElement)
          .toList(growable: false),
    );
  }

  PathElement _pathElement(_JsonReader reader) {
    reader.allowOnly({
      'id',
      'type',
      'activityId',
      'prerequisites',
      'practicePreference',
    });
    final activityId = reader.optionalString('activityId');
    final prerequisites = reader.optionalObject('prerequisites');
    return PathElement(
      id: PathElementId(reader.string('id')),
      type: reader.enumeration('type', PathElementType.values),
      activityId: activityId == null ? null : ActivityId(activityId),
      prerequisites: prerequisites == null
          ? null
          : _prerequisite(prerequisites),
      practicePreference:
          reader.optionalEnumeration(
            'practicePreference',
            PracticePreference.values,
          ) ??
          PracticePreference.balanced,
    );
  }

  PrerequisiteRule _prerequisite(_JsonReader reader) {
    switch (reader.string('type')) {
      case 'activityCompleted':
        reader.allowOnly({'type', 'activityId'});
        return ActivityCompletedRequirement(
          ActivityId(reader.string('activityId')),
        );
      case 'competencyAchieved':
        reader.allowOnly({'type', 'competencyId'});
        return CompetencyAchievedRequirement(
          CompetencyId(reader.string('competencyId')),
        );
      case 'group':
        reader.allowOnly({'type', 'operator', 'rules'});
        return PrerequisiteGroup(
          operator: reader.enumeration('operator', PrerequisiteOperator.values),
          rules: reader
              .objects('rules')
              .map(_prerequisite)
              .toList(growable: false),
        );
      default:
        throw LearningContentException(
          code: LearningContentErrorCode.invalidEnumValue,
          location: '${reader.location}.type',
          message: 'tipo de pré-requisito desconhecido',
        );
    }
  }

  Map<String, dynamic> _encodeLocalizedText(LocalizedText text) =>
      Map<String, dynamic>.from(text.values);

  Map<String, dynamic> _encodeCompetency(Competency competency) => {
    'id': competency.id.value,
    'title': _encodeLocalizedText(competency.title),
    'description': _encodeLocalizedText(competency.description),
  };

  Map<String, dynamic> _encodeActivity(
    Activity activity, {
    required int schemaVersion,
  }) => {
    'id': activity.id.value,
    'type': activity.type.name,
    'origin': activity.origin.name,
    'currentRevisionId': activity.currentRevisionId.value,
    'revisions': activity.revisions
        .map(
          (revision) =>
              _encodeActivityRevision(revision, schemaVersion: schemaVersion),
        )
        .toList(growable: false),
  };

  Map<String, dynamic> _encodeActivityRevision(
    ActivityRevision revision, {
    required int schemaVersion,
  }) {
    final execution = revision.execution;

    if (schemaVersion == 1 && execution != null) {
      throw LearningContentException(
        code: LearningContentErrorCode.invalidContent,
        location: 'activity:${revision.activityId}/revision:${revision.id}',
        message: 'schema 1 não suporta conteúdo execution',
      );
    }

    if (schemaVersion >= 2 && execution == null) {
      throw LearningContentException(
        code: LearningContentErrorCode.invalidContent,
        location: 'activity:${revision.activityId}/revision:${revision.id}',
        message: 'schema $schemaVersion exige conteúdo execution',
      );
    }

    return <String, dynamic>{
      'id': revision.id.value,
      'activityId': revision.activityId.value,
      'revisionNumber': revision.revisionNumber,
      'title': _encodeLocalizedText(revision.title),
      'instructions': _encodeLocalizedText(revision.instructions),
      'visibility': revision.visibility.name,
      'competencies': revision.competencies
          .map((competency) => competency.value)
          .toList(growable: false),
      if (execution != null) 'execution': _encodeActivityExecution(execution),
    };
  }

  Map<String, dynamic> _encodeActivityExecution(ActivityExecution execution) {
    return switch (execution) {
      VocabularyActivityExecution() => <String, dynamic>{
        'kind': execution.activityType.name,
        'items': execution.items
            .map(
              (item) => <String, dynamic>{
                'id': item.id,
                'text': _encodeLocalizedText(item.text),
              },
            )
            .toList(growable: false),
      },
      DialogueActivityExecution() => <String, dynamic>{
        'kind': execution.activityType.name,
        'scenarioTitle': _encodeLocalizedText(execution.scenarioTitle),
        'scenarioDescription': _encodeLocalizedText(
          execution.scenarioDescription,
        ),
        'turns': execution.turns
            .map(
              (turn) => <String, dynamic>{
                'id': turn.id,
                'partnerMessage': _encodeLocalizedText(turn.partnerMessage),
                'prompt': _encodeLocalizedText(turn.prompt),
                'correctReply': _encodeLocalizedText(turn.correctReply),
                'distractors': turn.distractors
                    .map(_encodeLocalizedText)
                    .toList(growable: false),
              },
            )
            .toList(growable: false),
      },
      SpeechActivityExecution() => <String, dynamic>{
        'kind': execution.activityType.name,
        'prompts': execution.prompts
            .map(
              (prompt) => <String, dynamic>{
                'id': prompt.id,
                'text': _encodeLocalizedText(prompt.text),
              },
            )
            .toList(growable: false),
      },
      QuizActivityExecution() => <String, dynamic>{
        'kind': execution.activityType.name,
        'questions': execution.questions
            .map(
              (question) => <String, dynamic>{
                'id': question.id,
                'category': _encodeLocalizedText(question.category),
                'scenario': _encodeLocalizedText(question.scenario),
                'prompt': _encodeLocalizedText(question.prompt),
                'correctAnswer': _encodeLocalizedText(question.correctAnswer),
                'distractors': question.distractors
                    .map(_encodeLocalizedText)
                    .toList(growable: false),
              },
            )
            .toList(growable: false),
      },
      ReviewActivityExecution() => <String, dynamic>{
        'kind': execution.activityType.name,
        'cards': execution.cards
            .map(
              (card) => <String, dynamic>{
                'id': card.id,
                'category': _encodeLocalizedText(card.category),
                'context': _encodeLocalizedText(card.context),
                'text': _encodeLocalizedText(card.text),
              },
            )
            .toList(growable: false),
      },
    };
  }

  Map<String, dynamic> _encodeJourney(Journey journey) => {
    'id': journey.id.value,
    'title': _encodeLocalizedText(journey.title),
    'stages': journey.stages.map(_encodeStage).toList(growable: false),
  };

  Map<String, dynamic> _encodeStage(Stage stage) => {
    'id': stage.id.value,
    'title': _encodeLocalizedText(stage.title),
    'elements': stage.elements.map(_encodePathElement).toList(growable: false),
  };

  Map<String, dynamic> _encodePathElement(PathElement element) => {
    'id': element.id.value,
    'type': element.type.name,
    if (element.activityId case final id?) 'activityId': id.value,
    if (element.prerequisites case final rule?)
      'prerequisites': _encodePrerequisite(rule),
    'practicePreference': element.practicePreference.name,
  };

  Map<String, dynamic> _encodePrerequisite(PrerequisiteRule rule) {
    return switch (rule) {
      ActivityCompletedRequirement() => {
        'type': 'activityCompleted',
        'activityId': rule.activityId.value,
      },
      CompetencyAchievedRequirement() => {
        'type': 'competencyAchieved',
        'competencyId': rule.competencyId.value,
      },
      PrerequisiteGroup() => {
        'type': 'group',
        'operator': rule.operator.name,
        'rules': rule.rules.map(_encodePrerequisite).toList(growable: false),
      },
    };
  }
}

final class _JsonReader {
  const _JsonReader(this.source, this.location);

  final Map<String, dynamic> source;
  final String location;

  void allowOnly(Set<String> fields) {
    for (final field in source.keys) {
      if (!fields.contains(field)) {
        throw LearningContentException(
          code: LearningContentErrorCode.unexpectedField,
          location: '$location.$field',
          message: 'campo não reconhecido pelo schema',
        );
      }
    }
  }

  Object _required(String field) {
    if (!source.containsKey(field) || source[field] == null) {
      throw LearningContentException(
        code: LearningContentErrorCode.missingField,
        location: '$location.$field',
        message: 'campo obrigatório ausente',
      );
    }
    return source[field] as Object;
  }

  String string(String field) {
    final value = _required(field);
    if (value is String) return value;
    throw _invalidType(field, 'texto');
  }

  String? optionalString(String field) {
    final value = source[field];
    if (value == null) return null;
    if (value is String) return value;
    throw _invalidType(field, 'texto');
  }

  int integer(String field) {
    final value = _required(field);
    if (value is int) return value;
    throw _invalidType(field, 'número inteiro');
  }

  _JsonReader object(String field) {
    final value = _required(field);
    if (value is Map<String, dynamic>) {
      return _JsonReader(value, '$location.$field');
    }
    throw _invalidType(field, 'objeto');
  }

  _JsonReader? optionalObject(String field) {
    final value = source[field];
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      return _JsonReader(value, '$location.$field');
    }
    throw _invalidType(field, 'objeto');
  }

  List<_JsonReader> objects(String field) {
    final value = _required(field);
    if (value is! List<dynamic>) throw _invalidType(field, 'lista');
    return List<_JsonReader>.generate(value.length, (index) {
      final item = value[index];
      if (item is! Map<String, dynamic>) {
        throw LearningContentException(
          code: LearningContentErrorCode.invalidFieldType,
          location: '$location.$field[$index]',
          message: 'era esperado objeto',
        );
      }
      return _JsonReader(item, '$location.$field[$index]');
    });
  }

  List<String> strings(String field) {
    final value = _required(field);
    if (value is! List<dynamic>) throw _invalidType(field, 'lista');
    return List<String>.generate(value.length, (index) {
      final item = value[index];
      if (item is! String) {
        throw LearningContentException(
          code: LearningContentErrorCode.invalidFieldType,
          location: '$location.$field[$index]',
          message: 'era esperado texto',
        );
      }
      return item;
    });
  }

  T enumeration<T extends Enum>(String field, List<T> values) {
    final name = string(field);
    for (final value in values) {
      if (value.name == name) return value;
    }
    throw LearningContentException(
      code: LearningContentErrorCode.invalidEnumValue,
      location: '$location.$field',
      message: 'valor desconhecido: $name',
    );
  }

  T? optionalEnumeration<T extends Enum>(String field, List<T> values) {
    if (!source.containsKey(field) || source[field] == null) return null;
    return enumeration(field, values);
  }

  LearningContentException _invalidType(String field, String expected) =>
      LearningContentException(
        code: LearningContentErrorCode.invalidFieldType,
        location: '$location.$field',
        message: 'era esperado $expected',
      );
}
