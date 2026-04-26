import '../api/dailytalk_api_service.dart';
import '../dao/activity_dao.dart';

/// Repository responsável por coordenar API + SQLite.
///
/// A interface chama o Repository.
/// O Repository decide quando chamar API e quando guardar localmente.
class ActivityRepository {
  ActivityRepository({
    required this.apiService,
    required this.activityDao,
  });

  final DailyTalkApiService apiService;
  final ActivityDao activityDao;

  /// Cria uma atividade localmente, chama o deploy e guarda a URL recebida.
  Future<String> createAndDeployActivity({
    required String remoteActivityId,
    required String title,
    required String type,
    required String scenario,
    required String languageCode,
    required String difficulty,
  }) async {
    final now = DateTime.now().toIso8601String();

    final localActivityId = await activityDao.upsertActivity({
      'remote_activity_id': remoteActivityId,
      'title': title,
      'type': type,
      'scenario': scenario,
      'language_code': languageCode,
      'difficulty': difficulty,
      'source': 'remote',
      'is_cached': 1,
      'is_active': 1,
      'created_at': now,
      'updated_at': now,
    });

    final activityUrl = await apiService.deployActivity(
      activityId: remoteActivityId,
      type: type,
    );

    await activityDao.updateDeployUrl(
      activityId: localActivityId,
      activityUrl: activityUrl,
    );

    await activityDao.markOpened(localActivityId);

    return activityUrl;
  }
}