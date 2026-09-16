import 'package:flutter/material.dart';

import '../../domain/learning/learning_enums.dart';
import 'learning_map_view_model.dart';
import 'learning_map_visuals.dart';

typedef LearningMapActivityTap =
    void Function(LearningMapElementViewModel element);

const double _learningMapContentMaxWidth = 920;

/// Scrollable composition of the DailyTalk Learning Path.
///
/// This widget consumes only [LearningMapViewModel]. It does not read
/// SQLite, access the network or execute pedagogical rules.
final class LearningMapView extends StatelessWidget {
  const LearningMapView({
    required this.model,
    this.onActivityTap,
    this.scrollController,
    this.footer,
    super.key,
  });

  final LearningMapViewModel model;
  final LearningMapActivityTap? onActivityTap;
  final ScrollController? scrollController;

  /// Conteúdo opcional renderizado depois da última jornada, dentro deste
  /// mesmo [CustomScrollView].
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;

    return ColoredBox(
      color: LearningMapVisualTokens.background,
      child: CustomScrollView(
        key: const Key('learning-map-scroll-view'),
        controller: scrollController,
        slivers: <Widget>[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              compact ? 10 : 14,
              compact ? 10 : 14,
              compact ? 10 : 14,
              8,
            ),
            sliver: SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _learningMapContentMaxWidth,
                  ),
                  child: LearningMapContextHeader(model: model),
                ),
              ),
            ),
          ),
          for (
            var journeyIndex = 0;
            journeyIndex < model.journeys.length;
            journeyIndex++
          )
            _JourneySliver(
              journey: model.journeys[journeyIndex],
              journeyIndex: journeyIndex,
              onActivityTap: onActivityTap,
            ),
          if (footer != null)
            SliverToBoxAdapter(
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _learningMapContentMaxWidth,
                  ),
                  child: footer!,
                ),
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

final class _JourneySliver extends StatelessWidget {
  const _JourneySliver({
    required this.journey,
    required this.journeyIndex,
    required this.onActivityTap,
  });

  final LearningMapJourneyViewModel journey;
  final int journeyIndex;
  final LearningMapActivityTap? onActivityTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;

    return SliverPadding(
      key: Key('learning-map-journey-${journey.id}'),
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 14,
        compact ? 10 : 12,
        compact ? 10 : 14,
        4,
      ),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate((context, itemIndex) {
          Widget child;

          if (itemIndex == 0) {
            child = Padding(
              padding: EdgeInsets.only(bottom: compact ? 8 : 10),
              child: _JourneyHeader(index: journeyIndex, title: journey.title),
            );
          } else {
            final stageIndex = itemIndex - 1;
            final isLastStage = stageIndex == journey.stages.length - 1;

            child = Padding(
              padding: EdgeInsets.only(
                bottom: isLastStage ? 0 : (compact ? 12 : 14),
              ),
              child: _StageSection(
                stage: journey.stages[stageIndex],
                stageIndex: stageIndex,
                onActivityTap: onActivityTap,
              ),
            );
          }

          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: _learningMapContentMaxWidth,
              ),
              child: child,
            ),
          );
        }, childCount: journey.stages.length + 1),
      ),
    );
  }
}

final class _JourneyHeader extends StatelessWidget {
  const _JourneyHeader({required this.index, required this.title});

  final int index;
  final String title;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Container(
      key: Key('learning-map-journey-header-$index'),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 8 : 10,
      ),
      decoration: BoxDecoration(
        color: LearningMapVisualTokens.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LearningMapVisualTokens.outline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: LearningMapVisualTokens.shadow,
            blurRadius: 14,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: compact ? 36 : 40,
            height: compact ? 36 : 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: <Color>[
                  LearningMapVisualTokens.cyan,
                  LearningMapVisualTokens.blue,
                ],
              ),
              borderRadius: BorderRadius.circular(compact ? 12 : 13),
            ),
            child: Icon(
              Icons.home_rounded,
              color: Colors.white,
              size: compact ? 20 : 22,
            ),
          ),
          SizedBox(width: compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'JORNADA ${index + 1}',
                  style: const TextStyle(
                    color: LearningMapVisualTokens.blue,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: LearningMapVisualTokens.textPrimary,
                    fontSize: 16,
                    height: 1.15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.route_rounded,
            color: LearningMapVisualTokens.blue,
            size: 22,
          ),
        ],
      ),
    );
  }
}

final class _StageSection extends StatelessWidget {
  const _StageSection({
    required this.stage,
    required this.stageIndex,
    required this.onActivityTap,
  });

  final LearningMapStageViewModel stage;
  final int stageIndex;
  final LearningMapActivityTap? onActivityTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Container(
      key: Key('learning-map-stage-${stage.id}'),
      padding: EdgeInsets.fromLTRB(
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 10 : 12,
        compact ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: LearningMapVisualTokens.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: LearningMapVisualTokens.outline),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: LearningMapVisualTokens.shadow,
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StageHeader(stage: stage, stageIndex: stageIndex),
          SizedBox(height: compact ? 10 : 12),
          Stack(
            children: <Widget>[
              if (stage.elements.length > 1)
                Positioned(
                  left: compact ? 14 : 16,
                  top: 18,
                  bottom: 18,
                  child: Container(
                    width: 2,
                    decoration: BoxDecoration(
                      color: LearningMapVisualTokens.outline,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              Column(
                children: <Widget>[
                  for (
                    var elementIndex = 0;
                    elementIndex < stage.elements.length;
                    elementIndex++
                  ) ...<Widget>[
                    if (stage
                        .elements[elementIndex]
                        .hasPrerequisites) ...<Widget>[
                      _LearningMapPrerequisiteConnector(
                        target: stage.elements[elementIndex],
                      ),
                      const SizedBox(height: 6),
                    ],
                    _RouteElement(
                      element: stage.elements[elementIndex],
                      onActivityTap: onActivityTap,
                    ),
                    if (elementIndex != stage.elements.length - 1)
                      SizedBox(height: compact ? 8 : 9),
                  ],
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _StageHeader extends StatelessWidget {
  const _StageHeader({required this.stage, required this.stageIndex});

  final LearningMapStageViewModel stage;
  final int stageIndex;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: compact ? 32 : 34,
              height: compact ? 32 : 34,
              decoration: BoxDecoration(
                color: LearningMapVisualTokens.surfaceElevated,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Center(
                child: Text(
                  '${stageIndex + 1}',
                  style: const TextStyle(
                    color: LearningMapVisualTokens.blue,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'ETAPA ${stageIndex + 1}',
                    style: const TextStyle(
                      color: LearningMapVisualTokens.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    stage.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LearningMapVisualTokens.textPrimary,
                      fontSize: 17,
                      height: 1.15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: compact ? 8 : 10),
            Container(
              key: Key('learning-map-stage-count-${stage.id}'),
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 5 : 6,
              ),
              decoration: BoxDecoration(
                color: LearningMapVisualTokens.surfaceElevated,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${stage.completedActivityCount} / ${stage.activityCount}',
                style: const TextStyle(
                  color: LearningMapVisualTokens.blue,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        if (stage.activityCount > 0) ...<Widget>[
          SizedBox(height: compact ? 9 : 11),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              key: Key('learning-map-stage-progress-${stage.id}'),
              value: stage.completionRatio,
              minHeight: 5,
              backgroundColor: LearningMapVisualTokens.surfaceElevated,
              valueColor: const AlwaysStoppedAnimation<Color>(
                LearningMapVisualTokens.green,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

final class _LearningMapPrerequisiteConnector extends StatelessWidget {
  const _LearningMapPrerequisiteConnector({required this.target});

  final LearningMapElementViewModel target;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final rule = target.prerequisites;

    if (rule == null) {
      return const SizedBox.shrink();
    }

    final summary = _summarizePrerequisite(rule);

    return Padding(
      key: Key('learning-map-topology-${target.pathElementId}'),
      padding: EdgeInsets.only(left: compact ? 34 : 40, right: 4),
      child: Container(
        key: Key('learning-map-prerequisite-summary-${target.pathElementId}'),
        constraints: const BoxConstraints(minHeight: 36),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
        decoration: BoxDecoration(
          color: summary.accent.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: summary.accent.withValues(alpha: 0.22)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: summary.accent.withValues(alpha: 0.11),
                shape: BoxShape.circle,
              ),
              child: Icon(summary.icon, size: 15, color: summary.accent),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                summary.label,
                key: Key(
                  'learning-map-prerequisite-label-${target.pathElementId}',
                ),
                style: const TextStyle(
                  color: LearningMapVisualTokens.textSecondary,
                  fontSize: 11,
                  height: 1.25,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PrerequisiteSummarySpec {
  const _PrerequisiteSummarySpec({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;
}

_PrerequisiteSummarySpec _summarizePrerequisite(
  LearningMapPrerequisiteViewModel rule,
) {
  return switch (rule.type) {
    LearningMapPrerequisiteType.activityCompleted => _PrerequisiteSummarySpec(
      label: rule.sourcePathElementId == null
          ? 'Completa uma miss\u00e3o para desbloquear'
          : 'Completa a miss\u00e3o anterior para desbloquear',
      icon: Icons.lock_open_rounded,
      accent: LearningMapVisualTokens.cyan,
    ),
    LearningMapPrerequisiteType.competencyAchieved =>
      const _PrerequisiteSummarySpec(
        label: 'Ganha a compet\u00eancia necess\u00e1ria para desbloquear',
        icon: Icons.workspace_premium_rounded,
        accent: LearningMapVisualTokens.gold,
      ),
    LearningMapPrerequisiteType.group => _summarizePrerequisiteGroup(rule),
  };
}

_PrerequisiteSummarySpec _summarizePrerequisiteGroup(
  LearningMapPrerequisiteViewModel rule,
) {
  final operator = rule.operator;

  if (operator == null) {
    throw StateError('A prerequisite group requires an operator.');
  }

  final flatActivityGroup = rule.rules.every(
    (child) => child.type == LearningMapPrerequisiteType.activityCompleted,
  );

  final flatCompetencyGroup = rule.rules.every(
    (child) => child.type == LearningMapPrerequisiteType.competencyAchieved,
  );

  if (operator == PrerequisiteOperator.any) {
    if (flatActivityGroup) {
      return _PrerequisiteSummarySpec(
        label:
            'Completa 1 de ${rule.rules.length} miss\u00f5es para desbloquear',
        icon: Icons.alt_route_rounded,
        accent: LearningMapVisualTokens.cyan,
      );
    }

    if (flatCompetencyGroup) {
      return _PrerequisiteSummarySpec(
        label:
            'Ganha 1 de ${rule.rules.length} compet\u00eancias para desbloquear',
        icon: Icons.workspace_premium_rounded,
        accent: LearningMapVisualTokens.gold,
      );
    }

    return _PrerequisiteSummarySpec(
      label:
          'Cumpre 1 de ${rule.rules.length} condi\u00e7\u00f5es para desbloquear',
      icon: Icons.alt_route_rounded,
      accent: LearningMapVisualTokens.cyan,
    );
  }

  if (flatActivityGroup) {
    return _PrerequisiteSummarySpec(
      label: rule.rules.length == 1
          ? 'Completa a miss\u00e3o anterior para desbloquear'
          : 'Completa as ${rule.rules.length} miss\u00f5es para desbloquear',
      icon: Icons.lock_open_rounded,
      accent: LearningMapVisualTokens.gold,
    );
  }

  if (flatCompetencyGroup) {
    return _PrerequisiteSummarySpec(
      label: rule.rules.length == 1
          ? 'Ganha a compet\u00eancia necess\u00e1ria para desbloquear'
          : 'Ganha as ${rule.rules.length} compet\u00eancias para desbloquear',
      icon: Icons.workspace_premium_rounded,
      accent: LearningMapVisualTokens.gold,
    );
  }

  return const _PrerequisiteSummarySpec(
    label: 'Completa todas as condi\u00e7\u00f5es para desbloquear',
    icon: Icons.lock_open_rounded,
    accent: LearningMapVisualTokens.gold,
  );
}

final class _RouteElement extends StatelessWidget {
  const _RouteElement({required this.element, required this.onActivityTap});

  final LearningMapElementViewModel element;
  final LearningMapActivityTap? onActivityTap;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final child = element.isActivity
        ? LearningMapActivityNode(
            element: element,
            onTap: onActivityTap == null ? null : () => onActivityTap!(element),
          )
        : _SpecialPathElement(element: element);

    return Row(
      key: Key('learning-map-route-${element.pathElementId}'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: SizedBox(
            width: compact ? 30 : 34,
            child: Align(
              alignment: Alignment.topCenter,
              child: _RouteMarker(element: element),
            ),
          ),
        ),
        SizedBox(width: compact ? 3 : 4),
        Expanded(child: child),
      ],
    );
  }
}

final class _RouteMarker extends StatelessWidget {
  const _RouteMarker({required this.element});

  final LearningMapElementViewModel element;

  @override
  Widget build(BuildContext context) {
    final marker = _routeMarkerSpec(element);

    return AnimatedContainer(
      key: Key('learning-map-route-marker-${element.pathElementId}'),
      duration: const Duration(milliseconds: 180),
      width: element.isPrimaryRecommendation ? 25 : 21,
      height: element.isPrimaryRecommendation ? 25 : 21,
      decoration: BoxDecoration(
        color: marker.fill,
        shape: BoxShape.circle,
        border: Border.all(color: marker.accent, width: 2),
        boxShadow: element.isPrimaryRecommendation
            ? <BoxShadow>[
                BoxShadow(
                  color: LearningMapVisualTokens.blue.withValues(alpha: 0.22),
                  blurRadius: 10,
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: Icon(marker.icon, size: 13, color: marker.iconColor),
    );
  }
}

final class _RouteMarkerSpec {
  const _RouteMarkerSpec({
    required this.icon,
    required this.accent,
    required this.fill,
    required this.iconColor,
  });

  final IconData icon;
  final Color accent;
  final Color fill;
  final Color iconColor;
}

_RouteMarkerSpec _routeMarkerSpec(LearningMapElementViewModel element) {
  if (element.isPrimaryRecommendation) {
    return const _RouteMarkerSpec(
      icon: Icons.play_arrow_rounded,
      accent: LearningMapVisualTokens.blue,
      fill: LearningMapVisualTokens.blue,
      iconColor: Colors.white,
    );
  }

  return switch (element.state) {
    LearningActivityState.completed => const _RouteMarkerSpec(
      icon: Icons.check_rounded,
      accent: LearningMapVisualTokens.green,
      fill: LearningMapVisualTokens.green,
      iconColor: Colors.white,
    ),
    LearningActivityState.inProgress => const _RouteMarkerSpec(
      icon: Icons.directions_walk_rounded,
      accent: LearningMapVisualTokens.gold,
      fill: Color(0xFFFFF5D9),
      iconColor: LearningMapVisualTokens.gold,
    ),
    LearningActivityState.available => const _RouteMarkerSpec(
      icon: Icons.circle_rounded,
      accent: LearningMapVisualTokens.blue,
      fill: Colors.white,
      iconColor: LearningMapVisualTokens.blue,
    ),
    LearningActivityState.locked => const _RouteMarkerSpec(
      icon: Icons.lock_rounded,
      accent: LearningMapVisualTokens.muted,
      fill: Colors.white,
      iconColor: LearningMapVisualTokens.muted,
    ),
  };
}

/// Final visual grammar for non-activity path elements.
///
/// These widgets display data already present in the read model.
/// They do not calculate availability or progression.
final class _SpecialPathElement extends StatelessWidget {
  const _SpecialPathElement({required this.element});

  final LearningMapElementViewModel element;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final visual = _specialVisual(element.elementType);
    final state = _structuralStateVisual(element.state);

    return Container(
      key: Key('learning-map-structural-${element.pathElementId}'),
      constraints: BoxConstraints(minHeight: compact ? 60 : 64),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 12,
        vertical: compact ? 9 : 10,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          visual.accent.withValues(alpha: 0.055),
          LearningMapVisualTokens.surface,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: visual.accent.withValues(alpha: 0.26)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: LearningMapVisualTokens.shadow,
            blurRadius: 12,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Row(
        children: <Widget>[
          Container(
            key: Key(
              'learning-map-special-${element.elementType.name}-${element.pathElementId}',
            ),
            width: compact ? 38 : 40,
            height: compact ? 38 : 40,
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(visual.icon, color: visual.accent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  visual.label,
                  style: const TextStyle(
                    color: LearningMapVisualTokens.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _structuralSubtitle(element.elementType),
                  style: const TextStyle(
                    color: LearningMapVisualTokens.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            key: Key('learning-map-structural-state-${element.pathElementId}'),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              color: state.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(state.icon, size: 13, color: state.color),
                const SizedBox(width: 4),
                Text(
                  state.label,
                  style: TextStyle(
                    color: state.color,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _structuralSubtitle(PathElementType type) {
  return switch (type) {
    PathElementType.checkpoint => 'Rev\u00ea e consolida o que aprendeste',
    PathElementType.scene => 'Pratica num contexto da jornada',
    PathElementType.reward => 'Celebra o progresso alcan\u00e7ado',
    PathElementType.activity => throw StateError(
      'Activities must use LearningMapActivityNode.',
    ),
  };
}

final class _SpecialVisualSpec {
  const _SpecialVisualSpec({
    required this.label,
    required this.icon,
    required this.accent,
  });

  final String label;
  final IconData icon;
  final Color accent;
}

final class _StructuralStateSpec {
  const _StructuralStateSpec({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;
}

_SpecialVisualSpec _specialVisual(PathElementType type) {
  return switch (type) {
    PathElementType.checkpoint => const _SpecialVisualSpec(
      label: 'Checkpoint',
      icon: Icons.flag_outlined,
      accent: LearningMapVisualTokens.blue,
    ),
    PathElementType.scene => const _SpecialVisualSpec(
      label: 'Cena',
      icon: Icons.forum_outlined,
      accent: LearningMapVisualTokens.cyan,
    ),
    PathElementType.reward => const _SpecialVisualSpec(
      label: 'Recompensa',
      icon: Icons.emoji_events_outlined,
      accent: LearningMapVisualTokens.gold,
    ),
    PathElementType.activity => throw StateError(
      'Activities must use LearningMapActivityNode.',
    ),
  };
}

_StructuralStateSpec _structuralStateVisual(LearningActivityState state) {
  return switch (state) {
    LearningActivityState.locked => const _StructuralStateSpec(
      label: 'Bloqueado',
      icon: Icons.lock_outline_rounded,
      color: LearningMapVisualTokens.muted,
    ),
    LearningActivityState.available => const _StructuralStateSpec(
      label: 'Dispon\u00edvel',
      icon: Icons.circle_outlined,
      color: LearningMapVisualTokens.cyan,
    ),
    LearningActivityState.inProgress => const _StructuralStateSpec(
      label: 'Em curso',
      icon: Icons.timelapse_rounded,
      color: LearningMapVisualTokens.gold,
    ),
    LearningActivityState.completed => const _StructuralStateSpec(
      label: 'Conclu\u00eddo',
      icon: Icons.check_circle_outline_rounded,
      color: LearningMapVisualTokens.green,
    ),
  };
}
