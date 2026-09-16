import 'dart:async';

import 'package:flutter/material.dart';

import 'learning_map_activity_navigation.dart';
import 'learning_map_mission_flow.dart';
import 'learning_map_window_segment_controls.dart';
import 'learning_map_view.dart';
import 'learning_map_view_model.dart';
import 'learning_map_window_composer.dart';
import 'learning_map_window_session.dart';

/// Estado de apresentação do percurso segmentado.
///
/// O controller não executa regras pedagógicas. A verdade do percurso
/// continua a vir de [LearningMapWindowSession].
/// Result of one window-aware activity cycle.
///
/// The MissionFlow local nextMission is deliberately not exposed as global
/// authority. After a real route return the controller reloads the current
/// segment and then resolves the global recommendation through the windowed
/// catalog index.
final class LearningMapWindowActivityFlowResult {
  const LearningMapWindowActivityFlowResult({
    required this.navigationOutcome,
    required this.refreshedAfterReturn,
    this.focusedGlobalRecommendation,
  });

  final LearningMapActivityNavigationOutcome navigationOutcome;
  final bool refreshedAfterReturn;
  final LearningMapElementViewModel? focusedGlobalRecommendation;

  bool get openedAndRefreshed =>
      navigationOutcome == LearningMapActivityNavigationOutcome.opened &&
      refreshedAfterReturn;
}

final class LearningMapWindowController extends ChangeNotifier {
  LearningMapWindowController({required LearningMapWindowSession session})
    : _session = session;

  final LearningMapWindowSession _session;

  LearningMapWindowComposition? _composition;
  Object? _error;
  StackTrace? _errorStackTrace;
  bool _isLoading = false;
  bool _isActivityFlowRunning = false;

  final Map<int, double> _scrollOffsets = <int, double>{};

  LearningMapWindowComposition? get composition => _composition;

  Object? get error => _error;

  StackTrace? get errorStackTrace => _errorStackTrace;

  bool get isLoading => _isLoading;

  bool get isActivityFlowRunning => _isActivityFlowRunning;

  bool get hasComposition => _composition != null;

  bool get hasError => _error != null;

  bool get canLoadPrevious =>
      !_isLoading &&
      !_isActivityFlowRunning &&
      (_composition?.window.hasPrevious ?? false);

  bool get canLoadNext =>
      !_isLoading &&
      !_isActivityFlowRunning &&
      (_composition?.window.hasNext ?? false);

  double get currentScrollOffset {
    final current = _composition;

    if (current == null) {
      return 0;
    }

    return scrollOffsetForWindow(current.window.startStageIndex);
  }

  double scrollOffsetForWindow(int startStageIndex) {
    return _scrollOffsets[startStageIndex] ?? 0;
  }

  void rememberCurrentScrollOffset(double offset) {
    final current = _composition;

    if (current == null || !offset.isFinite || offset < 0) {
      return;
    }

    _scrollOffsets[current.window.startStageIndex] = offset;
  }

  Future<bool> loadInitial() async {
    if (_composition != null) {
      return true;
    }

    return _perform(() => _session.loadInitial());
  }

  Future<bool> loadNext() async {
    if (_isActivityFlowRunning) {
      return false;
    }
    final current = _composition;

    if (current == null || !current.window.hasNext) {
      return false;
    }

    return _perform(() => _session.loadNext(current.window));
  }

  Future<bool> loadPrevious() async {
    if (_isActivityFlowRunning) {
      return false;
    }
    final current = _composition;

    if (current == null || !current.window.hasPrevious) {
      return false;
    }

    return _perform(() => _session.loadPrevious(current.window));
  }

  /// Loads the bounded segment containing [pathElementId].
  Future<bool> loadContainingPathElement(String pathElementId) async {
    final request = _session.requestContainingPathElement(pathElementId);

    if (request == null) {
      _error = StateError(
        'PathElementId outside active session: '
        '$pathElementId.',
      );
      _errorStackTrace = null;
      notifyListeners();
      return false;
    }

    final current = _composition?.window;

    if (current != null && current.startStageIndex == request.startStageIndex) {
      return true;
    }

    return _perform(() => _session.load(request));
  }

  /// Focuses the first globally recommended element this app can open.
  Future<LearningMapElementViewModel?> focusGlobalRecommendation() async {
    if (_isLoading) {
      return null;
    }

    if (_composition == null) {
      final loaded = await loadInitial();

      if (!loaded) {
        return null;
      }
    }

    final starting = _composition!;

    final startingRequest = LearningMapStageWindowRequest(
      startStageIndex: starting.window.startStageIndex,
      stageCount: starting.window.requestedStageCount,
    );

    final recommendations = List.of(
      starting.globalRecommendations,
      growable: false,
    );

    var changedSegment = false;

    for (final recommendation in recommendations) {
      var element = _findCurrentElement(recommendation.pathElementId);

      if (element == null) {
        final request = _session.requestContainingPathElement(
          recommendation.pathElementId,
        );

        if (request == null) {
          _error = StateError(
            'Global recommendation outside authored catalog: '
            '${recommendation.pathElementId}.',
          );
          _errorStackTrace = null;
          notifyListeners();
          return null;
        }

        final currentStart = _composition!.window.startStageIndex;

        if (currentStart != request.startStageIndex) {
          final loaded = await _perform(() => _session.load(request));

          if (!loaded) {
            return null;
          }

          changedSegment = true;
        }

        element = _findCurrentElement(recommendation.pathElementId);
      }

      if (element == null) {
        continue;
      }

      final navigation = LearningMapActivityNavigation.resolve(element);

      if (navigation.canNavigate) {
        return element;
      }
    }

    if (changedSegment &&
        _composition != null &&
        _composition!.window.startStageIndex !=
            startingRequest.startStageIndex) {
      await _perform(() => _session.load(startingRequest));
    }

    return null;
  }

  LearningMapElementViewModel? _findCurrentElement(String pathElementId) {
    final current = _composition;

    if (current == null) {
      return null;
    }

    for (final element in current.model.elements) {
      if (element.pathElementId == pathElementId) {
        return element;
      }
    }

    return null;
  }

  /// Opens one activity and reconciles the segmented map after route return.
  ///
  /// [LearningMapMissionFlow] remains the authority for the open/return/reload
  /// lifecycle. Its window-local nextMission is intentionally ignored here:
  /// global recommendation authority remains the persisted global list carried
  /// by the refreshed window composition.
  ///
  /// Returns null when another activity flow or a window load is already
  /// running, or when an unexpected open/reload error occurs.
  Future<LearningMapWindowActivityFlowResult?> openActivityAndRefresh(
    LearningMapElementViewModel element, {
    required LearningMapActivityOpenAction openActivity,
  }) async {
    if (_isActivityFlowRunning || _isLoading) {
      return null;
    }

    _isActivityFlowRunning = true;
    _error = null;
    _errorStackTrace = null;
    notifyListeners();

    try {
      final flow = LearningMapMissionFlow(
        openActivity: openActivity,
        reloadModel: () async {
          final reloaded = await reloadCurrent();

          final current = _composition;

          if (!reloaded || current == null) {
            throw StateError('Window reload failed after activity return.');
          }

          return current.model;
        },
      );

      final missionResult = await flow.openAndRefreshAfterReturn(element);

      if (!missionResult.returnedFromActivity) {
        return LearningMapWindowActivityFlowResult(
          navigationOutcome: missionResult.navigationOutcome,
          refreshedAfterReturn: false,
        );
      }

      // Deliberately ignore missionResult.nextMission here. It was calculated
      // only from the refreshed current-window ViewModel.
      final focusedGlobalRecommendation = await focusGlobalRecommendation();

      return LearningMapWindowActivityFlowResult(
        navigationOutcome: missionResult.navigationOutcome,
        refreshedAfterReturn: true,
        focusedGlobalRecommendation: focusedGlobalRecommendation,
      );
    } catch (error, stackTrace) {
      _error = error;
      _errorStackTrace = stackTrace;
      notifyListeners();
      return null;
    } finally {
      _isActivityFlowRunning = false;
      notifyListeners();
    }
  }

  /// Recarrega exatamente o segmento atual.
  ///
  /// É a operação destinada a reconciliar a UI com o estado local depois de
  /// uma atividade regressar. O catálogo authored continua congelado na
  /// sessão, enquanto projection/sync/recommendation são relidos.
  Future<bool> reloadCurrent() async {
    final current = _composition;

    if (current == null) {
      return loadInitial();
    }

    return _perform(
      () => _session.load(
        LearningMapStageWindowRequest(
          startStageIndex: current.window.startStageIndex,
          stageCount: current.window.requestedStageCount,
        ),
      ),
    );
  }

  Future<bool> _perform(
    Future<LearningMapWindowComposition?> Function() operation,
  ) async {
    if (_isLoading) {
      return false;
    }

    _isLoading = true;
    _error = null;
    _errorStackTrace = null;
    notifyListeners();

    try {
      final result = await operation();

      if (result == null) {
        return false;
      }

      _composition = result;
      return true;
    } catch (error, stackTrace) {
      // Fail-safe visual:
      // o último modelo válido permanece visível.
      _error = error;
      _errorStackTrace = stackTrace;
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

/// Adapter visual entre [LearningMapWindowController] e [LearningMapView].
///
/// O widget não conhece SQLite, catálogo, sync ou regras pedagógicas.
/// Limita-se a apresentar o segmento corrente e a preservar a posição de
/// scroll de cada segmento visitado.
final class LearningMapWindowViewport extends StatefulWidget {
  const LearningMapWindowViewport({
    required this.controller,
    this.onActivityTap,
    this.activityOpenAction,
    this.scrollController,
    this.footer,
    this.autoLoad = true,
    this.showSegmentControls = true,
    super.key,
  });

  final LearningMapWindowController controller;
  final LearningMapActivityTap? onActivityTap;

  /// Optional test/integration override for opening activities.
  /// When null, ActivityNavigation.open is used.
  final LearningMapActivityOpenAction? activityOpenAction;

  /// Pode ser injetado para integração/testes.
  ///
  /// Quando nulo, o viewport cria e gere o seu próprio controller de scroll.
  final ScrollController? scrollController;

  /// Conteúdo opcional anexado depois do mapa e da navegação de segmentos,
  /// dentro da mesma superfície de scroll.
  final Widget? footer;

  final bool autoLoad;
  final bool showSegmentControls;

  @override
  State<LearningMapWindowViewport> createState() =>
      _LearningMapWindowViewportState();
}

final class _LearningMapWindowViewportState
    extends State<LearningMapWindowViewport> {
  late ScrollController _scrollController;
  late bool _ownsScrollController;

  int? _activeWindowStart;

  Future<bool> Function()? _retryWindowAction;

  @override
  void initState() {
    super.initState();

    _installScrollController(widget.scrollController);

    widget.controller.addListener(_handleControllerChanged);

    _activeWindowStart = widget.controller.composition?.window.startStageIndex;

    if (widget.autoLoad &&
        !widget.controller.hasComposition &&
        !widget.controller.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        unawaited(widget.controller.loadInitial());
      });
    }
  }

  @override
  void didUpdateWidget(LearningMapWindowViewport oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_handleControllerChanged);

      widget.controller.addListener(_handleControllerChanged);

      _activeWindowStart =
          widget.controller.composition?.window.startStageIndex;

      if (widget.autoLoad &&
          !widget.controller.hasComposition &&
          !widget.controller.isLoading) {
        unawaited(widget.controller.loadInitial());
      }
    }

    if (oldWidget.scrollController != widget.scrollController) {
      _removeScrollController();
      _installScrollController(widget.scrollController);

      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _restoreCurrentScroll(),
      );
    }
  }

  void _installScrollController(ScrollController? supplied) {
    _ownsScrollController = supplied == null;

    _scrollController = supplied ?? ScrollController();

    _scrollController.addListener(_rememberScroll);
  }

  void _removeScrollController() {
    _scrollController.removeListener(_rememberScroll);

    if (_ownsScrollController) {
      _scrollController.dispose();
    }
  }

  void _rememberScroll() {
    if (!_scrollController.hasClients) {
      return;
    }

    widget.controller.rememberCurrentScrollOffset(_scrollController.offset);
  }

  void _handleControllerChanged() {
    final nextStart = widget.controller.composition?.window.startStageIndex;

    if (nextStart == null || nextStart == _activeWindowStart) {
      return;
    }

    _activeWindowStart = nextStart;

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _restoreCurrentScroll(),
    );
  }

  void _restoreCurrentScroll() {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final desired = widget.controller.currentScrollOffset;

    final maxExtent = _scrollController.position.maxScrollExtent;

    final target = desired.clamp(0.0, maxExtent).toDouble();

    if ((_scrollController.offset - target).abs() < 0.5) {
      return;
    }

    _scrollController.jumpTo(target);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerChanged);

    _removeScrollController();

    super.dispose();
  }

  Future<bool> _runWindowAction(Future<bool> Function() action) async {
    if (widget.controller.isLoading ||
        widget.controller.isActivityFlowRunning) {
      return false;
    }

    _retryWindowAction = action;

    final succeeded = await action();

    if (!mounted) {
      return succeeded;
    }

    setState(() {
      if (succeeded) {
        _retryWindowAction = null;
      }
    });

    return succeeded;
  }

  void _handlePreviousSegment() {
    unawaited(_runWindowAction(widget.controller.loadPrevious));
  }

  void _handleNextSegment() {
    unawaited(_runWindowAction(widget.controller.loadNext));
  }

  void _handleRetrySegment() {
    final action = _retryWindowAction;

    if (action == null) {
      return;
    }

    unawaited(_runWindowAction(action));
  }

  void _handleActivityTap(LearningMapElementViewModel element) {
    final customTap = widget.onActivityTap;

    // Preserve the pre-C.2B public override semantics.
    if (customTap != null) {
      customTap(element);
      return;
    }

    if (widget.controller.isLoading ||
        widget.controller.isActivityFlowRunning) {
      return;
    }

    final openAction =
        widget.activityOpenAction ??
        (target) => LearningMapActivityNavigation.open(context, target);

    unawaited(
      widget.controller.openActivityAndRefresh(
        element,
        openActivity: openAction,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, child) {
        final composition = widget.controller.composition;

        if (composition == null) {
          if (widget.controller.hasError) {
            return const Center(
              key: Key('learning-map-window-initial-error'),
              child: Icon(Icons.error_outline),
            );
          }

          return const Center(
            key: Key('learning-map-window-initial-loading'),
            child: CircularProgressIndicator(),
          );
        }

        final showSegmentControls =
            widget.showSegmentControls &&
            (composition.window.hasPrevious || composition.window.hasNext);

        final Widget? scrollFooter =
            showSegmentControls || widget.footer != null
            ? Column(
                key: const Key('learning-map-window-scroll-footer'),
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (showSegmentControls)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                      child: LearningMapWindowSegmentControls(
                        startStageIndex: composition.window.startStageIndex,
                        loadedStageCount: composition.window.loadedStageCount,
                        totalStageCount: composition.window.totalStageCount,
                        canPrevious: widget.controller.canLoadPrevious,
                        canNext: widget.controller.canLoadNext,
                        isBusy:
                            widget.controller.isLoading ||
                            widget.controller.isActivityFlowRunning,
                        hasError: widget.controller.hasError,
                        onPrevious: _handlePreviousSegment,
                        onNext: _handleNextSegment,
                        onRetry: _retryWindowAction == null
                            ? null
                            : _handleRetrySegment,
                      ),
                    ),
                  if (widget.footer != null) widget.footer!,
                ],
              )
            : null;

        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            LearningMapView(
              key: ValueKey<int>(composition.window.startStageIndex),
              model: composition.model,
              onActivityTap: _handleActivityTap,
              scrollController: _scrollController,
              footer: scrollFooter,
            ),
            if (widget.controller.isLoading)
              const Align(
                alignment: Alignment.topCenter,
                child: LinearProgressIndicator(
                  key: Key('learning-map-window-loading'),
                ),
              ),
          ],
        );
      },
    );
  }
}
