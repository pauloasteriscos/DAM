import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all supported flag assets are packaged', () async {
    const assets = <String>[
      'assets/flags/pt-PT.png',
      'assets/flags/en-US.png',
      'assets/flags/es-ES.png',
      'assets/flags/fr-FR.png',
      'assets/flags/it-IT.png',
      'assets/flags/de-DE.png',
    ];

    for (final asset in assets) {
      final data = await rootBundle.load(asset);
      expect(
        data.lengthInBytes,
        greaterThan(0),
        reason: 'Flag asset missing or empty: $asset',
      );
    }
  });
}
