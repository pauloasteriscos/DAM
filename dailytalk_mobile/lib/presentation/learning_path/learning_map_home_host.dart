import 'dart:async';

import 'package:flutter/material.dart';

import '../../data/content/learning_content_bootstrap.dart';
import '../../data/content/learning_content_catalog.dart';
import '../../data/content/official_learning_path_resolver.dart';
import '../../data/database/app_database.dart';
import '../../data/repositories/learning_progress_read_repository.dart';
import '../../data/repositories/learning_progress_repository.dart';
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
    required this.learningLanguageCode,
    required this.fallback,
    this.footer,
    super.key,
  });

  final String accountId;
  final String locale;
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

  bool _loading = true;
  bool _failed = false;

  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _startLoad();
  }

  @override
  void didUpdateWidget(LearningMapHomeHost oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.accountId != widget.accountId ||
        oldWidget.locale != widget.locale ||
        oldWidget.learningLanguageCode != widget.learningLanguageCode) {
      _controller?.dispose();
      _controller = null;

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

  Future<void> _load(int generation) async {
    LearningMapWindowController? createdController;

    try {
      final accountId = widget.accountId.trim();
      final locale = widget.locale.trim();
      final learningLanguageCode = widget.learningLanguageCode.trim();

      if (accountId.isEmpty) {
        throw StateError('Learning Map requires a non-empty account id.');
      }

      if (locale.isEmpty) {
        throw StateError('Learning Map requires a non-empty locale.');
      }

      if (learningLanguageCode.isEmpty) {
        throw StateError(
          'Learning Map requires a non-empty learning language code.',
        );
      }

      final descriptor = OfficialLearningPathResolver.resolve(
        learningLanguageCode,
      );
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
      );

      createdController = LearningMapWindowController(session: windowSession);

      if (!mounted || generation != _generation) {
        createdController.dispose();
        return;
      }

      setState(() {
        _controller = createdController;
        _loading = false;
        _failed = false;
      });
    } catch (error, stackTrace) {
      createdController?.dispose();

      debugPrint('Learning Map Home preparation failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted || generation != _generation) {
        return;
      }

      setState(() {
        _controller = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  @override
  void dispose() {
    _generation++;
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.fallback;
    }

    final controller = _controller;

    if (_loading || controller == null) {
      return const ColoredBox(
        color: Color(0xFF061823),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return LearningMapWindowViewport(
      controller: controller,
      footer: widget.footer,
    );
  }
}
