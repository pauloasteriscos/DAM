import 'package:flutter/material.dart';

import '../../domain/learning/learning_enums.dart';
import 'learning_map_view_model.dart';

/// Shared visual tokens for the DailyTalk Learning Path.
///
/// Presentation only. No pedagogical decision is made here.
abstract final class LearningMapVisualTokens {
  static const Color background = Color(0xFF061823);
  static const Color surface = Color(0xFF0B2736);
  static const Color surfaceElevated = Color(0xFF103653);
  static const Color cyan = Color(0xFF35C8FF);
  static const Color blue = Color(0xFF168CFF);
  static const Color gold = Color(0xFFFFC857);
  static const Color green = Color(0xFF59D69A);
  static const Color muted = Color(0xFF8196A3);
  static const Color danger = Color(0xFFFF6B6B);
  static const Color textPrimary = Color(0xFFF5FBFF);
  static const Color textSecondary = Color(0xFFB8CBD5);
}

/// Contextual header driven exclusively by [LearningMapViewModel].
final class LearningMapContextHeader extends StatelessWidget {
  const LearningMapContextHeader({required this.model, super.key});

  final LearningMapViewModel model;

  @override
  Widget build(BuildContext context) {
    final next = model.nextRecommendedElement;
    final rawNextTitle = next?.title?.trim();
    final nextTitle = rawNextTitle == null || rawNextTitle.isEmpty
        ? null
        : rawNextTitle;
    final contextualLocation = _resolveContext(next);

    return Container(
      key: const Key('learning-map-header'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            LearningMapVisualTokens.surfaceElevated,
            LearningMapVisualTokens.background,
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LearningMapVisualTokens.cyan.withValues(alpha: 0.24),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            contextualLocation,
            key: const Key('learning-map-context'),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: LearningMapVisualTokens.cyan,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            model.title,
            key: const Key('learning-map-title'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: LearningMapVisualTokens.textPrimary,
              fontSize: 24,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    key: const Key('learning-map-progress'),
                    value: model.completionRatio,
                    minHeight: 8,
                    backgroundColor: LearningMapVisualTokens.surface.withValues(
                      alpha: 0.8,
                    ),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      LearningMapVisualTokens.green,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${model.completedActivityCount} / ${model.totalActivityCount}',
                key: const Key('learning-map-progress-count'),
                style: const TextStyle(
                  color: LearningMapVisualTokens.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Text(
            '${model.completedActivityCount} de ${model.totalActivityCount} miss\u00f5es conclu\u00eddas',
            style: const TextStyle(
              color: LearningMapVisualTokens.textSecondary,
              fontSize: 12,
            ),
          ),
          if (nextTitle != null) ...<Widget>[
            const SizedBox(height: 16),
            Container(
              key: const Key('learning-map-next-mission'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: LearningMapVisualTokens.cyan.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.near_me_rounded,
                    color: LearningMapVisualTokens.cyan,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const Text(
                          'Pr\u00f3xima miss\u00e3o',
                          style: TextStyle(
                            color: LearningMapVisualTokens.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          nextTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: LearningMapVisualTokens.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (model.recoveredFromFallback) ...<Widget>[
            const SizedBox(height: 10),
            const _LocalFallbackBadge(),
          ],
        ],
      ),
    );
  }

  String _resolveContext(LearningMapElementViewModel? next) {
    if (next != null) {
      for (final journey in model.journeys) {
        for (final stage in journey.stages) {
          for (final element in stage.elements) {
            if (element.pathElementId == next.pathElementId) {
              return '${journey.title} \u2022 ${stage.title}';
            }
          }
        }
      }
    }

    if (model.journeys.isNotEmpty) {
      return model.journeys.first.title;
    }

    return 'Percurso de aprendizagem';
  }
}

final class _LocalFallbackBadge extends StatelessWidget {
  const _LocalFallbackBadge();

  @override
  Widget build(BuildContext context) {
    return const Row(
      key: Key('learning-map-fallback-badge'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(
          Icons.offline_bolt_outlined,
          size: 15,
          color: LearningMapVisualTokens.gold,
        ),
        SizedBox(width: 6),
        Text(
          'Conte\u00fado local recuperado',
          style: TextStyle(
            color: LearningMapVisualTokens.gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

/// Activity node with pedagogical and synchronization state kept separate.
final class LearningMapActivityNode extends StatelessWidget {
  const LearningMapActivityNode({required this.element, this.onTap, super.key});

  final LearningMapElementViewModel element;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    assert(
      element.isActivity,
      'LearningMapActivityNode requires an activity element.',
    );

    final stateSpec = _stateSpec(element.state);
    final syncSpec = _syncSpec(element.syncState);
    final rawTitle = element.title?.trim();
    final resolvedTitle = rawTitle == null || rawTitle.isEmpty
        ? 'Miss\u00e3o'
        : rawTitle;
    final enabled = element.canOpen && onTap != null;

    return Opacity(
      opacity: element.isLocked ? 0.68 : 1,
      child: Material(
        key: Key('learning-map-node-${element.pathElementId}'),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: const BoxConstraints(minHeight: 96),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: stateSpec.fill,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: stateSpec.accent.withValues(
                  alpha: element.isPrimaryRecommendation ? 0.95 : 0.58,
                ),
                width: element.isPrimaryRecommendation ? 2.2 : 1.2,
              ),
              boxShadow: element.isPrimaryRecommendation
                  ? <BoxShadow>[
                      BoxShadow(
                        color: LearningMapVisualTokens.cyan.withValues(
                          alpha: 0.14,
                        ),
                        blurRadius: 18,
                        offset: const Offset(0, 7),
                      ),
                    ]
                  : const <BoxShadow>[],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: stateSpec.accent.withValues(alpha: 0.14),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        stateSpec.icon,
                        color: stateSpec.accent,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            resolvedTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: LearningMapVisualTokens.textPrimary,
                              fontSize: 16,
                              height: 1.18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          if (element.instructions?.trim().isNotEmpty ?? false)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                element.instructions!.trim(),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: LearningMapVisualTokens.textSecondary,
                                  fontSize: 12,
                                  height: 1.25,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (element.isPrimaryRecommendation)
                      const _RecommendationBadge(),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 7,
                  children: <Widget>[
                    _StateBadge(
                      elementId: element.pathElementId,
                      spec: stateSpec,
                    ),
                    _SyncBadge(
                      elementId: element.pathElementId,
                      spec: syncSpec,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _RecommendationBadge extends StatelessWidget {
  const _RecommendationBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('learning-map-primary-recommendation'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: LearningMapVisualTokens.cyan.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        'A seguir',
        style: TextStyle(
          color: LearningMapVisualTokens.cyan,
          fontSize: 10,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

final class _StateBadge extends StatelessWidget {
  const _StateBadge({required this.elementId, required this.spec});

  final String elementId;
  final _LearningStateSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('learning-map-state-$elementId'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: spec.accent.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(spec.icon, size: 14, color: spec.accent),
          const SizedBox(width: 5),
          Text(
            spec.label,
            style: TextStyle(
              color: spec.accent,
              fontSize: 11,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

final class _SyncBadge extends StatelessWidget {
  const _SyncBadge({required this.elementId, required this.spec});

  final String elementId;
  final _SyncStateSpec spec;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('learning-map-sync-$elementId'),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: spec.color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: spec.color.withValues(alpha: 0.24)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(spec.icon, size: 14, color: spec.color),
          const SizedBox(width: 5),
          Text(
            spec.label,
            style: TextStyle(
              color: spec.color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

final class _LearningStateSpec {
  const _LearningStateSpec({
    required this.label,
    required this.icon,
    required this.accent,
    required this.fill,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Color fill;
}

final class _SyncStateSpec {
  const _SyncStateSpec({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

_LearningStateSpec _stateSpec(LearningActivityState state) {
  return switch (state) {
    LearningActivityState.locked => const _LearningStateSpec(
      label: 'Bloqueada',
      icon: Icons.lock_outline_rounded,
      accent: LearningMapVisualTokens.muted,
      fill: Color(0xFF0A202B),
    ),
    LearningActivityState.available => const _LearningStateSpec(
      label: 'Dispon\u00edvel',
      icon: Icons.play_arrow_rounded,
      accent: LearningMapVisualTokens.cyan,
      fill: Color(0xFF0A2B3C),
    ),
    LearningActivityState.inProgress => const _LearningStateSpec(
      label: 'Em progresso',
      icon: Icons.directions_walk_rounded,
      accent: LearningMapVisualTokens.gold,
      fill: Color(0xFF2C291D),
    ),
    LearningActivityState.completed => const _LearningStateSpec(
      label: 'Conclu\u00edda',
      icon: Icons.check_circle_outline_rounded,
      accent: LearningMapVisualTokens.green,
      fill: Color(0xFF102D29),
    ),
  };
}

_SyncStateSpec _syncSpec(ProgressSyncState state) {
  return switch (state) {
    ProgressSyncState.clean => const _SyncStateSpec(
      label: 'Sincronizado',
      icon: Icons.cloud_done_outlined,
      color: LearningMapVisualTokens.textSecondary,
    ),
    ProgressSyncState.pending => const _SyncStateSpec(
      label: 'Por sincronizar',
      icon: Icons.cloud_upload_outlined,
      color: LearningMapVisualTokens.gold,
    ),
    ProgressSyncState.syncing => const _SyncStateSpec(
      label: 'A sincronizar',
      icon: Icons.sync_rounded,
      color: LearningMapVisualTokens.cyan,
    ),
    ProgressSyncState.failed => const _SyncStateSpec(
      label: 'Falha na sincroniza\u00e7\u00e3o',
      icon: Icons.cloud_off_outlined,
      color: LearningMapVisualTokens.danger,
    ),
  };
}
