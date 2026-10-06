import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:dailytalk_mobile/state/app_session_controller.dart';
import 'package:dailytalk_mobile/widgets/top_overflow_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('menu superior localiza Personalização pelo idioma da app', (
    tester,
  ) async {
    AppSessionController.instance.startTestMode();
    await AppLocaleController.instance.setLanguageCode('en-US', persist: false);

    await tester.pumpWidget(
      AppLocaleScope(
        controller: AppLocaleController.instance,
        child: AppSessionScope(
          controller: AppSessionController.instance,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(actions: const <Widget>[TopOverflowMenu()]),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.text('Personalization'), findsOneWidget);
    expect(find.text('Personalização'), findsNothing);
  });
}
