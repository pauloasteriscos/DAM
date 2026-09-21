import 'package:flutter/material.dart';

import '../../domain/learning/learning_enums.dart';
import '../../l10n/app_localizations.dart';
import '../../state/app_locale_controller.dart';
import 'learning_map_view_model.dart';

String _translateLearningMapUi(
  String source, {
  Map<String, Object?> parameters = const <String, Object?>{},
}) {
  return AppTranslations.translate(
    source,
    AppLocaleController.instance.languageCode,
    parameters: parameters,
  );
}

/// Shared visual tokens for the DailyTalk Learning Path.
///
/// Presentation only. No pedagogical decision is made here.
abstract final class LearningMapVisualTokens {
  // Light learning-path canvas inspired by the approved DailyTalk mockups.
  static const Color background = Color(0xFFF3F8FC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFEAF3FB);
  static const Color surfaceMuted = Color(0xFFF8FBFE);
  static const Color outline = Color(0xFFD7E5F0);
  static const Color shadow = Color(0x1A123A5A);

  // Hero / contextual identity.
  static const Color heroStart = Color(0xFF073965);
  static const Color heroEnd = Color(0xFF041C34);
  static const Color heroText = Color(0xFFF8FCFF);
  static const Color heroTextSecondary = Color(0xFFC8DBEA);

  // Semantic accents. Activity type, pedagogical state and sync remain
  // independent visual signals.
  static const Color cyan = Color(0xFF18B9F2);
  static const Color blue = Color(0xFF147CF3);
  static const Color gold = Color(0xFFF2AE24);
  static const Color green = Color(0xFF16A667);
  static const Color purple = Color(0xFF744AE4);
  static const Color magenta = Color(0xFFC63BCB);
  static const Color teal = Color(0xFF16A79B);
  static const Color muted = Color(0xFF8294AA);
  static const Color danger = Color(0xFFD8505A);

  static const Color textPrimary = Color(0xFF102D50);
  static const Color textSecondary = Color(0xFF627992);
}

/// Contextual header driven exclusively by [LearningMapViewModel].
final class LearningMapContextHeader extends StatelessWidget {
  const LearningMapContextHeader({required this.model, super.key});

  final LearningMapViewModel model;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 390;
    final next = model.nextRecommendedElement;
    final rawNextTitle = next?.title?.trim();
    final nextTitle = rawNextTitle == null || rawNextTitle.isEmpty
        ? null
        : rawNextTitle;
    final contextInfo = _resolveContext(next);
    final syncSpec = _aggregateSyncSpec(model);
    final percent = (model.completionRatio * 100).round();

    return Container(
      key: const Key('learning-map-header'),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[
            LearningMapVisualTokens.heroStart,
            LearningMapVisualTokens.heroEnd,
          ],
        ),
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x26041C34),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(compact ? 24 : 28),
        child: Stack(
          children: <Widget>[
            const Positioned(right: -30, top: -24, child: _HeroDecoration()),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 18 : 22,
                compact ? 18 : 20,
                compact ? 18 : 22,
                compact ? 18 : 22,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '${contextInfo.journey} \u2022 ${contextInfo.stage}',
                              key: const Key('learning-map-context'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: LearningMapVisualTokens.cyan,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.35,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _HeroSyncBadge(spec: syncSpec),
                    ],
                  ),
                  SizedBox(height: compact ? 15 : 18),
                  Text(
                    model.title,
                    key: const Key('learning-map-title'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LearningMapVisualTokens.heroText,
                      fontSize: compact ? 25 : 28,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.45,
                    ),
                  ),
                  SizedBox(height: compact ? 6 : 8),
                  Text(
                    _translateLearningMapUi(
                      'Cada missão leva-te mais longe. Escolhe o teu próximo passo.',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: LearningMapVisualTokens.heroTextSecondary,
                      fontSize: compact ? 13 : 14,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: compact ? 16 : 20),
                  Container(
                    key: const Key('learning-map-progress-card'),
                    padding: EdgeInsets.all(compact ? 12 : 14),
                    decoration: BoxDecoration(
                      color: LearningMapVisualTokens.surface,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const <BoxShadow>[
                        BoxShadow(
                          color: Color(0x1A041C34),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Row(
                      children: <Widget>[
                        SizedBox(
                          width: compact ? 54 : 62,
                          height: compact ? 54 : 62,
                          child: Stack(
                            alignment: Alignment.center,
                            children: <Widget>[
                              SizedBox(
                                width: compact ? 50 : 58,
                                height: compact ? 50 : 58,
                                child: CircularProgressIndicator(
                                  key: const Key('learning-map-progress'),
                                  value: model.completionRatio,
                                  strokeWidth: compact ? 6 : 7,
                                  backgroundColor:
                                      LearningMapVisualTokens.surfaceElevated,
                                  valueColor:
                                      const AlwaysStoppedAnimation<Color>(
                                        LearningMapVisualTokens.blue,
                                      ),
                                ),
                              ),
                              Text(
                                '$percent%',
                                style: TextStyle(
                                  color: LearningMapVisualTokens.textPrimary,
                                  fontSize: compact ? 12 : 14,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: compact ? 11 : 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                _translateLearningMapUi(
                                  '{completed} de {total} missões concluídas',
                                  parameters: <String, Object?>{
                                    'completed': model.completedActivityCount,
                                    'total': model.totalActivityCount,
                                  },
                                ),
                                style: TextStyle(
                                  color: LearningMapVisualTokens.textPrimary,
                                  fontSize: compact ? 13 : 14,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _translateLearningMapUi(
                                  'Continua a construir o teu percurso.',
                                ),
                                style: const TextStyle(
                                  color: LearningMapVisualTokens.textSecondary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!compact) ...<Widget>[
                          const SizedBox(width: 8),
                          Container(
                            key: const Key('learning-map-progress-count'),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: LearningMapVisualTokens.surfaceElevated,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '${model.completedActivityCount}/${model.totalActivityCount}',
                              style: const TextStyle(
                                color: LearningMapVisualTokens.blue,
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (nextTitle != null) ...<Widget>[
                    SizedBox(height: compact ? 10 : 12),
                    Container(
                      key: const Key('learning-map-next-mission'),
                      padding: EdgeInsets.symmetric(
                        horizontal: compact ? 12 : 14,
                        vertical: compact ? 10 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: LearningMapVisualTokens.surface.withValues(
                          alpha: 0.96,
                        ),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: LearningMapVisualTokens.cyan.withValues(
                            alpha: 0.34,
                          ),
                        ),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: compact ? 38 : 40,
                            height: compact ? 38 : 40,
                            decoration: const BoxDecoration(
                              color: Color(0xFFE7F6FF),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              color: LearningMapVisualTokens.blue,
                              size: 25,
                            ),
                          ),
                          const SizedBox(width: 11),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _translateLearningMapUi('Próxima missão'),
                                  style: const TextStyle(
                                    color: LearningMapVisualTokens.blue,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
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
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            color: LearningMapVisualTokens.blue,
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
            ),
          ],
        ),
      ),
    );
  }

  _HeaderContext _resolveContext(LearningMapElementViewModel? next) {
    if (next != null) {
      for (final journey in model.journeys) {
        for (final stage in journey.stages) {
          for (final element in stage.elements) {
            if (element.pathElementId == next.pathElementId) {
              return _HeaderContext(journey: journey.title, stage: stage.title);
            }
          }
        }
      }
    }

    if (model.journeys.isNotEmpty) {
      final journey = model.journeys.first;

      return _HeaderContext(
        journey: journey.title,
        stage: journey.stages.isEmpty
            ? _translateLearningMapUi('Percurso de aprendizagem')
            : journey.stages.first.title,
      );
    }

    return _HeaderContext(
      journey: _translateLearningMapUi('Percurso de aprendizagem'),
      stage: _translateLearningMapUi('Próximo passo'),
    );
  }
}

final class _HeaderContext {
  const _HeaderContext({required this.journey, required this.stage});

  final String journey;
  final String stage;
}

final class _HeroDecoration extends StatelessWidget {
  const _HeroDecoration();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 190,
      height: 150,
      child: Stack(
        children: <Widget>[
          Positioned(
            right: 12,
            top: 0,
            child: Container(
              width: 118,
              height: 118,
              decoration: BoxDecoration(
                color: LearningMapVisualTokens.cyan.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Positioned(
            right: 36,
            top: 28,
            child: Icon(
              Icons.location_city_rounded,
              color: LearningMapVisualTokens.cyan.withValues(alpha: 0.17),
              size: 96,
            ),
          ),
          Positioned(
            right: 104,
            top: 18,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: LearningMapVisualTokens.gold.withValues(alpha: 0.9),
              size: 18,
            ),
          ),
          Positioned(
            right: 18,
            top: 92,
            child: Icon(
              Icons.flight_rounded,
              color: LearningMapVisualTokens.heroText.withValues(alpha: 0.25),
              size: 24,
            ),
          ),
        ],
      ),
    );
  }
}

final class _HeroSyncBadge extends StatelessWidget {
  const _HeroSyncBadge({required this.spec});

  final _SyncStateSpec spec;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: _translateLearningMapUi(spec.label),
      child: Container(
        key: const Key('learning-map-hero-sync'),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: LearningMapVisualTokens.heroText.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: spec.color.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(spec.icon, color: spec.color, size: 15),
            const SizedBox(width: 6),
            Text(
              _translateLearningMapUi(spec.heroLabel),
              style: const TextStyle(
                color: LearningMapVisualTokens.heroText,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _LocalFallbackBadge extends StatelessWidget {
  const _LocalFallbackBadge();

  @override
  Widget build(BuildContext context) {
    return Row(
      key: const Key('learning-map-fallback-badge'),
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Icon(
          Icons.offline_bolt_outlined,
          size: 15,
          color: LearningMapVisualTokens.gold,
        ),
        const SizedBox(width: 6),
        Text(
          _translateLearningMapUi('Conteúdo local recuperado'),
          style: const TextStyle(
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
    final compact = MediaQuery.sizeOf(context).width < 390;

    assert(
      element.isActivity,
      'LearningMapActivityNode requires an activity element.',
    );

    final stateSpec = _stateSpec(element.state);
    final typeSpec = _activityTypeSpec(element.activityType);
    final isPrimary = element.isPrimaryRecommendation;
    final isChallenge =
        element.activityType == LearningActivityType.integratedChallenge;

    final nodeFill = Color.alphaBlend(
      stateSpec.fill.withValues(alpha: element.isLocked ? 0.58 : 0.24),
      typeSpec.fill,
    );

    final rawTitle = element.title?.trim();
    final resolvedTitle = rawTitle == null || rawTitle.isEmpty
        ? _translateLearningMapUi('Missão')
        : rawTitle;
    final enabled = element.canOpen && onTap != null;

    final iconSize = isPrimary
        ? (compact ? 44.0 : 46.0)
        : (isChallenge ? (compact ? 40.0 : 44.0) : (compact ? 38.0 : 40.0));
    final cardMinHeight = isPrimary
        ? (compact ? 88.0 : 92.0)
        : (isChallenge ? (compact ? 78.0 : 82.0) : (compact ? 66.0 : 70.0));

    return Opacity(
      opacity: element.isLocked ? (isChallenge ? 0.86 : 0.76) : 1,
      child: Material(
        key: Key('learning-map-node-${element.pathElementId}'),
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(isPrimary ? 20 : 18),
          onTap: enabled ? onTap : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            constraints: BoxConstraints(minHeight: cardMinHeight),
            padding: EdgeInsets.symmetric(
              horizontal: isPrimary ? (compact ? 12 : 14) : (compact ? 10 : 12),
              vertical: isPrimary ? (compact ? 12 : 14) : (compact ? 9 : 10),
            ),
            decoration: BoxDecoration(
              color: nodeFill,
              borderRadius: BorderRadius.circular(isPrimary ? 20 : 18),
              border: Border.all(
                color:
                    (isPrimary ? LearningMapVisualTokens.blue : typeSpec.accent)
                        .withValues(
                          alpha: isPrimary ? 0.92 : (isChallenge ? 0.52 : 0.30),
                        ),
                width: isPrimary ? 2 : (isChallenge ? 1.5 : 1),
              ),
              boxShadow: <BoxShadow>[
                BoxShadow(
                  color: isPrimary
                      ? LearningMapVisualTokens.blue.withValues(alpha: 0.13)
                      : isChallenge
                      ? LearningMapVisualTokens.gold.withValues(alpha: 0.15)
                      : LearningMapVisualTokens.shadow.withValues(alpha: 0.55),
                  blurRadius: isPrimary ? 20 : (isChallenge ? 14 : 9),
                  offset: Offset(0, isPrimary ? 6 : (isChallenge ? 5 : 3)),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: typeSpec.accent.withValues(alpha: 0.13),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        typeSpec.icon,
                        key: Key(
                          'learning-map-type-icon-${typeSpec.key}-${element.pathElementId}',
                        ),
                        color: typeSpec.accent,
                        size: isPrimary ? 25 : 22,
                      ),
                    ),
                    SizedBox(
                      width: isPrimary
                          ? (compact ? 10 : 12)
                          : (compact ? 8 : 10),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            _translateLearningMapUi(typeSpec.label),
                            style: TextStyle(
                              color: typeSpec.accent,
                              fontSize: isPrimary ? 11 : 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            resolvedTitle,
                            maxLines: isPrimary || isChallenge ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: LearningMapVisualTokens.textPrimary,
                              fontSize: isPrimary
                                  ? (compact ? 15 : 16)
                                  : (compact ? 14 : 15),
                              height: 1.16,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          if (element.instructions?.trim().isNotEmpty ?? false)
                            Padding(
                              padding: const EdgeInsets.only(top: 3),
                              child: Text(
                                element.instructions!.trim(),
                                maxLines: isPrimary || isChallenge ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: LearningMapVisualTokens.textSecondary,
                                  fontSize: 11,
                                  height: 1.24,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    if (isPrimary)
                      const _RecommendationBadge()
                    else if (isChallenge)
                      _ChallengeSparkBadge(elementId: element.pathElementId),
                  ],
                ),
                SizedBox(height: isPrimary ? 10 : 7),
                _StateBadge(elementId: element.pathElementId, spec: stateSpec),
                if (isPrimary && enabled) ...<Widget>[
                  const SizedBox(height: 11),
                  Container(
                    key: Key('learning-map-continue-${element.pathElementId}'),
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: <Color>[
                          LearningMapVisualTokens.cyan,
                          LearningMapVisualTokens.blue,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 23,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _translateLearningMapUi('Continuar'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _ChallengeSparkBadge extends StatelessWidget {
  const _ChallengeSparkBadge({required this.elementId});

  final String elementId;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: Key('learning-map-challenge-spark-$elementId'),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        color: LearningMapVisualTokens.gold.withValues(alpha: 0.12),
        shape: BoxShape.circle,
        border: Border.all(
          color: LearningMapVisualTokens.gold.withValues(alpha: 0.32),
        ),
      ),
      child: const Icon(
        Icons.auto_awesome_rounded,
        color: LearningMapVisualTokens.gold,
        size: 17,
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
        color: const Color(0xFFE7F2FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _translateLearningMapUi('A seguir'),
        style: const TextStyle(
          color: LearningMapVisualTokens.blue,
          fontSize: 10,
          fontWeight: FontWeight.w900,
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
            _translateLearningMapUi(spec.label),
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

final class _ActivityTypeSpec {
  const _ActivityTypeSpec({
    required this.key,
    required this.label,
    required this.icon,
    required this.accent,
    required this.fill,
  });

  final String key;
  final String label;
  final IconData icon;
  final Color accent;
  final Color fill;
}

_ActivityTypeSpec _activityTypeSpec(LearningActivityType? type) {
  return switch (type) {
    LearningActivityType.vocabulary => const _ActivityTypeSpec(
      key: 'vocabulary',
      label: 'Vocabul\u00e1rio',
      icon: Icons.menu_book_rounded,
      accent: LearningMapVisualTokens.green,
      fill: Color(0xFFECF9F2),
    ),
    LearningActivityType.dialogue => const _ActivityTypeSpec(
      key: 'dialogue',
      label: 'Di\u00e1logo',
      icon: Icons.forum_rounded,
      accent: LearningMapVisualTokens.blue,
      fill: Color(0xFFEDF5FF),
    ),
    LearningActivityType.speech => const _ActivityTypeSpec(
      key: 'speech',
      label: 'Fala',
      icon: Icons.mic_rounded,
      accent: LearningMapVisualTokens.purple,
      fill: Color(0xFFF3F0FF),
    ),
    LearningActivityType.quiz => const _ActivityTypeSpec(
      key: 'quiz',
      label: 'Quiz',
      icon: Icons.quiz_rounded,
      accent: LearningMapVisualTokens.magenta,
      fill: Color(0xFFFFF0FC),
    ),
    LearningActivityType.review => const _ActivityTypeSpec(
      key: 'review',
      label: 'Revis\u00e3o',
      icon: Icons.replay_rounded,
      accent: LearningMapVisualTokens.teal,
      fill: Color(0xFFECFAF8),
    ),
    LearningActivityType.integratedChallenge => const _ActivityTypeSpec(
      key: 'integratedChallenge',
      label: 'Desafio',
      icon: Icons.emoji_events_rounded,
      accent: LearningMapVisualTokens.gold,
      fill: Color(0xFFFFF7E5),
    ),
    null => const _ActivityTypeSpec(
      key: 'generic',
      label: 'Miss\u00e3o',
      icon: Icons.play_circle_outline_rounded,
      accent: LearningMapVisualTokens.cyan,
      fill: Color(0xFFEDF8FE),
    ),
  };
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
    required this.heroLabel,
    required this.icon,
    required this.color,
  });

  final String label;
  final String heroLabel;
  final IconData icon;
  final Color color;
}

_LearningStateSpec _stateSpec(LearningActivityState state) {
  return switch (state) {
    LearningActivityState.locked => const _LearningStateSpec(
      label: 'Bloqueada',
      icon: Icons.lock_outline_rounded,
      accent: LearningMapVisualTokens.muted,
      fill: Color(0xFFEFF3F7),
    ),
    LearningActivityState.available => const _LearningStateSpec(
      label: 'Dispon\u00edvel',
      icon: Icons.play_arrow_rounded,
      accent: LearningMapVisualTokens.cyan,
      fill: Color(0xFFEDF8FE),
    ),
    LearningActivityState.inProgress => const _LearningStateSpec(
      label: 'Em progresso',
      icon: Icons.directions_walk_rounded,
      accent: LearningMapVisualTokens.gold,
      fill: Color(0xFFFFF5D9),
    ),
    LearningActivityState.completed => const _LearningStateSpec(
      label: 'Conclu\u00edda',
      icon: Icons.check_circle_outline_rounded,
      accent: LearningMapVisualTokens.green,
      fill: Color(0xFFE6F7EF),
    ),
  };
}

_SyncStateSpec _aggregateSyncSpec(LearningMapViewModel model) {
  var aggregate = ProgressSyncState.clean;

  for (final element in model.elements) {
    switch (element.syncState) {
      case ProgressSyncState.failed:
        return _syncSpec(ProgressSyncState.failed);
      case ProgressSyncState.syncing:
        aggregate = ProgressSyncState.syncing;
        break;
      case ProgressSyncState.pending:
        if (aggregate == ProgressSyncState.clean) {
          aggregate = ProgressSyncState.pending;
        }
        break;
      case ProgressSyncState.clean:
        break;
    }
  }

  return _syncSpec(aggregate);
}

_SyncStateSpec _syncSpec(ProgressSyncState state) {
  return switch (state) {
    ProgressSyncState.clean => const _SyncStateSpec(
      label: 'Tudo guardado',
      heroLabel: 'Tudo guardado',
      icon: Icons.cloud_done_outlined,
      color: LearningMapVisualTokens.green,
    ),
    ProgressSyncState.pending => const _SyncStateSpec(
      label: 'Por guardar',
      heroLabel: 'Por guardar',
      icon: Icons.cloud_upload_outlined,
      color: LearningMapVisualTokens.gold,
    ),
    ProgressSyncState.syncing => const _SyncStateSpec(
      label: 'A guardar...',
      heroLabel: 'A guardar...',
      icon: Icons.sync_rounded,
      color: LearningMapVisualTokens.cyan,
    ),
    ProgressSyncState.failed => const _SyncStateSpec(
      label: 'N\u00e3o guardado',
      heroLabel: 'N\u00e3o guardado',
      icon: Icons.cloud_off_outlined,
      color: LearningMapVisualTokens.danger,
    ),
  };
}
