import 'package:dailytalk_mobile/models/audio_speed_control_style.dart';
import 'package:dailytalk_mobile/screens/personalization_page.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:dailytalk_mobile/state/audio_speed_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Personalização mostra o estilo de áudio atual e abre o seletor',
    (tester) async {
      final controller = AudioSpeedPreferencesController(
        readStyle: () async => AudioSpeedControlStyle.buttons.storageValue,
        writeStyle: (_) async {},
      );
      await controller.ensureLoaded();

      await tester.pumpWidget(
        AppLocaleScope(
          controller: AppLocaleController.instance,
          child: MaterialApp(
            home: PersonalizationPage(audioController: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Personalização'), findsOneWidget);
      expect(find.text('Estilo da velocidade do áudio'), findsOneWidget);
      expect(find.text('Botões'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('personalization-audio-speed-style')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Estilo da velocidade do áudio'), findsWidgets);
      expect(
        find.byKey(const ValueKey<String>('audio-style-buttons')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('audio-style-slider')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey<String>('audio-style-compact')),
        findsOneWidget,
      );
    },
  );
}
