import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../../domain/learning/learning_enums.dart';
import '../../domain/learning/learning_models.dart';
import '../../state/app_learning_language_controller.dart';
import '../../state/app_locale_controller.dart';
import '../../widgets/learning_language_quick_switcher.dart';
import 'learning_activity_completed_page.dart';
import 'learning_activity_completion_coordinator.dart';

/// Mission-bound visual runtime for schema-v2 vocabulary activities.
///
/// Unlike [VocabularyPairsPage]'s legacy entry point, this widget has no
/// fallback bank. Every card comes from the immutable `revision.execution`
/// selected by the Learning Path.
final class LearningVocabularyRuntimePage extends StatefulWidget {
  const LearningVocabularyRuntimePage({
    super.key,
    required this.execution,
    required this.contentDefaultLocale,
    this.missionTitle,
    this.competencyCount = 0,
    this.onActivityCompleted,
    this.returnToLearningMapOnCompletion = false,
  });

  final VocabularyActivityExecution execution;
  final String contentDefaultLocale;
  final String? missionTitle;
  final int competencyCount;
  final LearningActivityCompletionAction? onActivityCompleted;
  final bool returnToLearningMapOnCompletion;

  @override
  State<LearningVocabularyRuntimePage> createState() =>
      _LearningVocabularyRuntimePageState();
}

final class _LearningVocabularyRuntimePageState
    extends State<LearningVocabularyRuntimePage> {
  final Set<String> _matchedIds = <String>{};

  late final List<VocabularyExecutionItem> _leftItems;
  late final Map<String, VocabularyExecutionItem> _itemById;

  /// Fixed visual slots. The board shows the maximum number of pairs that
  /// fits without scrolling, with a pedagogical minimum of 3 and maximum of 6.
  final List<VocabularyExecutionItem?> _leftSlots =
      List<VocabularyExecutionItem?>.filled(6, null, growable: false);
  final List<VocabularyExecutionItem?> _rightSlots =
      List<VocabularyExecutionItem?>.filled(6, null, growable: false);

  /// Activity items that have not yet entered the visible board.
  final List<String> _pendingIds = <String>[];

  /// Correct slots waiting for batch replacement. Two correct pairs free four
  /// cards; only those slots are reused and shuffled. Unmatched cards never
  /// move.
  final Set<int> _matchedLeftSlotIndexes = <int>{};
  final Set<int> _matchedRightSlotIndexes = <int>{};

  /// IDs currently fading out before their slots receive new content.
  final Set<String> _fadingIds = <String>{};

  /// Newly inserted IDs start transparent and then fade in.
  final Set<String> _enteringIds = <String>{};

  String? _selectedLeftId;
  String? _selectedRightId;
  String? _wrongLeftId;
  String? _wrongRightId;
  int _attempts = 0;
  bool _persistingCompletion = false;
  bool _isResolvingSelection = false;

  int _visiblePairCapacity = 0;
  int? _scheduledPairCapacity;

  final Random _random = Random();

  bool get _finished =>
      _leftItems.isNotEmpty && _matchedIds.length == _leftItems.length;

  @override
  void initState() {
    super.initState();
    _leftItems = List<VocabularyExecutionItem>.of(widget.execution.items);
    _itemById = <String, VocabularyExecutionItem>{
      for (final item in _leftItems) item.id: item,
    };
    _pendingIds.addAll(_leftItems.map((item) => item.id));

    // Populate authored content on the first frame too. LayoutBuilder may
    // still reduce the capacity to the best 3..6 value before interaction.
    _buildBoardForCapacity(6);
  }

  int _calculateVisiblePairCapacity(double availableHeight) {
    const double preferredCardHeight = 72;
    const double verticalGap = 10;

    final calculated =
        ((availableHeight + verticalGap) / (preferredCardHeight + verticalGap))
            .floor();

    if (calculated < 3) {
      return 3;
    }
    if (calculated > 6) {
      return 6;
    }
    return calculated;
  }

  void _schedulePairCapacityUpdate(int capacity) {
    if (capacity == _visiblePairCapacity ||
        capacity == _scheduledPairCapacity) {
      return;
    }

    // Once the user starts the round, keep every unmatched card spatially
    // stable. A new capacity can be chosen before the first attempt/reset.
    if (_visiblePairCapacity != 0 &&
        (_attempts > 0 || _matchedIds.isNotEmpty)) {
      return;
    }

    _scheduledPairCapacity = capacity;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final nextCapacity = _scheduledPairCapacity;
      _scheduledPairCapacity = null;

      if (nextCapacity == null || nextCapacity == _visiblePairCapacity) {
        return;
      }

      setState(() {
        _buildBoardForCapacity(nextCapacity);
      });
    });
  }

  void _buildBoardForCapacity(int capacity) {
    _leftSlots.fillRange(0, _leftSlots.length, null);
    _rightSlots.fillRange(0, _rightSlots.length, null);
    _matchedLeftSlotIndexes.clear();
    _matchedRightSlotIndexes.clear();

    final availableIds = _leftItems
        .where((item) => !_matchedIds.contains(item.id))
        .map((item) => item.id)
        .toList();

    final visibleIds = availableIds.take(capacity).toList();

    _pendingIds
      ..clear()
      ..addAll(availableIds.skip(visibleIds.length));

    for (var index = 0; index < visibleIds.length; index++) {
      _leftSlots[index] = _itemById[visibleIds[index]];
    }

    final shuffledRightIds = List<String>.from(visibleIds)..shuffle(_random);
    for (var index = 0; index < shuffledRightIds.length; index++) {
      _rightSlots[index] = _itemById[shuffledRightIds[index]];
    }

    _visiblePairCapacity = capacity;
  }

  Future<void> _animateAndRefillMatchedSlots() async {
    final waitingIds = <String>[];

    for (final leftIndex in _matchedLeftSlotIndexes) {
      final item = _leftSlots[leftIndex];
      if (item == null) {
        continue;
      }

      final hasMatchingRightSlot = _matchedRightSlotIndexes.any(
        (rightIndex) => _rightSlots[rightIndex]?.id == item.id,
      );

      if (hasMatchingRightSlot) {
        waitingIds.add(item.id);
      }
    }

    if (waitingIds.length < 2 || _pendingIds.isEmpty) {
      return;
    }

    waitingIds.shuffle(_random);

    final replaceCount = min(waitingIds.length, _pendingIds.length);
    final replaceIds = waitingIds.take(replaceCount).toList(growable: false);

    // First make only the cards that will actually be replaced fade out.
    setState(() {
      _fadingIds.addAll(replaceIds);
    });

    await Future<void>.delayed(const Duration(milliseconds: 240));
    if (!mounted) {
      return;
    }

    final leftIndexes = <int>[];
    final rightIndexes = <int>[];

    for (final id in replaceIds) {
      final leftIndex = _leftSlots.indexWhere((item) => item?.id == id);
      final rightIndex = _rightSlots.indexWhere((item) => item?.id == id);

      if (leftIndex >= 0 && rightIndex >= 0) {
        leftIndexes.add(leftIndex);
        rightIndexes.add(rightIndex);
      }
    }

    final actualReplacementCount = min(leftIndexes.length, rightIndexes.length);

    if (actualReplacementCount == 0) {
      setState(() {
        _fadingIds.removeAll(replaceIds);
      });
      return;
    }

    final nextIds = <String>[];
    for (var index = 0; index < actualReplacementCount; index++) {
      final pendingIndex = _random.nextInt(_pendingIds.length);
      nextIds.add(_pendingIds.removeAt(pendingIndex));
    }

    final leftIds = List<String>.from(nextIds)..shuffle(_random);
    final rightIds = List<String>.from(nextIds)..shuffle(_random);

    setState(() {
      for (var index = 0; index < actualReplacementCount; index++) {
        _leftSlots[leftIndexes[index]] = _itemById[leftIds[index]];
        _rightSlots[rightIndexes[index]] = _itemById[rightIds[index]];

        _matchedLeftSlotIndexes.remove(leftIndexes[index]);
        _matchedRightSlotIndexes.remove(rightIndexes[index]);
      }

      _fadingIds.removeAll(replaceIds);
      _enteringIds.addAll(nextIds);
    });

    // Give Flutter one frame with the new cards at opacity zero, then fade in.
    await Future<void>.delayed(const Duration(milliseconds: 30));
    if (!mounted) {
      return;
    }

    setState(() {
      _enteringIds.removeAll(nextIds);
    });

    await Future<void>.delayed(const Duration(milliseconds: 220));
  }

  void _select(VocabularyExecutionItem item, {required bool left}) {
    if (_isResolvingSelection || _matchedIds.contains(item.id) || _finished) {
      return;
    }

    setState(() {
      _wrongLeftId = null;
      _wrongRightId = null;
      if (left) {
        _selectedLeftId = item.id;
      } else {
        _selectedRightId = item.id;
      }
    });

    if (_selectedLeftId != null && _selectedRightId != null) {
      unawaited(_evaluateSelection());
    }
  }

  Future<void> _evaluateSelection() async {
    if (_isResolvingSelection) {
      return;
    }

    final leftId = _selectedLeftId;
    final rightId = _selectedRightId;
    if (leftId == null || rightId == null) {
      return;
    }

    final leftSlotIndex = _leftSlots.indexWhere((item) => item?.id == leftId);
    final rightSlotIndex = _rightSlots.indexWhere(
      (item) => item?.id == rightId,
    );

    if (leftSlotIndex < 0 || rightSlotIndex < 0) {
      return;
    }

    if (leftId == rightId) {
      setState(() {
        _attempts++;
        _matchedIds.add(leftId);
        _matchedLeftSlotIndexes.add(leftSlotIndex);
        _matchedRightSlotIndexes.add(rightSlotIndex);
        _selectedLeftId = null;
        _selectedRightId = null;
        _wrongLeftId = null;
        _wrongRightId = null;
        _isResolvingSelection = true;
      });

      // Keep the successful association visible long enough to be perceived.
      await Future<void>.delayed(const Duration(milliseconds: 380));
      if (!mounted) {
        return;
      }

      final hasTwoMatchedPairs =
          _matchedLeftSlotIndexes.length >= 2 &&
          _matchedRightSlotIndexes.length >= 2;

      if (hasTwoMatchedPairs && _pendingIds.isNotEmpty) {
        await _animateAndRefillMatchedSlots();
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _isResolvingSelection = false;
      });
      return;
    }

    setState(() {
      _attempts++;
      _wrongLeftId = leftId;
      _wrongRightId = rightId;
      _isResolvingSelection = true;
    });

    await Future<void>.delayed(const Duration(milliseconds: 520));
    if (!mounted) {
      return;
    }

    setState(() {
      _selectedLeftId = null;
      _selectedRightId = null;
      _wrongLeftId = null;
      _wrongRightId = null;
      _isResolvingSelection = false;
    });
  }

  void _reset() {
    setState(() {
      _matchedIds.clear();
      _matchedLeftSlotIndexes.clear();
      _matchedRightSlotIndexes.clear();
      _fadingIds.clear();
      _enteringIds.clear();
      _selectedLeftId = null;
      _selectedRightId = null;
      _wrongLeftId = null;
      _wrongRightId = null;
      _attempts = 0;
      _isResolvingSelection = false;

      if (_visiblePairCapacity > 0) {
        _buildBoardForCapacity(_visiblePairCapacity);
      } else {
        _leftSlots.fillRange(0, _leftSlots.length, null);
        _rightSlots.fillRange(0, _rightSlots.length, null);
        _pendingIds
          ..clear()
          ..addAll(_leftItems.map((item) => item.id));
      }
    });
  }

  Future<void> _openCompletion(_VocabularyRuntimeCopy copy) async {
    if (_persistingCompletion) {
      return;
    }

    setState(() {
      _persistingCompletion = true;
    });

    try {
      await widget.onActivityCompleted?.call();

      if (!mounted) {
        return;
      }

      final configuredTitle = widget.missionTitle?.trim();
      final title = configuredTitle != null && configuredTitle.isNotEmpty
          ? configuredTitle
          : copy.title;

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => LearningActivityCompletedPage(
            activityType: LearningActivityType.vocabulary,
            title: title,
            competencyCount: widget.competencyCount,
            returnToLearningMap: widget.returnToLearningMapOnCompletion,
            metrics: <LearningCompletionMetric>[
              LearningCompletionMetric(
                label: copy.pairsMetric,
                value: '${_matchedIds.length}/${_leftItems.length}',
                icon: Icons.link_rounded,
              ),
              LearningCompletionMetric(
                label: copy.attemptsMetric,
                value: '$_attempts',
                icon: Icons.touch_app_rounded,
              ),
            ],
          ),
        ),
      );
    } catch (error, stackTrace) {
      debugPrint('Learning progress persistence failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _persistingCompletion = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocaleController.instance,
      builder: (context, _) {
        return AnimatedBuilder(
          animation: AppLearningLanguageController.instance,
          builder: (context, _) {
            final appLanguage = AppLocaleController.instance.languageCode;
            final learningLanguage =
                AppLearningLanguageController.instance.languageCode;
            final copy = _copyFor(appLanguage);
            final total = _leftItems.length;
            final completed = _matchedIds.length;
            final displayFinished = _finished;

            return Scaffold(
              backgroundColor: const Color(0xFFF4F8FB),
              appBar: AppBar(
                elevation: 0,
                backgroundColor: const Color(0xFF071C25),
                foregroundColor: Colors.white,
                titleSpacing: 0,
                title: const Text(
                  'DailyTalk.pt',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                actions: const <Widget>[LearningLanguageQuickSwitcher()],
              ),
              body: SafeArea(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        children: <Widget>[
                          _Header(
                            copy: copy,
                            completed: completed,
                            total: total,
                            appLanguage: appLanguage,
                            learningLanguage: learningLanguage,
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final calculatedCapacity =
                                    _calculateVisiblePairCapacity(
                                      constraints.maxHeight,
                                    );
                                _schedulePairCapacityUpdate(calculatedCapacity);

                                final visibleCount = _visiblePairCapacity == 0
                                    ? calculatedCapacity
                                    : _visiblePairCapacity;

                                return Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Expanded(
                                      child: _buildColumn(
                                        items: _leftSlots,
                                        visibleCount: visibleCount,
                                        languageCode: appLanguage,
                                        left: true,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _buildColumn(
                                        items: _rightSlots,
                                        visibleCount: visibleCount,
                                        languageCode: learningLanguage,
                                        left: false,
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 12),
                          _Footer(
                            copy: copy,
                            completed: completed,
                            total: total,
                            attempts: _attempts,
                            finished: displayFinished,
                            onReset: _reset,
                            onComplete:
                                _persistingCompletion || _isResolvingSelection
                                ? null
                                : () => unawaited(_openCompletion(copy)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildColumn({
    required List<VocabularyExecutionItem?> items,
    required int visibleCount,
    required String languageCode,
    required bool left,
  }) {
    final count = min(visibleCount, _leftItems.length);

    return Column(
      key: ValueKey<String>(
        left ? 'mission-vocab-left' : 'mission-vocab-right',
      ),
      children: <Widget>[
        for (var index = 0; index < count; index++) ...<Widget>[
          if (index > 0) const SizedBox(height: 10),
          Expanded(
            child: items[index] == null
                ? const SizedBox.expand()
                : AnimatedOpacity(
                    duration: const Duration(milliseconds: 240),
                    curve: Curves.easeOut,
                    opacity:
                        _fadingIds.contains(items[index]!.id) ||
                            _enteringIds.contains(items[index]!.id)
                        ? 0
                        : _matchedIds.contains(items[index]!.id)
                        ? 0.52
                        : 1,
                    child: SizedBox.expand(
                      child: _PairCard(
                        key: ValueKey<String>(
                          'mission-vocab-${left ? 'left' : 'right'}-${items[index]!.id}',
                        ),
                        text: items[index]!.text.resolve(
                          languageCode,
                          fallbackLocale: widget.contentDefaultLocale,
                        ),
                        matched: _matchedIds.contains(items[index]!.id),
                        selected: left
                            ? _selectedLeftId == items[index]!.id
                            : _selectedRightId == items[index]!.id,
                        wrong: left
                            ? _wrongLeftId == items[index]!.id
                            : _wrongRightId == items[index]!.id,
                        onTap: () => _select(items[index]!, left: left),
                      ),
                    ),
                  ),
          ),
        ],
      ],
    );
  }
}

final class _Header extends StatelessWidget {
  const _Header({
    required this.copy,
    required this.completed,
    required this.total,
    required this.appLanguage,
    required this.learningLanguage,
  });

  final _VocabularyRuntimeCopy copy;
  final int completed;
  final int total;
  final String appLanguage;
  final String learningLanguage;

  @override
  Widget build(BuildContext context) {
    final progress = total == 0 ? 0.0 : completed / total;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD8E6EE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDF7ED),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: Color(0xFF18A875),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      copy.typeLabel,
                      style: const TextStyle(
                        color: Color(0xFF18A875),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      copy.title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$completed/$total',
                key: const ValueKey<String>('mission-vocab-progress-count'),
                style: const TextStyle(
                  color: Color(0xFF4B6572),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${_languageName(appLanguage)}  →  ${_languageName(learningLanguage)}',
            key: const ValueKey<String>('mission-vocab-language-pair'),
            style: const TextStyle(
              color: Color(0xFF58707C),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: progress,
              backgroundColor: const Color(0xFFE8F1F5),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF18A875),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            copy.instructions,
            style: const TextStyle(color: Color(0xFF627985), height: 1.35),
          ),
        ],
      ),
    );
  }
}

final class _PairCard extends StatelessWidget {
  const _PairCard({
    super.key,
    required this.text,
    required this.matched,
    required this.selected,
    required this.wrong,
    required this.onTap,
  });

  final String text;
  final bool matched;
  final bool selected;
  final bool wrong;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final border = wrong
        ? const Color(0xFFE74C5B)
        : matched
        ? const Color(0xFF18A875)
        : selected
        ? const Color(0xFF168CFF)
        : const Color(0xFFD5E2E9);
    final background = wrong
        ? const Color(0xFFFFF1F2)
        : matched
        ? const Color(0xFFEAF9F3)
        : selected
        ? const Color(0xFFEAF4FF)
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: matched ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: selected || wrong ? 2 : 1),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF20333D),
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                  ),
                ),
              ),
              if (matched) ...<Widget>[
                const SizedBox(width: 5),
                const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF18A875),
                  size: 19,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final class _Footer extends StatelessWidget {
  const _Footer({
    required this.copy,
    required this.completed,
    required this.total,
    required this.attempts,
    required this.finished,
    required this.onReset,
    required this.onComplete,
  });

  final _VocabularyRuntimeCopy copy;
  final int completed;
  final int total;
  final int attempts;
  final bool finished;
  final VoidCallback onReset;
  final VoidCallback? onComplete;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0D2530),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  finished ? copy.finished : copy.feedback,
                  key: const ValueKey<String>('mission-vocab-feedback'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$completed/$total · $attempts ${copy.attempts}',
                  style: const TextStyle(
                    color: Color(0xFFA9BBC4),
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (finished)
            FilledButton.icon(
              key: const ValueKey<String>('mission-vocab-complete'),
              onPressed: onComplete,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF18A875),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: Text(copy.continueLabel),
            )
          else
            IconButton.filled(
              key: const ValueKey<String>('mission-vocab-reset'),
              onPressed: onReset,
              tooltip: copy.reset,
              style: IconButton.styleFrom(
                backgroundColor: const Color(0xFF168CFF),
                foregroundColor: Colors.white,
              ),
              icon: const Icon(Icons.refresh_rounded),
            ),
        ],
      ),
    );
  }
}

final class _VocabularyRuntimeCopy {
  const _VocabularyRuntimeCopy({
    required this.typeLabel,
    required this.title,
    required this.instructions,
    required this.feedback,
    required this.finished,
    required this.attempts,
    required this.reset,
    required this.continueLabel,
    required this.pairsMetric,
    required this.attemptsMetric,
  });

  final String typeLabel;
  final String title;
  final String instructions;
  final String feedback;
  final String finished;
  final String attempts;
  final String reset;
  final String continueLabel;
  final String pairsMetric;
  final String attemptsMetric;
}

_VocabularyRuntimeCopy _copyFor(String locale) {
  return switch (locale.split('-').first.toLowerCase()) {
    'en' => const _VocabularyRuntimeCopy(
      typeLabel: 'Vocabulary',
      title: 'Match the pairs',
      instructions: 'Choose one card from each side that means the same thing.',
      feedback: 'Find the matching pair.',
      finished: 'Practice finished',
      attempts: 'attempts',
      reset: 'Restart',
      continueLabel: 'Continue',
      pairsMetric: 'Pairs',
      attemptsMetric: 'Attempts',
    ),
    'es' => const _VocabularyRuntimeCopy(
      typeLabel: 'Vocabulario',
      title: 'Relaciona las parejas',
      instructions: 'Elige una tarjeta de cada lado que signifique lo mismo.',
      feedback: 'Encuentra la pareja correcta.',
      finished: 'Práctica terminada',
      attempts: 'intentos',
      reset: 'Reiniciar',
      continueLabel: 'Continuar',
      pairsMetric: 'Parejas',
      attemptsMetric: 'Intentos',
    ),
    'fr' => const _VocabularyRuntimeCopy(
      typeLabel: 'Vocabulaire',
      title: 'Associe les paires',
      instructions: 'Choisis une carte de chaque côté qui a le même sens.',
      feedback: 'Trouve la bonne paire.',
      finished: 'Pratique terminée',
      attempts: 'tentatives',
      reset: 'Recommencer',
      continueLabel: 'Continuer',
      pairsMetric: 'Paires',
      attemptsMetric: 'Tentatives',
    ),
    'it' => const _VocabularyRuntimeCopy(
      typeLabel: 'Vocabolario',
      title: 'Abbina le coppie',
      instructions: 'Scegli una carta per lato con lo stesso significato.',
      feedback: 'Trova la coppia corretta.',
      finished: 'Pratica terminata',
      attempts: 'tentativi',
      reset: 'Ricomincia',
      continueLabel: 'Continua',
      pairsMetric: 'Coppie',
      attemptsMetric: 'Tentativi',
    ),
    'de' => const _VocabularyRuntimeCopy(
      typeLabel: 'Wortschatz',
      title: 'Finde die Paare',
      instructions: 'Wähle auf jeder Seite eine Karte mit derselben Bedeutung.',
      feedback: 'Finde das passende Paar.',
      finished: 'Übung beendet',
      attempts: 'Versuche',
      reset: 'Neu starten',
      continueLabel: 'Weiter',
      pairsMetric: 'Paare',
      attemptsMetric: 'Versuche',
    ),
    _ => const _VocabularyRuntimeCopy(
      typeLabel: 'Vocabulário',
      title: 'Combina os pares',
      instructions: 'Escolhe um cartão de cada lado com o mesmo significado.',
      feedback: 'Encontra o par correspondente.',
      finished: 'Prática terminada',
      attempts: 'tentativas',
      reset: 'Reiniciar',
      continueLabel: 'Continuar',
      pairsMetric: 'Pares',
      attemptsMetric: 'Tentativas',
    ),
  };
}

String _languageName(String languageCode) {
  return switch (languageCode.toLowerCase()) {
    'pt-pt' => 'Português',
    'en-us' => 'English',
    'es-es' => 'Español',
    'fr-fr' => 'Français',
    'it-it' => 'Italiano',
    'de-de' => 'Deutsch',
    _ => languageCode,
  };
}
