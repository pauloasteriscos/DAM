import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_assembler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('monta percurso preservando estrutura, locale, progresso e sync', () {
    final path = _buildPath();

    final model = const LearningMapAssembler().build(
      learningPath: path,
      packageVersion: 7,
      recoveredFromFallback: false,
      locale: 'pt-PT',
      projection: <LearningProgressProjectionEntry>[
        _projection(
          elementId: 'element-dialogue',
          activityId: 'activity-dialogue',
          state: LearningActivityState.completed,
          reason: ProgressionReason.completed,
          recommendationRank: 0,
        ),
        _projection(
          elementId: 'checkpoint-1',
          activityId: null,
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
        ),
      ],
      syncStates: const <String, ProgressSyncState>{
        'activity-dialogue': ProgressSyncState.pending,
      },
    );

    expect(model.learningPathId, 'path-1');
    expect(model.title, 'Percurso Erasmus+');
    expect(model.journeys.single.title, 'Jornada de Acolhimento');
    expect(model.journeys.single.stages.single.title, 'Chegada');
    expect(model.totalActivityCount, 1);
    expect(model.completedActivityCount, 1);
    expect(model.completionRatio, 1);

    final activity = model.journeys.single.stages.single.elements.first;

    expect(activity.title, 'Falar da minha casa');
    expect(activity.instructions, 'Pratica um diálogo.');
    expect(activity.activityType, LearningActivityType.dialogue);
    expect(activity.state, LearningActivityState.completed);
    expect(activity.syncState, ProgressSyncState.pending);
    expect(activity.competencyIds, contains('communication'));
    expect(activity.isPrimaryRecommendation, isTrue);

    final checkpoint = model.journeys.single.stages.single.elements.last;

    expect(checkpoint.elementType, PathElementType.checkpoint);
    expect(checkpoint.title, isNull);
    expect(checkpoint.activityId, isNull);
    expect(checkpoint.syncState, ProgressSyncState.clean);
  });

  test('usa defaultLocale quando o locale pedido não existe', () {
    final model = const LearningMapAssembler().build(
      learningPath: _buildPath(),
      packageVersion: 7,
      recoveredFromFallback: false,
      locale: 'de-DE',
      projection: <LearningProgressProjectionEntry>[
        _projection(
          elementId: 'element-dialogue',
          activityId: 'activity-dialogue',
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
          recommendationRank: 0,
        ),
        _projection(
          elementId: 'checkpoint-1',
          activityId: null,
          state: LearningActivityState.locked,
          reason: ProgressionReason.prerequisitesNotMet,
        ),
      ],
      syncStates: const <String, ProgressSyncState>{},
    );

    expect(model.title, 'Erasmus+ Learning Path');
    expect(model.journeys.single.title, 'Welcome Journey');

    final activity = model.journeys.single.stages.single.elements.first;
    expect(activity.title, 'Talk about my home');
  });

  test(
    'separa TARGET do SCAFFOLDING: título segue aprendizagem e instrução segue app',
    () {
      final model = const LearningMapAssembler().build(
        learningPath: _buildPath(),
        packageVersion: 7,
        recoveredFromFallback: false,
        locale: 'en-US',
        scaffoldingLocale: 'pt-PT',
        projection: <LearningProgressProjectionEntry>[
          _projection(
            elementId: 'element-dialogue',
            activityId: 'activity-dialogue',
            state: LearningActivityState.available,
            reason: ProgressionReason.ready,
            recommendationRank: 0,
          ),
          _projection(
            elementId: 'checkpoint-1',
            activityId: null,
            state: LearningActivityState.locked,
            reason: ProgressionReason.prerequisitesNotMet,
          ),
        ],
        syncStates: const <String, ProgressSyncState>{},
      );

      final activity = model.journeys.single.stages.single.elements.first;

      expect(activity.title, 'Talk about my home');
      expect(activity.instructions, 'Pratica um diálogo.');
    },
  );

  test('recusa projeção pertencente a outra versão do pacote', () {
    expect(
      () => const LearningMapAssembler().build(
        learningPath: _buildPath(),
        packageVersion: 7,
        recoveredFromFallback: false,
        locale: 'pt-PT',
        projection: <LearningProgressProjectionEntry>[
          _projection(
            elementId: 'element-dialogue',
            activityId: 'activity-dialogue',
            state: LearningActivityState.available,
            reason: ProgressionReason.ready,
            packageVersion: 6,
          ),
          _projection(
            elementId: 'checkpoint-1',
            activityId: null,
            state: LearningActivityState.available,
            reason: ProgressionReason.ready,
          ),
        ],
        syncStates: const <String, ProgressSyncState>{},
      ),
      throwsA(
        isA<LearningMapAssemblyException>().having(
          (error) => error.code,
          'code',
          LearningMapAssemblyErrorCode.projectionPackageMismatch,
        ),
      ),
    );
  });

  test('recusa percurso quando falta projeção de um elemento', () {
    expect(
      () => const LearningMapAssembler().build(
        learningPath: _buildPath(),
        packageVersion: 7,
        recoveredFromFallback: false,
        locale: 'pt-PT',
        projection: <LearningProgressProjectionEntry>[
          _projection(
            elementId: 'element-dialogue',
            activityId: 'activity-dialogue',
            state: LearningActivityState.available,
            reason: ProgressionReason.ready,
          ),
        ],
        syncStates: const <String, ProgressSyncState>{},
      ),
      throwsA(
        isA<LearningMapAssemblyException>().having(
          (error) => error.code,
          'code',
          LearningMapAssemblyErrorCode.missingProjectionEntry,
        ),
      ),
    );
  });

  test('schema v2 carries exact revision execution into the read model', () {
    final execution = DialogueActivityExecution(
      scenarioTitle: LocalizedText(<String, String>{
        'en': 'Mission scenario',
        'pt-PT': 'Cenário da missão',
      }),
      scenarioDescription: LocalizedText(<String, String>{
        'en': 'Mission description',
        'pt-PT': 'Descrição da missão',
      }),
      turns: <DialogueExecutionTurn>[
        DialogueExecutionTurn(
          id: 'turn-1',
          partnerMessage: LocalizedText(<String, String>{
            'en': 'Hello',
            'pt-PT': 'Olá',
          }),
          prompt: LocalizedText(<String, String>{
            'en': 'Reply',
            'pt-PT': 'Responde',
          }),
          correctReply: LocalizedText(<String, String>{
            'en': 'Hi',
            'pt-PT': 'Olá!',
          }),
          distractors: <LocalizedText>[
            LocalizedText(<String, String>{'en': 'Bye', 'pt-PT': 'Adeus'}),
          ],
        ),
      ],
    );

    final model = const LearningMapAssembler().build(
      learningPath: _buildPath(schemaVersion: 2, execution: execution),
      packageVersion: 7,
      recoveredFromFallback: false,
      locale: 'pt-PT',
      projection: <LearningProgressProjectionEntry>[
        _projection(
          elementId: 'element-dialogue',
          activityId: 'activity-dialogue',
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
          recommendationRank: 0,
        ),
        _projection(
          elementId: 'checkpoint-1',
          activityId: null,
          state: LearningActivityState.locked,
          reason: ProgressionReason.prerequisitesNotMet,
        ),
      ],
      syncStates: const <String, ProgressSyncState>{},
    );

    final activity = model.journeys.single.stages.single.elements.first;

    expect(activity.contentSchemaVersion, 2);
    expect(activity.contentDefaultLocale, 'en');
    expect(identical(activity.execution, execution), isTrue);
  });
}

LearningPath _buildPath({int schemaVersion = 1, ActivityExecution? execution}) {
  final activityId = ActivityId('activity-dialogue');
  final revisionId = RevisionId('revision-dialogue-1');
  final competencyId = CompetencyId('communication');

  return LearningPath(
    id: LearningPathId('path-1'),
    schemaVersion: SchemaVersion(schemaVersion),
    defaultLocale: 'en',
    title: LocalizedText(<String, String>{
      'en': 'Erasmus+ Learning Path',
      'pt-PT': 'Percurso Erasmus+',
    }),
    journeys: <Journey>[
      Journey(
        id: JourneyId('journey-1'),
        title: LocalizedText(<String, String>{
          'en': 'Welcome Journey',
          'pt-PT': 'Jornada de Acolhimento',
        }),
        stages: <Stage>[
          Stage(
            id: StageId('stage-1'),
            title: LocalizedText(<String, String>{
              'en': 'Arrival',
              'pt-PT': 'Chegada',
            }),
            elements: <PathElement>[
              PathElement(
                id: PathElementId('element-dialogue'),
                type: PathElementType.activity,
                activityId: activityId,
                practicePreference: PracticePreference.dialogue,
              ),
              PathElement(
                id: PathElementId('checkpoint-1'),
                type: PathElementType.checkpoint,
              ),
            ],
          ),
        ],
      ),
    ],
    activities: <Activity>[
      Activity(
        id: activityId,
        type: LearningActivityType.dialogue,
        origin: ContentOrigin.official,
        currentRevisionId: revisionId,
        revisions: <ActivityRevision>[
          ActivityRevision(
            id: revisionId,
            activityId: activityId,
            revisionNumber: 1,
            title: LocalizedText(<String, String>{
              'en': 'Talk about my home',
              'pt-PT': 'Falar da minha casa',
            }),
            instructions: LocalizedText(<String, String>{
              'en': 'Practise a dialogue.',
              'pt-PT': 'Pratica um diálogo.',
            }),
            visibility: ContentVisibility.public,
            execution: execution,
            competencies: <CompetencyId>{competencyId},
          ),
        ],
      ),
    ],
    competencies: <Competency>[
      Competency(
        id: competencyId,
        title: LocalizedText(<String, String>{
          'en': 'Communication',
          'pt-PT': 'Comunicação',
        }),
        description: LocalizedText(<String, String>{
          'en': 'Communicate in everyday situations.',
          'pt-PT': 'Comunicar em situações do dia a dia.',
        }),
      ),
    ],
  );
}

LearningProgressProjectionEntry _projection({
  required String elementId,
  required String? activityId,
  required LearningActivityState state,
  required ProgressionReason reason,
  int? recommendationRank,
  int packageVersion = 7,
}) {
  return LearningProgressProjectionEntry(
    pathElementId: elementId,
    activityId: activityId,
    state: state,
    reason: reason,
    recommendationRank: recommendationRank,
    packageVersion: packageVersion,
    updatedAt: DateTime.utc(2026, 9, 13, 20),
  );
}
