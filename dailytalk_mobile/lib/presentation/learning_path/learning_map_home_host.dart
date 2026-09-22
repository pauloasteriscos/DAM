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
import 'learning_map_window_controller.dart';
import 'learning_map_window_session.dart';

/// Fail-closed decision used by the application shell.
///
/// The dynamic Learning Map is never selected without:
/// - an effective feature flag;
/// - an authenticated session;
/// - a stable non-empty account identifier.
bool shouldUseLearningMapHome({
  required bool featureEnabled,
  required bool isAuthenticated,
  required String? accountId,
}) {
  return featureEnabled &&
      isAuthenticated &&
      accountId != null &&
      accountId.trim().isNotEmpty;
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
    required this.fallback,
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

    if (oldWidget.accountId != widget.accountId ||
        oldWidget.locale != widget.locale ||
        oldWidget.appLanguageCode != widget.appLanguageCode ||
        oldWidget.learningLanguageCode != widget.learningLanguageCode) {
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
    final generation = ++_generation;
    unawaited(_load(generation));
  }

  void _handleAppEvent() {
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
            onCompletionPersisted: LearningProgressStartupReconciliationService
                .instance
                .retryIfAuthenticated,
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

      _scheduleSyncRefresh();
    } catch (error, stackTrace) {
      createdController?.dispose();

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

  @override
  void dispose() {
    _generation++;

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
      footer: widget.footer,
    );
  }
}
