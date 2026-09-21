import 'package:sqflite/sqflite.dart';

final class UiTranslationBundleSnapshot {
  const UiTranslationBundleSnapshot({
    required this.locale,
    required this.bundleVersion,
    required this.schemaVersion,
    required this.checksum,
    required this.translations,
  });

  final String locale;
  final int bundleVersion;
  final int schemaVersion;
  final String checksum;
  final Map<String, String> translations;
}

final class UiTranslationCatalogEntry {
  const UiTranslationCatalogEntry({
    required this.locale,
    required this.activeBundleVersion,
    required this.previousBundleVersion,
    required this.activatedAt,
  });

  final String locale;
  final int activeBundleVersion;
  final int? previousBundleVersion;
  final String activatedAt;
}

final class UiTranslationImmutableRevisionConflict implements Exception {
  const UiTranslationImmutableRevisionConflict({
    required this.locale,
    required this.bundleVersion,
  });

  final String locale;
  final int bundleVersion;

  @override
  String toString() =>
      'UiTranslationImmutableRevisionConflict(locale: $locale, '
      'bundleVersion: $bundleVersion)';
}

final class UiTranslationBundleIncomplete implements Exception {
  const UiTranslationBundleIncomplete({
    required this.locale,
    required this.bundleVersion,
    required this.missingKeys,
  });

  final String locale;
  final int bundleVersion;
  final Set<String> missingKeys;

  @override
  String toString() =>
      'UiTranslationBundleIncomplete(locale: $locale, '
      'bundleVersion: $bundleVersion, missingKeys: $missingKeys)';
}

/// Persistência de bundles LC-001.
///
/// Todas as mutações de importação/ativação são transacionais. Uma revisão já
/// importada é imutável: o mesmo (locale, version) nunca pode receber bytes
/// lógicos diferentes.
class UiTranslationRepository {
  UiTranslationRepository(this.db);

  final Database db;

  Future<void> importBundle({
    required String locale,
    required int bundleVersion,
    required int schemaVersion,
    required String checksum,
    required Map<String, String> translations,
    String source = 'remote',
  }) async {
    final normalizedLocale = _validateLocale(locale);
    if (bundleVersion < 1) {
      throw ArgumentError.value(
        bundleVersion,
        'bundleVersion',
        'deve ser >= 1',
      );
    }
    if (schemaVersion < 1) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'deve ser >= 1',
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(checksum)) {
      throw ArgumentError.value(
        checksum,
        'checksum',
        'deve ser SHA-256 hexadecimal',
      );
    }
    final normalizedChecksum = checksum.toLowerCase();
    if (translations.isEmpty) {
      throw ArgumentError.value(
        translations,
        'translations',
        'não pode estar vazio',
      );
    }

    final canonical = <String, String>{};
    for (final entry in translations.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (!_semanticKeyPattern.hasMatch(key)) {
        throw ArgumentError.value(
          entry.key,
          'translationKey',
          'chave semântica inválida',
        );
      }
      if (value.isEmpty) {
        throw ArgumentError.value(
          entry.value,
          key,
          'tradução não pode estar vazia',
        );
      }
      canonical[key] = value;
    }

    await db.transaction((txn) async {
      final existing = await txn.query(
        'ui_translation_bundles',
        columns: ['checksum', 'schema_version', 'key_count'],
        where: 'locale = ? AND bundle_version = ?',
        whereArgs: [normalizedLocale, bundleVersion],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        final row = existing.single;
        final sameMetadata =
            row['checksum'] == normalizedChecksum &&
            row['schema_version'] == schemaVersion &&
            row['key_count'] == canonical.length;
        if (!sameMetadata) {
          throw UiTranslationImmutableRevisionConflict(
            locale: normalizedLocale,
            bundleVersion: bundleVersion,
          );
        }

        final stored = await _readBundleTranslations(
          txn,
          normalizedLocale,
          bundleVersion,
        );
        if (!_sameTranslations(stored, canonical)) {
          throw UiTranslationImmutableRevisionConflict(
            locale: normalizedLocale,
            bundleVersion: bundleVersion,
          );
        }
        return;
      }

      await txn.insert('ui_translation_bundles', {
        'locale': normalizedLocale,
        'bundle_version': bundleVersion,
        'schema_version': schemaVersion,
        'checksum': normalizedChecksum,
        'source': source.trim().isEmpty ? 'remote' : source.trim(),
        'key_count': canonical.length,
        'imported_at': DateTime.now().toUtc().toIso8601String(),
      });

      final batch = txn.batch();
      for (final entry in canonical.entries) {
        batch.insert('ui_translations', {
          'locale': normalizedLocale,
          'bundle_version': bundleVersion,
          'translation_key': entry.key,
          'value': entry.value,
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> activateBundle({
    required String locale,
    required int bundleVersion,
    required Set<String> requiredKeys,
  }) async {
    final normalizedLocale = _validateLocale(locale);
    final canonicalRequired = requiredKeys.map((key) => key.trim()).toSet();

    await db.transaction((txn) async {
      final bundleRows = await txn.query(
        'ui_translation_bundles',
        columns: ['key_count'],
        where: 'locale = ? AND bundle_version = ?',
        whereArgs: [normalizedLocale, bundleVersion],
        limit: 1,
      );
      if (bundleRows.isEmpty) {
        throw StateError(
          'Bundle $normalizedLocale v$bundleVersion não foi importado.',
        );
      }

      final translations = await _readBundleTranslations(
        txn,
        normalizedLocale,
        bundleVersion,
      );
      final missing = canonicalRequired.difference(translations.keys.toSet());
      if (missing.isNotEmpty) {
        throw UiTranslationBundleIncomplete(
          locale: normalizedLocale,
          bundleVersion: bundleVersion,
          missingKeys: missing,
        );
      }

      final catalogRows = await txn.query(
        'ui_translation_catalog',
        columns: ['active_bundle_version'],
        where: 'locale = ?',
        whereArgs: [normalizedLocale],
        limit: 1,
      );
      final currentActive = catalogRows.isEmpty
          ? null
          : catalogRows.single['active_bundle_version'] as int?;

      if (currentActive == bundleVersion) {
        return;
      }

      await txn.insert('ui_translation_catalog', {
        'locale': normalizedLocale,
        'active_bundle_version': bundleVersion,
        'previous_bundle_version': currentActive,
        'activated_at': DateTime.now().toUtc().toIso8601String(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Repara apenas a baseline bundled v1 incompleta criada durante o
  /// desenvolvimento pré-release da LC-001.
  ///
  /// Esta exceção é deliberadamente estreita: só atua sobre `source=bundled`,
  /// apenas na versão 1 e apenas quando faltam chaves obrigatórias. Revisões
  /// completas e bundles remotos continuam imutáveis.
  Future<bool> repairBundledV1IfIncomplete({
    required String locale,
    required int schemaVersion,
    required String checksum,
    required Map<String, String> translations,
    required Set<String> requiredKeys,
  }) async {
    final normalizedLocale = _validateLocale(locale);
    if (schemaVersion < 1) {
      throw ArgumentError.value(
        schemaVersion,
        'schemaVersion',
        'deve ser >= 1',
      );
    }
    if (!RegExp(r'^[0-9a-fA-F]{64}$').hasMatch(checksum)) {
      throw ArgumentError.value(
        checksum,
        'checksum',
        'deve ser SHA-256 hexadecimal',
      );
    }

    final canonical = <String, String>{};
    for (final entry in translations.entries) {
      final key = entry.key.trim();
      final value = entry.value.trim();
      if (!_semanticKeyPattern.hasMatch(key)) {
        throw ArgumentError.value(
          entry.key,
          'translationKey',
          'chave semântica inválida',
        );
      }
      if (value.isEmpty) {
        throw ArgumentError.value(
          entry.value,
          key,
          'tradução não pode estar vazia',
        );
      }
      canonical[key] = value;
    }

    final missingCandidate = requiredKeys.difference(canonical.keys.toSet());
    if (missingCandidate.isNotEmpty) {
      throw UiTranslationBundleIncomplete(
        locale: normalizedLocale,
        bundleVersion: 1,
        missingKeys: missingCandidate,
      );
    }

    return db.transaction((txn) async {
      final rows = await txn.query(
        'ui_translation_bundles',
        columns: ['source'],
        where: 'locale = ? AND bundle_version = 1',
        whereArgs: [normalizedLocale],
        limit: 1,
      );
      if (rows.isEmpty || rows.single['source'] != 'bundled') {
        return false;
      }

      final stored = await _readBundleTranslations(txn, normalizedLocale, 1);
      final missingStored = requiredKeys.difference(stored.keys.toSet());
      if (missingStored.isEmpty) {
        return false;
      }

      await txn.delete(
        'ui_translations',
        where: 'locale = ? AND bundle_version = 1',
        whereArgs: [normalizedLocale],
      );

      await txn.update(
        'ui_translation_bundles',
        {
          'schema_version': schemaVersion,
          'checksum': checksum.toLowerCase(),
          'key_count': canonical.length,
          'imported_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'locale = ? AND bundle_version = 1',
        whereArgs: [normalizedLocale],
      );

      final batch = txn.batch();
      for (final entry in canonical.entries) {
        batch.insert('ui_translations', {
          'locale': normalizedLocale,
          'bundle_version': 1,
          'translation_key': entry.key,
          'value': entry.value,
        });
      }
      await batch.commit(noResult: true);
      return true;
    });
  }

  Future<void> rollbackToPrevious(String locale) async {
    final normalizedLocale = _validateLocale(locale);
    await db.transaction((txn) async {
      final rows = await txn.query(
        'ui_translation_catalog',
        columns: ['active_bundle_version', 'previous_bundle_version'],
        where: 'locale = ?',
        whereArgs: [normalizedLocale],
        limit: 1,
      );
      if (rows.isEmpty) {
        throw StateError('Não existe catálogo ativo para $normalizedLocale.');
      }

      final active = rows.single['active_bundle_version'] as int;
      final previous = rows.single['previous_bundle_version'] as int?;
      if (previous == null) {
        throw StateError(
          'Não existe last-known-good anterior para $normalizedLocale.',
        );
      }

      await txn.update(
        'ui_translation_catalog',
        {
          'active_bundle_version': previous,
          'previous_bundle_version': active,
          'activated_at': DateTime.now().toUtc().toIso8601String(),
        },
        where: 'locale = ?',
        whereArgs: [normalizedLocale],
      );
    });
  }

  Future<UiTranslationBundleSnapshot?> readActiveBundle(String locale) async {
    final normalizedLocale = _validateLocale(locale);
    final rows = await db.rawQuery(
      '''
      SELECT b.bundle_version, b.schema_version, b.checksum
      FROM ui_translation_catalog c
      INNER JOIN ui_translation_bundles b
        ON b.locale = c.locale
       AND b.bundle_version = c.active_bundle_version
      WHERE c.locale = ?
      LIMIT 1
      ''',
      [normalizedLocale],
    );
    if (rows.isEmpty) return null;

    final row = rows.single;
    final version = row['bundle_version'] as int;
    final translations = await _readBundleTranslations(
      db,
      normalizedLocale,
      version,
    );

    return UiTranslationBundleSnapshot(
      locale: normalizedLocale,
      bundleVersion: version,
      schemaVersion: row['schema_version'] as int,
      checksum: row['checksum'] as String,
      translations: Map<String, String>.unmodifiable(translations),
    );
  }

  Future<UiTranslationCatalogEntry?> readCatalog(String locale) async {
    final normalizedLocale = _validateLocale(locale);
    final rows = await db.query(
      'ui_translation_catalog',
      where: 'locale = ?',
      whereArgs: [normalizedLocale],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return UiTranslationCatalogEntry(
      locale: normalizedLocale,
      activeBundleVersion: row['active_bundle_version'] as int,
      previousBundleVersion: row['previous_bundle_version'] as int?,
      activatedAt: row['activated_at'] as String,
    );
  }

  static Future<Map<String, String>> _readBundleTranslations(
    DatabaseExecutor executor,
    String locale,
    int bundleVersion,
  ) async {
    final rows = await executor.query(
      'ui_translations',
      columns: ['translation_key', 'value'],
      where: 'locale = ? AND bundle_version = ?',
      whereArgs: [locale, bundleVersion],
      orderBy: 'translation_key ASC',
    );
    return <String, String>{
      for (final row in rows)
        row['translation_key'] as String: row['value'] as String,
    };
  }

  static bool _sameTranslations(
    Map<String, String> left,
    Map<String, String> right,
  ) {
    if (left.length != right.length) return false;
    for (final entry in left.entries) {
      if (right[entry.key] != entry.value) return false;
    }
    return true;
  }

  static String _validateLocale(String locale) {
    final normalized = locale.trim().replaceAll('_', '-');
    if (!_localePattern.hasMatch(normalized)) {
      throw ArgumentError.value(
        locale,
        'locale',
        'BCP-47 simplificado inválido',
      );
    }
    return normalized;
  }

  static final RegExp _localePattern = RegExp(
    r'^[A-Za-z]{2,3}(?:-[A-Za-z]{2})?$',
  );
  static final RegExp _semanticKeyPattern = RegExp(
    r'^[a-z][A-Za-z0-9]*(?:\.[a-z][A-Za-z0-9]*)+$',
  );
}
