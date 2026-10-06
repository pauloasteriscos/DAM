import 'package:dailytalk_mobile/audio/vocabulary_pronunciation_player.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/models/audio_speed_control_style.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_vocabulary_runtime_page.dart';
import 'package:dailytalk_mobile/state/app_learning_language_controller.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:dailytalk_mobile/state/audio_speed_preferences_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await AppLocaleController.instance.setLanguageCode('pt-PT');
    await AppLearningLanguageController.instance.setLanguageCode(
      'it-IT',
      persist: false,
    );
  });

  testWidgets(
    'schema-v2 vocabulary renders authored execution without legacy bank',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          home: LearningVocabularyRuntimePage(
            execution: _execution(),
            contentDefaultLocale: 'pt-PT',
            pronunciationPlayer: _FakeVocabularyPronunciationPlayer(),
            audioPreferencesController: _audioPreferences(),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Combina os pares'), findsOneWidget);
      expect(find.text('Olá'), findsOneWidget);
      expect(find.text('Ciao'), findsOneWidget);
      expect(find.text('Obrigado'), findsOneWidget);
      expect(find.text('Grazie'), findsOneWidget);
      expect(find.text('Estou cansado'), findsNothing);
      expect(find.textContaining('Recomendado'), findsNothing);

      await tester.tap(
        find.byKey(const ValueKey<String>('mission-vocab-left-hello')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('mission-vocab-right-hello')),
      );
      await tester.pump(const Duration(milliseconds: 450));

      await tester.tap(
        find.byKey(const ValueKey<String>('mission-vocab-left-thanks')),
      );
      await tester.tap(
        find.byKey(const ValueKey<String>('mission-vocab-right-thanks')),
      );
      await tester.pump(const Duration(milliseconds: 450));

      expect(find.text('Prática terminada'), findsOneWidget);

      final complete = find.byKey(
        const ValueKey<String>('mission-vocab-complete'),
      );
      expect(complete, findsOneWidget);
      await tester.tap(complete);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('learning-activity-completed-page')),
        findsOneWidget,
      );
      expect(find.text('Atividade concluída'), findsOneWidget);
      expect(find.text('2/2'), findsOneWidget);
    },
  );

  testWidgets('target language text follows the practice-language controller', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: LearningVocabularyRuntimePage(
          execution: _execution(),
          contentDefaultLocale: 'pt-PT',
          pronunciationPlayer: _FakeVocabularyPronunciationPlayer(),
          audioPreferencesController: _audioPreferences(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Ciao'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);

    await AppLearningLanguageController.instance.setLanguageCode(
      'en-US',
      persist: false,
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Ciao'), findsNothing);
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('right cards pronounce the target language and respect speed', (
    tester,
  ) async {
    final player = _FakeVocabularyPronunciationPlayer();

    await tester.pumpWidget(
      MaterialApp(
        home: LearningVocabularyRuntimePage(
          execution: _execution(),
          contentDefaultLocale: 'pt-PT',
          pronunciationPlayer: player,
          audioPreferencesController: _audioPreferences(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('mission-vocab-audio-hello')),
      findsOneWidget,
    );

    await tester.tap(
      find.byKey(const ValueKey<String>('mission-vocab-right-hello')),
    );
    await tester.pump();

    expect(player.calls, hasLength(1));
    expect(player.calls.single.text, 'Ciao');
    expect(player.calls.single.locale, 'it-IT');
    expect(player.calls.single.speed, 1);

    await tester.tap(
      find.byKey(const ValueKey<String>('mission-vocab-speed-0-5')),
    );
    await tester.pump();

    final thanksAudio = find.byKey(
      const ValueKey<String>('mission-vocab-audio-thanks'),
    );
    expect(
      find.ancestor(of: thanksAudio, matching: find.byType(IconButton)),
      findsNothing,
    );

    await tester.tap(thanksAudio);
    await tester.pump();

    expect(player.calls, hasLength(2));
    expect(player.calls.last.text, 'Grazie');
    expect(player.calls.last.locale, 'it-IT');
    expect(player.calls.last.speed, 0.5);

    // The speaker is only a visual indicator inside the card. Tapping exactly
    // on it must select the same card as any other point of the card.
    await tester.tap(
      find.byKey(const ValueKey<String>('mission-vocab-left-thanks')),
    );
    await tester.pump(const Duration(milliseconds: 450));

    expect(find.text('1/2 · 1 tentativas'), findsOneWidget);
  });

  testWidgets('unavailable audio stays grey and never blocks card selection', (
    tester,
  ) async {
    final player = _FakeVocabularyPronunciationPlayer(available: false);

    await tester.pumpWidget(
      MaterialApp(
        home: LearningVocabularyRuntimePage(
          execution: _execution(),
          contentDefaultLocale: 'pt-PT',
          pronunciationPlayer: player,
          audioPreferencesController: _audioPreferences(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    final audioFinder = find.byKey(
      const ValueKey<String>('mission-vocab-audio-hello'),
    );
    expect(audioFinder, findsOneWidget);

    final icon = tester.widget<Icon>(audioFinder);
    expect(icon.color, const Color(0xFF9AAAB3));
    expect(
      find.ancestor(of: audioFinder, matching: find.byType(IconButton)),
      findsNothing,
    );

    // Even without TTS support, the whole card remains one interaction target.
    await tester.tap(audioFinder);
    await tester.pump();
    await tester.tap(
      find.byKey(const ValueKey<String>('mission-vocab-left-hello')),
    );
    await tester.pump(const Duration(milliseconds: 450));

    expect(player.calls, isEmpty);
    expect(find.text('1/2 · 1 tentativas'), findsOneWidget);
    expect(find.byType(SnackBar), findsNothing);
  });
}

AudioSpeedPreferencesController _audioPreferences({
  AudioSpeedControlStyle style = AudioSpeedControlStyle.compact,
}) {
  return AudioSpeedPreferencesController(
    readStyle: () async => style.storageValue,
    writeStyle: (_) async {},
  );
}

VocabularyActivityExecution _execution() {
  return VocabularyActivityExecution(
    items: <VocabularyExecutionItem>[
      VocabularyExecutionItem(
        id: 'hello',
        text: LocalizedText(<String, String>{
          'pt-PT': 'Olá',
          'it-IT': 'Ciao',
          'en-US': 'Hello',
        }),
      ),
      VocabularyExecutionItem(
        id: 'thanks',
        text: LocalizedText(<String, String>{
          'pt-PT': 'Obrigado',
          'it-IT': 'Grazie',
          'en-US': 'Thank you',
        }),
      ),
    ],
  );
}

final class _PronunciationCall {
  const _PronunciationCall({
    required this.text,
    required this.locale,
    required this.speed,
  });

  final String text;
  final String locale;
  final double speed;
}

final class _FakeVocabularyPronunciationPlayer
    implements VocabularyPronunciationPlayer {
  _FakeVocabularyPronunciationPlayer({this.available = true});

  final bool available;
  final List<_PronunciationCall> calls = <_PronunciationCall>[];

  @override
  Future<bool> isAvailable({required String locale}) async => available;

  @override
  Future<bool> speak({
    required String text,
    required String locale,
    required double speed,
  }) async {
    calls.add(_PronunciationCall(text: text, locale: locale, speed: speed));
    return available;
  }

  @override
  Future<void> stop() async {}
}
