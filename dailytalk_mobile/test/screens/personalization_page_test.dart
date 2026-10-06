import 'package:dailytalk_mobile/l10n/app_localizations.dart';
import 'package:dailytalk_mobile/models/audio_speed_control_style.dart';
import 'package:dailytalk_mobile/screens/personalization_page.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:dailytalk_mobile/state/audio_speed_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await AppLocaleController.instance.setLanguageCode('pt-PT', persist: false);
  });

  test('Personalização tem designação própria em todos os idiomas da app', () {
    const expected = <String, String>{
      'pt-PT': 'Personalização',
      'en-US': 'Personalization',
      'es-ES': 'Personalización',
      'fr-FR': 'Personnalisation',
      'it-IT': 'Personalizzazione',
      'de-DE': 'Personalisierung',
    };

    for (final entry in expected.entries) {
      expect(
        AppTranslations.translate('Personalização', entry.key),
        entry.value,
        reason: entry.key,
      );
    }
  });

  testWidgets(
    'Personalização segue o idioma da app e localiza todo o conteúdo de áudio',
    (tester) async {
      await AppLocaleController.instance.setLanguageCode(
        'en-US',
        persist: false,
      );

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

      expect(find.text('Personalization'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);
      expect(find.text('Customize your experience'), findsOneWidget);
      expect(
        find.text(
          'These preferences only change the app’s presentation and interaction.',
        ),
        findsOneWidget,
      );
      expect(find.text('Audio speed control style'), findsOneWidget);
      expect(
        find.text('Choose how the speed control appears in activities.'),
        findsOneWidget,
      );
      expect(find.text('Buttons'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey<String>('personalization-audio-speed-style')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Audio speed control style'), findsWidgets);
      expect(
        find.text('Choose how you want to control the speed'),
        findsOneWidget,
      );
      expect(
        find.text(
          'Your choice only changes the control style. The five speeds and the activity logic remain exactly the same.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('This preference is saved on this device.'),
        findsOneWidget,
      );
      expect(find.text('Buttons'), findsOneWidget);
      expect(find.text('Slider'), findsOneWidget);
      expect(find.text('Compact'), findsOneWidget);
      expect(
        find.text(
          'Five visible options with a clear highlight for the active speed.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('A slider with five positions for a smoother choice.'),
        findsOneWidget,
      );
      expect(
        find.text('A compact bar that leaves more room for the cards.'),
        findsOneWidget,
      );
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
