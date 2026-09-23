import 'package:dailytalk_mobile/security/device_key_service.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('sequence recovery fast-forwards monotonically', () async {
    final service = DeviceKeyService();

    expect(await service.nextSyncSequence(), 1);
    expect(await service.ensureSyncSequenceAtLeast(71), 71);
    expect(await service.nextSyncSequence(), 72);

    // Uma resposta atrasada nunca pode reduzir o contador.
    expect(await service.ensureSyncSequenceAtLeast(20), 72);
    expect(await service.nextSyncSequence(), 73);
  });

  test(
    'multiple DeviceKeyService instances reserve unique sequences',
    () async {
      final first = DeviceKeyService();
      final second = DeviceKeyService();

      final values = await Future.wait(<Future<int>>[
        first.nextSyncSequence(),
        second.nextSyncSequence(),
      ]);

      expect(values.toSet(), <int>{1, 2});
    },
  );

  test('negative server floor is rejected', () {
    final service = DeviceKeyService();

    expect(() => service.ensureSyncSequenceAtLeast(-1), throwsArgumentError);
  });
}
