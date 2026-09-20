import 'package:dailytalk_mobile/state/app_learning_language_controller.dart';
import 'package:dailytalk_mobile/widgets/learning_language_quick_switcher.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await AppLearningLanguageController.instance.setLanguageCode(
      'it-IT',
      persist: false,
    );
  });

  testWidgets('shows the current practice language as a flag', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LearningLanguageQuickSwitcher()),
      ),
    );

    expect(
      find.byKey(const ValueKey<String>('learning-language-flag-it-IT')),
      findsOneWidget,
    );

    await AppLearningLanguageController.instance.setLanguageCode(
      'fr-FR',
      persist: false,
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('learning-language-flag-fr-FR')),
      findsOneWidget,
    );
  });

  testWidgets('opens the quick practice-language selector', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: LearningLanguageQuickSwitcher()),
      ),
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('learning-language-flag-it-IT')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Idioma a praticar'), findsWidgets);
    expect(find.text('English'), findsOneWidget);
    expect(find.text('Español'), findsOneWidget);
    expect(find.text('Français'), findsOneWidget);
    expect(find.text('Italiano'), findsOneWidget);
    expect(find.text('Deutsch'), findsOneWidget);
  });
}
