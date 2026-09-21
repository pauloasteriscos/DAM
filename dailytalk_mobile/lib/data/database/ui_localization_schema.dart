import 'package:sqflite/sqflite.dart';

/// Schema SQLite do contrato LC-001.
///
/// Mantém bundles de tradução imutáveis, catálogo ativo por locale e as
/// traduções materializadas para lookup bulk. A camada de apresentação nunca
/// consulta estas tabelas diretamente; o hot path usa cache em memória.
abstract final class UiLocalizationSchema {
  static Future<void> create(Database db) async {
    final batch = db.batch();
    addToBatch(batch);
    addIndexesToBatch(batch);
    await batch.commit(noResult: true);
  }

  static void addToBatch(Batch batch) {
    batch.execute('''
      CREATE TABLE IF NOT EXISTS ui_translation_bundles (
        locale TEXT NOT NULL,
        bundle_version INTEGER NOT NULL CHECK(bundle_version >= 1),
        schema_version INTEGER NOT NULL CHECK(schema_version >= 1),
        checksum TEXT NOT NULL CHECK(length(checksum) = 64),
        source TEXT NOT NULL,
        key_count INTEGER NOT NULL CHECK(key_count >= 1),
        imported_at TEXT NOT NULL,
        PRIMARY KEY (locale, bundle_version)
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS ui_translations (
        locale TEXT NOT NULL,
        bundle_version INTEGER NOT NULL,
        translation_key TEXT NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (locale, bundle_version, translation_key),
        FOREIGN KEY (locale, bundle_version)
          REFERENCES ui_translation_bundles(locale, bundle_version)
          ON DELETE CASCADE
      )
    ''');

    batch.execute('''
      CREATE TABLE IF NOT EXISTS ui_translation_catalog (
        locale TEXT PRIMARY KEY,
        active_bundle_version INTEGER NOT NULL,
        previous_bundle_version INTEGER,
        activated_at TEXT NOT NULL,
        FOREIGN KEY (locale, active_bundle_version)
          REFERENCES ui_translation_bundles(locale, bundle_version)
          ON DELETE RESTRICT,
        FOREIGN KEY (locale, previous_bundle_version)
          REFERENCES ui_translation_bundles(locale, bundle_version)
          ON DELETE RESTRICT,
        CHECK(
          previous_bundle_version IS NULL OR
          previous_bundle_version <> active_bundle_version
        )
      )
    ''');
  }

  static void addIndexesToBatch(Batch batch) {
    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_ui_translations_locale_version '
      'ON ui_translations(locale, bundle_version)',
    );

    batch.execute(
      'CREATE INDEX IF NOT EXISTS idx_ui_translation_catalog_active '
      'ON ui_translation_catalog(locale, active_bundle_version)',
    );
  }
}
