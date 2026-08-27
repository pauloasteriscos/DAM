import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/app_status.dart';
import '../../security/jose_utils.dart';

/// DAO para submissões e respetivos resultados.
///
/// Esta tabela suporta o requisito de guardar submissões pendentes
/// quando não houver rede e sincronizá-las posteriormente.
class SubmissionDao {
  SubmissionDao(this.db);

  final Database db;

  /// Cria uma submissão pendente para posterior envio ao endpoint POST /submit.
  Future<int> createPendingSubmission({
    required int activityId,
    int? studentId,
    required String remoteActivityId,
    required Map<String, dynamic> submission,
  }) async {
    final now = DateTime.now().toIso8601String();

    return db.insert('submissions', {
      'client_submission_id': randomBase64Url(24),
      'activity_id': activityId,
      'student_id': studentId,
      'remote_activity_id': remoteActivityId,
      'submission_json': jsonEncode(submission),
      'sync_status': SubmissionSyncStatus.pending.databaseValue,
      'attempt_count': 0,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Lista submissões pendentes ou com falha para tentar sincronizar.
  Future<List<Map<String, Object?>>> getPendingSubmissions({
    int limit = 50,
  }) async {
    return db.query(
      'submissions',
      where: 'sync_status IN (?, ?)',
      whereArgs: [
        SubmissionSyncStatus.pending.databaseValue,
        SubmissionSyncStatus.failed.databaseValue,
      ],
      orderBy: 'created_at ASC',
      limit: limit,
    );
  }

  /// Regista erro numa tentativa de sincronização.
  Future<int> markAsFailed({
    required int submissionId,
    required String error,
  }) async {
    final now = DateTime.now().toIso8601String();

    return db.rawUpdate(
      '''
      UPDATE submissions
      SET sync_status = ?,
          attempt_count = attempt_count + 1,
          last_error = ?,
          updated_at = ?
      WHERE id = ?
      ''',
      [SubmissionSyncStatus.failed.databaseValue, error, now, submissionId],
    );
  }

  /// Marca uma submissão como sincronizada e grava o resultado.
  ///
  /// Espera resposta compatível com:
  /// {
  ///   "activityID": "...",
  ///   "score": 10,
  ///   "feedback": "...",
  ///   "metrics": {...}
  /// }
  Future<void> markAsSyncedWithResult({
    required int submissionId,
    required String remoteActivityId,
    double? score,
    String? feedbackText,
    String? feedbackUrl,
    Map<String, dynamic>? metrics,
  }) async {
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'submissions',
        {
          'sync_status': SubmissionSyncStatus.synced.databaseValue,
          'submitted_at': now,
          'updated_at': now,
          'last_sync_at': now,
          'last_error': null,
        },
        where: 'id = ?',
        whereArgs: [submissionId],
      );

      await txn.insert('submission_results', {
        'submission_id': submissionId,
        'remote_activity_id': remoteActivityId,
        'score': score,
        'feedback_text': feedbackText,
        'feedback_url': feedbackUrl,
        'metrics_json': metrics == null ? null : jsonEncode(metrics),
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Grava um resultado local sem marcar a submissão como sincronizada.
  ///
  /// Usado no modo teste: o utilizador recebe feedback imediato, mas a
  /// submissão continua pendente para indicar que não foi enviada para a conta.
  Future<void> markAsLocalResult({
    required int submissionId,
    required String remoteActivityId,
    double? score,
    String? feedbackText,
    String? feedbackUrl,
    Map<String, dynamic>? metrics,
  }) async {
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.update(
        'submissions',
        {
          'sync_status': SubmissionSyncStatus.pending.databaseValue,
          'submitted_at': now,
          'updated_at': now,
          'last_error': null,
        },
        where: 'id = ?',
        whereArgs: [submissionId],
      );

      await txn.insert('submission_results', {
        'submission_id': submissionId,
        'remote_activity_id': remoteActivityId,
        'score': score,
        'feedback_text': feedbackText,
        'feedback_url': feedbackUrl,
        'metrics_json': metrics == null ? null : jsonEncode(metrics),
        'created_at': now,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  /// Obtém o resultado associado a uma submissão.
  Future<Map<String, Object?>?> getResultForSubmission(int submissionId) async {
    final rows = await db.query(
      'submission_results',
      where: 'submission_id = ?',
      whereArgs: [submissionId],
      limit: 1,
    );

    return rows.isEmpty ? null : rows.first;
  }

  /// Lista submissões de uma atividade.
  Future<List<Map<String, Object?>>> getSubmissionsForActivity(
    int activityId,
  ) async {
    return db.query(
      'submissions',
      where: 'activity_id = ?',
      whereArgs: [activityId],
      orderBy: 'created_at DESC',
    );
  }

  /// Lista resultados recentes para o ecrã "Meus Resultados".
  Future<List<Map<String, Object?>>> getRecentResults({int limit = 20}) async {
    return db.rawQuery(
      '''
      SELECT
        sr.*,
        s.activity_id,
        s.student_id,
        s.sync_status AS sync_status,
        s.submitted_at AS submitted_at,
        s.last_sync_at AS last_sync_at,
        s.last_error AS last_error,
        a.title,
        a.type,
        a.scenario,
        a.language_code,
        a.difficulty
      FROM submission_results sr
      INNER JOIN submissions s ON s.id = sr.submission_id
      INNER JOIN activities a ON a.id = s.activity_id
      ORDER BY sr.created_at DESC
      LIMIT ?
      ''',
      [limit],
    );
  }

  /// Aplica a resposta autenticada do lote às submissões locais.
  Future<void> applySecureSyncResults(
    List<Map<String, dynamic>> results,
  ) async {
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      for (final result in results) {
        final clientId = result['clientSubmissionId']?.toString();
        if (clientId == null || clientId.isEmpty) continue;

        final rows = await txn.query(
          'submissions',
          columns: ['id', 'remote_activity_id'],
          where: 'client_submission_id = ?',
          whereArgs: [clientId],
          limit: 1,
        );
        if (rows.isEmpty) continue;

        final submissionId = rows.first['id'] as int;
        final status = result['status']?.toString();
        if (status == 'accepted' || status == 'duplicate') {
          await txn.update(
            'submissions',
            {
              'sync_status': SubmissionSyncStatus.synced.databaseValue,
              'submitted_at': now,
              'updated_at': now,
              'last_sync_at': now,
              'last_error': null,
            },
            where: 'id = ?',
            whereArgs: [submissionId],
          );
          await txn.insert('submission_results', {
            'submission_id': submissionId,
            'remote_activity_id':
                result['remoteActivityId']?.toString() ??
                rows.first['remote_activity_id']?.toString() ??
                '',
            'score': _asDouble(result['score']),
            'feedback_text': result['feedback']?.toString(),
            'metrics_json': result['metrics'] is Map
                ? jsonEncode(result['metrics'])
                : null,
            'created_at': now,
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        } else {
          await txn.rawUpdate(
            '''
            UPDATE submissions
            SET sync_status = ?, attempt_count = attempt_count + 1,
                last_error = ?, updated_at = ?
            WHERE id = ?
            ''',
            [
              SubmissionSyncStatus.failed.databaseValue,
              result['reason']?.toString() ??
                  'Submissão rejeitada pelo servidor.',
              now,
              submissionId,
            ],
          );
        }
      }
    });
  }

  Future<void> markBatchAsFailed(
    Iterable<int> submissionIds,
    String error,
  ) async {
    for (final submissionId in submissionIds) {
      await markAsFailed(submissionId: submissionId, error: error);
    }
  }

  double? _asDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }
}
