import 'package:dailytalk_mobile/models/audio_speed_control_style.dart';
import 'package:dailytalk_mobile/state/audio_speed_preferences_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('defaults to buttons when no preference exists', () async {
    final controller = AudioSpeedPreferencesController(
      readStyle: () async => null,
      writeStyle: (_) async {},
    );

    await controller.ensureLoaded();

    expect(controller.style, AudioSpeedControlStyle.buttons);
    expect(controller.isLoaded, isTrue);
  });

  test('loads a persisted style', () async {
    final controller = AudioSpeedPreferencesController(
      readStyle: () async => AudioSpeedControlStyle.slider.storageValue,
      writeStyle: (_) async {},
    );

    await controller.ensureLoaded();

    expect(controller.style, AudioSpeedControlStyle.slider);
  });

  test('persists a user-selected style', () async {
    String? persisted;
    final controller = AudioSpeedPreferencesController(
      readStyle: () async => null,
      writeStyle: (value) async {
        persisted = value;
      },
    );

    final saved = await controller.setStyle(AudioSpeedControlStyle.buttons);

    expect(saved, isTrue);
    expect(controller.style, AudioSpeedControlStyle.buttons);
    expect(persisted, 'buttons');
  });

  test('invalid persisted values fail closed to buttons', () async {
    final controller = AudioSpeedPreferencesController(
      readStyle: () async => 'future-unknown-style',
      writeStyle: (_) async {},
    );

    await controller.ensureLoaded();

    expect(controller.style, AudioSpeedControlStyle.buttons);
  });
}
