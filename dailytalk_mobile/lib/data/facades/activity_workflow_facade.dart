import '../../models/app_status.dart';
import '../../strategies/activity_strategy.dart';
import '../api/dailytalk_api_service.dart';
import '../dao/activity_dao.dart';
import '../dao/submission_dao.dart';
import '../database/app_database.dart';
import '../repositories/activity_repository.dart';
import '../repositories/submission_repository.dart';

/// Resultado do fluxo de criação/deploy de uma atividade.
///
/// Este objeto evita devolver apenas uma String solta,
/// mantendo juntos os dados necessários para abrir a atividade.
class ActivityLaunchResult {
  const ActivityLaunchResult({
    required this.activityUrl,
    required this.remoteActivityId,
    required this.activityType,
  });

  final String activityUrl;
  final String remoteActivityId;
  final String activityType;
}

/// Facade do fluxo principal de atividades.
///
/// Esta classe oferece uma interface de alto nível para a UI,
/// escondendo os detalhes de:
/// - abertura da base SQLite;
/// - criação dos DAOs;
/// - criação dos repositories;
/// - chamada à API;
/// - gravação local;
/// - submissão de respostas;
/// - carregamento de resultados.
class ActivityWorkflowFacade {
  ActivityWorkflowFacade._({
    required this.activityDao,
    required this.submissionDao,
    required this.activityRepository,
    required this.submissionRepository,
  });

  final ActivityDao activityDao;
  final SubmissionDao submissionDao;
  final ActivityRepository activityRepository;
  final SubmissionRepository submissionRepository;

  /// Cria uma instância da facade com todas as dependências necessárias.
  static Future<ActivityWorkflowFacade> create() async {
    final db = await AppDatabase.instance.database;

    final apiService = DailyTalkApiService();
    final activityDao = ActivityDao(db);
    final submissionDao = SubmissionDao(db);

    return ActivityWorkflowFacade._(
      activityDao: activityDao,
      submissionDao: submissionDao,
      activityRepository: ActivityRepository(
        apiService: apiService,
        activityDao: activityDao,
      ),
      submissionRepository: SubmissionRepository(
        apiService: apiService,
        submissionDao: submissionDao,
      ),
    );
  }

  /// Cria uma atividade proposta pelo utilizador e executa o deploy.
  ///
  /// Usado no fluxo "Criar atividade".
  Future<ActivityLaunchResult> createAndDeployActivity({
    required String title,
    required String type,
    required String scenario,
    required String languageCode,
    required String difficulty,
  }) async {
    final remoteActivityId = 'DT-${DateTime.now().millisecondsSinceEpoch}';

    final activityUrl = await activityRepository.createAndDeployActivity(
      remoteActivityId: remoteActivityId,
      title: title,
      type: type,
      scenario: scenario,
      languageCode: languageCode,
      difficulty: difficulty,
    );

    return ActivityLaunchResult(
      activityUrl: activityUrl,
      remoteActivityId: remoteActivityId,
      activityType: type,
    );
  }

  /// Garante que uma atividade predefinida existe na base local.
  ///
  /// Usado pela aba "Praticar".
  Future<int> ensurePredefinedActivity({
    required ActivityStrategy strategy,
    String targetLanguageCode = 'it-IT',
  }) async {
    return activityDao.upsertActivity({
      'remote_activity_id': strategy.predefinedRemoteActivityId,
      'title': 'Prática: ${strategy.label}',
      'type': strategy.type,
      'scenario': strategy.defaultScenario,
      'language_code': targetLanguageCode,
      'difficulty': strategy.defaultDifficulty,
      'source': ActivitySourceType.predefined.databaseValue,
      'is_cached': 1,
      'is_active': 1,
    });
  }

  /// Submete uma resposta de uma atividade predefinida.
  ///
  /// Usado pela aba "Praticar".
  Future<Map<String, dynamic>> submitPracticeAnswer({
    required ActivityStrategy strategy,
    required String answerText,
    String nativeLanguageCode = 'pt-PT',
    String targetLanguageCode = 'it-IT',
  }) async {
    final localActivityId = await ensurePredefinedActivity(
      strategy: strategy,
      targetLanguageCode: targetLanguageCode,
    );

    return submissionRepository.submitAnswer(
      activityId: localActivityId,
      remoteActivityId: strategy.predefinedRemoteActivityId,
      activityType: strategy.type,
      answerText: answerText,
      nativeLanguageCode: nativeLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );
  }

  /// Submete uma resposta de uma atividade criada/iniciada pelo fluxo de deploy.
  ///
  /// Usado por ActivityDisplayPage.
  Future<Map<String, dynamic>> submitAnswerForRemoteActivity({
    required String remoteActivityId,
    required String activityType,
    required String answerText,
    String nativeLanguageCode = 'pt-PT',
    String targetLanguageCode = 'it-IT',
  }) async {
    final activity = await activityDao.getByRemoteActivityId(remoteActivityId);

    if (activity == null) {
      throw Exception('Atividade local não encontrada.');
    }

    final localActivityId = activity['id'] as int;

    return submissionRepository.submitAnswer(
      activityId: localActivityId,
      remoteActivityId: remoteActivityId,
      activityType: activityType,
      answerText: answerText,
      nativeLanguageCode: nativeLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );
  }

  /// Carrega resultados recentes para o ecrã "Meus Resultados".
  Future<List<Map<String, Object?>>> loadRecentResults({
    int limit = 20,
  }) {
    return submissionDao.getRecentResults(limit: limit);
  }
}