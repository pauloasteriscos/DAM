import 'package:sqflite/sqflite.dart';

/// DAO para parâmetros dinâmicos obtidos por GET /json-params.
class ActivityParamsDao {
  ActivityParamsDao(this.db);

  final Database db;

  /// Substitui todos os parâmetros de uma atividade.
  ///
  /// Útil quando a app recebe novamente a estrutura de /json-params.
  Future<void> replaceParamsForActivity({
    required int activityId,
    required List<Map<String, Object?>> params,
  }) async {
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        'activity_params',
        where: 'activity_id = ?',
        whereArgs: [activityId],
      );

      for (var i = 0; i < params.length; i++) {
        final param = params[i];

        await txn.insert('activity_params', {
          'activity_id': activityId,
          'param_name': param['name'] ?? param['param_name'],
          'param_type': param['type'] ?? param['param_type'] ?? 'text/plain',
          'param_value': param['value'] ?? param['param_value'],
          'is_required': param['is_required'] ?? 0,
          'sort_order': param['sort_order'] ?? i,
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  /// Insere ou atualiza um parâmetro individual.
  Future<int> upsertParam({
    required int? activityId,
    required String paramName,
    required String paramType,
    String? paramValue,
    bool isRequired = false,
    int sortOrder = 0,
  }) async {
    final now = DateTime.now().toIso8601String();

    final existing = await db.query(
      'activity_params',
      where: activityId == null
          ? 'activity_id IS NULL AND param_name = ?'
          : 'activity_id = ? AND param_name = ?',
      whereArgs: activityId == null ? [paramName] : [activityId, paramName],
      limit: 1,
    );

    final data = {
      'activity_id': activityId,
      'param_name': paramName,
      'param_type': paramType,
      'param_value': paramValue,
      'is_required': isRequired ? 1 : 0,
      'sort_order': sortOrder,
      'updated_at': now,
    };

    if (existing.isEmpty) {
      return db.insert('activity_params', {
        ...data,
        'created_at': now,
      });
    }

    final id = existing.first['id'] as int;

    await db.update(
      'activity_params',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );

    return id;
  }

  /// Lista parâmetros associados a uma atividade.
  Future<List<Map<String, Object?>>> getParamsForActivity(int activityId) async {
    return db.query(
      'activity_params',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'sort_order ASC, id ASC',
    );
  }

  /// Lista parâmetros genéricos, não associados a uma atividade específica.
  Future<List<Map<String, Object?>>> getGlobalParams() async {
    return db.query(
      'activity_params',
      where: 'activity_id IS NULL',
      orderBy: 'sort_order ASC, id ASC',
    );
  }
}
