import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dailytalk_mobile/data/database/app_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp(
      'dailytalk-lc001-migration-',
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('v7 -> v8 cria fundação LC-001 de forma aditiva', () async {
    final path = p.join(tempDir.path, 'historical-v7.db');

    var db = await AppDatabase.instance.openDatabaseForTesting(path);
    await db.execute('DROP TABLE ui_translation_catalog');
    await db.execute('DROP TABLE ui_translations');
    await db.execute('DROP TABLE ui_translation_bundles');
    await db.execute('PRAGMA user_version = 7');
    await db.update(
      'app_settings',
      {'value': '7', 'updated_at': DateTime.utc(2026, 9, 21).toIso8601String()},
      where: 'key = ?',
      whereArgs: ['database_version'],
    );
    await db.close();

    db = await AppDatabase.instance.openDatabaseForTesting(path);

    expect(await db.getVersion(), 8);
    expect(await _tableExists(db, 'ui_translation_bundles'), isTrue);
    expect(await _tableExists(db, 'ui_translations'), isTrue);
    expect(await _tableExists(db, 'ui_translation_catalog'), isTrue);
    expect(
      await _indexExists(db, 'idx_ui_translations_locale_version'),
      isTrue,
    );
    expect(await _indexExists(db, 'idx_ui_translation_catalog_active'), isTrue);

    final versionSetting = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: ['database_version'],
      limit: 1,
    );
    expect(versionSetting.single['value'], '8');

    await db.close();
  });
}

Future<bool> _tableExists(Database db, String name) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'table' AND name = ?",
    [name],
  );
  return rows.isNotEmpty;
}

Future<bool> _indexExists(Database db, String name) async {
  final rows = await db.rawQuery(
    "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
    [name],
  );
  return rows.isNotEmpty;
}
