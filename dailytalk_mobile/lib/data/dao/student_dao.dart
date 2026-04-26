import 'package:sqflite/sqflite.dart';

/// DAO responsável pela tabela students.
///
/// O campo principal é invenira_std_id, porque as análises
/// do backend usam esse identificador por aluno.
class StudentDao {
  StudentDao(this.db);

  final Database db;

  /// Cria ou atualiza um aluno a partir do inveniraStdID.
  Future<int> upsertStudent({
    required String inveniraStdId,
    String? displayName,
    String? className,
  }) async {
    final now = DateTime.now().toIso8601String();

    final existing = await getByInveniraStdId(inveniraStdId);

    if (existing == null) {
      return db.insert('students', {
        'invenira_std_id': inveniraStdId,
        'display_name': displayName,
        'class_name': className,
        'created_at': now,
        'updated_at': now,
        'last_seen_at': now,
      });
    }

    final id = existing['id'] as int;

    await db.update(
      'students',
      {
        'display_name': displayName ?? existing['display_name'],
        'class_name': className ?? existing['class_name'],
        'updated_at': now,
        'last_seen_at': now,
      },
      where: 'id = ?',
      whereArgs: [id],
    );

    return id;
  }

  /// Procura aluno pelo identificador externo.
  Future<Map<String, Object?>?> getByInveniraStdId(String inveniraStdId) async {
    final rows = await db.query(
      'students',
      where: 'invenira_std_id = ?',
      whereArgs: [inveniraStdId],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  /// Lista alunos conhecidos localmente.
  Future<List<Map<String, Object?>>> getAllStudents() async {
    return db.query(
      'students',
      orderBy: 'updated_at DESC',
    );
  }
}
