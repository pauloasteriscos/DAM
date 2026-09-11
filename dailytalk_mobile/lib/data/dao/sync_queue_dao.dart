import 'dart:math' as math;

import 'package:sqflite/sqflite.dart';

typedef SyncQueueClock = DateTime Function();

/// Política determinística de backoff da outbox.
///
/// 1.ª falha: 5 min
/// 2.ª falha: 10 min
/// 3.ª falha: 20 min
/// 4.ª falha: 40 min
/// seguintes: máximo 60 min
final class SyncQueueRetryPolicy {
  const SyncQueueRetryPolicy({
    this.baseDelay = const Duration(minutes: 5),
    this.maxDelay = const Duration(hours: 1),
  });

  final Duration baseDelay;
  final Duration maxDelay;

  Duration delayForAttempt(int attemptNumber) {
    if (attemptNumber < 1) {
      throw ArgumentError.value(
        attemptNumber,
        'attemptNumber',
        'deve ser igual ou superior a 1',
      );
    }

    if (baseDelay <= Duration.zero) {
      throw StateError('baseDelay deve ser positivo.');
    }

    if (maxDelay < baseDelay) {
      throw StateError('maxDelay não pode ser inferior a baseDelay.');
    }

    final exponent = math.min(attemptNumber - 1, 20);
    final multiplier = 1 << exponent;

    final candidateMilliseconds = baseDelay.inMilliseconds * multiplier;

    return Duration(
      milliseconds: math.min(candidateMilliseconds, maxDelay.inMilliseconds),
    );
  }
}

/// DAO da outbox persistente.
///
/// A fila é durável e independente da rede. Um item só é entregue a um
/// worker após claim local atómico. Se a aplicação morrer enquanto o item
/// está em `processing`, o lease expira e o item pode ser recuperado.
class SyncQueueDao {
  SyncQueueDao(
    this.db, {
    SyncQueueClock? clock,
    SyncQueueRetryPolicy retryPolicy = const SyncQueueRetryPolicy(),
  }) : _clock = clock ?? DateTime.now,
       _retryPolicy = retryPolicy;

  final Database db;
  final SyncQueueClock _clock;
  final SyncQueueRetryPolicy _retryPolicy;

  DateTime _nowUtc() => _clock().toUtc();

  String _iso(DateTime value) => value.toUtc().toIso8601String();

  /// Adiciona uma operação à fila.
  ///
  /// A idempotência específica de cada entidade é garantida pelos
  /// invariantes/índices do respetivo domínio.
  Future<int> enqueue({
    required String entityType,
    required int entityId,
    required String operation,
    required String endpoint,
    String method = 'POST',
    required String payloadJson,
  }) async {
    final now = _iso(_nowUtc());

    return db.insert('sync_queue', <String, Object?>{
      'entity_type': entityType,
      'entity_id': entityId,
      'operation': operation,
      'endpoint': endpoint,
      'method': method,
      'payload_json': payloadJson,
      'sync_status': 'pending',
      'attempt_count': 0,
      'last_error': null,
      'created_at': now,
      'updated_at': now,
      'next_retry_at': null,
      'processed_at': null,
    });
  }

  /// Lista itens elegíveis sem alterar o respetivo estado.
  ///
  /// Útil para inspeção. Workers devem preferir [claimPendingItems].
  Future<List<Map<String, Object?>>> getPendingItems({int limit = 20}) async {
    _validateLimit(limit);

    final now = _iso(_nowUtc());

    return db.query(
      'sync_queue',
      where: '''
        sync_status IN (?, ?)
        AND (next_retry_at IS NULL OR next_retry_at <= ?)
      ''',
      whereArgs: <Object?>['pending', 'failed', now],
      orderBy: 'created_at ASC, id ASC',
      limit: limit,
    );
  }

  /// Recupera itens que ficaram em `processing` porque o processo morreu,
  /// a app foi terminada ou o worker deixou de responder.
  ///
  /// Não incrementamos attempt_count aqui porque não sabemos se o pedido
  /// chegou efetivamente a ser enviado. A idempotência remota da Fase 3.4
  /// tornará seguro repetir a entrega.
  Future<int> recoverStaleProcessing({
    Duration processingLease = const Duration(minutes: 15),
  }) {
    _validateLease(processingLease);

    return _recoverStaleProcessing(
      db,
      now: _nowUtc(),
      processingLease: processingLease,
    );
  }

  /// Faz claim atómico de itens elegíveis.
  ///
  /// A transação impede dois workers locais de receberem simultaneamente
  /// os mesmos registos.
  Future<List<Map<String, Object?>>> claimPendingItems({
    int limit = 20,
    Duration processingLease = const Duration(minutes: 15),
  }) async {
    _validateLimit(limit);
    _validateLease(processingLease);

    return db.transaction((txn) async {
      final now = _nowUtc();
      final nowIso = _iso(now);

      await _recoverStaleProcessing(
        txn,
        now: now,
        processingLease: processingLease,
      );

      final candidates = await txn.query(
        'sync_queue',
        where: '''
          sync_status IN (?, ?)
          AND (next_retry_at IS NULL OR next_retry_at <= ?)
        ''',
        whereArgs: <Object?>['pending', 'failed', nowIso],
        orderBy: 'created_at ASC, id ASC',
        limit: limit,
      );

      final claimed = <Map<String, Object?>>[];

      for (final row in candidates) {
        final id = row['id'] as int;

        final updated = await txn.update(
          'sync_queue',
          <String, Object?>{'sync_status': 'processing', 'updated_at': nowIso},
          where: '''
            id = ?
            AND sync_status IN (?, ?)
            AND (next_retry_at IS NULL OR next_retry_at <= ?)
          ''',
          whereArgs: <Object?>[id, 'pending', 'failed', nowIso],
        );

        if (updated == 1) {
          claimed.add(<String, Object?>{
            ...row,
            'sync_status': 'processing',
            'updated_at': nowIso,
          });
        }
      }

      return claimed;
    });
  }

  /// Compatibilidade com código existente: faz claim de um único item.
  /// Faz claim atómico apenas dos itens de uma família da outbox.
  ///
  /// Isto impede que um worker especializado reclame operações pertencentes
  /// a outro domínio. A recuperação de leases expirados também permanece
  /// limitada ao mesmo [entityType].
  Future<List<Map<String, Object?>>> claimPendingItemsByEntityType({
    required String entityType,
    int limit = 20,
    Duration processingLease = const Duration(minutes: 15),
  }) async {
    final normalizedEntityType = entityType.trim();

    if (normalizedEntityType.isEmpty) {
      throw ArgumentError.value(
        entityType,
        'entityType',
        'não pode estar vazio',
      );
    }

    _validateLimit(limit);
    _validateLease(processingLease);

    return db.transaction((txn) async {
      final now = _nowUtc();
      final nowIso = _iso(now);
      final staleBefore = now.subtract(processingLease);

      await txn.update(
        'sync_queue',
        <String, Object?>{
          'sync_status': 'pending',
          'last_error': 'processing_lease_expired',
          'updated_at': nowIso,
          'next_retry_at': null,
          'processed_at': null,
        },
        where: '''
          entity_type = ?
          AND sync_status = ?
          AND updated_at <= ?
        ''',
        whereArgs: <Object?>[
          normalizedEntityType,
          'processing',
          _iso(staleBefore),
        ],
      );

      final candidates = await txn.query(
        'sync_queue',
        where: '''
          entity_type = ?
          AND sync_status IN (?, ?)
          AND (next_retry_at IS NULL OR next_retry_at <= ?)
        ''',
        whereArgs: <Object?>[normalizedEntityType, 'pending', 'failed', nowIso],
        orderBy: 'created_at ASC, id ASC',
        limit: limit,
      );

      final claimed = <Map<String, Object?>>[];

      for (final row in candidates) {
        final id = row['id'] as int;

        final updated = await txn.update(
          'sync_queue',
          <String, Object?>{'sync_status': 'processing', 'updated_at': nowIso},
          where: '''
            id = ?
            AND entity_type = ?
            AND sync_status IN (?, ?)
            AND (next_retry_at IS NULL OR next_retry_at <= ?)
          ''',
          whereArgs: <Object?>[
            id,
            normalizedEntityType,
            'pending',
            'failed',
            nowIso,
          ],
        );

        if (updated == 1) {
          claimed.add(<String, Object?>{
            ...row,
            'sync_status': 'processing',
            'updated_at': nowIso,
          });
        }
      }

      return claimed;
    });
  }

  Future<int> markProcessing(int id) async {
    final now = _iso(_nowUtc());

    return db.update(
      'sync_queue',
      <String, Object?>{'sync_status': 'processing', 'updated_at': now},
      where: '''
        id = ?
        AND sync_status IN (?, ?)
        AND (next_retry_at IS NULL OR next_retry_at <= ?)
      ''',
      whereArgs: <Object?>[id, 'pending', 'failed', now],
    );
  }

  /// Finaliza com sucesso apenas um item atualmente reclamado.
  Future<int> markSynced(int id) async {
    final now = _iso(_nowUtc());

    return db.update(
      'sync_queue',
      <String, Object?>{
        'sync_status': 'synced',
        'updated_at': now,
        'processed_at': now,
        'next_retry_at': null,
        'last_error': null,
      },
      where: 'id = ? AND sync_status = ?',
      whereArgs: <Object?>[id, 'processing'],
    );
  }

  /// Regista falha e agenda retry com backoff exponencial limitado.
  ///
  /// [retryAfterMinutes] permanece por compatibilidade e pode representar
  /// uma indicação remota. Nunca reduz o backoff calculado localmente.
  ///
  /// O texto bruto de [error] não é persistido: apenas uma categoria segura.
  Future<int> markFailed({
    required int id,
    required String error,
    int? retryAfterMinutes,
  }) async {
    if (retryAfterMinutes != null && retryAfterMinutes < 0) {
      throw ArgumentError.value(
        retryAfterMinutes,
        'retryAfterMinutes',
        'não pode ser negativo',
      );
    }

    return db.transaction((txn) async {
      final rows = await txn.query(
        'sync_queue',
        columns: const <String>['id', 'sync_status', 'attempt_count'],
        where: 'id = ?',
        whereArgs: <Object?>[id],
        limit: 1,
      );

      if (rows.isEmpty) {
        return 0;
      }

      final row = rows.single;

      if (row['sync_status'] != 'processing') {
        return 0;
      }

      final currentAttempts = (row['attempt_count'] as int?) ?? 0;

      final nextAttempt = currentAttempts + 1;

      var delay = _retryPolicy.delayForAttempt(nextAttempt);

      if (retryAfterMinutes != null) {
        final requested = Duration(minutes: retryAfterMinutes);

        if (requested > delay) {
          delay = requested;
        }
      }

      final now = _nowUtc();
      final nextRetry = now.add(delay);

      return txn.update(
        'sync_queue',
        <String, Object?>{
          'sync_status': 'failed',
          'attempt_count': nextAttempt,
          'last_error': _safeErrorCategory(error),
          'updated_at': _iso(now),
          'next_retry_at': _iso(nextRetry),
          'processed_at': null,
        },
        where: 'id = ? AND sync_status = ?',
        whereArgs: <Object?>[id, 'processing'],
      );
    });
  }

  Future<int> _recoverStaleProcessing(
    DatabaseExecutor executor, {
    required DateTime now,
    required Duration processingLease,
  }) {
    final staleBefore = now.subtract(processingLease);

    return executor.update(
      'sync_queue',
      <String, Object?>{
        'sync_status': 'pending',
        'last_error': 'processing_lease_expired',
        'updated_at': _iso(now),
        'next_retry_at': null,
        'processed_at': null,
      },
      where: '''
        sync_status = ?
        AND updated_at <= ?
      ''',
      whereArgs: <Object?>['processing', _iso(staleBefore)],
    );
  }

  String _safeErrorCategory(String rawError) {
    final value = rawError.toLowerCase();

    if (value.contains('429') ||
        value.contains('rate limit') ||
        value.contains('too many requests')) {
      return 'rate_limited';
    }

    if (value.contains('401') ||
        value.contains('403') ||
        value.contains('unauthorized') ||
        value.contains('forbidden') ||
        value.contains('bearer') ||
        value.contains('token')) {
      return 'authentication';
    }

    if (value.contains('timeout') || value.contains('timed out')) {
      return 'timeout';
    }

    if (value.contains('socket') ||
        value.contains('network') ||
        value.contains('connection') ||
        value.contains('offline') ||
        value.contains('dns')) {
      return 'network';
    }

    if (value.contains('format') ||
        value.contains('json') ||
        value.contains('payload')) {
      return 'invalid_payload';
    }

    return 'sync_failure';
  }

  void _validateLimit(int limit) {
    if (limit < 1) {
      throw ArgumentError.value(
        limit,
        'limit',
        'deve ser igual ou superior a 1',
      );
    }
  }

  void _validateLease(Duration lease) {
    if (lease <= Duration.zero) {
      throw ArgumentError.value(lease, 'processingLease', 'deve ser positivo');
    }
  }
}
