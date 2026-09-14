import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const stageCount = 100;
  const elementsPerStage = 10;

  testWidgets('large path mounts only viewport-near stages initially', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    final model = _largeModel(
      stageCount: stageCount,
      elementsPerStage: elementsPerStage,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningMapView(model: model, scrollController: controller),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(SliverList), findsOneWidget);
    expect(find.byKey(const Key('learning-map-stage-stage-0')), findsOneWidget);
    expect(find.byKey(const Key('learning-map-stage-stage-99')), findsNothing);

    var mountedStageCount = 0;
    for (var index = 0; index < stageCount; index++) {
      if (find
          .byKey(Key('learning-map-stage-stage-$index'))
          .evaluate()
          .isNotEmpty) {
        mountedStageCount++;
      }
    }

    expect(mountedStageCount, greaterThan(0));
    expect(mountedStageCount, lessThan(stageCount));
    expect(model.totalActivityCount, 1000);
  });

  testWidgets('large path can lazily reach the final stage', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);

    final model = _largeModel(
      stageCount: stageCount,
      elementsPerStage: elementsPerStage,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LearningMapView(model: model, scrollController: controller),
        ),
      ),
    );
    await tester.pump();

    final finalStageFinder = find.byKey(
      const Key('learning-map-stage-stage-99'),
    );

    expect(finalStageFinder, findsNothing);
    expect(controller.hasClients, isTrue);
    expect(controller.position.maxScrollExtent, greaterThan(0));

    for (
      var attempt = 0;
      attempt < 12 && finalStageFinder.evaluate().isEmpty;
      attempt++
    ) {
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
    }

    expect(finalStageFinder, findsOneWidget);
  });
}

LearningMapViewModel _largeModel({
  required int stageCount,
  required int elementsPerStage,
}) {
  final stages = List<LearningMapStageViewModel>.generate(stageCount, (
    stageIndex,
  ) {
    final elements = List<LearningMapElementViewModel>.generate(
      elementsPerStage,
      (elementIndex) {
        final id = 'stage-$stageIndex-element-$elementIndex';

        return LearningMapElementViewModel(
          pathElementId: id,
          elementType: PathElementType.activity,
          activityId: 'activity-$id',
          revisionId: 'revision-$id',
          activityType: LearningActivityType.vocabulary,
          title: 'Mission $id',
          instructions: 'Synthetic large-path activity.',
          state: LearningActivityState.available,
          reason: ProgressionReason.ready,
          syncState: ProgressSyncState.clean,
          practicePreference: PracticePreference.balanced,
          competencyIds: const <String>{'communication'},
        );
      },
      growable: false,
    );

    return LearningMapStageViewModel(
      id: 'stage-$stageIndex',
      title: 'Stage $stageIndex',
      elements: elements,
    );
  }, growable: false);

  return LearningMapViewModel(
    learningPathId: 'large-path',
    title: 'Large Learning Path',
    locale: 'pt-PT',
    packageVersion: 1,
    recoveredFromFallback: false,
    completedActivityCount: 0,
    totalActivityCount: stageCount * elementsPerStage,
    journeys: <LearningMapJourneyViewModel>[
      LearningMapJourneyViewModel(
        id: 'large-journey',
        title: 'Large Journey',
        stages: stages,
      ),
    ],
  );
}
