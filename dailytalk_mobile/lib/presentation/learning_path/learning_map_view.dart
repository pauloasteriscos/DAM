import 'package:flutter/material.dart';

import '../../domain/learning/learning_enums.dart';
import 'learning_map_view_model.dart';
import 'learning_map_visuals.dart';

typedef LearningMapActivityTap =
    void Function(LearningMapElementViewModel element);

/// Scrollable composition of the DailyTalk Learning Path.
///
/// This widget consumes only [LearningMapViewModel]. It does not read
/// SQLite, access the network or execute pedagogical rules.
final class LearningMapView extends StatelessWidget {
  const LearningMapView({
    required this.model,
    this.onActivityTap,
    this.scrollController,
    super.key,
  });

  final LearningMapViewModel model;
  final LearningMapActivityTap? onActivityTap;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: LearningMapVisualTokens.background,
      child: CustomScrollView(
        key: const Key('learning-map-scroll-view'),
        controller: scrollController,
        slivers: <Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            sliver: SliverToBoxAdapter(
              child: LearningMapContextHeader(model: model),
            ),
          ),
          for (
            var journeyIndex = 0;
            journeyIndex < model.journeys.length;
            journeyIndex++
          )
            SliverToBoxAdapter(
              child: _JourneySection(
                journey: model.journeys[journeyIndex],
                journeyIndex: journeyIndex,
                onActivityTap: onActivityTap,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 28)),
        ],
      ),
    );
  }
}

final class _JourneySection extends StatelessWidget {
  const _JourneySection({
    required this.journey,
    required this.journeyIndex,
    required this.onActivityTap,
  });

  final LearningMapJourneyViewModel journey;
  final int journeyIndex;
  final LearningMapActivityTap? onActivityTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: Key('learning-map-journey-${journey.id}'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _JourneyHeader(index: journeyIndex, title: journey.title),
          const SizedBox(height: 12),
          for (
            var stageIndex = 0;
            stageIndex < journey.stages.length;
            stageIndex++
          ) ...<Widget>[
            _StageSection(
              stage: journey.stages[stageIndex],
              stageIndex: stageIndex,
              onActivityTap: onActivityTap,
            ),
            if (stageIndex != journey.stages.length - 1)
              const SizedBox(height: 18),
          ],
        ],
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
    return Row(
      children: <Widget>[
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: LearningMapVisualTokens.cyan.withValues(alpha: 0.12),
            shape: BoxShape.circle,
            border: Border.all(
              color: LearningMapVisualTokens.cyan.withValues(alpha: 0.3),
            ),
          ),
          child: const Icon(
            Icons.flight_takeoff_rounded,
            color: LearningMapVisualTokens.cyan,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'JORNADA ${index + 1}',
                style: const TextStyle(
                  color: LearningMapVisualTokens.cyan,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: LearningMapVisualTokens.textPrimary,
                  fontSize: 20,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ],
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
    return Container(
      key: Key('learning-map-stage-${stage.id}'),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
      decoration: BoxDecoration(
        color: LearningMapVisualTokens.surface.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: LearningMapVisualTokens.cyan.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StageHeader(stage: stage, stageIndex: stageIndex),
          const SizedBox(height: 16),
          Stack(
            children: <Widget>[
              if (stage.elements.length > 1)
                Positioned(
                  left: 16,
                  top: 18,
                  bottom: 18,
                  child: Container(
                    width: 2,
                    color: LearningMapVisualTokens.cyan.withValues(alpha: 0.16),
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
                      const SizedBox(height: 8),
                    ],
                    _RouteElement(
                      element: stage.elements[elementIndex],
                      onActivityTap: onActivityTap,
                    ),
                    if (elementIndex != stage.elements.length - 1)
                      const SizedBox(height: 12),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
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
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    stage.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LearningMapVisualTokens.textPrimary,
                      fontSize: 17,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              key: Key('learning-map-stage-count-${stage.id}'),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: LearningMapVisualTokens.background.withValues(
                  alpha: 0.58,
                ),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${stage.completedActivityCount} / ${stage.activityCount}',
                style: const TextStyle(
                  color: LearningMapVisualTokens.textPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        if (stage.activityCount > 0) ...<Widget>[
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              key: Key('learning-map-stage-progress-${stage.id}'),
              value: stage.completionRatio,
              minHeight: 5,
              backgroundColor: LearningMapVisualTokens.background.withValues(
                alpha: 0.7,
              ),
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
    final rule = target.prerequisites;

    if (rule == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      key: Key('learning-map-topology-${target.pathElementId}'),
      padding: const EdgeInsets.only(left: 40, right: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _PrerequisiteRuleConnector(
            rule: rule,
            targetPathElementId: target.pathElementId,
            branchPath: 'root',
          ),
          const SizedBox(height: 3),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Column(
              children: <Widget>[
                Container(
                  width: 2,
                  height: 8,
                  color: LearningMapVisualTokens.cyan.withValues(alpha: 0.26),
                ),
                const Icon(
                  Icons.arrow_drop_down_rounded,
                  color: LearningMapVisualTokens.cyan,
                  size: 18,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _PrerequisiteRuleConnector extends StatelessWidget {
  const _PrerequisiteRuleConnector({
    required this.rule,
    required this.targetPathElementId,
    required this.branchPath,
  });

  final LearningMapPrerequisiteViewModel rule;
  final String targetPathElementId;
  final String branchPath;

  @override
  Widget build(BuildContext context) {
    return switch (rule.type) {
      LearningMapPrerequisiteType.activityCompleted =>
        _ActivityDependencyConnector(
          rule: rule,
          targetPathElementId: targetPathElementId,
          branchPath: branchPath,
        ),
      LearningMapPrerequisiteType.competencyAchieved =>
        _CompetencyRequirementConnector(
          targetPathElementId: targetPathElementId,
          branchPath: branchPath,
        ),
      LearningMapPrerequisiteType.group => _PrerequisiteGroupConnector(
        rule: rule,
        targetPathElementId: targetPathElementId,
        branchPath: branchPath,
      ),
    };
  }
}

final class _ActivityDependencyConnector extends StatelessWidget {
  const _ActivityDependencyConnector({
    required this.rule,
    required this.targetPathElementId,
    required this.branchPath,
  });

  final LearningMapPrerequisiteViewModel rule;
  final String targetPathElementId;
  final String branchPath;

  @override
  Widget build(BuildContext context) {
    final sourcePathElementId = rule.sourcePathElementId;

    if (sourcePathElementId == null) {
      return _UnresolvedActivityRequirement(
        targetPathElementId: targetPathElementId,
        branchPath: branchPath,
      );
    }

    return Container(
      key: Key(
        'learning-map-edge-$sourcePathElementId-'
        '$targetPathElementId-$branchPath',
      ),
      constraints: const BoxConstraints(minHeight: 34),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 30,
            height: 30,
            child: Stack(
              children: <Widget>[
                Positioned(
                  left: 7,
                  top: 0,
                  bottom: 14,
                  child: Container(
                    width: 2,
                    color: LearningMapVisualTokens.cyan.withValues(alpha: 0.42),
                  ),
                ),
                Positioned(
                  left: 7,
                  right: 7,
                  top: 14,
                  child: Container(
                    height: 2,
                    color: LearningMapVisualTokens.cyan.withValues(alpha: 0.42),
                  ),
                ),
                const Positioned(
                  right: 0,
                  top: 7,
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 16,
                    color: LearningMapVisualTokens.cyan,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: LearningMapVisualTokens.cyan.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: LearningMapVisualTokens.cyan.withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                children: <Widget>[
                  Icon(
                    Icons.route_outlined,
                    size: 15,
                    color: LearningMapVisualTokens.cyan,
                  ),
                  SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'Miss\u00e3o necess\u00e1ria',
                      style: TextStyle(
                        color: LearningMapVisualTokens.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _UnresolvedActivityRequirement extends StatelessWidget {
  const _UnresolvedActivityRequirement({
    required this.targetPathElementId,
    required this.branchPath,
  });

  final String targetPathElementId;
  final String branchPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(
        'learning-map-unresolved-activity-'
        '$targetPathElementId-$branchPath',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: LearningMapVisualTokens.muted.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LearningMapVisualTokens.muted.withValues(alpha: 0.2),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.link_off_rounded,
            size: 15,
            color: LearningMapVisualTokens.muted,
          ),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Atividade necess\u00e1ria',
              style: TextStyle(
                color: LearningMapVisualTokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _CompetencyRequirementConnector extends StatelessWidget {
  const _CompetencyRequirementConnector({
    required this.targetPathElementId,
    required this.branchPath,
  });

  final String targetPathElementId;
  final String branchPath;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key(
        'learning-map-competency-'
        '$targetPathElementId-$branchPath',
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: LearningMapVisualTokens.gold.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: LearningMapVisualTokens.gold.withValues(alpha: 0.22),
        ),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.workspace_premium_outlined,
            size: 15,
            color: LearningMapVisualTokens.gold,
          ),
          SizedBox(width: 7),
          Flexible(
            child: Text(
              'Compet\u00eancia necess\u00e1ria',
              style: TextStyle(
                color: LearningMapVisualTokens.textSecondary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _PrerequisiteGroupConnector extends StatelessWidget {
  const _PrerequisiteGroupConnector({
    required this.rule,
    required this.targetPathElementId,
    required this.branchPath,
  });

  final LearningMapPrerequisiteViewModel rule;
  final String targetPathElementId;
  final String branchPath;

  @override
  Widget build(BuildContext context) {
    final operator = rule.operator;

    if (operator == null) {
      throw StateError('A prerequisite group requires an operator.');
    }

    final isAny = operator == PrerequisiteOperator.any;

    final accent = isAny
        ? LearningMapVisualTokens.cyan
        : LearningMapVisualTokens.gold;

    final label = isAny ? 'QUALQUER UMA' : 'TODAS';

    final icon = isAny ? Icons.call_split_rounded : Icons.call_merge_rounded;

    return Container(
      key: Key(
        'learning-map-group-${operator.name}-'
        '$targetPathElementId-$branchPath',
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: accent,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.only(left: 9),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: accent.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
            ),
            child: Column(
              children: <Widget>[
                for (
                  var index = 0;
                  index < rule.rules.length;
                  index++
                ) ...<Widget>[
                  _PrerequisiteRuleConnector(
                    rule: rule.rules[index],
                    targetPathElementId: targetPathElementId,
                    branchPath: '$branchPath-$index',
                  ),
                  if (index != rule.rules.length - 1) const SizedBox(height: 7),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

final class _RouteElement extends StatelessWidget {
  const _RouteElement({required this.element, required this.onActivityTap});

  final LearningMapElementViewModel element;
  final LearningMapActivityTap? onActivityTap;

  @override
  Widget build(BuildContext context) {
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
          padding: const EdgeInsets.only(top: 13),
          child: Container(
            width: 34,
            alignment: Alignment.topCenter,
            child: Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: element.isPrimaryRecommendation
                    ? LearningMapVisualTokens.cyan
                    : LearningMapVisualTokens.surfaceElevated,
                shape: BoxShape.circle,
                border: Border.all(
                  color: LearningMapVisualTokens.cyan.withValues(alpha: 0.45),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(child: child),
      ],
    );
  }
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
    final visual = _specialVisual(element.elementType);
    final state = _structuralStateVisual(element.state);

    return Container(
      key: Key('learning-map-structural-${element.pathElementId}'),
      constraints: const BoxConstraints(minHeight: 70),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: visual.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: visual.accent.withValues(alpha: 0.32)),
      ),
      child: Row(
        children: <Widget>[
          Container(
            key: Key(
              'learning-map-special-${element.elementType.name}-${element.pathElementId}',
            ),
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: visual.accent.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(visual.icon, color: visual.accent, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  visual.label,
                  style: TextStyle(
                    color: visual.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                const Text(
                  'Elemento da jornada',
                  style: TextStyle(
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
                    fontWeight: FontWeight.w700,
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
      accent: LearningMapVisualTokens.gold,
    ),
    PathElementType.scene => const _SpecialVisualSpec(
      label: 'Cena',
      icon: Icons.forum_outlined,
      accent: LearningMapVisualTokens.cyan,
    ),
    PathElementType.reward => const _SpecialVisualSpec(
      label: 'Recompensa',
      icon: Icons.emoji_events_outlined,
      accent: LearningMapVisualTokens.green,
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
