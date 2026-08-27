import 'package:sqflite/sqflite.dart';

/// DAO para notas privadas locais.
///
/// Estas notas são opcionais e devem ficar apenas no dispositivo.
/// Não são sincronizadas, não entram na sync_queue e não são enviadas
/// para o backend.
class LocalPrivateNotesDao {
  LocalPrivateNotesDao(this.db);

  final Database db;

  /// Cria uma nota privada local.
  Future<int> createNote({
    required String title,
    required String noteText,
    String? scenario,
  }) async {
    final now = DateTime.now().toIso8601String();

    return db.insert('local_private_notes', {
      'title': title,
      'note_text': noteText,
      'scenario': scenario,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Lista as notas privadas locais mais recentes.
  Future<List<Map<String, Object?>>> getRecentNotes({int limit = 20}) async {
    return db.query(
      'local_private_notes',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  /// Atualiza uma nota privada local.
  Future<int> updateNote({
    required int id,
    required String title,
    required String noteText,
    String? scenario,
  }) async {
    return db.update(
      'local_private_notes',
      {
        'title': title,
        'note_text': noteText,
        'scenario': scenario,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Apaga uma nota privada local.
  Future<int> deleteNote(int id) async {
    return db.delete('local_private_notes', where: 'id = ?', whereArgs: [id]);
  }

  /// Apaga todas as notas privadas locais.
  ///
  /// Útil caso o utilizador queira limpar rapidamente dados sensíveis
  /// guardados apenas neste dispositivo.
  Future<int> deleteAllNotes() async {
    return db.delete('local_private_notes');
  }
}
