import 'dart:convert';

import '../api/dailytalk_api_service.dart';
import '../dao/submission_dao.dart';

/// Resultado da execução de um comando de sincronização.
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

/// Interface base para comandos de sincronização.
///
/// Cada comando encapsula uma operação que pode ser executada
/// posteriormente, como reenviar uma submissão pendente.
abstract class SyncCommand {
  Future<SyncCommandResult> execute();
}

/// Comando responsável por sincronizar uma submissão pendente.
class SubmitPendingSubmissionCommand implements SyncCommand {
  SubmitPendingSubmissionCommand({
    required this.apiService,
    required this.submissionDao,
    required this.submission,
  });

  final DailyTalkApiService apiService;
  final SubmissionDao submissionDao;
  final Map<String, Object?> submission;

  @override
  Future<SyncCommandResult> execute() async {
    final submissionId = submission['id'] as int?;
    final remoteActivityId = submission['remote_activity_id']?.toString();
    final submissionJson = submission['submission_json']?.toString();

    if (submissionId == null ||
        remoteActivityId == null ||
        remoteActivityId.isEmpty ||
        submissionJson == null ||
        submissionJson.isEmpty) {
      return const SyncCommandResult(
        success: false,
        message: 'Submissão pendente inválida.',
        failedCount: 1,
      );
    }

    try {
      final decoded = jsonDecode(submissionJson);

      if (decoded is! Map) {
        throw Exception('Formato inválido da submissão pendente.');
      }

      final submissionPayload = Map<String, dynamic>.from(decoded);

      final response = await apiService.submitActivity(
        activityId: remoteActivityId,
        submission: submissionPayload,
      );

      final score = _extractScore(response);
      final feedbackText = response['feedback']?.toString();
      final metrics = response['metrics'] is Map
          ? Map<String, dynamic>.from(response['metrics'] as Map)
          : null;

      await submissionDao.markAsSyncedWithResult(
        submissionId: submissionId,
        remoteActivityId: remoteActivityId,
        score: score,
        feedbackText: feedbackText,
        metrics: metrics,
      );

      return const SyncCommandResult(
        success: true,
        message: 'Submissão sincronizada.',
        syncedCount: 1,
      );
    } catch (error) {
      await submissionDao.markAsFailed(
        submissionId: submissionId,
        error: error.toString(),
      );

      return SyncCommandResult(
        success: false,
        message: error.toString(),
        failedCount: 1,
      );
    }
  }

  double? _extractScore(Map<String, dynamic> response) {
    final value = response['score'];

    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }
}

/// Comando composto responsável por sincronizar todas as submissões pendentes.
class SyncPendingSubmissionsCommand implements SyncCommand {
  SyncPendingSubmissionsCommand({
    required this.apiService,
    required this.submissionDao,
  });

  final DailyTalkApiService apiService;
  final SubmissionDao submissionDao;

  @override
  Future<SyncCommandResult> execute() async {
    final pendingSubmissions = await submissionDao.getPendingSubmissions();

    if (pendingSubmissions.isEmpty) {
      return const SyncCommandResult(
        success: true,
        message: 'Não existem submissões pendentes para sincronizar.',
      );
    }

    var syncedCount = 0;
    var failedCount = 0;

    for (final submission in pendingSubmissions) {
      final command = SubmitPendingSubmissionCommand(
        apiService: apiService,
        submissionDao: submissionDao,
        submission: submission,
      );

      final result = await command.execute();

      syncedCount += result.syncedCount;
      failedCount += result.failedCount;
    }

    return SyncCommandResult(
      success: failedCount == 0,
      syncedCount: syncedCount,
      failedCount: failedCount,
      message: failedCount == 0
          ? 'Sincronização concluída com sucesso.'
          : 'Sincronização concluída com falhas.',
    );
  }
}