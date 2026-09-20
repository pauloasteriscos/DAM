import 'package:flutter/material.dart';

import '../../domain/learning/learning_enums.dart';
import 'learning_map_view_model.dart';

/// Child-friendly entry screen for a mission opened from the Learning Path.
///
/// This screen deliberately sits between the map and the concrete activity
/// runtime. It does not persist progress and does not evaluate prerequisites.
final class LearningMissionDetailPage extends StatelessWidget {
  const LearningMissionDetailPage({
    super.key,
    required this.mission,
    required this.runtimeDestination,
  });

  final LearningMapElementViewModel mission;
  final Widget runtimeDestination;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final locale = mission.contentDefaultLocale;
    final palette = _paletteFor(mission.activityType);
    final title = mission.title?.trim().isNotEmpty == true
        ? mission.title!.trim()
        : _copy(locale).fallbackTitle;
    final instructions = mission.instructions?.trim();
    final completed = mission.state == LearningActivityState.completed;

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
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(18, 20, 18, 28),
              children: <Widget>[
                Text(
                  _copy(locale).eyebrow,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: palette.accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: .8,
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: palette.surface,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: palette.border),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        blurRadius: 24,
                        offset: Offset(0, 10),
                        color: Color(0x14000000),
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
                            width: 58,
                            height: 58,
                            decoration: BoxDecoration(
                              color: palette.iconSurface,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              _iconFor(mission.activityType),
                              color: palette.accent,
                              size: 30,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  _typeLabel(mission.activityType, locale),
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: palette.accent,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  title,
                                  style: theme.textTheme.headlineSmall
                                      ?.copyWith(
                                        fontWeight: FontWeight.w900,
                                        height: 1.08,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (instructions != null &&
                          instructions.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 18),
                        Text(
                          instructions,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            height: 1.42,
                            color: const Color(0xFF435761),
                          ),
                        ),
                      ],
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .78),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: <Widget>[
                            Icon(Icons.flag_rounded, color: palette.accent),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    _copy(locale).goal,
                                    style: theme.textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _goalFor(mission.activityType, locale),
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: const Color(0xFF5F727B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: <Widget>[
                          Expanded(
                            child: _InfoChip(
                              icon: Icons.auto_awesome_rounded,
                              label: completed
                                  ? _copy(locale).completed
                                  : _copy(locale).ready,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _InfoChip(
                              icon: Icons.psychology_alt_rounded,
                              label: _competencyLabel(
                                mission.competencyIds.length,
                                locale,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  key: const ValueKey<String>('mission-detail-start'),
                  onPressed: () async {
                    await Navigator.of(context).push<void>(
                      MaterialPageRoute<void>(
                        builder: (_) => runtimeDestination,
                      ),
                    );
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
                  icon: Icon(
                    completed ? Icons.replay_rounded : Icons.play_arrow_rounded,
                  ),
                  label: Text(
                    completed
                        ? _copy(locale).practiceAgain
                        : _copy(locale).start,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  _copy(locale).hint,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: const Color(0xFF71858E),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

final class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EAF0)),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: const Color(0xFF526B77)),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: Color(0xFF435761),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _MissionPalette {
  const _MissionPalette({
    required this.accent,
    required this.surface,
    required this.iconSurface,
    required this.border,
  });

  final Color accent;
  final Color surface;
  final Color iconSurface;
  final Color border;
}

_MissionPalette _paletteFor(LearningActivityType? type) {
  return switch (type) {
    LearningActivityType.vocabulary => const _MissionPalette(
      accent: Color(0xFF18A875),
      surface: Color(0xFFF0FBF7),
      iconSurface: Color(0xFFDDF7ED),
      border: Color(0xFFBDE8D7),
    ),
    LearningActivityType.dialogue => const _MissionPalette(
      accent: Color(0xFF268CF5),
      surface: Color(0xFFF1F7FE),
      iconSurface: Color(0xFFDDEEFF),
      border: Color(0xFFC2DDFB),
    ),
    LearningActivityType.speech => const _MissionPalette(
      accent: Color(0xFF8258E8),
      surface: Color(0xFFF6F2FE),
      iconSurface: Color(0xFFEAE2FD),
      border: Color(0xFFD8CBF8),
    ),
    LearningActivityType.quiz => const _MissionPalette(
      accent: Color(0xFFC248CE),
      surface: Color(0xFFFDF3FD),
      iconSurface: Color(0xFFF7DFF8),
      border: Color(0xFFEFC9F1),
    ),
    LearningActivityType.review => const _MissionPalette(
      accent: Color(0xFF158F95),
      surface: Color(0xFFF0FAFA),
      iconSurface: Color(0xFFDDF3F3),
      border: Color(0xFFBDE1E2),
    ),
    _ => const _MissionPalette(
      accent: Color(0xFFD58A08),
      surface: Color(0xFFFFF8EA),
      iconSurface: Color(0xFFFFEDC4),
      border: Color(0xFFF1D99E),
    ),
  };
}

IconData _iconFor(LearningActivityType? type) => switch (type) {
  LearningActivityType.vocabulary => Icons.menu_book_rounded,
  LearningActivityType.dialogue => Icons.forum_rounded,
  LearningActivityType.speech => Icons.mic_rounded,
  LearningActivityType.quiz => Icons.quiz_rounded,
  LearningActivityType.review => Icons.autorenew_rounded,
  _ => Icons.emoji_events_rounded,
};

String _typeLabel(LearningActivityType? type, String locale) {
  final lang = locale.split('-').first.toLowerCase();
  final pt = switch (type) {
    LearningActivityType.vocabulary => 'Vocabulário',
    LearningActivityType.dialogue => 'Diálogo',
    LearningActivityType.speech => 'Fala',
    LearningActivityType.quiz => 'Quiz',
    LearningActivityType.review => 'Revisão',
    _ => 'Desafio',
  };
  final en = switch (type) {
    LearningActivityType.vocabulary => 'Vocabulary',
    LearningActivityType.dialogue => 'Dialogue',
    LearningActivityType.speech => 'Speaking',
    LearningActivityType.quiz => 'Quiz',
    LearningActivityType.review => 'Review',
    _ => 'Challenge',
  };
  final fr = switch (type) {
    LearningActivityType.vocabulary => 'Vocabulaire',
    LearningActivityType.dialogue => 'Dialogue',
    LearningActivityType.speech => 'Expression orale',
    LearningActivityType.quiz => 'Quiz',
    LearningActivityType.review => 'Révision',
    _ => 'Défi',
  };
  return lang == 'fr' ? fr : (lang == 'en' ? en : pt);
}

String _goalFor(LearningActivityType? type, String locale) {
  final lang = locale.split('-').first.toLowerCase();
  const pt = <LearningActivityType, String>{
    LearningActivityType.vocabulary:
        'Reconhecer e usar palavras úteis nesta situação.',
    LearningActivityType.dialogue:
        'Responder com naturalidade numa conversa curta.',
    LearningActivityType.speech: 'Praticar frases importantes em voz alta.',
    LearningActivityType.quiz: 'Confirmar que compreendeste o essencial.',
    LearningActivityType.review: 'Consolidar o que já aprendeste.',
    LearningActivityType.integratedChallenge:
        'Juntar várias competências numa situação completa.',
  };
  const en = <LearningActivityType, String>{
    LearningActivityType.vocabulary:
        'Recognise and use useful words for this situation.',
    LearningActivityType.dialogue: 'Respond naturally in a short conversation.',
    LearningActivityType.speech: 'Practise important phrases out loud.',
    LearningActivityType.quiz: 'Check that you understood the essentials.',
    LearningActivityType.review: 'Strengthen what you have already learned.',
    LearningActivityType.integratedChallenge:
        'Combine several skills in one complete situation.',
  };
  const fr = <LearningActivityType, String>{
    LearningActivityType.vocabulary:
        'Reconnaître et utiliser les mots utiles de cette situation.',
    LearningActivityType.dialogue:
        'Répondre naturellement dans une courte conversation.',
    LearningActivityType.speech:
        'Pratiquer à voix haute des phrases importantes.',
    LearningActivityType.quiz: 'Vérifier que tu as compris l’essentiel.',
    LearningActivityType.review: 'Consolider ce que tu as déjà appris.',
    LearningActivityType.integratedChallenge:
        'Combiner plusieurs compétences dans une situation complète.',
  };
  final key = type ?? LearningActivityType.integratedChallenge;
  return lang == 'fr' ? fr[key]! : (lang == 'en' ? en[key]! : pt[key]!);
}

String _competencyLabel(int count, String locale) {
  final lang = locale.split('-').first.toLowerCase();
  if (lang == 'en') return count == 1 ? '1 skill' : '$count skills';
  if (lang == 'fr') return count == 1 ? '1 compétence' : '$count compétences';
  return count == 1 ? '1 competência' : '$count competências';
}

final class _MissionCopy {
  const _MissionCopy({
    required this.eyebrow,
    required this.fallbackTitle,
    required this.goal,
    required this.ready,
    required this.completed,
    required this.start,
    required this.practiceAgain,
    required this.hint,
  });
  final String eyebrow;
  final String fallbackTitle;
  final String goal;
  final String ready;
  final String completed;
  final String start;
  final String practiceAgain;
  final String hint;
}

_MissionCopy _copy(String locale) {
  final lang = locale.split('-').first.toLowerCase();
  if (lang == 'en') {
    return const _MissionCopy(
      eyebrow: 'YOUR NEXT MISSION',
      fallbackTitle: 'Mission',
      goal: 'Goal',
      ready: 'Ready to start',
      completed: 'Completed',
      start: 'Start mission',
      practiceAgain: 'Practise again',
      hint: 'Complete the activity to continue your journey.',
    );
  }
  if (lang == 'fr') {
    return const _MissionCopy(
      eyebrow: 'TA PROCHAINE MISSION',
      fallbackTitle: 'Mission',
      goal: 'Objectif',
      ready: 'Prêt à commencer',
      completed: 'Terminée',
      start: 'Commencer la mission',
      practiceAgain: 'Recommencer',
      hint: 'Termine l’activité pour poursuivre ton parcours.',
    );
  }
  return const _MissionCopy(
    eyebrow: 'A TUA PRÓXIMA MISSÃO',
    fallbackTitle: 'Missão',
    goal: 'Objetivo',
    ready: 'Pronta para começar',
    completed: 'Concluída',
    start: 'Começar missão',
    practiceAgain: 'Praticar novamente',
    hint: 'Conclui a atividade para continuares a tua jornada.',
  );
}
