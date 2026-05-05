import '../../models/app_status.dart';
import '../api/dailytalk_api_service.dart';
import '../dao/submission_dao.dart';

/// Repository responsável pela submissão de respostas.
///
/// Coordena:
/// - criação da submissão local;
/// - tentativa de envio ao backend;
/// - gravação do resultado;
/// - marcação do estado de sincronização.
class SubmissionRepository {
  SubmissionRepository({
    required this.apiService,
    required this.submissionDao,
  });

  final DailyTalkApiService apiService;
  final SubmissionDao submissionDao;

  /// Submete uma resposta de atividade.
  ///
  /// Nesta Sprint 2, o envio pode funcionar em modo mock,
  /// mas a estrutura já fica preparada para POST /submit real.
  Future<Map<String, dynamic>> submitAnswer({
    required int activityId,
    int? studentId,
    required String remoteActivityId,
    required String activityType,
    required String answerText,
    String nativeLanguageCode = 'pt-PT',
    String targetLanguageCode = 'it-IT',
  }) async {
    final submissionPayload = {
      'activityType': activityType,
      'nativeLanguageCode': nativeLanguageCode,
      'targetLanguageCode': targetLanguageCode,
      'submittedAt': DateTime.now().toIso8601String(),
      'answers': [
        {
          'field': 'response',
          'value': answerText,
        },
      ],
    };

    final submissionId = await submissionDao.createPendingSubmission(
      activityId: activityId,
      studentId: studentId,
      remoteActivityId: remoteActivityId,
      submission: submissionPayload,
    );

    try {
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

      final syncStatus = SubmissionSyncStatus.synced;

      return {
        'submission_id': submissionId,
        'sync_status': syncStatus.databaseValue,
        'sync_status_label': syncStatus.label,
        'remote_activity_id': remoteActivityId,
        'score': score,
        'feedback': feedbackText,
        'metrics': metrics,
      };
    } catch (error) {
      await submissionDao.markAsFailed(
        submissionId: submissionId,
        error: error.toString(),
      );

      rethrow;
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