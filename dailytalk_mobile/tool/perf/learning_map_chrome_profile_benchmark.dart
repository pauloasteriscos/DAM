import 'package:dailytalk_mobile/data/repositories/learning_progress_read_repository.dart';
import 'package:dailytalk_mobile/domain/learning/domain_ids.dart';
import 'package:dailytalk_mobile/domain/learning/learning_enums.dart';
import 'package:dailytalk_mobile/domain/learning/learning_models.dart';
import 'package:dailytalk_mobile/domain/learning/progression_engine.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_read_service.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_controller.dart';
import 'package:dailytalk_mobile/presentation/learning_path/learning_map_window_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const stageCount = 1000;
  const windowSize = 4;

  final fixture = await _fixture(
    stageCount: stageCount,
    windowSize: windowSize,
  );

  runApp(_BenchmarkApp(fixture: fixture));
}

final class _BenchmarkApp extends StatelessWidget {
  const _BenchmarkApp({required this.fixture});

  final _Fixture fixture;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: _BenchmarkScreen(fixture: fixture),
    );
  }
}

final class _BenchmarkScreen extends StatefulWidget {
  const _BenchmarkScreen({required this.fixture});

  final _Fixture fixture;

  @override
  State<_BenchmarkScreen> createState() => _BenchmarkScreenState();
}

final class _BenchmarkScreenState extends State<_BenchmarkScreen> {
  final List<FrameTiming> _frameTimings = <FrameTiming>[];

  String _status = 'A preparar benchmark Chrome PROFILE...';

  String? _result;

  @override
  void initState() {
    super.initState();

    SchedulerBinding.instance.addTimingsCallback(_recordTimings);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _run();
    });
  }

  @override
  void dispose() {
    SchedulerBinding.instance.removeTimingsCallback(_recordTimings);

    widget.fixture.controller.dispose();

    super.dispose();
  }

  void _recordTimings(List<FrameTiming> timings) {
    _frameTimings.addAll(timings);
  }

  Future<void> _run() async {
    const repeatedCycles = 50;

    final controller = widget.fixture.controller;

    await _settleFrame();

    final initialWatch = Stopwatch()..start();

    final initialOk = await controller.loadInitial();

    await _settleFrame();
    initialWatch.stop();

    if (!initialOk) {
      _fail('initial load failed');
      return;
    }

    final directJumpWatch = Stopwatch()..start();

    final jumpOk = await controller.loadContainingPathElement('element-999');

    await _settleFrame();
    directJumpWatch.stop();

    if (!jumpOk) {
      _fail('direct jump failed');
      return;
    }

    if (controller.composition!.window.startStageIndex != 996) {
      _fail('unexpected direct-jump segment');
      return;
    }

    final transitionMicros = <int>[];

    for (var cycle = 0; cycle < repeatedCycles; cycle++) {
      final previousWatch = Stopwatch()..start();

      final previousOk = await controller.loadPrevious();

      await _settleFrame();
      previousWatch.stop();

      if (!previousOk) {
        _fail('loadPrevious failed at cycle $cycle');
        return;
      }

      transitionMicros.add(previousWatch.elapsedMicroseconds);

      final nextWatch = Stopwatch()..start();

      final nextOk = await controller.loadNext();

      await _settleFrame();
      nextWatch.stop();

      if (!nextOk) {
        _fail('loadNext failed at cycle $cycle');
        return;
      }

      transitionMicros.add(nextWatch.elapsedMicroseconds);
    }

    await Future<void>.delayed(const Duration(milliseconds: 250));

    await _settleFrame();

    final sortedTransitions = List<int>.of(transitionMicros)..sort();

    final buildMicros =
        _frameTimings
            .map((timing) => timing.buildDuration.inMicroseconds)
            .toList()
          ..sort();

    final rasterMicros =
        _frameTimings
            .map((timing) => timing.rasterDuration.inMicroseconds)
            .toList()
          ..sort();

    final projectionMax = widget.fixture.projectionRequests.fold<int>(
      0,
      (current, ids) => ids.length > current ? ids.length : current,
    );

    final syncMax = widget.fixture.syncRequests.fold<int>(
      0,
      (current, ids) => ids.length > current ? ids.length : current,
    );

    final currentModelCount = controller.composition!.model.elements.length;

    if (projectionMax > 4 ||
        syncMax > 4 ||
        currentModelCount > 4 ||
        widget.fixture.catalogLoadCount != 1) {
      _fail('boundedness invariant failed');
      return;
    }

    final result =
        'DAILYTALK_C45C4W_PERF '
        'mode=chrome-profile '
        'stages=1000 '
        'window=4 '
        'transitions=${transitionMicros.length} '
        'initial_us=${initialWatch.elapsedMicroseconds} '
        'direct_jump_us=${directJumpWatch.elapsedMicroseconds} '
        'transition_p50_us=${_percentile(sortedTransitions, 0.50)} '
        'transition_p95_us=${_percentile(sortedTransitions, 0.95)} '
        'transition_max_us=${sortedTransitions.last} '
        'frames=${_frameTimings.length} '
        'build_p50_us=${_percentile(buildMicros, 0.50)} '
        'build_p95_us=${_percentile(buildMicros, 0.95)} '
        'build_max_us=${_maxOrZero(buildMicros)} '
        'raster_p50_us=${_percentile(rasterMicros, 0.50)} '
        'raster_p95_us=${_percentile(rasterMicros, 0.95)} '
        'raster_max_us=${_maxOrZero(rasterMicros)} '
        'projection_reads=${widget.fixture.projectionRequests.length} '
        'projection_max=$projectionMax '
        'sync_reads=${widget.fixture.syncRequests.length} '
        'sync_max=$syncMax '
        'model_elements=$currentModelCount '
        'catalog_reads=${widget.fixture.catalogLoadCount}';

    // ignore: avoid_print
    print(result);

    if (mounted) {
      setState(() {
        _result = result;
        _status =
            'Benchmark concluido. '
            'Copie a linha abaixo e cole na janela PowerShell.';
      });
    }
  }

  Future<void> _settleFrame() async {
    await WidgetsBinding.instance.endOfFrame;

    await Future<void>.delayed(const Duration(milliseconds: 8));
  }

  void _fail(String message) {
    final result = 'DAILYTALK_C45C4W_FAIL $message';

    // ignore: avoid_print
    print(result);

    if (mounted) {
      setState(() {
        _result = result;
        _status = 'Benchmark falhou. Copie a linha abaixo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          LearningMapWindowViewport(
            controller: widget.fixture.controller,
            autoLoad: false,
          ),
          Align(
            alignment: Alignment.topCenter,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Material(
                  elevation: 10,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1100),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          Text(
                            _status,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          if (_result != null) ...[
                            const SizedBox(height: 12),
                            SelectableText(_result!, textAlign: TextAlign.left),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

int _percentile(List<int> sortedValues, double quantile) {
  if (sortedValues.isEmpty) {
    return 0;
  }

  final rawIndex = ((sortedValues.length - 1) * quantile).round();

  return sortedValues[rawIndex.clamp(0, sortedValues.length - 1)];
}

int _maxOrZero(List<int> sortedValues) {
  if (sortedValues.isEmpty) {
    return 0;
  }

  return sortedValues.last;
}

Future<_Fixture> _fixture({
  required int stageCount,
  required int windowSize,
}) async {
  final path = _buildPath(stageCount);

  var catalogLoadCount = 0;

  final projectionRequests = <List<String>>[];

  final syncRequests = <List<String>>[];

  final coordinator = LearningMapWindowCoordinator(
    loadActiveContent: (_) async {
      catalogLoadCount++;

      return LearningMapActiveContentSnapshot(
        path: path,
        packageVersion: 9,
        recoveredFromFallback: false,
      );
    },
    loadWindowProjection:
        ({
          required String accountId,
          required String learningPathId,
          required Iterable<String> pathElementIds,
        }) async {
          final ids = pathElementIds.toList(growable: false);

          projectionRequests.add(ids);

          return ids
              .map((id) => _projection(id, recommendedIndex: 999))
              .toList(growable: false);
        },
    loadWindowSync:
        ({
          required String accountId,
          required String learningPathId,
          required Iterable<String> activityIds,
        }) async {
          final ids = activityIds.toList(growable: false);

          syncRequests.add(ids);

          return const <String, ProgressSyncState>{};
        },
    loadGlobalRecommendations:
        ({required String accountId, required String learningPathId}) async {
          return <LearningProgressProjectionEntry>[
            _projection('element-999', recommendedIndex: 999),
          ];
        },
    loadGlobalCounts:
        ({required String accountId, required String learningPathId}) async {
          return LearningProgressProjectionCounts(
            projectionRowCount: stageCount,
            totalActivityCount: stageCount,
            completedActivityCount: 0,
            minPackageVersion: 9,
            maxPackageVersion: 9,
          );
        },
    policy: LearningMapStageWindowPolicy(
      initialStageCount: windowSize,
      segmentStageCount: windowSize,
    ),
  );

  final session = await coordinator.open(
    accountId: 'account-1',
    learningPathId: 'path-1',
    locale: 'pt-PT',
  );

  return _Fixture(
    controller: LearningMapWindowController(session: session),
    projectionRequests: projectionRequests,
    syncRequests: syncRequests,
    catalogCounter: () => catalogLoadCount,
  );
}

final class _Fixture {
  const _Fixture({
    required this.controller,
    required this.projectionRequests,
    required this.syncRequests,
    required int Function() catalogCounter,
  }) : _catalogCounter = catalogCounter;

  final LearningMapWindowController controller;

  final List<List<String>> projectionRequests;

  final List<List<String>> syncRequests;

  final int Function() _catalogCounter;

  int get catalogLoadCount => _catalogCounter();
}

LearningPath _buildPath(int stageCount) {
  return LearningPath(
    id: LearningPathId('path-1'),
    schemaVersion: SchemaVersion(1),
    defaultLocale: 'en',
    title: LocalizedText(const <String, String>{
      'en': 'Chrome benchmark path',
      'pt-PT': 'Percurso benchmark Chrome',
    }),
    journeys: <Journey>[
      Journey(
        id: JourneyId('journey-1'),
        title: LocalizedText(const <String, String>{
          'en': 'Journey',
          'pt-PT': 'Jornada',
        }),
        stages: List<Stage>.generate(stageCount, _stage, growable: false),
      ),
    ],
    activities: List<Activity>.generate(stageCount, _activity, growable: false),
    competencies: const <Competency>[],
  );
}

Stage _stage(int index) {
  return Stage(
    id: StageId('stage-$index'),
    title: LocalizedText(<String, String>{
      'en': 'Stage $index',
      'pt-PT': 'Etapa $index',
    }),
    elements: <PathElement>[
      PathElement(
        id: PathElementId('element-$index'),
        type: PathElementType.activity,
        activityId: ActivityId('activity-$index'),
      ),
    ],
  );
}

Activity _activity(int index) {
  final activityId = ActivityId('activity-$index');

  final revisionId = RevisionId('activity-$index-r1');

  return Activity(
    id: activityId,
    type: LearningActivityType.dialogue,
    origin: ContentOrigin.official,
    currentRevisionId: revisionId,
    revisions: <ActivityRevision>[
      ActivityRevision(
        id: revisionId,
        activityId: activityId,
        revisionNumber: 1,
        title: LocalizedText(<String, String>{
          'en': 'Activity $index',
          'pt-PT': 'Atividade $index',
        }),
        instructions: LocalizedText(const <String, String>{
          'en': 'Practise.',
          'pt-PT': 'Pratica.',
        }),
        visibility: ContentVisibility.public,
        competencies: const <CompetencyId>{},
      ),
    ],
  );
}

LearningProgressProjectionEntry _projection(
  String pathElementId, {
  required int recommendedIndex,
}) {
  final index = int.parse(pathElementId.substring('element-'.length));

  return LearningProgressProjectionEntry(
    pathElementId: pathElementId,
    activityId: 'activity-$index',
    state: LearningActivityState.available,
    reason: ProgressionReason.ready,
    recommendationRank: index == recommendedIndex ? 0 : null,
    packageVersion: 9,
    updatedAt: DateTime.utc(2026, 9, 14, 18, 30),
  );
}
