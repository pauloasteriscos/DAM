import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_activity_completed_page.dart';

void main() {
  testWidgets(
    'Continue volta diretamente ao mapa quando completion veio do Learning Map',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: FilledButton(
                  key: const ValueKey<String>('open-mission-detail'),
                  onPressed: () {
                    Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => const _MissionDetailHarness(),
                      ),
                    );
                  },
                  child: const Text('Open mission'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('open-mission-detail')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('mission-detail-harness')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const ValueKey<String>('open-completion')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('learning-activity-completed-page')),
        findsOneWidget,
      );

      await tester.tap(
        find.byKey(const ValueKey<String>('learning-completion-continue')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('learning-activity-completed-page')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('mission-detail-harness')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey<String>('open-mission-detail')),
        findsOneWidget,
      );
    },
  );

  testWidgets('default mantém o comportamento de um único pop', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: FilledButton(
                key: const ValueKey<String>('open-default-completion'),
                onPressed: () {
                  Navigator.of(context).push<void>(
                    MaterialPageRoute<void>(
                      builder: (_) => const LearningActivityCompletedPage(
                        activityType: LearningActivityType.vocabulary,
                        title: 'Mission',
                        competencyCount: 1,
                      ),
                    ),
                  );
                },
                child: const Text('Open completion'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('open-default-completion')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey<String>('learning-completion-continue')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('open-default-completion')),
      findsOneWidget,
    );
  });
}

final class _MissionDetailHarness extends StatelessWidget {
  const _MissionDetailHarness();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey<String>('mission-detail-harness'),
      body: Center(
        child: FilledButton(
          key: const ValueKey<String>('open-completion'),
          onPressed: () {
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => const LearningActivityCompletedPage(
                  activityType: LearningActivityType.vocabulary,
                  title: 'Mission',
                  competencyCount: 1,
                  returnToLearningMap: true,
                ),
              ),
            );
          },
          child: const Text('Complete'),
        ),
      ),
    );
  }
}
