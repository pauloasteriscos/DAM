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

  // SQLite host-parameter limits vary by platform. Each IN clause stays
  // deliberately bounded and leaves room for account/path parameters.
  static const int _idChunkSize = 400;

  /// Reads projection rows only for the requested path elements.
  ///
  /// The caller owns authored ordering. SQLite row order is never used as a
  /// pedagogical or presentation-order signal.
  Future<List<LearningProgressProjectionEntry>> readProjectionForPathElements({
    required String accountId,
    required String learningPathId,
    required Iterable<String> pathElementIds,
  }) async {
    final normalizedAccountId = _normalizeRequired(accountId, 'accountId');
    final normalizedPathId = _normalizeRequired(
      learningPathId,
      'learningPathId',
    );
    final normalizedElementIds = _normalizeIds(
      pathElementIds,
      'pathElementIds',
    );

    if (normalizedElementIds.isEmpty) {
      return const <LearningProgressProjectionEntry>[];
    }

    final result = <LearningProgressProjectionEntry>[];

    for (final chunk in _chunks(normalizedElementIds)) {
      final placeholders = List<String>.filled(chunk.length, '?').join(', ');

      final rows = await _db.query(
        'learning_progress_projection',
        where:
            'account_id = ? AND learning_path_id = ? '
            'AND path_element_id IN ($placeholders)',
        whereArgs: <Object?>[normalizedAccountId, normalizedPathId, ...chunk],
      );

      result.addAll(rows.map(_projectionFromRow));
    }

    return List<LearningProgressProjectionEntry>.unmodifiable(result);
  }

  /// Reads the persisted recommendation set for the whole active path.
  ///
  /// This query deliberately does not make a window-local recommendation.
  /// Recommendation rank remains a global Progression Engine fact.
  Future<List<LearningProgressProjectionEntry>> readRecommendedProjection({
    required String accountId,
    required String learningPathId,
  }) async {
    final normalizedAccountId = _normalizeRequired(accountId, 'accountId');
    final normalizedPathId = _normalizeRequired(
      learningPathId,
      'learningPathId',
    );

    final rows = await _db.query(
      'learning_progress_projection',
      where:
          'account_id = ? AND learning_path_id = ? '
          'AND recommendation_rank IS NOT NULL',
      whereArgs: <Object?>[normalizedAccountId, normalizedPathId],
    );

    return List<LearningProgressProjectionEntry>.unmodifiable(
      rows.map(_projectionFromRow),
    );
  }

  /// Reads outbox-derived sync state only for requested activities.
  ///
  /// Sync remains technically independent from pedagogical state.
  Future<Map<String, ProgressSyncState>> readActivitySyncStatesForActivities({
    required String accountId,
    required String learningPathId,
    required Iterable<String> activityIds,
  }) async {
    final normalizedAccountId = _normalizeRequired(accountId, 'accountId');
    final normalizedPathId = _normalizeRequired(
      learningPathId,
      'learningPathId',
    );
    final normalizedActivityIds = _normalizeIds(activityIds, 'activityIds');

    if (normalizedActivityIds.isEmpty) {
      return const <String, ProgressSyncState>{};
    }

    final result = <String, ProgressSyncState>{};

    for (final chunk in _chunks(normalizedActivityIds)) {
      final placeholders = List<String>.filled(chunk.length, '?').join(', ');

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
          AND c.activity_id IN ($placeholders)
        ''',
        <Object?>[normalizedAccountId, normalizedPathId, ...chunk],
      );

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
    }

    return Map<String, ProgressSyncState>.unmodifiable(result);
  }

  String _normalizeRequired(String value, String argumentName) {
    final normalized = value.trim();

    if (normalized.isEmpty) {
      throw ArgumentError.value(value, argumentName, 'nao pode estar vazio');
    }

    return normalized;
  }

  List<String> _normalizeIds(Iterable<String> values, String argumentName) {
    final result = <String>[];
    final seen = <String>{};

    for (final rawValue in values) {
      final value = rawValue.trim();

      if (value.isEmpty) {
        throw ArgumentError.value(
          rawValue,
          argumentName,
          'nao pode conter identificadores vazios',
        );
      }

      if (seen.add(value)) {
        result.add(value);
      }
    }

    return result;
  }

  Iterable<List<String>> _chunks(List<String> values) sync* {
    for (var start = 0; start < values.length; start += _idChunkSize) {
      final candidateEnd = start + _idChunkSize;
      final end = candidateEnd < values.length ? candidateEnd : values.length;

      yield values.sublist(start, end);
    }
  }

  /// Reads global aggregate counts from the persisted projection.
  ///
  /// These counts mirror the assembler semantics: one count per path element
  /// that references an activity. Structural elements are excluded.
  Future<LearningProgressProjectionCounts> readProjectionCounts({
    required String accountId,
    required String learningPathId,
  }) async {
    final normalizedAccountId = _normalizeRequired(accountId, 'accountId');
    final normalizedPathId = _normalizeRequired(
      learningPathId,
      'learningPathId',
    );

    final rows = await _db.rawQuery(
      '''
      SELECT
        COUNT(*) AS projection_row_count,
        SUM(
          CASE
            WHEN activity_id IS NOT NULL THEN 1
            ELSE 0
          END
        ) AS total_activity_count,
        SUM(
          CASE
            WHEN activity_id IS NOT NULL AND state = ? THEN 1
            ELSE 0
          END
        ) AS completed_activity_count,
        MIN(package_version) AS min_package_version,
        MAX(package_version) AS max_package_version
      FROM learning_progress_projection
      WHERE account_id = ?
        AND learning_path_id = ?
      ''',
      <Object?>[
        LearningActivityState.completed.name,
        normalizedAccountId,
        normalizedPathId,
      ],
    );

    final row = rows.single;

    return LearningProgressProjectionCounts(
      projectionRowCount: (row['projection_row_count'] as int?) ?? 0,
      totalActivityCount: (row['total_activity_count'] as int?) ?? 0,
      completedActivityCount: (row['completed_activity_count'] as int?) ?? 0,
      minPackageVersion: row['min_package_version'] as int?,
      maxPackageVersion: row['max_package_version'] as int?,
    );
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

/// Agregado global e leve sobre a projeção persistida.
///
/// Não executa regras pedagógicas e não substitui a projeção por elemento.
final class LearningProgressProjectionCounts {
  LearningProgressProjectionCounts({
    required this.projectionRowCount,
    required this.totalActivityCount,
    required this.completedActivityCount,
    required this.minPackageVersion,
    required this.maxPackageVersion,
  }) {
    if (projectionRowCount < 0) {
      throw ArgumentError.value(projectionRowCount, 'projectionRowCount');
    }

    if (totalActivityCount < 0) {
      throw ArgumentError.value(totalActivityCount, 'totalActivityCount');
    }

    if (completedActivityCount < 0 ||
        completedActivityCount > totalActivityCount) {
      throw ArgumentError.value(
        completedActivityCount,
        'completedActivityCount',
      );
    }

    if (totalActivityCount > projectionRowCount) {
      throw ArgumentError(
        'totalActivityCount nao pode exceder projectionRowCount.',
      );
    }

    if (projectionRowCount == 0) {
      if (minPackageVersion != null || maxPackageVersion != null) {
        throw ArgumentError(
          'Uma projecao vazia nao pode declarar packageVersion.',
        );
      }
    } else {
      if (minPackageVersion == null || maxPackageVersion == null) {
        throw ArgumentError(
          'Uma projecao nao vazia deve declarar packageVersion.',
        );
      }
    }
  }

  final int projectionRowCount;
  final int totalActivityCount;
  final int completedActivityCount;
  final int? minPackageVersion;
  final int? maxPackageVersion;
}
