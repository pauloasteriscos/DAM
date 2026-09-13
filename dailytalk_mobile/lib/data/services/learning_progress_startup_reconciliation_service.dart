import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:sqflite/sqflite.dart';

import '../../domain/learning/learning_domain.dart';
import '../../state/app_event_notifier.dart';
import '../../state/app_session_controller.dart';
import '../api/dailytalk_api_service.dart';
import '../commands/sync_command.dart';
import '../content/learning_content_bootstrap.dart';
import '../dao/sync_queue_dao.dart';
import '../database/app_database.dart';
import '../repositories/learning_progress_repository.dart';

/// Conteúdo oficial necessário para reconciliar o progresso.
///
/// A sincronização nunca transporta estados pedagógicos nem competências.
/// Esses valores são novamente derivados deste percurso oficial local.
final class LearningProgressStartupContext {
  const LearningProgressStartupContext({
    required this.learningPath,
    required this.packageVersion,
  });

  final LearningPath learningPath;
  final int packageVersion;
}

typedef LearningProgressContextLoader =
    Future<LearningProgressStartupContext> Function();

typedef LearningProgressDatabaseLoader = Future<Database> Function();

typedef LearningProgressApiFactory = DailyTalkApiService Function();

/// Coordena a reconciliação automática do progresso autenticado.
///
/// Propriedades da Fase 3.5C:
///
/// - não bloqueia o primeiro frame;
/// - não depende de um connectivity flag;
/// - uma conta autenticada faz pull mesmo com outbox vazia;
/// - falha de rede não elimina progresso nem sessão;
/// - regressar a foreground volta a tentar;
/// - execuções concorrentes da mesma sessão são coalescidas;
/// - após a tentativa, a UI é avisada para reler SQLite.
final class LearningProgressStartupReconciliationService {
  LearningProgressStartupReconciliationService({
    required Listenable sessionListenable,
    required bool Function() isAuthenticated,
    required Future<String?> Function() resolveAccountId,
    required LearningProgressContextLoader loadContext,
    required LearningProgressDatabaseLoader loadDatabase,
    required LearningProgressApiFactory createApiService,
    required VoidCallback notifySyncCompleted,
    bool observeLifecycle = false,
  }) : _sessionListenable = sessionListenable,
       _isAuthenticated = isAuthenticated,
       _resolveAccountId = resolveAccountId,
       _loadContext = loadContext,
       _loadDatabase = loadDatabase,
       _createApiService = createApiService,
       _notifySyncCompleted = notifySyncCompleted,
       _observeLifecycle = observeLifecycle;

  factory LearningProgressStartupReconciliationService.production() {
    final session = AppSessionController.instance;

    return LearningProgressStartupReconciliationService(
      sessionListenable: session,
      isAuthenticated: () => session.isAuthenticated,
      resolveAccountId: () async {
        var user = session.currentUser;

        // Alguns fluxos de login históricos apenas mudam o estado da
        // sessão. Nesse caso resolvemos o utilizador silenciosamente.
        if (user == null) {
          await session.refreshCurrentUser();
          user = session.currentUser;
        }

        return user?.id;
      },
      loadContext: () async {
        final active = await LearningContentBootstrapService.instance
            .ensureLocalBaseline();

        return LearningProgressStartupContext(
          learningPath: active.path,
          packageVersion: active.package.packageVersion,
        );
      },
      loadDatabase: () => AppDatabase.instance.database,
      createApiService: () => DailyTalkApiService(),
      notifySyncCompleted: AppEventNotifier.instance.notifySyncCompleted,
      observeLifecycle: true,
    );
  }

  static final LearningProgressStartupReconciliationService instance =
      LearningProgressStartupReconciliationService.production();

  final Listenable _sessionListenable;
  final bool Function() _isAuthenticated;
  final Future<String?> Function() _resolveAccountId;

  final LearningProgressContextLoader _loadContext;
  final LearningProgressDatabaseLoader _loadDatabase;
  final LearningProgressApiFactory _createApiService;

  final VoidCallback _notifySyncCompleted;
  final bool _observeLifecycle;

  final Map<String, Future<SyncCommandResult>> _activeByAccount =
      <String, Future<SyncCommandResult>>{};

  bool _started = false;
  Future<void>? _activeSessionExecution;
  AppLifecycleListener? _lifecycleListener;

  /// Começa a observar a sessão.
  ///
  /// Esta chamada é síncrona e não espera rede.
  void start() {
    if (_started) {
      return;
    }

    _started = true;

    _sessionListenable.addListener(_onSessionChanged);

    if (_observeLifecycle) {
      _lifecycleListener = AppLifecycleListener(onResume: retryIfAuthenticated);
    }

    // Pode acontecer de a sessão já ter sido resolvida antes de este
    // observador ser instalado.
    retryIfAuthenticated();
  }

  /// Remove os observers.
  ///
  /// Em produção o singleton vive durante todo o processo; este método é
  /// útil sobretudo para testes e hot-reload controlado.
  void stop() {
    if (!_started) {
      return;
    }

    _started = false;

    _sessionListenable.removeListener(_onSessionChanged);

    _lifecycleListener?.dispose();
    _lifecycleListener = null;
  }

  void _onSessionChanged() {
    retryIfAuthenticated();
  }

  /// Agenda uma tentativa sem bloquear o chamador.
  ///
  /// Não existe consulta prévia de conectividade: o próprio Secure Sync
  /// determina se a rede está disponível.
  void retryIfAuthenticated() {
    if (!_started || !_isAuthenticated()) {
      return;
    }

    if (_activeSessionExecution != null) {
      return;
    }

    final execution = _reconcileAuthenticatedSession();

    _activeSessionExecution = execution;

    unawaited(_observeSessionExecution(execution));
  }

  Future<void> _observeSessionExecution(Future<void> execution) async {
    try {
      await execution;
    } catch (error, stackTrace) {
      //@@DEBUG: Diagnóstico da reconciliação automática.
      // Manter comentado em produção; reativar temporariamente se
      // for necessário investigar falhas de startup/resume.
      //
      // debugPrint(
      //   'Reconciliação automática de progresso falhou: $error',
      // );
      // debugPrintStack(stackTrace: stackTrace);

      debugPrint('Reconciliação de progresso adiada: $error');

      if (kDebugMode) {
        debugPrintStack(stackTrace: stackTrace);
      }
    } finally {
      if (identical(_activeSessionExecution, execution)) {
        _activeSessionExecution = null;
      }
    }
  }

  Future<void> _reconcileAuthenticatedSession() async {
    if (!_isAuthenticated()) {
      return;
    }

    final accountId = (await _resolveAccountId())?.trim();

    if (accountId == null || accountId.isEmpty || !_isAuthenticated()) {
      return;
    }

    await reconcileAccount(accountId);
  }

  /// Executa a reconciliação para uma conta conhecida.
  ///
  /// Este método também é o seam utilizado pelos testes de integração local.
  Future<SyncCommandResult> reconcileAccount(String accountId) {
    final normalizedAccountId = accountId.trim();

    if (normalizedAccountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'não pode estar vazio');
    }

    final active = _activeByAccount[normalizedAccountId];

    if (active != null) {
      return active;
    }

    final execution = _reconcileAccountOnce(normalizedAccountId);

    _activeByAccount[normalizedAccountId] = execution;

    return execution.whenComplete(() {
      if (identical(_activeByAccount[normalizedAccountId], execution)) {
        _activeByAccount.remove(normalizedAccountId);
      }
    });
  }

  Future<SyncCommandResult> _reconcileAccountOnce(String accountId) async {
    final context = await _loadContext();
    final db = await _loadDatabase();
    final repository = LearningProgressRepository(db);

    // O mapa pedagógico deve existir antes de qualquer tentativa de rede.
    //
    // Isto cobre:
    // - conta nova sem factos;
    // - atualização/fallback do pacote;
    // - execução completamente offline.
    //
    // A operação é idempotente e não cria itens na outbox.
    await repository.ensureProjection(
      accountId: accountId,
      learningPath: context.learningPath,
      activePackageVersion: context.packageVersion,
    );

    try {
      return await ReconcileLearningProgressCommand(
        apiService: _createApiService(),
        syncQueueDao: SyncQueueDao(db),
        repository: repository,
        accountId: accountId,
        learningPath: context.learningPath,
        activePackageVersion: context.packageVersion,
      ).execute();
    } finally {
      // Mesmo que a rede falhe, a projeção local pode ter sido criada ou
      // reparada. Se a sync avançou parcialmente, também pode ter aplicado
      // factos remotos válidos. Em ambos os casos a UI deve reler SQLite.
      _notifySyncCompleted();
    }
  }

  @visibleForTesting
  Future<void> waitForIdle() async {
    final active = _activeSessionExecution;

    if (active == null) {
      return;
    }

    try {
      await active;
    } catch (_) {
      // A execução observada já possui tratamento de erro próprio.
    }
  }
}
