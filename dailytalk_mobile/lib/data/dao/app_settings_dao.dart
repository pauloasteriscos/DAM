import 'package:sqflite/sqflite.dart';

/// DAO para configurações simples da aplicação.
///
/// Não usar esta tabela para tokens, passwords ou API keys.
/// Para credenciais, usar flutter_secure_storage.
class AppSettingsDao {
  AppSettingsDao(this.db);

  final Database db;

  /// Guarda uma configuração simples.
  Future<void> setValue({
    required String key,
    String? value,
    String valueType = 'text',
  }) async {
    await db.insert(
      'app_settings',
      {
        'key': key,
        'value': value,
        'value_type': valueType,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Lê uma configuração como texto.
  Future<String?> getString(String key) async {
    final rows = await db.query(
      'app_settings',
      columns: ['value'],
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (rows.isEmpty) return null;
    return rows.first['value']?.toString();
  }

  /// Lê uma configuração booleana.
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final value = await getString(key);

    if (value == null) return defaultValue;

    return value == 'true' || value == '1';
  }

  /// Lê uma configuração inteira.
  Future<int?> getInt(String key) async {
    final value = await getString(key);
    if (value == null) return null;

    return int.tryParse(value);
  }

  /// Remove uma configuração.
  Future<int> deleteValue(String key) async {
    return db.delete(
      'app_settings',
      where: 'key = ?',
      whereArgs: [key],
    );
  }
}
