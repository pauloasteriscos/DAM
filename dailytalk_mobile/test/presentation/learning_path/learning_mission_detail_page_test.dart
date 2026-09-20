import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_view_model.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_mission_detail_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders a child-friendly mission entry before the runtime at 360px',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final mission = LearningMapElementViewModel(
        pathElementId: 'arrival.vocabulary-01',
        elementType: PathElementType.activity,
        activityId: 'arrival.vocabulary-01',
        revisionId: 'revision-03',
        activityType: LearningActivityType.vocabulary,
        title: 'Cumprimentos essenciais',
        instructions:
            'Associa as expressões essenciais de chegada ao significado certo.',
        competencyIds: const <String>{'greeting', 'arrival'},
        state: LearningActivityState.available,
        reason: ProgressionReason.ready,
        syncState: ProgressSyncState.clean,
        practicePreference: PracticePreference.balanced,
        contentDefaultLocale: 'pt-PT',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: LearningMissionDetailPage(
            mission: mission,
            runtimeDestination: const Scaffold(body: Text('RUNTIME_47B1')),
          ),
        ),
      );

      expect(find.text('A TUA PRÓXIMA MISSÃO'), findsOneWidget);
      expect(find.text('Vocabulário'), findsOneWidget);
      expect(find.text('Cumprimentos essenciais'), findsOneWidget);
      expect(find.text('Objetivo'), findsOneWidget);
      expect(find.text('2 competências'), findsOneWidget);
      expect(find.text('Começar missão'), findsOneWidget);
      expect(find.text('RUNTIME_47B1'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('mission-detail-start')),
      );
      await tester.pumpAndSettle();
      expect(find.text('RUNTIME_47B1'), findsOneWidget);
    },
  );
}
