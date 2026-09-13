import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_assembler.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_read_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('compõe catálogo, projeção e sync num único ViewModel', () async {
    String? catalogPath;
    String? projectionAccount;
    String? projectionPath;
    String? syncAccount;
    String? syncPath;

    final service = LearningMapReadService(
      loadActiveContent: (learningPathId) async {
        catalogPath = learningPathId;

        return LearningMapActiveContentSnapshot(
          path: _buildPath(),
          packageVersion: 9,
          recoveredFromFallback: true,
        );
      },
      loadProjection:
          ({required String accountId, required String learningPathId}) async {
            projectionAccount = accountId;
            projectionPath = learningPathId;

            return <LearningProgressProjectionEntry>[
              _projection(
                state: LearningActivityState.completed,
                reason: ProgressionReason.completed,
                recommendationRank: 0,
              ),
            ];
          },
      loadSyncStates:
          ({required String accountId, required String learningPathId}) async {
            syncAccount = accountId;
            syncPath = learningPathId;

            return const <String, ProgressSyncState>{
              'activity-1': ProgressSyncState.pending,
            };
          },
    );

    final model = await service.load(
      accountId: ' account-1 ',
      learningPathId: ' path-1 ',
      locale: ' pt-PT ',
    );

    expect(catalogPath, 'path-1');
    expect(projectionAccount, 'account-1');
    expect(projectionPath, 'path-1');
    expect(syncAccount, 'account-1');
    expect(syncPath, 'path-1');

    expect(model.learningPathId, 'path-1');
    expect(model.title, 'Percurso de Mobilidade');
    expect(model.locale, 'pt-PT');
    expect(model.packageVersion, 9);
    expect(model.recoveredFromFallback, isTrue);

    expect(model.totalActivityCount, 1);
    expect(model.completedActivityCount, 1);

    final element = model.elements.single;

    expect(element.activityId, 'activity-1');
    expect(element.title, 'Primeira conversa');
    expect(element.state, LearningActivityState.completed);
    expect(element.syncState, ProgressSyncState.pending);
    expect(element.isPrimaryRecommendation, isTrue);
  });

  test('recusa conteúdo cujo id não corresponde ao percurso solicitado', () {
    final service = LearningMapReadService(
      loadActiveContent: (_) async {
        return LearningMapActiveContentSnapshot(
          path: _buildPath(pathId: 'other-path'),
          packageVersion: 9,
          recoveredFromFallback: false,
        );
      },
      loadProjection:
          ({required String accountId, required String learningPathId}) async {
            return const <LearningProgressProjectionEntry>[];
          },
      loadSyncStates:
          ({required String accountId, required String learningPathId}) async {
            return const <String, ProgressSyncState>{};
          },
    );

    expect(
      service.load(
        accountId: 'account-1',
        learningPathId: 'path-1',
        locale: 'pt-PT',
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('identificadores e locale vazios são rejeitados', () {
    var loaderCalled = false;

    final service = LearningMapReadService(
      loadActiveContent: (_) async {
        loaderCalled = true;

        return LearningMapActiveContentSnapshot(
          path: _buildPath(),
          packageVersion: 9,
          recoveredFromFallback: false,
        );
      },
      loadProjection:
          ({required String accountId, required String learningPathId}) async {
            return const <LearningProgressProjectionEntry>[];
          },
      loadSyncStates:
          ({required String accountId, required String learningPathId}) async {
            return const <String, ProgressSyncState>{};
          },
    );

    expect(
      service.load(accountId: ' ', learningPathId: 'path-1', locale: 'pt-PT'),
      throwsArgumentError,
    );

    expect(
      service.load(
        accountId: 'account-1',
        learningPathId: ' ',
        locale: 'pt-PT',
      ),
      throwsArgumentError,
    );

    expect(
      service.load(
        accountId: 'account-1',
        learningPathId: 'path-1',
        locale: ' ',
      ),
      throwsArgumentError,
    );

    expect(loaderCalled, isFalse);
  });

  test('falha de forma explícita quando a projeção está ausente', () {
    final service = LearningMapReadService(
      loadActiveContent: (_) async {
        return LearningMapActiveContentSnapshot(
          path: _buildPath(),
          packageVersion: 9,
          recoveredFromFallback: false,
        );
      },
      loadProjection:
          ({required String accountId, required String learningPathId}) async {
            return const <LearningProgressProjectionEntry>[];
          },
      loadSyncStates:
          ({required String accountId, required String learningPathId}) async {
            return const <String, ProgressSyncState>{};
          },
    );

    expect(
      service.load(
        accountId: 'account-1',
        learningPathId: 'path-1',
        locale: 'pt-PT',
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
}

LearningPath _buildPath({String pathId = 'path-1'}) {
  final activityId = ActivityId('activity-1');
  final revisionId = RevisionId('activity-1-r1');

  return LearningPath(
    id: LearningPathId(pathId),
    schemaVersion: SchemaVersion(1),
    defaultLocale: 'en',
    title: LocalizedText(<String, String>{
      'en': 'Mobility Learning Path',
      'pt-PT': 'Percurso de Mobilidade',
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
                id: PathElementId('element-1'),
                type: PathElementType.activity,
                activityId: activityId,
                practicePreference: PracticePreference.dialogue,
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
              'en': 'First conversation',
              'pt-PT': 'Primeira conversa',
            }),
            instructions: LocalizedText(<String, String>{
              'en': 'Practise the conversation.',
              'pt-PT': 'Pratica a conversa.',
            }),
            visibility: ContentVisibility.public,
          ),
        ],
      ),
    ],
    competencies: const <Competency>[],
  );
}

LearningProgressProjectionEntry _projection({
  required LearningActivityState state,
  required ProgressionReason reason,
  int? recommendationRank,
}) {
  return LearningProgressProjectionEntry(
    pathElementId: 'element-1',
    activityId: 'activity-1',
    state: state,
    reason: reason,
    recommendationRank: recommendationRank,
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 13, 20),
  );
}
