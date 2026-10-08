import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/content/learning_content_bootstrap.dart';
import '../../data/content/learning_content_catalog.dart';
import '../../data/content/official_learning_path_resolver.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/learning_progress_read_repository.dart';
import '../../data/repositories/learning_progress_repository.dart';
import '../../data/services/learning_progress_startup_reconciliation_service.dart';
import '../../state/app_event_notifier.dart';
import 'learning_activity_completion_coordinator.dart';
import 'learning_map_activity_navigation.dart';
import 'learning_map_window_controller.dart';
import 'learning_map_window_session.dart';

/// Fail-closed decision used by the application shell.
///
/// The dynamic Learning Map is selected only when:
/// - the feature flag is effective;
/// - the session is authenticated or explicitly in test mode;
/// - a stable local progress identifier exists.
///
/// Test mode uses an ephemeral local identifier and never enables Secure Sync.
bool shouldUseLearningMapHome({
  required bool featureEnabled,
  required bool isAuthenticated,
  required bool isTestMode,
  required String? accountId,
}) {
  return featureEnabled &&
      (isAuthenticated || isTestMode) &&
      accountId != null &&
      accountId.trim().isNotEmpty;
}

/// Ponte controlada entre a barra inferior e o Learning Map.
///
/// Quando o mapa está pronto, [LearningMapHomeHost] associa a ação que abre a
/// recomendação global atual. Fora desse estado, o controller falha fechado e
/// não tenta abrir atividades legadas por engano.
final class LearningMapPracticeController {
  Object? _owner;
  Future<bool> Function()? _openRecommendedActivity;

  bool get isReady => _openRecommendedActivity != null;

  Future<bool> openRecommendedActivity() async {
    final action = _openRecommendedActivity;

    if (action == null) {
      return false;
    }

    return action();
  }

  void attach(Object owner, Future<bool> Function() action) {
    _owner = owner;
    _openRecommendedActivity = action;
  }

  void detach(Object owner) {
    if (!identical(_owner, owner)) {
      return;
    }

    _owner = null;
    _openRecommendedActivity = null;
  }
}

/// Real application host for the bounded Learning Map.
///
/// This widget performs only local preparation:
/// 1. loads the active local catalog snapshot;
/// 2. ensures/repairs the local pedagogical projection;
/// 3. opens a bounded LearningMapWindowSession;
/// 4. delegates rendering to LearningMapWindowViewport.
///
/// Network access is not required for any of these steps.
///
/// If preparation fails, the previous Home supplied by [fallback] is shown.
/// This keeps the integration fail-closed while the feature flag is disabled
/// by default in production.
final class LearningMapHomeHost extends StatefulWidget {
  const LearningMapHomeHost({
    required this.accountId,
    required this.locale,
    required this.appLanguageCode,
    required this.learningLanguageCode,
    required this.syncEnabled,
    required this.fallback,
    this.practiceController,
    this.footer,
    super.key,
  });

  final String accountId;

  /// Locale TARGET usado para títulos e conteúdo a aprender.
  /// Deve corresponder ao learningLanguageCode.
  final String locale;

  /// Locale APP/SCAFFOLDING usado para instruções, dicas e explicações.
  final String appLanguageCode;

  final String learningLanguageCode;

  /// Apenas sessões autenticadas podem produzir/consumir Secure Sync.
  /// O modo teste usa o mesmo SQLite e Progression Engine com sync desligado.
  final bool syncEnabled;

  /// Permite que a ação "Praticar" do shell abra a recomendação global atual
  /// do mesmo Learning Map, em vez de cair nos exercícios legados.
  final LearningMapPracticeController? practiceController;

  final Widget fallback;

  /// Conteúdo pertencente à Home que deve surgir depois do percurso,
  /// dentro da mesma superfície de scroll.
  final Widget? footer;

  @override
  State<LearningMapHomeHost> createState() => _LearningMapHomeHostState();
}

final class _LearningMapHomeHostState extends State<LearningMapHomeHost> {
  LearningMapWindowController? _controller;
  LearningActivityCompletionCoordinator? _completionCoordinator;

  bool _loading = true;
  bool _failed = false;

  int _generation = 0;

  int _lastSyncVersion = 0;
  bool _syncRefreshQueued = false;
  Future<void>? _syncRefreshExecution;

  @override
  void initState() {
    super.initState();

    final appEvents = AppEventNotifier.instance;

    _lastSyncVersion = appEvents.syncVersion;
    appEvents.addListener(_handleAppEvent);

    _startLoad();
  }

  @override
  void didUpdateWidget(LearningMapHomeHost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!identical(oldWidget.practiceController, widget.practiceController)) {
      oldWidget.practiceController?.detach(this);

      if (_controller != null && _completionCoordinator != null && !_loading) {
        widget.practiceController?.attach(this, _openRecommendedActivity);
      }
    }

    if (oldWidget.accountId != widget.accountId ||
        oldWidget.locale != widget.locale ||
        oldWidget.appLanguageCode != widget.appLanguageCode ||
        oldWidget.learningLanguageCode != widget.learningLanguageCode ||
        oldWidget.syncEnabled != widget.syncEnabled) {
      _controller?.removeListener(_handleControllerChangedForSync);
      _controller?.dispose();
      _controller = null;
      _completionCoordinator = null;

      _syncRefreshQueued = false;
      _lastSyncVersion = AppEventNotifier.instance.syncVersion;

      setState(() {
        _loading = true;
        _failed = false;
      });

      _startLoad();
    }
  }

  void _startLoad() {
    widget.practiceController?.detach(this);

    final generation = ++_generation;
    unawaited(_load(generation));
  }

  void _handleAppEvent() {
    if (!widget.syncEnabled) {
      return;
    }

    final currentSyncVersion = AppEventNotifier.instance.syncVersion;

    if (currentSyncVersion == _lastSyncVersion) {
      return;
    }

    _lastSyncVersion = currentSyncVersion;
    _syncRefreshQueued = true;

    _scheduleSyncRefresh();
  }

  void _handleControllerChangedForSync() {
    final controller = _controller;

    if (!mounted ||
        !widget.syncEnabled ||
        !_syncRefreshQueued ||
        _syncRefreshExecution != null ||
        controller == null ||
        controller.isLoading ||
        controller.isActivityFlowRunning) {
      return;
    }

    _scheduleSyncRefresh();
  }

  void _scheduleSyncRefresh() {
    final controller = _controller;

    if (!mounted ||
        !widget.syncEnabled ||
        !_syncRefreshQueued ||
        _syncRefreshExecution != null ||
        controller == null ||
        controller.isLoading ||
        controller.isActivityFlowRunning) {
      return;
    }

    _syncRefreshQueued = false;

    final execution = _reloadSyncState(controller);

    _syncRefreshExecution = execution;

    unawaited(
      execution.whenComplete(() {
        if (!identical(_syncRefreshExecution, execution)) {
          return;
        }

        _syncRefreshExecution = null;

        if (mounted && _syncRefreshQueued) {
          _scheduleSyncRefresh();
        }
      }),
    );
  }

  Future<void> _reloadSyncState(LearningMapWindowController controller) async {
    final reloaded = await controller.reloadCurrent();

    if (!mounted || !identical(controller, _controller)) {
      return;
    }

    if (!reloaded &&
        (controller.isLoading || controller.isActivityFlowRunning)) {
      _syncRefreshQueued = true;
    }
  }

  Future<void> _load(int generation) async {
    LearningMapWindowController? createdController;

    try {
      final accountId = widget.accountId.trim();
      final locale = widget.locale.trim();
      final appLanguageCode = widget.appLanguageCode.trim();
      final learningLanguageCode = widget.learningLanguageCode.trim();

      if (accountId.isEmpty) {
        throw StateError('Learning Map requires a non-empty account id.');
      }

      if (locale.isEmpty) {
        throw StateError('Learning Map requires a non-empty locale.');
      }

      if (appLanguageCode.isEmpty) {
        throw StateError(
          'Learning Map requires a non-empty app language code.',
        );
      }

      if (learningLanguageCode.isEmpty) {
        throw StateError(
          'Learning Map requires a non-empty learning language code.',
        );
      }

      final descriptor = OfficialLearningPathResolver.resolve(
        learningLanguageCode,
      );

      if (locale.toLowerCase() !=
          descriptor.learningLanguageCode.toLowerCase()) {
        throw StateError(
          'Learning Map content locale $locale does not match '
          'learning language ${descriptor.learningLanguageCode}.',
        );
      }

      final database = await AppDatabase.instance.database;
      final catalogService = LearningContentCatalogService();

      final active = await LearningContentBootstrapService.instance
          .ensureLocalBaseline(learningLanguageCode: learningLanguageCode);

      if (active.path.id.value != descriptor.learningPathId) {
        throw StateError(
          'Active Learning Path ${active.path.id.value} does not match '
          '${descriptor.learningPathId}.',
        );
      }

      // Preparation/repair belongs before presentation.
      // It is idempotent and does not create outbox work by itself.
      final progressRepository = LearningProgressRepository(database);

      final completionCoordinator =
          LearningActivityCompletionCoordinator.fromRepository(
            accountId: accountId,
            learningPath: active.path,
            packageVersion: active.package.packageVersion,
            repository: progressRepository,
            syncEnabled: widget.syncEnabled,
            onCompletionPersisted: widget.syncEnabled
                ? LearningProgressStartupReconciliationService
                      .instance
                      .retryIfAuthenticated
                : null,
          );

      await progressRepository.ensureProjection(
        accountId: accountId,
        learningPath: active.path,
        activePackageVersion: active.package.packageVersion,
      );

      final coordinator = LearningMapWindowCoordinator.fromRepositories(
        catalogService: catalogService,
        progressRepository: LearningProgressReadRepository(database),
      );

      final windowSession = await coordinator.open(
        accountId: accountId,
        learningPathId: descriptor.learningPathId,
        locale: locale,
        scaffoldingLocale: appLanguageCode,
      );

      createdController = LearningMapWindowController(session: windowSession);

      if (!mounted || generation != _generation) {
        createdController.dispose();
        return;
      }

      createdController.addListener(_handleControllerChangedForSync);

      setState(() {
        _controller = createdController;
        _completionCoordinator = completionCoordinator;
        _loading = false;
        _failed = false;
      });

      widget.practiceController?.attach(this, _openRecommendedActivity);

      _scheduleSyncRefresh();
    } catch (error, stackTrace) {
      createdController?.dispose();
      widget.practiceController?.detach(this);

      debugPrint('Learning Map Home preparation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _controller = null;
        _completionCoordinator = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<bool> _openRecommendedActivity() async {
    final controller = _controller;
    final completionCoordinator = _completionCoordinator;

    if (!mounted ||
        controller == null ||
        completionCoordinator == null ||
        controller.isLoading ||
        controller.isActivityFlowRunning) {
      return false;
    }

    final target = await controller.focusGlobalRecommendation();

    if (!mounted || target == null) {
      return false;
    }

    final result = await controller.openActivityAndRefresh(
      target,
      openActivity: (element) => LearningMapActivityNavigation.open(
        context,
        element,
        completionActionFactory: completionCoordinator.actionFor,
      ),
    );

    return result?.navigationOutcome ==
        LearningMapActivityNavigationOutcome.opened;
  }

  @override
  void dispose() {
    _generation++;

    widget.practiceController?.detach(this);

    AppEventNotifier.instance.removeListener(_handleAppEvent);

    _controller?.removeListener(_handleControllerChangedForSync);
    _controller?.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.fallback;
    }

    final controller = _controller;
    final completionCoordinator = _completionCoordinator;

    if (_loading || controller == null || completionCoordinator == null) {
      return const ColoredBox(
        color: Color(0xFF061823),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return LearningMapWindowViewport(
      controller: controller,
      completionActionFactory: completionCoordinator.actionFor,
      showSyncStatus: widget.syncEnabled,
      footer: widget.footer,
    );
  }
}
