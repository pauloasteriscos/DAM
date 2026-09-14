import 'package:flutter/material.dart';

/// Presentation-only controls for one bounded Learning Map segment.
///
/// Pedagogical state is not calculated here. The widget only exposes the
/// window navigation capabilities already decided by the controller/session.
final class LearningMapWindowSegmentControls extends StatelessWidget {
  const LearningMapWindowSegmentControls({
    required this.startStageIndex,
    required this.loadedStageCount,
    required this.totalStageCount,
    required this.canPrevious,
    required this.canNext,
    required this.isBusy,
    required this.hasError,
    required this.onPrevious,
    required this.onNext,
    this.onRetry,
    super.key,
  }) : assert(startStageIndex >= 0),
       assert(loadedStageCount > 0),
       assert(totalStageCount > 0),
       assert(startStageIndex < totalStageCount),
       assert(startStageIndex + loadedStageCount <= totalStageCount);

  final int startStageIndex;
  final int loadedStageCount;
  final int totalStageCount;

  final bool canPrevious;
  final bool canNext;
  final bool isBusy;
  final bool hasError;

  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final localizations = MaterialLocalizations.of(context);

    final endStageExclusive = startStageIndex + loadedStageCount;

    final previousEnabled = canPrevious && !isBusy;

    final nextEnabled = canNext && !isBusy;

    final retryEnabled = hasError && !isBusy && onRetry != null;

    return Material(
      elevation: 6,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            children: <Widget>[
              IconButton(
                key: const Key('learning-map-window-previous-segment'),
                tooltip: localizations.previousPageTooltip,
                onPressed: previousEnabled ? onPrevious : null,
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      '${startStageIndex + 1}\u2013'
                      '$endStageExclusive / '
                      '$totalStageCount',
                      key: const Key('learning-map-window-stage-range'),
                      textAlign: TextAlign.center,
                    ),
                    if (hasError)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          const Icon(
                            Icons.error_outline,
                            key: Key('learning-map-window-segment-error'),
                            size: 18,
                          ),
                          if (retryEnabled)
                            IconButton(
                              key: const Key(
                                'learning-map-window-retry-segment',
                              ),
                              tooltip:
                                  localizations.refreshIndicatorSemanticLabel,
                              visualDensity: VisualDensity.compact,
                              onPressed: onRetry,
                              icon: const Icon(Icons.refresh, size: 18),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
              if (isBusy)
                const SizedBox(
                  width: 28,
                  height: 28,
                  child: Padding(
                    padding: EdgeInsets.all(5),
                    child: CircularProgressIndicator(
                      key: Key('learning-map-window-segment-busy'),
                      strokeWidth: 2,
                    ),
                  ),
                ),
              IconButton(
                key: const Key('learning-map-window-next-segment'),
                tooltip: localizations.nextPageTooltip,
                onPressed: nextEnabled ? onNext : null,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
