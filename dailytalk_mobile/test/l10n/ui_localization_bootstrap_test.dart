import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dailytalk_mobile/data/database/ui_localization_schema.dart';
import 'package:dailytalk_mobile/data/repositories/ui_translation_repository.dart';
import 'package:dailytalk_mobile/data/services/ui_translation_bootstrap_service.dart';
import 'package:dailytalk_mobile/l10n/ui_localization_contract.dart';
import 'package:dailytalk_mobile/l10n/ui_localization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('LC-001.2 instala e ativa os seis bundles offline', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => UiLocalizationSchema.create(db),
      ),
    );
    addTearDown(db.close);

    final repository = UiTranslationRepository(db);
    await UiTranslationBootstrapService(
      repository: repository,
      assetBundle: rootBundle,
    ).ensureLocalBundles();

    const expected = <String, String>{
      'pt-PT': 'Continuar',
      'en-US': 'Continue',
      'es-ES': 'Continuar',
      'fr-FR': 'Continuer',
      'it-IT': 'Continua',
      'de-DE': 'Weiter',
    };

    for (final entry in expected.entries) {
      final active = await repository.readActiveBundle(entry.key);
      expect(active, isNotNull, reason: entry.key);
      expect(active!.bundleVersion, 1, reason: entry.key);
      expect(active.schemaVersion, UiLocalizationContract.schemaVersion);
      expect(
        active.translations.keys.toSet(),
        containsAll(UiLocalizationContract.requiredKeysCurrent),
        reason: entry.key,
      );
      expect(
        active.translations[UiTranslationKeys.commonContinue],
        entry.value,
        reason: entry.key,
      );
      expect(
        active.translations,
        contains(UiTranslationKeys.systemLanguageSavedSyncDeferred),
        reason: entry.key,
      );
    }
  });

  test(
    'serviço troca cache por locale sem alterar conteúdo persistido',
    () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, version) => UiLocalizationSchema.create(db),
        ),
      );
      addTearDown(db.close);

      final repository = UiTranslationRepository(db);
      await UiTranslationBootstrapService(
        repository: repository,
        assetBundle: rootBundle,
      ).ensureLocalBundles();

      final service = UiLocalizationService(repository);

      await service.loadLocale('en-US');
      expect(service.locale, 'en-US');
      expect(service.text(UiTranslationKeys.learningMapAvailable), 'Available');
      expect(
        service.text(
          UiTranslationKeys.learningMapJourney,
          parameters: const {'number': 2},
        ),
        'JOURNEY 2',
      );

      await service.loadLocale('de-DE');
      expect(service.locale, 'de-DE');
      expect(service.text(UiTranslationKeys.learningMapAvailable), 'Verfügbar');
      expect(
        service.text(
          UiTranslationKeys.learningMapJourney,
          parameters: const {'number': 2},
        ),
        'LERNREISE 2',
      );
    },
  );

  test('mensagens de sistema seguem o locale ativo no cache LC-001', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => UiLocalizationSchema.create(db),
      ),
    );
    addTearDown(db.close);

    final repository = UiTranslationRepository(db);
    await UiTranslationBootstrapService(
      repository: repository,
      assetBundle: rootBundle,
    ).ensureLocalBundles();

    final service = UiLocalizationService(repository);
    await service.loadLocale('en-US');

    expect(
      service.text(UiTranslationKeys.systemLanguageSavedSyncDeferred),
      'Language saved on this device. Sync will be retried later.',
    );
    expect(
      service.text(
        UiTranslationKeys.systemLanguagePairSaved,
        parameters: const <String, Object?>{
          'source': 'English',
          'target': 'Italiano',
        },
      ),
      'Saved: English → Italiano',
    );
  });

  test('bootstrap repara v1 bundled DEV incompleta sem criar v2', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => UiLocalizationSchema.create(db),
      ),
    );
    addTearDown(db.close);

    final repository = UiTranslationRepository(db);
    final oldV1 = <String, String>{
      for (final key in UiLocalizationContract.requiredKeysCurrent)
        if (!key.startsWith('system.')) key: 'old $key',
    };

    await repository.importBundle(
      locale: 'en-US',
      bundleVersion: 1,
      schemaVersion: UiLocalizationContract.schemaVersion,
      checksum: List<String>.filled(64, '1').join(),
      translations: oldV1,
      source: 'bundled',
    );
    await repository.activateBundle(
      locale: 'en-US',
      bundleVersion: 1,
      requiredKeys: oldV1.keys.toSet(),
    );

    await UiTranslationBootstrapService(
      repository: repository,
      assetBundle: rootBundle,
    ).ensureLocalBundles();

    final active = await repository.readActiveBundle('en-US');
    expect(active, isNotNull);
    expect(active!.bundleVersion, 1);
    expect(
      active.translations[UiTranslationKeys.systemLanguageSavedSyncDeferred],
      'Language saved on this device. Sync will be retried later.',
    );
  });

  test('bootstrap nunca faz downgrade de bundle remoto mais recente', () async {
    final db = await databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) => UiLocalizationSchema.create(db),
      ),
    );
    addTearDown(db.close);

    final repository = UiTranslationRepository(db);
    await UiTranslationBootstrapService(
      repository: repository,
      assetBundle: rootBundle,
    ).ensureLocalBundles();

    final v2 = <String, String>{
      for (final key in UiLocalizationContract.requiredKeysCurrent)
        key: key == UiTranslationKeys.commonContinue
            ? 'Continue v2'
            : 'v2 $key',
    };

    await repository.importBundle(
      locale: 'en-US',
      bundleVersion: 2,
      schemaVersion: UiLocalizationContract.schemaVersion,
      checksum: List<String>.filled(64, '2').join(),
      translations: v2,
      source: 'remote-test',
    );
    await repository.activateBundle(
      locale: 'en-US',
      bundleVersion: 2,
      requiredKeys: UiLocalizationContract.requiredKeysCurrent,
    );

    await UiTranslationBootstrapService(
      repository: repository,
      assetBundle: rootBundle,
    ).ensureLocalBundles();

    final active = await repository.readActiveBundle('en-US');
    expect(active, isNotNull);
    expect(active!.bundleVersion, 2);
    expect(
      active.translations[UiTranslationKeys.commonContinue],
      'Continue v2',
    );
  });
}
