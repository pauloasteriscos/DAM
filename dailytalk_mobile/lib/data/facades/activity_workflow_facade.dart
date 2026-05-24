import '../../models/app_status.dart';
import '../../models/user_profile.dart';
import '../../state/app_event_notifier.dart';
import '../../strategies/activity_strategy.dart';
import '../api/dailytalk_api_service.dart';
import '../commands/sync_command.dart';
import '../dao/activity_dao.dart';
import '../dao/pedagogical_analytics_dao.dart';
import '../dao/submission_dao.dart';
import '../database/app_database.dart';
import '../repositories/activity_repository.dart';
import '../repositories/submission_repository.dart';

/// Resultado do fluxo de criação/deploy de uma atividade.
///
/// Este objeto mantém juntos os dados necessários para abrir
/// a atividade após o deploy.
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
/// escondendo detalhes internos como:
/// - abertura da base SQLite;
/// - criação dos DAOs;
/// - criação dos repositories;
/// - chamada à API;
/// - gravação local;
/// - submissão de respostas;
/// - carregamento de resultados;
/// - sincronização de submissões pendentes;
/// - registo de analytics pedagógicos.
class ActivityWorkflowFacade {
  ActivityWorkflowFacade._({
    required this.activityDao,
    required this.submissionDao,
    required this.pedagogicalAnalyticsDao,
    required this.activityRepository,
    required this.submissionRepository,
  });

  final ActivityDao activityDao;
  final SubmissionDao submissionDao;
  final PedagogicalAnalyticsDao pedagogicalAnalyticsDao;
  final ActivityRepository activityRepository;
  final SubmissionRepository submissionRepository;

  /// Cria uma instância da Facade com todas as dependências necessárias.
  static Future<ActivityWorkflowFacade> create() async {
    final db = await AppDatabase.instance.database;

    final apiService = DailyTalkApiService();
    final activityDao = ActivityDao(db);
    final submissionDao = SubmissionDao(db);
    final pedagogicalAnalyticsDao = PedagogicalAnalyticsDao(db);

    return ActivityWorkflowFacade._(
      activityDao: activityDao,
      submissionDao: submissionDao,
      pedagogicalAnalyticsDao: pedagogicalAnalyticsDao,
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
    String? remoteActivityIdOverride,
    String? titleOverride,
    String? scenarioOverride,
    String? difficultyOverride,
  }) async {
    final remoteActivityId =
        remoteActivityIdOverride ?? strategy.predefinedRemoteActivityId;

    return activityDao.upsertActivity({
      'remote_activity_id': remoteActivityId,
      'title': titleOverride ?? 'Prática: ${strategy.label}',
      'type': strategy.type,
      'scenario': scenarioOverride ?? strategy.defaultScenario,
      'language_code': targetLanguageCode,
      'difficulty': difficultyOverride ?? strategy.defaultDifficulty,
      'source': ActivitySourceType.predefined.databaseValue,
      'is_cached': 1,
      'is_active': 1,
    });
  }

  /// Submete uma resposta de uma atividade predefinida.
  ///
  /// Usado pela aba "Praticar".
  /// Também pode registar analytics pedagógicos locais quando recebe
  /// o perfil do utilizador e o cenário da atividade.
  Future<Map<String, dynamic>> submitPracticeAnswer({
    required ActivityStrategy strategy,
    required String answerText,
    String nativeLanguageCode = 'pt-PT',
    String targetLanguageCode = 'it-IT',
    String? remoteActivityIdOverride,
    String? titleOverride,
    String? scenarioOverride,
    String? difficultyOverride,
    UserProfileType? userProfile,
  }) async {
    final remoteActivityId =
        remoteActivityIdOverride ?? strategy.predefinedRemoteActivityId;

    final localActivityId = await ensurePredefinedActivity(
      strategy: strategy,
      targetLanguageCode: targetLanguageCode,
      remoteActivityIdOverride: remoteActivityId,
      titleOverride: titleOverride,
      scenarioOverride: scenarioOverride,
      difficultyOverride: difficultyOverride,
    );

    final result = await submissionRepository.submitAnswer(
      activityId: localActivityId,
      remoteActivityId: remoteActivityId,
      activityType: strategy.type,
      answerText: answerText,
      nativeLanguageCode: nativeLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );

    if (userProfile != null && scenarioOverride != null) {
      await pedagogicalAnalyticsDao.recordPracticeAttempt(
        profile: userProfile,
        scenario: scenarioOverride,
        activityType: strategy.type,
        score: _readScore(result['score']),
        feedbackText: result['feedback']?.toString(),
      );
    }

    AppEventNotifier.instance.notifyResultsChanged();

    return result;
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

    final result = await submissionRepository.submitAnswer(
      activityId: localActivityId,
      remoteActivityId: remoteActivityId,
      activityType: activityType,
      answerText: answerText,
      nativeLanguageCode: nativeLanguageCode,
      targetLanguageCode: targetLanguageCode,
    );

    AppEventNotifier.instance.notifyResultsChanged();

    return result;
  }

  /// Carrega resultados recentes para o ecrã "Meus Resultados".
  Future<List<Map<String, Object?>>> loadRecentResults({int limit = 20}) {
    return submissionDao.getRecentResults(limit: limit);
  }

  /// Carrega analytics pedagógicos locais.
  ///
  /// Estes dados são agregados por perfil, cenário e tipo de atividade.
  Future<List<Map<String, Object?>>> loadPedagogicalAnalytics({
    int limit = 30,
  }) {
    return pedagogicalAnalyticsDao.getPedagogicalAnalytics(limit: limit);
  }

  /// Sincroniza submissões pendentes ou com falha.
  ///
  /// Usa o padrão Command para encapsular cada operação de sincronização.
  Future<SyncCommandResult> syncPendingSubmissions() async {
    final command = SyncPendingSubmissionsCommand(
      apiService: DailyTalkApiService(),
      submissionDao: submissionDao,
    );

    final result = await command.execute();

    AppEventNotifier.instance.notifySyncCompleted();

    if (result.syncedCount > 0) {
      AppEventNotifier.instance.notifyResultsChanged();
    }

    return result;
  }

  /// Lê a pontuação de forma segura a partir do resultado.
  double? _readScore(Object? value) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }
}
