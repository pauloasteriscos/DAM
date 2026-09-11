import 'dart:convert';

import '../api/dailytalk_api_service.dart';
import '../dao/submission_dao.dart';
import '../dao/sync_queue_dao.dart';

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

/// Sincroniza exclusivamente factos pedagógicos persistidos na outbox.
///
/// O payload local pode conter informação auxiliar, como competencyIds, mas
/// apenas os campos autorizados pelo contrato remoto são transportados.
/// DPoP, JWS, JWE, sequence e batchId continuam a ser responsabilidade de
/// [DailyTalkApiService.secureSyncProgress].
class SyncLearningProgressOutboxCommand implements SyncCommand {
  SyncLearningProgressOutboxCommand({
    required this.apiService,
    required this.syncQueueDao,
  });

  static const String _entityType = 'learning_progress_completion';

  final DailyTalkApiService apiService;
  final SyncQueueDao syncQueueDao;

  static Future<SyncCommandResult>? _activeExecution;

  @override
  Future<SyncCommandResult> execute() {
    final active = _activeExecution;
    if (active != null) {
      return active;
    }

    final execution = _executeOnce();
    _activeExecution = execution;

    return execution.whenComplete(() {
      if (identical(_activeExecution, execution)) {
        _activeExecution = null;
      }
    });
  }

  Future<SyncCommandResult> _executeOnce() async {
    final pending = await syncQueueDao.claimPendingItemsByEntityType(
      entityType: _entityType,
      limit: 50,
    );

    if (pending.isEmpty) {
      return const SyncCommandResult(
        success: true,
        message: 'Não existem conclusões pedagógicas pendentes.',
      );
    }

    final valid = <_LearningOutboxItem>[];
    final byClientId = <String, _LearningOutboxItem>{};

    var invalidCount = 0;

    for (final row in pending) {
      final localId = row['id'];

      if (localId is! int) {
        invalidCount += 1;
        continue;
      }

      try {
        if (row['operation']?.toString() != 'ActivityCompleted' ||
            row['endpoint']?.toString() != '/api/sync/progress' ||
            row['method']?.toString().toUpperCase() != 'POST') {
          throw const FormatException(
            'Metadados da operação de outbox inválidos.',
          );
        }

        final rawPayload = row['payload_json']?.toString();

        if (rawPayload == null || rawPayload.isEmpty) {
          throw const FormatException('Payload local ausente.');
        }

        final decoded = jsonDecode(rawPayload);

        if (decoded is! Map) {
          throw const FormatException('Payload local inválido.');
        }

        final payload = Map<String, dynamic>.from(decoded);

        if (payload['type'] != 'ActivityCompleted') {
          throw const FormatException('Tipo local de conclusão inválido.');
        }

        final clientCompletionId = _requiredString(
          payload,
          'clientCompletionId',
        );
        final learningPathId = _requiredString(payload, 'learningPathId');
        final activityId = _requiredString(payload, 'activityId');
        final revisionId = _requiredString(payload, 'revisionId');
        final completedAt = _requiredString(payload, 'completedAt');

        final packageVersion = payload['packageVersion'];

        if (packageVersion is! int || packageVersion <= 0) {
          throw const FormatException('packageVersion inválido.');
        }

        final parsedCompletedAt = DateTime.tryParse(completedAt);

        if (parsedCompletedAt == null) {
          throw const FormatException('completedAt inválido.');
        }

        if (byClientId.containsKey(clientCompletionId)) {
          throw const FormatException(
            'clientCompletionId duplicado na outbox local.',
          );
        }

        // Whitelist explícita do contrato remoto.
        //
        // competencyIds NÃO é transportado. O servidor não confia em
        // competências declaradas pelo cliente.
        final serverItem = <String, dynamic>{
          'type': 'activityCompletion',
          'clientCompletionId': clientCompletionId,
          'learningPathId': learningPathId,
          'activityId': activityId,
          'revisionId': revisionId,
          'packageVersion': packageVersion,
          'completedAt': parsedCompletedAt.toUtc().toIso8601String(),
        };

        final item = _LearningOutboxItem(
          localId: localId,
          clientCompletionId: clientCompletionId,
          serverItem: serverItem,
        );

        valid.add(item);
        byClientId[clientCompletionId] = item;
      } catch (_) {
        invalidCount += 1;

        await syncQueueDao.markFailed(id: localId, error: 'invalid payload');
      }
    }

    if (valid.isEmpty) {
      return SyncCommandResult(
        success: false,
        message: 'As conclusões pedagógicas pendentes são inválidas.',
        failedCount: invalidCount,
      );
    }

    try {
      final response = await apiService.secureSyncProgress(
        valid.map((item) => item.serverItem).toList(growable: false),
      );

      final rawResults = response['results'];

      if (rawResults is! List) {
        throw const FormatException('Resposta do lote sem resultados.');
      }

      if (rawResults.length != valid.length) {
        throw const FormatException(
          'Quantidade de resultados não corresponde ao lote enviado.',
        );
      }

      final seenClientIds = <String>{};

      for (final rawResult in rawResults) {
        if (rawResult is! Map) {
          throw const FormatException('Resultado de sincronização inválido.');
        }

        final result = Map<String, dynamic>.from(rawResult);

        if (result['type'] != 'activityCompletion') {
          throw const FormatException('Tipo de resultado remoto inválido.');
        }

        final clientCompletionId = _requiredString(
          result,
          'clientCompletionId',
        );

        final expected = byClientId[clientCompletionId];

        if (expected == null) {
          throw const FormatException(
            'Resposta contém clientCompletionId desconhecido.',
          );
        }

        if (!seenClientIds.add(clientCompletionId)) {
          throw const FormatException(
            'Resposta contém clientCompletionId duplicado.',
          );
        }

        final status = _requiredString(result, 'status');

        if (status != 'accepted' && status != 'duplicate') {
          throw const FormatException('Estado remoto de conclusão inválido.');
        }

        _requiredString(result, 'completionId');

        if (result['activityId'] != expected.serverItem['activityId'] ||
            result['revisionId'] != expected.serverItem['revisionId']) {
          throw const FormatException(
            'Resposta remota não corresponde ao facto enviado.',
          );
        }
      }

      if (seenClientIds.length != valid.length) {
        throw const FormatException('Resposta remota incompleta.');
      }

      for (final item in valid) {
        final changed = await syncQueueDao.markSynced(item.localId);

        if (changed != 1) {
          throw StateError('Item da outbox deixou de estar em processing.');
        }
      }

      return SyncCommandResult(
        success: invalidCount == 0,
        message: invalidCount == 0
            ? 'Progresso pedagógico sincronizado com segurança.'
            : 'Sincronização concluída com itens locais inválidos.',
        syncedCount: valid.length,
        failedCount: invalidCount,
      );
    } catch (error) {
      for (final item in valid) {
        await syncQueueDao.markFailed(
          id: item.localId,
          error: error.toString(),
        );
      }

      return SyncCommandResult(
        success: false,
        message:
            'O progresso continua guardado neste dispositivo. '
            'A sincronização será retomada quando for possível.',
        failedCount: valid.length + invalidCount,
      );
    }
  }

  String _requiredString(Map<String, dynamic> source, String key) {
    final value = source[key];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo obrigatório ausente ou inválido: $key.');
    }

    return value;
  }
}

final class _LearningOutboxItem {
  const _LearningOutboxItem({
    required this.localId,
    required this.clientCompletionId,
    required this.serverItem,
  });

  final int localId;
  final String clientCompletionId;
  final Map<String, dynamic> serverItem;
}
