import 'package:sqflite/sqflite.dart';

import '../../domain/learning/learning_enums.dart';
import '../../domain/learning/progression_engine.dart';

/// Linha persistida da projeÃ§Ã£o pedagÃ³gica.
///
/// Ã‰ um read model derivado. Os factos durÃ¡veis continuam a ser as conclusÃµes
/// e as evidÃªncias; esta projeÃ§Ã£o pode ser reconstruÃ­da pelo ProgressionEngine.
final class LearningProgressProjectionEntry {
  const LearningProgressProjectionEntry({
    required this.pathElementId,
    required this.activityId,
    required this.state,
    required this.reason,
    required this.recommendationRank,
    required this.packageVersion,
    required this.updatedAt,
  });

  final String pathElementId;
  final String? activityId;
  final LearningActivityState state;
  final ProgressionReason reason;
  final int? recommendationRank;
  final int packageVersion;
  final DateTime updatedAt;

  bool get isRecommended => recommendationRank != null;
}

/// Estado tÃ©cnico de sincronizaÃ§Ã£o associado a uma atividade.
///
/// Esta informaÃ§Ã£o Ã© deliberadamente independente do estado pedagÃ³gico.
/// Uma atividade pode, por exemplo, estar completed + pending.
final class LearningActivitySyncEntry {
  const LearningActivitySyncEntry({
    required this.activityId,
    required this.state,
  });

  final String activityId;
  final ProgressSyncState state;
}

/// API exclusivamente de leitura para a apresentaÃ§Ã£o da progressÃ£o.
///
/// Esta classe nÃ£o executa ProgressionEngine e nÃ£o altera factos, projeÃ§Ãµes
/// ou outbox. Apenas lÃª o estado local jÃ¡ persistido.
final class LearningProgressReadRepository {
  const LearningProgressReadRepository(this._db);

  final Database _db;

  Future<List<LearningProgressProjectionEntry>> readProjection({
    required String accountId,
    required String learningPathId,
  }) async {
    final normalizedAccountId = accountId.trim();
    final normalizedPathId = learningPathId.trim();

    if (normalizedAccountId.isEmpty) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'nÃ£o pode estar vazio',
      );
    }

    if (normalizedPathId.isEmpty) {
      throw ArgumentError.value(
        learningPathId,
        'learningPathId',
        'nÃ£o pode estar vazio',
      );
    }

    final rows = await _db.query(
      'learning_progress_projection',
      where: 'account_id = ? AND learning_path_id = ?',
      whereArgs: <Object?>[normalizedAccountId, normalizedPathId],
    );

    return rows.map(_projectionFromRow).toList(growable: false);
  }

  Future<int> readCompletedActivityCount({
    required String accountId,
    required String learningPathId,
  }) async {
    final normalizedAccountId = accountId.trim();
    final normalizedPathId = learningPathId.trim();

    if (normalizedAccountId.isEmpty) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'nÃ£o pode estar vazio',
      );
    }

    if (normalizedPathId.isEmpty) {
      throw ArgumentError.value(
        learningPathId,
        'learningPathId',
        'nÃ£o pode estar vazio',
      );
    }

    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(DISTINCT activity_id) AS activity_count
      FROM learning_progress_completions
      WHERE account_id = ?
        AND learning_path_id = ?
      ''',
      <Object?>[normalizedAccountId, normalizedPathId],
    );

    return (rows.single['activity_count'] as int?) ?? 0;
  }

  Future<Map<String, ProgressSyncState>> readActivitySyncStates({
    required String accountId,
    required String learningPathId,
  }) async {
    final normalizedAccountId = accountId.trim();
    final normalizedPathId = learningPathId.trim();

    if (normalizedAccountId.isEmpty) {
      throw ArgumentError.value(
        accountId,
        'accountId',
        'nÃ£o pode estar vazio',
      );
    }

    if (normalizedPathId.isEmpty) {
      throw ArgumentError.value(
        learningPathId,
        'learningPathId',
        'nÃ£o pode estar vazio',
      );
    }

    final rows = await _db.rawQuery(
      '''
      SELECT
        c.activity_id,
        q.sync_status
      FROM learning_progress_completions c
      INNER JOIN sync_queue q
        ON q.entity_type = 'learning_progress_completion'
       AND q.entity_id = c.id
      WHERE c.account_id = ?
        AND c.learning_path_id = ?
      ''',
      <Object?>[normalizedAccountId, normalizedPathId],
    );

    final result = <String, ProgressSyncState>{};

    for (final row in rows) {
      final activityId = row['activity_id']?.toString();
      final rawStatus = row['sync_status']?.toString();

      if (activityId == null || activityId.isEmpty) {
        continue;
      }

      final state = _syncStateFromQueueStatus(rawStatus);
      final current = result[activityId];

      if (current == null || _syncPriority(state) > _syncPriority(current)) {
        result[activityId] = state;
      }
    }

    return result;
  }

  LearningProgressProjectionEntry _projectionFromRow(Map<String, Object?> row) {
    return LearningProgressProjectionEntry(
      pathElementId: row['path_element_id']! as String,
      activityId: row['activity_id'] as String?,
      state: _enumByName(
        LearningActivityState.values,
        row['state']! as String,
        'learning_progress_projection.state',
      ),
      reason: _enumByName(
        ProgressionReason.values,
        row['reason']! as String,
        'learning_progress_projection.reason',
      ),
      recommendationRank: row['recommendation_rank'] as int?,
      packageVersion: row['package_version']! as int,
      updatedAt: DateTime.parse(row['updated_at']! as String).toUtc(),
    );
  }

  ProgressSyncState _syncStateFromQueueStatus(String? status) {
    return switch (status) {
      'pending' => ProgressSyncState.pending,
      'processing' => ProgressSyncState.syncing,
      'failed' => ProgressSyncState.failed,
      'synced' => ProgressSyncState.clean,
      _ => throw FormatException(
        'Estado desconhecido em sync_queue.sync_status: $status',
      ),
    };
  }

  int _syncPriority(ProgressSyncState state) {
    return switch (state) {
      ProgressSyncState.clean => 0,
      ProgressSyncState.pending => 1,
      ProgressSyncState.syncing => 2,
      ProgressSyncState.failed => 3,
    };
  }

  T _enumByName<T extends Enum>(List<T> values, String name, String field) {
    for (final value in values) {
      if (value.name == name) {
        return value;
      }
    }

    throw FormatException('Valor desconhecido em $field: $name');
  }
}
