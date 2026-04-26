import 'dart:convert';

import '../database/app_database.dart';
import 'activity_dao.dart';
import 'activity_params_dao.dart';
import 'submission_dao.dart';
import 'sync_queue_dao.dart';

/// Exemplo de utilização da base local.
///
/// Este ficheiro não é obrigatório na app.
/// Serve apenas como guia inicial para a equipa de desenvolvimento.
Future<void> exampleDatabaseUsage() async {
  final db = await AppDatabase.instance.database;

  final activityDao = ActivityDao(db);
  final paramsDao = ActivityParamsDao(db);
  final submissionDao = SubmissionDao(db);
  final syncQueueDao = SyncQueueDao(db);

  final now = DateTime.now().toIso8601String();

  // 1. Criar ou atualizar uma atividade.
  final activityId = await activityDao.upsertActivity({
    'remote_activity_id': 'TEST-QUIZ-001',
    'title': 'Diálogo em sala de aula',
    'type': 'quiz',
    'scenario': 'sala de aula',
    'language_code': 'pt-PT',
    'difficulty': 'iniciante',
    'source': 'mock',
    'is_cached': 1,
    'is_active': 1,
    'created_at': now,
    'updated_at': now,
  });

  // 2. Guardar parâmetros vindos de GET /json-params.
  await paramsDao.replaceParamsForActivity(
    activityId: activityId,
    params: [
      {'name': 'scenario', 'type': 'text/plain', 'value': 'sala de aula'},
      {'name': 'language', 'type': 'text/plain', 'value': 'pt-PT'},
      {'name': 'difficulty', 'type': 'text/plain', 'value': 'iniciante'},
    ],
  );

  // 3. Guardar a URL recebida de GET /deploy.
  await activityDao.updateDeployUrl(
    activityId: activityId,
    activityUrl: 'https://dailytalk.pt/activity/quiz/TEST-QUIZ-001',
  );

  // 4. Criar submissão pendente para POST /submit.
  final submissionPayload = {
    'answers': [
      {'questionId': 'q1', 'answer': 'Bom dia'},
      {'questionId': 'q2', 'answer': 'Obrigado'},
    ],
  };

  final submissionId = await submissionDao.createPendingSubmission(
    activityId: activityId,
    remoteActivityId: 'TEST-QUIZ-001',
    submission: submissionPayload,
  );

  // 5. Adicionar à fila de sincronização.
  await syncQueueDao.enqueue(
    entityType: 'submission',
    entityId: submissionId,
    operation: 'upload',
    endpoint: '/submit',
    method: 'POST',
    payloadJson: jsonEncode({
      'activityID': 'TEST-QUIZ-001',
      'submission': submissionPayload,
    }),
  );
}
