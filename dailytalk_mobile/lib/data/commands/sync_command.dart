import 'dart:convert';
import '../../domain/learning/learning_domain.dart';

import '../api/dailytalk_api_service.dart';
import '../dao/submission_dao.dart';
import '../dao/sync_queue_dao.dart';
import '../repositories/learning_progress_repository.dart';

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
/// Contexto opcional que transforma a sincronização de outbox numa
/// reconciliação bidirecional.
///
/// Sem este contexto, [SyncLearningProgressOutboxCommand] mantém exatamente
/// o comportamento push-only da Fase 3.4B.
final class LearningProgressReconciliationContext {
  const LearningProgressReconciliationContext({
    required this.repository,
    required this.accountId,
    required this.learningPath,
    required this.activePackageVersion,
    this.practicePreference = PracticePreference.balanced,
    this.pullLimit = 50,
    this.maxPullPages = 100,
  });

  final LearningProgressRepository repository;
  final String accountId;
  final LearningPath learningPath;
  final int activePackageVersion;
  final PracticePreference practicePreference;
  final int pullLimit;
  final int maxPullPages;

  void validate() {
    if (accountId.trim().isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'não pode estar vazio');
    }

    if (activePackageVersion < 1) {
      throw ArgumentError.value(
        activePackageVersion,
        'activePackageVersion',
        'deve ser igual ou superior a 1',
      );
    }

    if (pullLimit < 1 || pullLimit > 100) {
      throw ArgumentError.value(
        pullLimit,
        'pullLimit',
        'deve estar entre 1 e 100',
      );
    }

    if (maxPullPages < 1) {
      throw ArgumentError.value(
        maxPullPages,
        'maxPullPages',
        'deve ser igual ou superior a 1',
      );
    }
  }
}

/// Sincroniza factos pedagógicos persistidos na outbox.
///
/// Fase 3.4B:
/// - sem [reconciliation], permanece push-only.
///
/// Fase 3.5:
/// - com [reconciliation], executa push + pull no mesmo Secure Sync;
/// - mesmo com outbox vazia, realiza pull;
/// - aplica cada página remotamente antes de considerar o progresso local
///   reconciliado;
/// - só marca a outbox como synced depois de toda a paginação terminar.
///
/// DPoP, JWS, JWE, sequence e batchId continuam exclusivamente sob
/// responsabilidade de [DailyTalkApiService.secureSyncProgress].
class SyncLearningProgressOutboxCommand implements SyncCommand {
  SyncLearningProgressOutboxCommand({
    required this.apiService,
    required this.syncQueueDao,
    this.reconciliation,
    this.forceRetry = false,
  });

  static const String _entityType = 'learning_progress_completion';

  final DailyTalkApiService apiService;
  final SyncQueueDao syncQueueDao;
  final LearningProgressReconciliationContext? reconciliation;

  /// Ignora apenas o agendamento de retry ao reclamar itens.
  ///
  /// Usado pela ação manual explícita do utilizador. Uma eventual falha
  /// continua a passar por markFailed e volta ao backoff normal.
  final bool forceRetry;

  static Future<SyncCommandResult>? _activePushExecution;

  static final Map<String, Future<SyncCommandResult>> _activeReconciliations =
      <String, Future<SyncCommandResult>>{};

  @override
  Future<SyncCommandResult> execute() {
    final context = reconciliation;

    if (context == null) {
      final active = _activePushExecution;

      if (active != null) {
        return active;
      }

      final execution = _executeOnce();
      _activePushExecution = execution;

      return execution.whenComplete(() {
        if (identical(_activePushExecution, execution)) {
          _activePushExecution = null;
        }
      });
    }

    context.validate();

    final key =
        '${context.accountId.trim()}\u0000'
        '${context.learningPath.id.value}';

    final active = _activeReconciliations[key];

    if (active != null) {
      return active;
    }

    final execution = _executeOnce();
    _activeReconciliations[key] = execution;

    return execution.whenComplete(() {
      if (identical(_activeReconciliations[key], execution)) {
        _activeReconciliations.remove(key);
      }
    });
  }

  Future<SyncCommandResult> _executeOnce() async {
    final context = reconciliation;

    final pending = await syncQueueDao.claimPendingItemsByEntityType(
      entityType: _entityType,
      limit: 50,
      ignoreRetrySchedule: forceRetry,
    );

    // Compatibilidade estrita com a Fase 3.4B.
    if (pending.isEmpty && context == null) {
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
        final item = _parseOutboxItem(row, localId: localId);

        if (byClientId.containsKey(item.clientCompletionId)) {
          throw const FormatException(
            'clientCompletionId duplicado na outbox local.',
          );
        }

        valid.add(item);
        byClientId[item.clientCompletionId] = item;
      } catch (_) {
        invalidCount += 1;

        await syncQueueDao.markFailed(id: localId, error: 'invalid payload');
      }
    }

    // Compatibilidade estrita com a Fase 3.4B.
    if (context == null && valid.isEmpty) {
      return SyncCommandResult(
        success: false,
        message: 'As conclusões pedagógicas pendentes são inválidas.',
        failedCount: invalidCount,
      );
    }

    try {
      if (context == null) {
        return await _executePushOnly(
          valid: valid,
          byClientId: byClientId,
          invalidCount: invalidCount,
        );
      }

      return await _executeReconciliation(
        context: context,
        valid: valid,
        byClientId: byClientId,
        invalidCount: invalidCount,
      );
    } catch (error) {
      // Se o servidor já tiver aceite estes factos, o retry será
      // devolvido como duplicate. Portanto é seguro não os perder.
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
            'A reconciliação será retomada quando for possível.',
        failedCount: valid.length + invalidCount,
      );
    }
  }

  Future<SyncCommandResult> _executePushOnly({
    required List<_LearningOutboxItem> valid,
    required Map<String, _LearningOutboxItem> byClientId,
    required int invalidCount,
  }) async {
    final response = await apiService.secureSyncProgress(
      valid.map((item) => item.serverItem).toList(growable: false),
    );

    _validatePushResults(response, valid: valid, byClientId: byClientId);

    await _markSynced(valid);

    return SyncCommandResult(
      success: invalidCount == 0,
      message: invalidCount == 0
          ? 'Progresso pedagógico sincronizado com segurança.'
          : 'Sincronização concluída com itens locais inválidos.',
      syncedCount: valid.length,
      failedCount: invalidCount,
    );
  }

  Future<SyncCommandResult> _executeReconciliation({
    required LearningProgressReconciliationContext context,
    required List<_LearningOutboxItem> valid,
    required Map<String, _LearningOutboxItem> byClientId,
    required int invalidCount,
  }) async {
    var cursor = await context.repository.readSyncCursor(
      accountId: context.accountId,
      learningPathId: context.learningPath.id.value,
    );

    var response = await apiService.secureSyncProgress(
      valid.map((item) => item.serverItem).toList(growable: false),
      pullLearningProgress: true,
      learningProgressPathId: context.learningPath.id.value,
      learningProgressCursor: cursor,
      learningProgressLimit: context.pullLimit,
    );

    _validatePushResults(response, valid: valid, byClientId: byClientId);

    var pageNumber = 0;

    while (true) {
      pageNumber += 1;

      if (pageNumber > context.maxPullPages) {
        throw StateError('A paginação remota excedeu o limite de segurança.');
      }

      final page = _parsePullPage(
        response,
        expectedLearningPathId: context.learningPath.id.value,
      );

      final merged = await context.repository.mergeRemoteProgress(
        MergeRemoteLearningProgressWrite(
          accountId: context.accountId,
          learningPath: context.learningPath,
          activePackageVersion: context.activePackageVersion,
          expectedCursor: cursor,
          nextCursor: page.nextCursor,
          completions: page.completions,
          practicePreference: context.practicePreference,
        ),
      );

      cursor = merged.cursor;

      if (!page.hasMore) {
        break;
      }

      response = await apiService.secureSyncProgress(
        const <Map<String, dynamic>>[],
        pullLearningProgress: true,
        learningProgressPathId: context.learningPath.id.value,
        learningProgressCursor: cursor,
        learningProgressLimit: context.pullLimit,
      );

      // Páginas seguintes são obrigatoriamente pull-only.
      _validatePushResults(
        response,
        valid: const <_LearningOutboxItem>[],
        byClientId: const <String, _LearningOutboxItem>{},
      );
    }

    // Só depois do pull completo é que os factos locais ficam
    // definitivamente marcados como sincronizados.
    await _markSynced(valid);

    return SyncCommandResult(
      success: invalidCount == 0,
      message: invalidCount == 0
          ? 'Progresso pedagógico reconciliado com segurança.'
          : 'Reconciliação concluída com itens locais inválidos.',
      syncedCount: valid.length,
      failedCount: invalidCount,
    );
  }

  _LearningOutboxItem _parseOutboxItem(
    Map<String, Object?> row, {
    required int localId,
  }) {
    if (row['operation']?.toString() != 'ActivityCompleted' ||
        row['endpoint']?.toString() != '/api/sync/progress' ||
        row['method']?.toString().toUpperCase() != 'POST') {
      throw const FormatException('Metadados da operação de outbox inválidos.');
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

    final clientCompletionId = _requiredString(payload, 'clientCompletionId');

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

    // Whitelist explícita do contrato remoto.
    //
    // competencyIds permanece exclusivamente local.
    final serverItem = <String, dynamic>{
      'type': 'activityCompletion',
      'clientCompletionId': clientCompletionId,
      'learningPathId': learningPathId,
      'activityId': activityId,
      'revisionId': revisionId,
      'packageVersion': packageVersion,
      'completedAt': parsedCompletedAt.toUtc().toIso8601String(),
    };

    return _LearningOutboxItem(
      localId: localId,
      clientCompletionId: clientCompletionId,
      serverItem: serverItem,
    );
  }

  void _validatePushResults(
    Map<String, dynamic> response, {
    required List<_LearningOutboxItem> valid,
    required Map<String, _LearningOutboxItem> byClientId,
  }) {
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

      final clientCompletionId = _requiredString(result, 'clientCompletionId');

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
  }

  _LearningProgressPullPage _parsePullPage(
    Map<String, dynamic> response, {
    required String expectedLearningPathId,
  }) {
    final rawPull = response['pull'];

    if (rawPull is! Map) {
      throw const FormatException('Resposta Secure Sync sem pull.');
    }

    final pull = Map<String, dynamic>.from(rawPull);
    final rawLearning = pull['learningProgress'];

    if (rawLearning is! Map) {
      throw const FormatException('Resposta sem learningProgress.');
    }

    final learning = Map<String, dynamic>.from(rawLearning);

    final rawItems = learning['items'];
    final rawHasMore = learning['hasMore'];
    final rawNextCursor = learning['nextCursor'];

    if (rawItems is! List || rawHasMore is! bool) {
      throw const FormatException('Página de progresso remoto inválida.');
    }

    String? nextCursor;

    if (rawNextCursor != null) {
      if (rawNextCursor is! String || rawNextCursor.trim().isEmpty) {
        throw const FormatException('nextCursor remoto inválido.');
      }

      nextCursor = rawNextCursor.trim();
    }

    final completions = <RemoteLearningCompletionFact>[];

    final seenCompletionIds = <String>{};
    final seenClientIds = <String>{};

    for (final rawItem in rawItems) {
      if (rawItem is! Map) {
        throw const FormatException('Facto remoto inválido.');
      }

      final item = Map<String, dynamic>.from(rawItem);

      if (item['type'] != 'activityCompletion') {
        throw const FormatException('Tipo de facto remoto inválido.');
      }

      final completionId = _requiredString(item, 'completionId');

      final clientCompletionId = _requiredString(item, 'clientCompletionId');

      final learningPathId = _requiredString(item, 'learningPathId');

      final activityId = _requiredString(item, 'activityId');

      final revisionId = _requiredString(item, 'revisionId');

      final completedAt = _requiredString(item, 'completedAt');

      final packageVersion = item['packageVersion'];

      if (packageVersion is! int || packageVersion <= 0) {
        throw const FormatException('packageVersion remoto inválido.');
      }

      final parsedCompletedAt = DateTime.tryParse(completedAt);

      if (parsedCompletedAt == null) {
        throw const FormatException('completedAt remoto inválido.');
      }

      if (learningPathId != expectedLearningPathId) {
        throw const FormatException('Facto remoto pertence a outro percurso.');
      }

      if (!seenCompletionIds.add(completionId) ||
          !seenClientIds.add(clientCompletionId)) {
        throw const FormatException('Página remota contém factos duplicados.');
      }

      completions.add(
        RemoteLearningCompletionFact(
          serverCompletionId: completionId,
          clientCompletionId: clientCompletionId,
          learningPathId: learningPathId,
          activityId: ActivityId(activityId),
          revisionId: RevisionId(revisionId),
          packageVersion: packageVersion,
          completedAt: parsedCompletedAt.toUtc(),
        ),
      );
    }

    if (rawHasMore && (completions.isEmpty || nextCursor == null)) {
      throw const FormatException('Página remota incompleta declarou hasMore.');
    }

    return _LearningProgressPullPage(
      completions: completions,
      nextCursor: nextCursor,
      hasMore: rawHasMore,
    );
  }

  Future<void> _markSynced(List<_LearningOutboxItem> items) async {
    for (final item in items) {
      final changed = await syncQueueDao.markSynced(item.localId);

      if (changed != 1) {
        throw StateError('Item da outbox deixou de estar em processing.');
      }
    }
  }

  String _requiredString(Map<String, dynamic> source, String key) {
    final value = source[key];

    if (value is! String || value.trim().isEmpty) {
      throw FormatException('Campo obrigatório ausente ou inválido: $key.');
    }

    return value.trim();
  }
}

/// Comando semântico da Fase 3.5.
///
/// Usa o mesmo motor e o mesmo protocolo da outbox 3.4B, mas torna o
/// pull obrigatório mesmo quando não há nada local para enviar.
final class ReconcileLearningProgressCommand implements SyncCommand {
  ReconcileLearningProgressCommand({
    required DailyTalkApiService apiService,
    required SyncQueueDao syncQueueDao,
    required LearningProgressRepository repository,
    required String accountId,
    required LearningPath learningPath,
    required int activePackageVersion,
    PracticePreference practicePreference = PracticePreference.balanced,
    int pullLimit = 50,
    int maxPullPages = 100,
  }) : _delegate = SyncLearningProgressOutboxCommand(
         apiService: apiService,
         syncQueueDao: syncQueueDao,
         reconciliation: LearningProgressReconciliationContext(
           repository: repository,
           accountId: accountId,
           learningPath: learningPath,
           activePackageVersion: activePackageVersion,
           practicePreference: practicePreference,
           pullLimit: pullLimit,
           maxPullPages: maxPullPages,
         ),
       );

  final SyncLearningProgressOutboxCommand _delegate;

  @override
  Future<SyncCommandResult> execute() {
    return _delegate.execute();
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

final class _LearningProgressPullPage {
  _LearningProgressPullPage({
    required Iterable<RemoteLearningCompletionFact> completions,
    required this.nextCursor,
    required this.hasMore,
  }) : completions = List<RemoteLearningCompletionFact>.unmodifiable(
         completions,
       );

  final List<RemoteLearningCompletionFact> completions;
  final String? nextCursor;
  final bool hasMore;
}
