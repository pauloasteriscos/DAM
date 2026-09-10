import 'dart:io';

import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter_test/flutter_test.dart';

const _referencePath =
    '../dailytalk-api/docs/phase2/official_reference_journey_v3.json';

LearningPath _loadReferenceJourney() {
  final source = File(_referencePath).readAsStringSync();
  return const LearningContentCodec().decodeString(source);
}

PathElementDecision _decision(ProgressionResult result, String elementId) {
  return result.decisions[PathElementId(elementId)]!;
}

void main() {
  group('Fase 2.4 — percurso oficial de referência', () {
    test('pacote v3 é válido e possui 16 atividades em 4 etapas', () {
      final path = _loadReferenceJourney();
      const LearningPathValidator().validate(path);

      expect(path.id.value, 'student.fr-fr.phase1');
      expect(path.schemaVersion.value, 1);
      expect(path.journeys, hasLength(1));
      expect(path.journeys.single.stages, hasLength(4));
      expect(path.activities, hasLength(16));
      expect(path.competencies, hasLength(8));
      expect(
        path.journeys.single.stages
            .expand((stage) => stage.elements)
            .where((element) => element.activityId != null),
        hasLength(16),
      );
    });

    test(
      'percurso cobre todos os tipos suportados com distribuição equilibrada',
      () {
        final path = _loadReferenceJourney();
        final counts = <LearningActivityType, int>{};
        for (final activity in path.activities) {
          counts.update(activity.type, (value) => value + 1, ifAbsent: () => 1);
        }

        expect(counts[LearningActivityType.vocabulary], 4);
        expect(counts[LearningActivityType.dialogue], 4);
        expect(counts[LearningActivityType.speech], 4);
        expect(counts[LearningActivityType.quiz], 2);
        expect(counts[LearningActivityType.review], 1);
        expect(counts[LearningActivityType.integratedChallenge], 1);
      },
    );

    test(
      'atividade existente evolui por nova revisão sem perder histórico',
      () {
        final path = _loadReferenceJourney();
        final vocabulary = path.activities.singleWhere(
          (activity) => activity.id.value == 'arrival.vocabulary-01',
        );

        expect(vocabulary.revisions, hasLength(3));
        expect(
          vocabulary.revisions.map((revision) => revision.revisionNumber),
          orderedEquals([1, 2, 3]),
        );
        expect(
          vocabulary.currentRevisionId.value,
          'arrival.vocabulary-01.revision-03',
        );
        expect(
          vocabulary.currentRevision.title.resolve(
            'fr-FR',
            fallbackLocale: path.defaultLocale,
          ),
          'Salutations essentielles',
        );
      },
    );

    test(
      'preferência altera recomendação inicial sem bloquear outros caminhos',
      () {
        final path = _loadReferenceJourney();
        const engine = DefaultProgressionEngine();
        final result = engine.evaluate(
          ProgressionRequest(
            learningPath: path,
            facts: ProgressionFacts(),
            practicePreference: PracticePreference.dialogue,
          ),
        );

        expect(
          _decision(result, 'arrival.vocabulary-01.element').state,
          LearningActivityState.available,
        );
        expect(
          _decision(result, 'arrival.dialogue-01.element').state,
          LearningActivityState.available,
        );
        expect(
          _decision(result, 'arrival.speech-01.element').state,
          LearningActivityState.available,
        );
        expect(
          result.recommendations.first.value,
          'arrival.dialogue-01.element',
        );
      },
    );

    test('ramo de diálogo permite avançar sem obrigar vocabulário inicial', () {
      final path = _loadReferenceJourney();
      const engine = DefaultProgressionEngine();
      final result = engine.evaluate(
        ProgressionRequest(
          learningPath: path,
          facts: ProgressionFacts(
            completedActivities: [ActivityId('arrival.dialogue-01')],
            achievedCompetencies: [CompetencyId('arrival.greeting-basics')],
          ),
        ),
      );

      expect(
        _decision(result, 'arrival.dialogue-02.element').state,
        LearningActivityState.available,
      );
      expect(
        _decision(result, 'arrival.quiz-01.element').state,
        LearningActivityState.available,
      );
      expect(
        _decision(result, 'arrival.vocabulary-02.element').state,
        LearningActivityState.locked,
      );
      expect(
        _decision(result, 'arrival.vocabulary-01.element').state,
        LearningActivityState.available,
      );
    });

    test('revisão exige amplitude mínima mas aceita caminhos alternativos', () {
      final path = _loadReferenceJourney();
      const engine = DefaultProgressionEngine();
      final result = engine.evaluate(
        ProgressionRequest(
          learningPath: path,
          facts: ProgressionFacts(
            completedActivities: [
              ActivityId('arrival.dialogue-01'),
              ActivityId('arrival.dialogue-02'),
              ActivityId('arrival.quiz-01'),
            ],
            achievedCompetencies: [CompetencyId('arrival.greeting-basics')],
          ),
        ),
      );

      expect(
        _decision(result, 'arrival.review-01.element').state,
        LearningActivityState.available,
      );
      expect(
        _decision(result, 'arrival.speech-02.element').state,
        LearningActivityState.locked,
      );
    });

    test(
      'refeições desbloqueiam quiz apenas após competências complementares',
      () {
        final path = _loadReferenceJourney();
        const engine = DefaultProgressionEngine();

        final branch = engine.evaluate(
          ProgressionRequest(
            learningPath: path,
            facts: ProgressionFacts(
              completedActivities: [
                ActivityId('arrival.vocabulary-01'),
                ActivityId('arrival.vocabulary-02'),
                ActivityId('arrival.quiz-01'),
                ActivityId('arrival.review-01'),
              ],
              achievedCompetencies: [CompetencyId('arrival.greeting-basics')],
            ),
            practicePreference: PracticePreference.vocabulary,
          ),
        );
        expect(
          _decision(branch, 'arrival.vocabulary-03.element').state,
          LearningActivityState.available,
        );
        expect(
          _decision(branch, 'arrival.dialogue-03.element').state,
          LearningActivityState.available,
        );
        expect(
          _decision(branch, 'arrival.speech-03.element').state,
          LearningActivityState.available,
        );
        expect(
          branch.recommendations.first.value,
          'arrival.vocabulary-03.element',
        );
        expect(
          _decision(branch, 'arrival.quiz-02.element').state,
          LearningActivityState.locked,
        );

        final readyForQuiz = engine.evaluate(
          ProgressionRequest(
            learningPath: path,
            facts: ProgressionFacts(
              completedActivities: [
                ActivityId('arrival.review-01'),
                ActivityId('arrival.vocabulary-03'),
                ActivityId('arrival.dialogue-03'),
              ],
              achievedCompetencies: [
                CompetencyId('arrival.meal-vocabulary'),
                CompetencyId('arrival.meal-interaction'),
              ],
            ),
          ),
        );
        expect(
          _decision(readyForQuiz, 'arrival.quiz-02.element').state,
          LearningActivityState.available,
        );
      },
    );

    test(
      'desafio final aceita diálogo ou fala e mantém ramo não escolhido aberto',
      () {
        final path = _loadReferenceJourney();
        const engine = DefaultProgressionEngine();
        final result = engine.evaluate(
          ProgressionRequest(
            learningPath: path,
            facts: ProgressionFacts(
              completedActivities: [
                ActivityId('arrival.quiz-02'),
                ActivityId('arrival.vocabulary-04'),
                ActivityId('arrival.dialogue-04'),
              ],
              achievedCompetencies: [
                CompetencyId('arrival.schedule-basics'),
                CompetencyId('arrival.help-basics'),
              ],
            ),
          ),
        );

        expect(
          _decision(result, 'arrival.integrated-01.element').state,
          LearningActivityState.available,
        );
        expect(
          _decision(result, 'arrival.speech-04.element').state,
          LearningActivityState.available,
        );
        expect(
          _decision(result, 'arrival.dialogue-04.element').state,
          LearningActivityState.completed,
        );
      },
    );
  });
}
