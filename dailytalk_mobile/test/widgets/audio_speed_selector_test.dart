import 'package:dailytalk_mobile/models/audio_speed_control_style.dart';
import 'package:dailytalk_mobile/state/app_locale_controller.dart';
import 'package:dailytalk_mobile/widgets/audio_speed_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('cinco velocidades ficam sempre na mesma linha em telemóvel', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await AppLocaleController.instance.setLanguageCode('en-US', persist: false);

    const speeds = <double>[0.5, 0.75, 1, 1.25, 1.5];

    await tester.pumpWidget(
      AppLocaleScope(
        controller: AppLocaleController.instance,
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: AudioSpeedSelector(
                  style: AudioSpeedControlStyle.buttons,
                  speeds: speeds,
                  selectedSpeed: 1,
                  onSelected: (_) {},
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final finders = <Finder>[
      find.byKey(const ValueKey<String>('mission-vocab-speed-0-5')),
      find.byKey(const ValueKey<String>('mission-vocab-speed-0-75')),
      find.byKey(const ValueKey<String>('mission-vocab-speed-1-0')),
      find.byKey(const ValueKey<String>('mission-vocab-speed-1-25')),
      find.byKey(const ValueKey<String>('mission-vocab-speed-1-5')),
    ];

    for (final finder in finders) {
      expect(finder, findsOneWidget);
    }

    final baseline = tester.getCenter(finders.first).dy;
    for (final finder in finders.skip(1)) {
      expect(tester.getCenter(finder).dy, closeTo(baseline, 0.1));
    }

    expect(tester.takeException(), isNull);
  });
}
