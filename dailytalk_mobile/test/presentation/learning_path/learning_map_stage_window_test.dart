import 'package:dailytalk_mobile/presentation/learning_path/learning_map_stage_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = LearningMapStageWindowPlanner();

  test('seleciona janela preservando ordem authored', () {
    final window = planner.plan(
      stages: _stages(),
      startStageIndex: 1,
      stageCount: 2,
    );

    expect(window.startStageIndex, 1);
    expect(window.requestedStageCount, 2);
    expect(window.totalStageCount, 4);
    expect(window.loadedStageCount, 2);
    expect(window.endStageIndexExclusive, 3);

    expect(window.stages.map((stage) => stage.stageId), <String>[
      'stage-1',
      'stage-2',
    ]);

    expect(window.pathElementIds, <String>[
      'element-1-a',
      'element-1-b',
      'element-2-a',
    ]);

    expect(window.hasPrevious, isTrue);
    expect(window.hasNext, isTrue);
  });

  test('deduplica activity ids sem alterar ordem da primeira ocorrencia', () {
    final window = planner.plan(
      stages: _stages(),
      startStageIndex: 0,
      stageCount: 3,
    );

    expect(window.activityIds, <String>[
      'activity-shared',
      'activity-0-b',
      'activity-1-b',
      'activity-2-a',
    ]);
  });

  test('janela pode atravessar fronteira entre jornadas', () {
    final window = planner.plan(
      stages: _stages(),
      startStageIndex: 1,
      stageCount: 3,
    );

    expect(window.stages.map((stage) => stage.journeyId), <String>[
      'journey-a',
      'journey-b',
      'journey-b',
    ]);

    expect(window.hasPrevious, isTrue);
    expect(window.hasNext, isFalse);
  });

  test('pedido maior que o restante termina no fim do percurso', () {
    final window = planner.plan(
      stages: _stages(),
      startStageIndex: 3,
      stageCount: 50,
    );

    expect(window.loadedStageCount, 1);
    expect(window.endStageIndexExclusive, 4);
    expect(window.hasPrevious, isTrue);
    expect(window.hasNext, isFalse);

    expect(window.pathElementIds, <String>['element-3-a']);
  });

  test('indices e tamanhos invalidos falham fechado', () {
    expect(
      () => planner.plan(stages: _stages(), startStageIndex: -1, stageCount: 1),
      throwsRangeError,
    );

    expect(
      () => planner.plan(stages: _stages(), startStageIndex: 0, stageCount: 0),
      throwsRangeError,
    );

    expect(
      () => planner.plan(stages: _stages(), startStageIndex: 4, stageCount: 1),
      throwsRangeError,
    );

    expect(
      () => planner.plan(
        stages: const <LearningMapStageDescriptor>[],
        startStageIndex: 0,
        stageCount: 1,
      ),
      throwsArgumentError,
    );
  });

  test('descritor normaliza ids e rejeita ids vazios', () {
    final descriptor = LearningMapStageDescriptor(
      journeyId: ' journey-a ',
      stageId: ' stage-a ',
      pathElementIds: const <String>[' element-a ', 'element-a', 'element-b'],
      activityIds: const <String>[' activity-a ', 'activity-a', 'activity-b'],
    );

    expect(descriptor.journeyId, 'journey-a');
    expect(descriptor.stageId, 'stage-a');

    expect(descriptor.pathElementIds, <String>['element-a', 'element-b']);

    expect(descriptor.activityIds, <String>['activity-a', 'activity-b']);

    expect(
      () => LearningMapStageDescriptor(
        journeyId: ' ',
        stageId: 'stage',
        pathElementIds: const <String>['element'],
        activityIds: const <String>[],
      ),
      throwsArgumentError,
    );

    expect(
      () => LearningMapStageDescriptor(
        journeyId: 'journey',
        stageId: 'stage',
        pathElementIds: const <String>[],
        activityIds: const <String>[],
      ),
      throwsArgumentError,
    );

    expect(
      () => LearningMapStageDescriptor(
        journeyId: 'journey',
        stageId: 'stage',
        pathElementIds: const <String>[' '],
        activityIds: const <String>[],
      ),
      throwsArgumentError,
    );
  });

  test('percurso sintetico grande materializa somente ids da janela', () {
    final stages = List<LearningMapStageDescriptor>.generate(1000, (index) {
      return LearningMapStageDescriptor(
        journeyId: 'journey-${index ~/ 100}',
        stageId: 'stage-$index',
        pathElementIds: <String>['element-$index-a', 'element-$index-b'],
        activityIds: <String>['activity-$index-a', 'activity-$index-b'],
      );
    }, growable: false);

    final window = planner.plan(
      stages: stages,
      startStageIndex: 500,
      stageCount: 5,
    );

    expect(window.totalStageCount, 1000);
    expect(window.loadedStageCount, 5);
    expect(window.pathElementIds, hasLength(10));
    expect(window.activityIds, hasLength(10));

    expect(window.stages.first.stageId, 'stage-500');

    expect(window.stages.last.stageId, 'stage-504');

    expect(window.pathElementIds.first, 'element-500-a');

    expect(window.pathElementIds.last, 'element-504-b');
  });
}

List<LearningMapStageDescriptor> _stages() {
  return <LearningMapStageDescriptor>[
    LearningMapStageDescriptor(
      journeyId: 'journey-a',
      stageId: 'stage-0',
      pathElementIds: const <String>['element-0-a', 'element-0-b'],
      activityIds: const <String>['activity-shared', 'activity-0-b'],
    ),
    LearningMapStageDescriptor(
      journeyId: 'journey-a',
      stageId: 'stage-1',
      pathElementIds: const <String>['element-1-a', 'element-1-b'],
      activityIds: const <String>['activity-shared', 'activity-1-b'],
    ),
    LearningMapStageDescriptor(
      journeyId: 'journey-b',
      stageId: 'stage-2',
      pathElementIds: const <String>['element-2-a'],
      activityIds: const <String>['activity-2-a'],
    ),
    LearningMapStageDescriptor(
      journeyId: 'journey-b',
      stageId: 'stage-3',
      pathElementIds: const <String>['element-3-a'],
      activityIds: const <String>['activity-shared'],
    ),
  ];
}
