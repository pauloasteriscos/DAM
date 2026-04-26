import 'package:sqflite/sqflite.dart';

/// DAO responsável por operações na tabela activities.
class ActivityDao {
  ActivityDao(this.db);

  final Database db;

  /// Cria ou atualiza uma atividade local com base no remote_activity_id.
  ///
  /// Espera campos compatíveis com a tabela activities.
  Future<int> upsertActivity(Map<String, Object?> activity) async {
    final now = DateTime.now().toIso8601String();

    final data = Map<String, Object?>.from(activity);
    data['updated_at'] = data['updated_at'] ?? now;
    data['created_at'] = data['created_at'] ?? now;

    final existing = await getByRemoteActivityId(
      data['remote_activity_id'] as String,
    );

    if (existing == null) {
      return db.insert('activities', data);
    }

    await db.update(
      'activities',
      data..remove('created_at'),
      where: 'id = ?',
      whereArgs: [existing['id']],
    );

    return existing['id'] as int;
  }

  /// Obtém uma atividade pelo ID local.
  Future<Map<String, Object?>?> getById(int id) async {
    final rows = await db.query(
      'activities',
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  /// Obtém uma atividade pelo identificador remoto do backend.
  Future<Map<String, Object?>?> getByRemoteActivityId(String remoteActivityId) async {
    final rows = await db.query(
      'activities',
      where: 'remote_activity_id = ?',
      whereArgs: [remoteActivityId],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  /// Lista atividades ativas.
  Future<List<Map<String, Object?>>> getActiveActivities() async {
    return db.query(
      'activities',
      where: 'is_active = ?',
      whereArgs: [1],
      orderBy: 'updated_at DESC',
    );
  }

  /// Lista atividades disponíveis em cache/offline.
  Future<List<Map<String, Object?>>> getCachedActivities() async {
    return db.query(
      'activities',
      where: 'is_cached = ? AND is_active = ?',
      whereArgs: [1, 1],
      orderBy: 'updated_at DESC',
    );
  }

  /// Atualiza a URL devolvida pelo endpoint GET /deploy.
  Future<int> updateDeployUrl({
    required int activityId,
    required String activityUrl,
  }) async {
    final now = DateTime.now().toIso8601String();

    return db.update(
      'activities',
      {
        'activity_url': activityUrl,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  /// Marca a atividade como aberta pelo utilizador.
  Future<int> markOpened(int activityId) async {
    final now = DateTime.now().toIso8601String();

    return db.update(
      'activities',
      {
        'last_opened_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  /// Define se a atividade está disponível em cache.
  Future<int> setCached({
    required int activityId,
    required bool isCached,
  }) async {
    return db.update(
      'activities',
      {
        'is_cached': isCached ? 1 : 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }

  /// Desativa uma atividade sem apagar o histórico.
  Future<int> deactivate(int activityId) async {
    return db.update(
      'activities',
      {
        'is_active': 0,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [activityId],
    );
  }
}
