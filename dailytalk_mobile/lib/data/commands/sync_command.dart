import 'dart:convert';

import '../api/dailytalk_api_service.dart';
import '../dao/submission_dao.dart';

class SyncCommandResult {
  const SyncCommandResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.failedCount = 0,
  });

  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
}

abstract class SyncCommand {
  Future<SyncCommandResult> execute();
}

/// Sincroniza o progresso num único lote assinado e cifrado.
///
/// O lote reduz o número de pedidos HTTP e mantém idempotência através do
/// clientSubmissionId estável de cada registo local.
class SyncPendingSubmissionsCommand implements SyncCommand {
  SyncPendingSubmissionsCommand({
    required this.apiService,
    required this.submissionDao,
  });

  final DailyTalkApiService apiService;
  final SubmissionDao submissionDao;

  static Future<SyncCommandResult>? _activeExecution;

  @override
  Future<SyncCommandResult> execute() {
    final active = _activeExecution;
    if (active != null) return active;

    final execution = _executeOnce();
    _activeExecution = execution;
    return execution.whenComplete(() {
      if (identical(_activeExecution, execution)) {
        _activeExecution = null;
      }
    });
  }

  Future<SyncCommandResult> _executeOnce() async {
    final pending = await submissionDao.getPendingSubmissions(limit: 50);
    if (pending.isEmpty) {
      return const SyncCommandResult(
        success: true,
        message: 'Não existem submissões pendentes para sincronizar.',
      );
    }

    final validItems = <Map<String, dynamic>>[];
    final validLocalIds = <int>[];
    var invalidCount = 0;

    for (final row in pending) {
      final localId = row['id'] as int?;
      final clientId = row['client_submission_id']?.toString();
      final remoteActivityId = row['remote_activity_id']?.toString();
      final rawSubmission = row['submission_json']?.toString();
      final createdAt = row['created_at']?.toString();

      try {
        if (localId == null ||
            clientId == null ||
            clientId.isEmpty ||
            remoteActivityId == null ||
            remoteActivityId.isEmpty ||
            rawSubmission == null ||
            rawSubmission.isEmpty ||
            createdAt == null) {
          throw const FormatException('Submissão pendente incompleta.');
        }
        final decoded = jsonDecode(rawSubmission);
        if (decoded is! Map) {
          throw const FormatException('Payload local inválido.');
        }

        validItems.add({
          'clientSubmissionId': clientId,
          'remoteActivityId': remoteActivityId,
          'createdAt': DateTime.parse(createdAt).toUtc().toIso8601String(),
          'submission': Map<String, dynamic>.from(decoded),
        });
        validLocalIds.add(localId);
      } catch (error) {
        invalidCount += 1;
        if (localId != null) {
          await submissionDao.markAsFailed(
            submissionId: localId,
            error: error.toString(),
          );
        }
      }
    }

    if (validItems.isEmpty) {
      return SyncCommandResult(
        success: false,
        message: 'As submissões pendentes são inválidas.',
        failedCount: invalidCount,
      );
    }

    try {
      final response = await apiService.secureSyncProgress(validItems);
      final rawResults = response['results'];
      if (rawResults is! List) {
        throw const FormatException('Resposta do lote sem resultados.');
      }
      final results = rawResults
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      await submissionDao.applySecureSyncResults(results);

      final syncedCount = results
          .where(
            (item) =>
                item['status'] == 'accepted' || item['status'] == 'duplicate',
          )
          .length;
      final rejectedCount = results.length - syncedCount;
      final failedCount = invalidCount + rejectedCount;

      return SyncCommandResult(
        success: failedCount == 0,
        syncedCount: syncedCount,
        failedCount: failedCount,
        message: failedCount == 0
            ? 'Progresso sincronizado com segurança.'
            : 'Sincronização concluída com alguns itens rejeitados.',
      );
    } catch (error) {
      await submissionDao.markBatchAsFailed(validLocalIds, error.toString());
      return SyncCommandResult(
        success: false,
        message:
            'O progresso continua guardado neste dispositivo. A sincronização será retomada quando for possível.',
        failedCount: validItems.length + invalidCount,
      );
    }
  }
}
