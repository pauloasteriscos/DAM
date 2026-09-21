import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/data/repositories/ui_translation_repository.dart';
import 'package:dailytalk_mobile/l10n/ui_localization_contract.dart';
import 'package:dailytalk_mobile/l10n/ui_localization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late Database db;
  late UiTranslationRepository repository;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dailytalk-lc001-');
    db = await AppDatabase.instance.openDatabaseForTesting(
      p.join(tempDir.path, 'lc001.db'),
    );
    repository = UiTranslationRepository(db);
  });

  tearDown(() async {
    if (db.isOpen) {
      await db.close();
    }
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('importa, ativa e lê bundle completo', () async {
    await repository.importBundle(
      locale: 'en-US',
      bundleVersion: 1,
      schemaVersion: UiLocalizationContract.schemaVersion,
      checksum: _checksum('a'),
      translations: _translations('en'),
      source: 'test',
    );

    await repository.activateBundle(
      locale: 'en-US',
      bundleVersion: 1,
      requiredKeys: UiLocalizationContract.requiredKeysV1,
    );

    final catalog = await repository.readCatalog('en-US');
    final active = await repository.readActiveBundle('en-US');

    expect(catalog, isNotNull);
    expect(catalog!.activeBundleVersion, 1);
    expect(catalog.previousBundleVersion, isNull);
    expect(active, isNotNull);
    expect(active!.translations[UiTranslationKeys.commonContinue], 'Continue');
    expect(active.translations.length, _translations('en').length);
  });

  test('bundle incompleto não pode ser ativado', () async {
    await repository.importBundle(
      locale: 'en-US',
      bundleVersion: 1,
      schemaVersion: UiLocalizationContract.schemaVersion,
      checksum: _checksum('b'),
      translations: <String, String>{
        UiTranslationKeys.commonContinue: 'Continue',
      },
    );

    expect(
      () => repository.activateBundle(
        locale: 'en-US',
        bundleVersion: 1,
        requiredKeys: UiLocalizationContract.requiredKeysV1,
      ),
      throwsA(isA<UiTranslationBundleIncomplete>()),
    );
  });

  test('mesma revisão é imutável', () async {
    await repository.importBundle(
      locale: 'en-US',
      bundleVersion: 1,
      schemaVersion: 1,
      checksum: _checksum('c'),
      translations: _translations('en'),
    );

    // Reimportar exatamente os mesmos dados é idempotente.
    await repository.importBundle(
      locale: 'en-US',
      bundleVersion: 1,
      schemaVersion: 1,
      checksum: _checksum('c'),
      translations: _translations('en'),
    );

    expect(
      () => repository.importBundle(
        locale: 'en-US',
        bundleVersion: 1,
        schemaVersion: 1,
        checksum: _checksum('d'),
        translations: _translations('en'),
      ),
      throwsA(isA<UiTranslationImmutableRevisionConflict>()),
    );
  });

  test('ativação preserva last-known-good e rollback troca versões', () async {
    await _importAndActivate(repository, 'en-US', 1, _checksum('e'), 'en');

    final v2 = _translations('en')
      ..[UiTranslationKeys.learningMapNextMission] = 'Next learning mission';
    await repository.importBundle(
      locale: 'en-US',
      bundleVersion: 2,
      schemaVersion: 1,
      checksum: _checksum('f'),
      translations: v2,
    );
    await repository.activateBundle(
      locale: 'en-US',
      bundleVersion: 2,
      requiredKeys: UiLocalizationContract.requiredKeysV1,
    );

    var catalog = await repository.readCatalog('en-US');
    expect(catalog!.activeBundleVersion, 2);
    expect(catalog.previousBundleVersion, 1);

    await repository.rollbackToPrevious('en-US');

    catalog = await repository.readCatalog('en-US');
    final active = await repository.readActiveBundle('en-US');
    expect(catalog!.activeBundleVersion, 1);
    expect(catalog.previousBundleVersion, 2);
    expect(
      active!.translations[UiTranslationKeys.learningMapNextMission],
      'Next mission',
    );
  });

  test(
    'service faz lookup em memória e fallback técnico apenas en-US',
    () async {
      final english = _translations('en')
        ..['diagnostic.onlyEnglish'] = 'English fallback';
      await repository.importBundle(
        locale: 'en-US',
        bundleVersion: 1,
        schemaVersion: 1,
        checksum: _checksum('1'),
        translations: english,
      );
      await repository.activateBundle(
        locale: 'en-US',
        bundleVersion: 1,
        requiredKeys: UiLocalizationContract.requiredKeysV1,
      );

      await _importAndActivate(repository, 'it-IT', 1, _checksum('2'), 'it');

      final service = UiLocalizationService(repository);
      await service.loadLocale('it-IT');

      expect(service.locale, 'it-IT');
      expect(service.text(UiTranslationKeys.commonContinue), 'Continua');
      expect(service.text('diagnostic.onlyEnglish'), 'English fallback');

      // Depois da carga, o hot path não depende da base.
      await db.close();
      expect(
        service.text(UiTranslationKeys.learningMapAvailable),
        'Disponibile',
      );
      expect(service.cachedKeyCount, _translations('it').length);
    },
  );
}

Future<void> _importAndActivate(
  UiTranslationRepository repository,
  String locale,
  int version,
  String checksum,
  String language,
) async {
  await repository.importBundle(
    locale: locale,
    bundleVersion: version,
    schemaVersion: 1,
    checksum: checksum,
    translations: _translations(language),
  );
  await repository.activateBundle(
    locale: locale,
    bundleVersion: version,
    requiredKeys: UiLocalizationContract.requiredKeysV1,
  );
}

Map<String, String> _translations(String language) {
  final isItalian = language == 'it';
  return <String, String>{
    UiTranslationKeys.commonContinue: isItalian ? 'Continua' : 'Continue',
    UiTranslationKeys.commonCancel: isItalian ? 'Annulla' : 'Cancel',
    UiTranslationKeys.commonSave: isItalian ? 'Salva' : 'Save',
    UiTranslationKeys.commonRetry: isItalian ? 'Riprova' : 'Retry',
    UiTranslationKeys.learningMapAllSaved: isItalian
        ? 'Tutto salvato'
        : 'All saved',
    UiTranslationKeys.learningMapNextMission: isItalian
        ? 'Prossima missione'
        : 'Next mission',
    UiTranslationKeys.learningMapAvailable: isItalian
        ? 'Disponibile'
        : 'Available',
    UiTranslationKeys.learningMapUpNext: isItalian ? 'A seguire' : 'Up next',
    UiTranslationKeys.learningMapJourney: isItalian ? 'Percorso' : 'Journey',
    UiTranslationKeys.learningMapStage: isItalian ? 'Fase' : 'Stage',
    UiTranslationKeys.activityTypeVocabulary: isItalian
        ? 'Vocabolario'
        : 'Vocabulary',
    UiTranslationKeys.activityTypeDialogue: isItalian ? 'Dialogo' : 'Dialogue',
    UiTranslationKeys.activityTypeSpeech: isItalian ? 'Parlato' : 'Speaking',
    UiTranslationKeys.systemLanguageSavedSyncDeferred: isItalian
        ? 'Lingua salvata su questo dispositivo. La sincronizzazione verrà ritentata più tardi.'
        : 'Language saved on this device. Sync will be retried later.',
    UiTranslationKeys.systemLanguagePairSaved: isItalian
        ? 'Salvato: {source} → {target}'
        : 'Saved: {source} → {target}',
    UiTranslationKeys.systemChooseDifferentLanguages: isItalian
        ? 'Scegli due lingue diverse.'
        : 'Choose two different languages.',
  };
}

String _checksum(String digit) => List<String>.filled(64, digit).join();
