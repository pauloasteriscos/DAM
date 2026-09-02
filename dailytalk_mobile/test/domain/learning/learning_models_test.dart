import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';

LocalizedText _text(String portuguese, {String? english}) {
  return LocalizedText({'pt-PT': portuguese, 'en': ?english});
}

ActivityRevision _revision({
  required ActivityId activityId,
  String id = 'revision-01',
  int number = 1,
}) {
  return ActivityRevision(
    id: RevisionId(id),
    activityId: activityId,
    revisionNumber: number,
    title: _text('Cumprimentos', english: 'Greetings'),
    instructions: _text('Escolhe a resposta correta.'),
    visibility: ContentVisibility.public,
    competencies: [CompetencyId('arrival.greeting')],
  );
}

void main() {
  group('LocalizedText', () {
    test('resolve locale exato, idioma e fallback', () {
      final text = _text('Cumprimentos', english: 'Greetings');

      expect(text.resolve('en-US', fallbackLocale: 'pt-PT'), 'Greetings');
      expect(text.resolve('fr-FR', fallbackLocale: 'pt-PT'), 'Cumprimentos');
    });

    test('rejeita coleção vazia', () {
      expect(() => LocalizedText(const {}), throwsArgumentError);
    });
  });

  group('Activity e ActivityRevision', () {
    test('mantém activityId estável e revisão atual explícita', () {
      final activityId = ActivityId('arrival.greetings');
      final first = _revision(activityId: activityId);
      final second = _revision(
        activityId: activityId,
        id: 'revision-02',
        number: 2,
      );
      final activity = Activity(
        id: activityId,
        type: LearningActivityType.dialogue,
        origin: ContentOrigin.official,
        currentRevisionId: second.id,
        revisions: [first, second],
      );

      expect(activity.id, activityId);
      expect(activity.currentRevision.id, RevisionId('revision-02'));
      expect(activity.currentRevision.revisionNumber, 2);
    });

    test('rejeita revisão pertencente a outra atividade', () {
      final activityId = ActivityId('arrival.greetings');
      final foreignRevision = _revision(
        activityId: ActivityId('school.greetings'),
      );

      expect(
        () => Activity(
          id: activityId,
          type: LearningActivityType.dialogue,
          origin: ContentOrigin.official,
          currentRevisionId: foreignRevision.id,
          revisions: [foreignRevision],
        ),
        throwsArgumentError,
      );
    });
  });

  group('LearningPath', () {
    test('compõe percurso, jornada, etapa e elemento', () {
      final activityId = ActivityId('arrival.greetings');
      final revision = _revision(activityId: activityId);
      final activity = Activity(
        id: activityId,
        type: LearningActivityType.dialogue,
        origin: ContentOrigin.official,
        currentRevisionId: revision.id,
        revisions: [revision],
      );
      final element = PathElement(
        id: PathElementId('arrival.element-01'),
        type: PathElementType.activity,
        activityId: activityId,
        practicePreference: PracticePreference.dialogue,
      );
      final stage = Stage(
        id: StageId('arrival.stage-01'),
        title: _text('Chegada'),
        elements: [element],
      );
      final journey = Journey(
        id: JourneyId('arrival.journey'),
        title: _text('Chegada ao destino'),
        stages: [stage],
      );
      final path = LearningPath(
        id: LearningPathId('student.fr-fr'),
        schemaVersion: SchemaVersion(1),
        defaultLocale: 'pt-PT',
        title: _text('Percurso do estudante'),
        journeys: [journey],
        activities: [activity],
        competencies: [
          Competency(
            id: CompetencyId('arrival.greeting'),
            title: _text('Cumprimentar'),
            description: _text('Reconhecer e utilizar cumprimentos básicos.'),
          ),
        ],
      );

      expect(path.schemaVersion, SchemaVersion(1));
      expect(path.journeys.single.stages.single.elements.single, element);
      expect(path.activities.single.currentRevision, revision);
    });

    test('rejeita StageId duplicado dentro da jornada', () {
      Stage stage(String title) => Stage(
        id: StageId('arrival.stage-01'),
        title: _text(title),
        elements: [
          PathElement(
            id: PathElementId('element-${title.toLowerCase()}'),
            type: PathElementType.scene,
          ),
        ],
      );

      expect(
        () => Journey(
          id: JourneyId('arrival.journey'),
          title: _text('Chegada'),
          stages: [stage('A'), stage('B')],
        ),
        throwsArgumentError,
      );
    });
  });

  group('PathElement', () {
    test('atividade exige activityId', () {
      expect(
        () => PathElement(
          id: PathElementId('element-01'),
          type: PathElementType.activity,
        ),
        throwsArgumentError,
      );
    });

    test('elemento visual não pode referenciar atividade', () {
      expect(
        () => PathElement(
          id: PathElementId('element-01'),
          type: PathElementType.reward,
          activityId: ActivityId('arrival.greetings'),
        ),
        throwsArgumentError,
      );
    });
  });
}
