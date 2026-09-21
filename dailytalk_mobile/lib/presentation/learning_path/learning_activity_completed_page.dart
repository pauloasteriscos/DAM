import 'package:flutter/material.dart';

import '../../domain/learning/learning_enums.dart';
import '../../state/app_locale_controller.dart';
import '../../widgets/learning_language_quick_switcher.dart';

/// Lightweight presentation model for one result shown after a runtime ends.
///
/// These values describe only the execution that just happened. They do not
/// represent durable progression and are intentionally independent from the
/// SQLite progression write path introduced in 4.7C.
final class LearningCompletionMetric {
  const LearningCompletionMetric({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}

/// Shared visual completion screen for mission-bound runtimes.
///
/// 4.7B.3 deliberately stops at presentation. Pressing Continue only returns
/// to the mission detail; it does not call completeActivity(), unlock another
/// activity, write progress or enqueue synchronization.
final class LearningActivityCompletedPage extends StatelessWidget {
  const LearningActivityCompletedPage({
    super.key,
    required this.activityType,
    required this.title,
    required this.competencyCount,
    this.metrics = const <LearningCompletionMetric>[],
    this.returnToLearningMap = false,
  });

  final LearningActivityType activityType;
  final String title;
  final int competencyCount;
  final List<LearningCompletionMetric> metrics;

  /// When true, Continue closes both this completion route and the mission
  /// detail route underneath it. The Learning Map route then resumes and its
  /// existing open/return/reload flow refreshes projection + recommendations.
  ///
  /// Defaults to false so non-map consumers preserve the original one-pop
  /// behavior.
  final bool returnToLearningMap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppLocaleController.instance,
      builder: (context, _) {
        final locale = AppLocaleController.instance.languageCode;
        final copy = _copyFor(locale);
        final palette = _paletteFor(activityType);

        return Scaffold(
          key: const ValueKey<String>('learning-activity-completed-page'),
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
                constraints: const BoxConstraints(maxWidth: 620),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(18, 28, 18, 28),
                  children: <Widget>[
                    Center(
                      child: Container(
                        width: 92,
                        height: 92,
                        decoration: BoxDecoration(
                          color: palette.iconSurface,
                          shape: BoxShape.circle,
                          border: Border.all(color: palette.border, width: 2),
                        ),
                        child: Icon(
                          Icons.check_rounded,
                          color: palette.accent,
                          size: 50,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      copy.completed,
                      key: const ValueKey<String>(
                        'learning-completion-heading',
                      ),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: const Color(0xFF1E3039),
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      key: const ValueKey<String>('learning-completion-title'),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: palette.accent,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      copy.subtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF607782),
                        fontSize: 15.5,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (metrics.isNotEmpty)
                      Wrap(
                        key: const ValueKey<String>(
                          'learning-completion-metrics',
                        ),
                        spacing: 10,
                        runSpacing: 10,
                        children: <Widget>[
                          for (final metric in metrics)
                            _MetricCard(metric: metric, palette: palette),
                        ],
                      ),
                    if (metrics.isNotEmpty) const SizedBox(height: 14),
                    Container(
                      key: const ValueKey<String>(
                        'learning-completion-competencies',
                      ),
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFDCE7ED)),
                      ),
                      child: Row(
                        children: <Widget>[
                          Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: palette.iconSurface,
                              borderRadius: BorderRadius.circular(13),
                            ),
                            child: Icon(
                              Icons.psychology_alt_rounded,
                              color: palette.accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  copy.competencies,
                                  style: const TextStyle(
                                    color: Color(0xFF2A404B),
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _competencyValue(copy, competencyCount),
                                  style: const TextStyle(
                                    color: Color(0xFF667C86),
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton.icon(
                      key: const ValueKey<String>(
                        'learning-completion-continue',
                      ),
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        navigator.pop();

                        if (returnToLearningMap && navigator.canPop()) {
                          navigator.pop();
                        }
                      },
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(58),
                        backgroundColor: palette.accent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward_rounded),
                      label: Text(copy.continueLabel),
                    ),
                    const SizedBox(height: 11),
                    Text(
                      copy.sessionHint,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF7A8C95),
                        fontSize: 12.5,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric, required this.palette});

  final LearningCompletionMetric metric;
  final _CompletionPalette palette;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 150),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFDCE7ED)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(metric.icon, color: palette.accent, size: 21),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                metric.value,
                style: const TextStyle(
                  color: Color(0xFF20333D),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                metric.label,
                style: const TextStyle(
                  color: Color(0xFF6A7E88),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

final class _CompletionPalette {
  const _CompletionPalette({
    required this.accent,
    required this.iconSurface,
    required this.border,
  });

  final Color accent;
  final Color iconSurface;
  final Color border;
}

_CompletionPalette _paletteFor(LearningActivityType type) {
  return switch (type) {
    LearningActivityType.vocabulary => const _CompletionPalette(
      accent: Color(0xFF18A875),
      iconSurface: Color(0xFFDDF7ED),
      border: Color(0xFFBDE8D7),
    ),
    LearningActivityType.dialogue => const _CompletionPalette(
      accent: Color(0xFF268CF5),
      iconSurface: Color(0xFFDDEEFF),
      border: Color(0xFFC2DDFB),
    ),
    LearningActivityType.speech => const _CompletionPalette(
      accent: Color(0xFF8258E8),
      iconSurface: Color(0xFFEAE2FD),
      border: Color(0xFFD8CBF8),
    ),
    LearningActivityType.quiz => const _CompletionPalette(
      accent: Color(0xFFC248CE),
      iconSurface: Color(0xFFF7DFF8),
      border: Color(0xFFEFC9F1),
    ),
    LearningActivityType.review => const _CompletionPalette(
      accent: Color(0xFF158F95),
      iconSurface: Color(0xFFDDF3F3),
      border: Color(0xFFBDE1E2),
    ),
    LearningActivityType.integratedChallenge => const _CompletionPalette(
      accent: Color(0xFFD58A08),
      iconSurface: Color(0xFFFFEDC4),
      border: Color(0xFFF1D99E),
    ),
  };
}

final class _CompletionCopy {
  const _CompletionCopy({
    required this.completed,
    required this.subtitle,
    required this.competencies,
    required this.noCompetencies,
    required this.oneCompetency,
    required this.manyCompetencies,
    required this.continueLabel,
    required this.sessionHint,
  });

  final String completed;
  final String subtitle;
  final String competencies;
  final String noCompetencies;
  final String oneCompetency;
  final String manyCompetencies;
  final String continueLabel;
  final String sessionHint;
}

String _competencyValue(_CompletionCopy copy, int count) {
  if (count <= 0) return copy.noCompetencies;
  if (count == 1) return copy.oneCompetency;
  return copy.manyCompetencies.replaceFirst('{count}', '$count');
}

_CompletionCopy _copyFor(String locale) {
  return switch (locale.split('-').first.toLowerCase()) {
    'en' => const _CompletionCopy(
      completed: 'Activity completed',
      subtitle: 'You reached the end of this practice.',
      competencies: 'Skills practised',
      noCompetencies: 'This activity has no listed skill.',
      oneCompetency: '1 skill practised',
      manyCompetencies: '{count} skills practised',
      continueLabel: 'Continue',
      sessionHint: 'This screen summarises the practice you just completed.',
    ),
    'es' => const _CompletionCopy(
      completed: 'Actividad completada',
      subtitle: 'Has llegado al final de esta práctica.',
      competencies: 'Competencias practicadas',
      noCompetencies: 'Esta actividad no tiene competencias listadas.',
      oneCompetency: '1 competencia practicada',
      manyCompetencies: '{count} competencias practicadas',
      continueLabel: 'Continuar',
      sessionHint: 'Esta pantalla resume la práctica que acabas de terminar.',
    ),
    'fr' => const _CompletionCopy(
      completed: 'Activité terminée',
      subtitle: 'Tu es arrivé à la fin de cette pratique.',
      competencies: 'Compétences travaillées',
      noCompetencies: 'Cette activité ne contient aucune compétence listée.',
      oneCompetency: '1 compétence travaillée',
      manyCompetencies: '{count} compétences travaillées',
      continueLabel: 'Continuer',
      sessionHint: 'Cet écran résume la pratique que tu viens de terminer.',
    ),
    'it' => const _CompletionCopy(
      completed: 'Attività completata',
      subtitle: 'Hai raggiunto la fine di questa pratica.',
      competencies: 'Competenze esercitate',
      noCompetencies: 'Questa attività non ha competenze elencate.',
      oneCompetency: '1 competenza esercitata',
      manyCompetencies: '{count} competenze esercitate',
      continueLabel: 'Continua',
      sessionHint: 'Questa schermata riassume la pratica appena terminata.',
    ),
    'de' => const _CompletionCopy(
      completed: 'Aktivität abgeschlossen',
      subtitle: 'Du hast diese Übung bis zum Ende durchgeführt.',
      competencies: 'Geübte Kompetenzen',
      noCompetencies: 'Für diese Aktivität sind keine Kompetenzen angegeben.',
      oneCompetency: '1 Kompetenz geübt',
      manyCompetencies: '{count} Kompetenzen geübt',
      continueLabel: 'Weiter',
      sessionHint: 'Diese Ansicht fasst die gerade beendete Übung zusammen.',
    ),
    _ => const _CompletionCopy(
      completed: 'Atividade concluída',
      subtitle: 'Chegaste ao fim desta prática.',
      competencies: 'Competências trabalhadas',
      noCompetencies: 'Esta atividade não tem competências listadas.',
      oneCompetency: '1 competência trabalhada',
      manyCompetencies: '{count} competências trabalhadas',
      continueLabel: 'Continuar',
      sessionHint: 'Este ecrã resume a prática que acabaste de concluir.',
    ),
  };
}
