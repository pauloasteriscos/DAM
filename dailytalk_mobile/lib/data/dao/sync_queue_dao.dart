import 'package:sqflite/sqflite.dart';

/// DAO para fila de sincronização.
///
/// Usado para guardar operações que devem ser tentadas novamente
/// quando a ligação à internet voltar.
class SyncQueueDao {
  SyncQueueDao(this.db);

  final Database db;

  /// Adiciona uma operação à fila de sincronização.
  Future<int> enqueue({
    required String entityType,
    required int entityId,
    required String operation,
    required String endpoint,
    String method = 'POST',
    required String payloadJson,
  }) async {
    final now = DateTime.now().toIso8601String();

    return db.insert('sync_queue', {
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'endpoint': endpoint,
      'method': method,
      'payload_json': payloadJson,
      'sync_status': 'pending',
      'attempt_count': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Lista operações pendentes, ordenadas pela data de criação.
  Future<List<Map<String, Object?>>> getPendingItems({int limit = 20}) async {
    final now = DateTime.now().toIso8601String();

    return db.query(
      'sync_queue',
      where: '''
        sync_status IN (?, ?)
        AND (next_retry_at IS NULL OR next_retry_at <= ?)
      ''',
      whereArgs: ['pending', 'failed', now],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// Marca uma operação como em processamento.
  Future<int> markProcessing(int id) async {
    return db.update(
      'sync_queue',
      {
        'sync_status': 'processing',
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marca uma operação como sincronizada.
  Future<int> markSynced(int id) async {
    final now = DateTime.now().toIso8601String();

    return db.update(
      'sync_queue',
      {
        'sync_status': 'synced',
        'updated_at': now,
        'processed_at': now,
        'last_error': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Marca falha e agenda nova tentativa com backoff simples.
  Future<int> markFailed({
    required int id,
    required String error,
    int retryAfterMinutes = 5,
  }) async {
    final now = DateTime.now();
    final nextRetry = now.add(Duration(minutes: retryAfterMinutes));

    return db.rawUpdate(
      '''
      UPDATE sync_queue
      SET sync_status = ?,
          attempt_count = attempt_count + 1,
          last_error = ?,
          updated_at = ?,
          next_retry_at = ?
      WHERE id = ?
      ''',
      [
        'failed',
        error,
        now.toIso8601String(),
        nextRetry.toIso8601String(),
        id,
      ],
    );
  }
}
