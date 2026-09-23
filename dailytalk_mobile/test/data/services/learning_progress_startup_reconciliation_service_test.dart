import 'dart:io';

import 'package:dailytalk_mobile/data/api/dailytalk_api_service.dart';
import 'package:dailytalk_mobile/data/database/app_database.dart';
import 'package:dailytalk_mobile/data/services/learning_progress_startup_reconciliation_service.dart';
import 'package:dailytalk_mobile/domain/learning/learning_domain.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _referencePath =
    '../dailytalk-api/docs/phase2/official_reference_journey_v3.json';

typedef _Handler =
    Future<Map<String, dynamic>> Function(
      List<Map<String, dynamic>> items, {
      required bool pullLearningProgress,
      String? learningProgressCursor,
      String? learningProgressPathId,
      required int learningProgressLimit,
    });

final class _FakeApiService extends DailyTalkApiService {
  _FakeApiService(this.handler);

  final _Handler handler;

  int calls = 0;

  @override
  Future<Map<String, dynamic>> secureSyncProgress(
    List<Map<String, dynamic>> items, {
    bool pullLearningProgress = false,
    String? learningProgressCursor,
    String? learningProgressPathId,
    int learningProgressLimit = 50,
  }) {
    calls += 1;

    if (pullLearningProgress &&
        (learningProgressPathId == null ||
            learningProgressPathId.trim().isEmpty)) {
      throw StateError('learningProgressPathId ausente no startup/resume.');
    }

    return handler(
      items,
      pullLearningProgress: pullLearningProgress,
      learningProgressCursor: learningProgressCursor,
      learningProgressPathId: learningProgressPathId,
      learningProgressLimit: learningProgressLimit,
    );
  }
}

LearningPath _loadJourney() {
  final source = File(_referencePath).readAsStringSync();

  return const LearningContentCodec().decodeString(source);
}

Map<String, dynamic> _remoteCompletion({
  required LearningPath path,
  required Activity activity,
  required String serverCompletionId,
  required String clientCompletionId,
}) {
  return <String, dynamic>{
    'type': 'activityCompletion',
    'completionId': serverCompletionId,
    'clientCompletionId': clientCompletionId,
    'learningPathId': path.id.value,
    'activityId': activity.id.value,
    'revisionId': activity.currentRevisionId.value,
    'packageVersion': 3,
    'completedAt': '2026-09-13T10:00:00.000Z',
  };
}

Map<String, dynamic> _pullResponse(Map<String, dynamic> completion) {
  return <String, dynamic>{
    'results': const <Map<String, dynamic>>[],
    'pull': <String, dynamic>{
      'learningProgress': <String, dynamic>{
        'items': <Map<String, dynamic>>[completion],
        'nextCursor': completion['completionId'],
        'hasMore': false,
      },
    },
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  Database? db;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('dailytalk-phase35c-');
  });

  tearDown(() async {
    final current = db;

    if (current != null && current.isOpen) {
      await current.close();
    }

    db = null;

    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test(
    '3.5C — dispositivo B autenticado abre com outbox vazia e recebe progresso de A',
    () async {
      final journey = _loadJourney();
      final activity = journey.activities.first;

      db = await AppDatabase.instance.openDatabaseForTesting(
        p.join(tempDir.path, 'device-b-startup.db'),
      );

      final remote = _remoteCompletion(
        path: journey,
        activity: activity,
        serverCompletionId: 'server-device-a-0001',
        clientCompletionId: 'device-a-completion-0001',
      );

      final api = _FakeApiService((
        items, {
        required bool pullLearningProgress,
        String? learningProgressCursor,
        String? learningProgressPathId,
        required int learningProgressLimit,
      }) async {
        // B não possui absolutamente nada para enviar.
        expect(items, isEmpty);

        // Mesmo assim a entrada autenticada faz contacto remoto.
        expect(pullLearningProgress, isTrue);

        expect(learningProgressCursor, isNull);

        return _pullResponse(remote);
      });

      final sessionSignal = ChangeNotifier();
      var authenticated = false;
      var notifications = 0;

      final service = LearningProgressStartupReconciliationService(
        sessionListenable: sessionSignal,
        isAuthenticated: () => authenticated,
        resolveAccountId: () async => 'user-phase35c',
        loadContext: () async => LearningProgressStartupContext(
          learningPath: journey,
          packageVersion: 3,
        ),
        loadDatabase: () async => db!,
        createApiService: () => api,
        notifySyncCompleted: () => notifications += 1,
      );

      try {
        // O serviço inicia sem sessão e não faz rede.
        service.start();

        expect(api.calls, 0);

        // Simula checkStoredSession() a concluir com sessão autenticada.
        authenticated = true;
        sessionSignal.notifyListeners();

        await service.waitForIdle();

        expect(api.calls, 1);
        expect(notifications, 1);

        // Facto de A chegou ao SQLite de B.
        final completions = await db!.query('learning_progress_completions');

        expect(completions, hasLength(1));

        expect(
          completions.single['client_completion_id'],
          'device-a-completion-0001',
        );

        // A projeção é derivada localmente.
        final projection = await db!.query(
          'learning_progress_projection',
          where:
              'account_id = ? '
              'AND learning_path_id = ? '
              'AND activity_id = ?',
          whereArgs: <Object?>[
            'user-phase35c',
            journey.id.value,
            activity.id.value,
          ],
        );

        expect(projection, hasLength(1));

        expect(projection.single['state'], 'completed');

        // O cursor também foi confirmado.
        final cursor = await db!.query(
          'learning_progress_sync_state',
          where:
              'account_id = ? '
              'AND learning_path_id = ?',
          whereArgs: <Object?>['user-phase35c', journey.id.value],
        );

        expect(cursor, hasLength(1));

        expect(cursor.single['cursor'], 'server-device-a-0001');

        // Receber da cloud não produz eco na outbox de B.
        final queue = await db!.query('sync_queue');

        expect(queue, isEmpty);
      } finally {
        service.stop();
        sessionSignal.dispose();
      }
    },
  );

  test(
    '3.5C — falha offline não bloqueia e uma tentativa posterior converge',
    () async {
      final journey = _loadJourney();
      final activity = journey.activities.first;

      db = await AppDatabase.instance.openDatabaseForTesting(
        p.join(tempDir.path, 'retry-after-offline.db'),
      );

      final remote = _remoteCompletion(
        path: journey,
        activity: activity,
        serverCompletionId: 'server-after-offline',
        clientCompletionId: 'remote-after-offline',
      );

      late final _FakeApiService api;

      api = _FakeApiService((
        items, {
        required bool pullLearningProgress,
        String? learningProgressCursor,
        String? learningProgressPathId,
        required int learningProgressLimit,
      }) async {
        expect(items, isEmpty);
        expect(pullLearningProgress, isTrue);

        if (api.calls == 1) {
          throw Exception('network offline');
        }

        return _pullResponse(remote);
      });

      final signal = ChangeNotifier();
      var authenticated = true;
      var notifications = 0;

      final service = LearningProgressStartupReconciliationService(
        sessionListenable: signal,
        isAuthenticated: () => authenticated,
        resolveAccountId: () async => 'user-retry',
        loadContext: () async => LearningProgressStartupContext(
          learningPath: journey,
          packageVersion: 3,
        ),
        loadDatabase: () async => db!,
        createApiService: () => api,
        notifySyncCompleted: () => notifications += 1,
      );

      try {
        // Primeira tentativa: sem rede.
        service.start();

        await service.waitForIdle();

        expect(api.calls, 1);
        expect(notifications, 1);

        // Network failed, but the local pedagogical projection
        // must already exist because ensureProjection runs first.
        final offlineProjection = await db!.query(
          'learning_progress_projection',
          where:
              'account_id = ? '
              'AND learning_path_id = ?',
          whereArgs: <Object?>['user-retry', journey.id.value],
        );

        final expectedProjectionCount = journey.journeys
            .expand((item) => item.stages)
            .expand((stage) => stage.elements)
            .length;

        expect(offlineProjection, hasLength(expectedProjectionCount));

        expect(
          offlineProjection.every((row) => row['package_version'] == 3),
          isTrue,
        );

        expect(
          offlineProjection.any(
            (row) =>
                row['activity_id'] != null &&
                row['state'] == LearningActivityState.available.name,
          ),
          isTrue,
        );

        // No local completion exists and no sync echo is produced.
        expect(await db!.query('sync_queue'), isEmpty);

        expect(await db!.query('learning_progress_completions'), isEmpty);

        // A app continua funcional e uma tentativa posterior
        // (em produção: resume da app ou nova notificação de sessão)
        // usa exatamente o mesmo fluxo.
        service.retryIfAuthenticated();

        await service.waitForIdle();

        expect(api.calls, 2);
        expect(notifications, 2);

        expect(await db!.query('learning_progress_completions'), hasLength(1));

        final cursor = await db!.query(
          'learning_progress_sync_state',
          where:
              'account_id = ? '
              'AND learning_path_id = ?',
          whereArgs: <Object?>['user-retry', journey.id.value],
        );

        expect(cursor.single['cursor'], 'server-after-offline');

        expect(await db!.query('sync_queue'), isEmpty);
      } finally {
        authenticated = false;
        service.stop();
        signal.dispose();
      }
    },
  );
}
