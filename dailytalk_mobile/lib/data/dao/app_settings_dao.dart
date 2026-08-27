import 'package:sqflite/sqflite.dart';

import '../../models/user_profile.dart';

/// DAO para configurações simples da aplicação.
///
/// Não usar esta tabela para tokens, passwords ou API keys.
/// Para credenciais, usar flutter_secure_storage.
class AppSettingsDao {
  AppSettingsDao(this.db);

  final Database db;

  /// Chave usada para guardar o perfil selecionado pelo utilizador.
  static const String selectedProfileKey = 'selected_profile';

  /// Idioma usado na interface/feedback da aplicação.
  static const String nativeLanguageKey = 'native_language_code';

  /// Idioma que o utilizador quer praticar/aprender.
  static const String targetLanguageKey = 'target_language_code';

  /// Guarda uma configuração simples.
  Future<void> setValue({
    required String key,
    String? value,
    String valueType = 'text',
  }) async {
    await db.insert('app_settings', {
      'key': key,
      'value': value,
      'value_type': valueType,
      'updated_at': DateTime.now().toIso8601String(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
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

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value']?.toString();
  }

  /// Lê uma configuração booleana.
  Future<bool> getBool(String key, {bool defaultValue = false}) async {
    final value = await getString(key);

    if (value == null) {
      return defaultValue;
    }

    return value == 'true' || value == '1';
  }

  /// Lê uma configuração inteira.
  Future<int?> getInt(String key) async {
    final value = await getString(key);

    if (value == null) {
      return null;
    }

    return int.tryParse(value);
  }

  /// Remove uma configuração.
  Future<int> deleteValue(String key) async {
    return db.delete('app_settings', where: 'key = ?', whereArgs: [key]);
  }

  /// Guarda o perfil selecionado pelo utilizador.
  ///
  /// Exemplos:
  /// - student
  /// - host
  /// - teacher
  Future<void> setSelectedProfile(UserProfileType profile) async {
    await setValue(
      key: selectedProfileKey,
      value: profile.databaseValue,
      valueType: 'text',
    );
  }

  /// Lê o perfil selecionado pelo utilizador.
  ///
  /// Se ainda não existir perfil guardado, assume Estudante como padrão.
  Future<UserProfileType> getSelectedProfile() async {
    final value = await getString(selectedProfileKey);

    return UserProfileType.fromDatabase(value);
  }

  /// Guarda o par de idiomas escolhido pelo utilizador.
  Future<void> setLanguagePair({
    required String nativeLanguageCode,
    required String targetLanguageCode,
  }) async {
    final batch = db.batch();
    final now = DateTime.now().toIso8601String();

    batch.insert('app_settings', {
      'key': nativeLanguageKey,
      'value': nativeLanguageCode,
      'value_type': 'text',
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    batch.insert('app_settings', {
      'key': targetLanguageKey,
      'value': targetLanguageCode,
      'value_type': 'text',
      'updated_at': now,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await batch.commit(noResult: true);
  }

  /// Lê o idioma base da aplicação.
  Future<String> getNativeLanguageCode() async {
    return await getString(nativeLanguageKey) ?? 'pt-PT';
  }

  /// Lê o idioma que o utilizador quer praticar.
  Future<String> getTargetLanguageCode() async {
    return await getString(targetLanguageKey) ?? 'it-IT';
  }
}
