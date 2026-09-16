import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_visuals.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const expectedTypeColors = <LearningActivityType, Color>{
    LearningActivityType.vocabulary: LearningMapVisualTokens.green,
    LearningActivityType.dialogue: LearningMapVisualTokens.blue,
    LearningActivityType.speech: LearningMapVisualTokens.purple,
    LearningActivityType.quiz: LearningMapVisualTokens.magenta,
    LearningActivityType.review: LearningMapVisualTokens.teal,
    LearningActivityType.integratedChallenge: LearningMapVisualTokens.gold,
  };

  for (final entry in expectedTypeColors.entries) {
    testWidgets('activity type ${entry.key.name} keeps semantic accent', (
      tester,
    ) async {
      final element = _activity(
        id: 'type-${entry.key.name}',
        type: entry.key,
        state: LearningActivityState.available,
      );

      await _pumpNode(tester, element);

      final iconFinder = find.byKey(
        Key(
          'learning-map-type-icon-${entry.key.name}-${element.pathElementId}',
        ),
      );

      expect(iconFinder, findsOneWidget);

      final icon = tester.widget<Icon>(iconFinder);

      expect(icon.color, entry.value);
    });
  }

  testWidgets('completed dialogue keeps dialogue blue and completion state', (
    tester,
  ) async {
    final element = _activity(
      id: 'completed-dialogue',
      type: LearningActivityType.dialogue,
      state: LearningActivityState.completed,
    );

    await _pumpNode(tester, element);

    final icon = tester.widget<Icon>(
      find.byKey(
        const Key('learning-map-type-icon-dialogue-completed-dialogue'),
      ),
    );

    expect(icon.color, LearningMapVisualTokens.blue);
    expect(find.text('Conclu\u00edda'), findsOneWidget);
  });

  testWidgets('locked quiz keeps quiz identity and locked state', (
    tester,
  ) async {
    final element = _activity(
      id: 'locked-quiz',
      type: LearningActivityType.quiz,
      state: LearningActivityState.locked,
    );

    await _pumpNode(tester, element);

    final icon = tester.widget<Icon>(
      find.byKey(const Key('learning-map-type-icon-quiz-locked-quiz')),
    );

    expect(icon.color, LearningMapVisualTokens.magenta);
    expect(find.text('Bloqueada'), findsOneWidget);
  });

  testWidgets(
    'activity cards do not duplicate the global synchronization signal',
    (tester) async {
      final element = _activity(
        id: 'clean-sync',
        type: LearningActivityType.speech,
        state: LearningActivityState.available,
        syncState: ProgressSyncState.clean,
      );

      await _pumpNode(tester, element);

      expect(
        find.byKey(const Key('learning-map-sync-clean-sync')),
        findsNothing,
      );
      expect(find.text('Sincronizado'), findsNothing);
      expect(find.text('Dispon\u00edvel'), findsOneWidget);
    },
  );

  testWidgets(
    'legacy activity without type renders generic instead of crashing',
    (tester) async {
      final element = _activity(
        id: 'generic',
        type: null,
        state: LearningActivityState.available,
      );

      await _pumpNode(tester, element);

      expect(
        find.byKey(const Key('learning-map-type-icon-generic-generic')),
        findsOneWidget,
      );

      expect(find.text('Miss\u00e3o'), findsOneWidget);
    },
  );
}

Future<void> _pumpNode(
  WidgetTester tester,
  LearningMapElementViewModel element,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: LearningMapVisualTokens.background,
        body: Center(
          child: SizedBox(
            width: 420,
            child: LearningMapActivityNode(element: element),
          ),
        ),
      ),
    ),
  );
}

LearningMapElementViewModel _activity({
  required String id,
  required LearningActivityType? type,
  required LearningActivityState state,
  ProgressSyncState syncState = ProgressSyncState.clean,
}) {
  return LearningMapElementViewModel(
    pathElementId: id,
    elementType: PathElementType.activity,
    activityId: 'activity-$id',
    revisionId: 'revision-$id',
    activityType: type,
    title: 'Miss\u00e3o sem\u00e2ntica',
    instructions: 'Atividade usada para validar a identidade visual.',
    competencyIds: const <String>{'communication'},
    state: state,
    reason: switch (state) {
      LearningActivityState.locked => ProgressionReason.prerequisitesNotMet,
      LearningActivityState.available => ProgressionReason.ready,
      LearningActivityState.inProgress => ProgressionReason.attemptStarted,
      LearningActivityState.completed => ProgressionReason.completed,
    },
    syncState: syncState,
    practicePreference: PracticePreference.balanced,
  );
}
