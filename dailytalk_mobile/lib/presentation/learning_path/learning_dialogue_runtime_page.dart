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

/// Mission-bound visual runtime for schema-v2 dialogue activities.
///
/// It intentionally has no access to the legacy random scenario bank. The
/// scenario, turns and reply options come exclusively from the immutable
/// `revision.execution` selected by the Learning Path.
final class LearningDialogueRuntimePage extends StatefulWidget {
  const LearningDialogueRuntimePage({
    super.key,
    required this.execution,
    required this.contentDefaultLocale,
    this.missionTitle,
    this.competencyCount = 0,
    this.onActivityCompleted,
    this.returnToLearningMapOnCompletion = false,
  });

  final DialogueActivityExecution execution;
  final String contentDefaultLocale;
  final String? missionTitle;
  final int competencyCount;
  final LearningActivityCompletionAction? onActivityCompleted;
  final bool returnToLearningMapOnCompletion;

  @override
  State<LearningDialogueRuntimePage> createState() =>
      _LearningDialogueRuntimePageState();
}

final class _LearningDialogueRuntimePageState
    extends State<LearningDialogueRuntimePage> {
  int _turnIndex = 0;
  String? _selectedOptionId;
  bool _answered = false;
  final bool _finished = false;
  int _answerAttempts = 0;
  bool _persistingCompletion = false;
  late List<_DialogueOption> _options;

  DialogueExecutionTurn get _turn => widget.execution.turns[_turnIndex];
  bool get _isLastTurn => _turnIndex == widget.execution.turns.length - 1;

  @override
  void initState() {
    super.initState();
    _options = _buildOptions(_turn);
  }

  List<_DialogueOption> _buildOptions(DialogueExecutionTurn turn) {
    final options = <_DialogueOption>[
      _DialogueOption(
        id: '${turn.id}-correct',
        text: turn.correctReply,
        correct: true,
      ),
      for (var index = 0; index < turn.distractors.length; index++)
        _DialogueOption(
          id: '${turn.id}-distractor-$index',
          text: turn.distractors[index],
          correct: false,
        ),
    ]..shuffle(Random());
    return options;
  }

  _DialogueOption? get _selectedOption {
    final id = _selectedOptionId;
    if (id == null) {
      return null;
    }
    for (final option in _options) {
      if (option.id == id) {
        return option;
      }
    }
    return null;
  }

  void _select(_DialogueOption option) {
    if (_answered || _finished) {
      return;
    }
    setState(() {
      _selectedOptionId = option.id;
    });
  }

  void _primaryAction() {
    if (_finished) {
      Navigator.of(context).pop();
      return;
    }

    if (!_answered) {
      if (_selectedOptionId == null) {
        return;
      }
      setState(() {
        _answered = true;
        _answerAttempts++;
      });
      return;
    }

    final selected = _selectedOption;
    if (selected == null) {
      return;
    }

    if (!selected.correct) {
      setState(() {
        _selectedOptionId = null;
        _answered = false;
      });
      return;
    }

    if (_isLastTurn) {
      unawaited(_openCompletion());
      return;
    }

    setState(() {
      _turnIndex++;
      _selectedOptionId = null;
      _answered = false;
      _options = _buildOptions(_turn);
    });
  }

  Future<void> _openCompletion() async {
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

      final appLanguage = AppLocaleController.instance.languageCode;
      final copy = _copyFor(appLanguage);
      final configuredTitle = widget.missionTitle?.trim();
      final title = configuredTitle != null && configuredTitle.isNotEmpty
          ? configuredTitle
          : widget.execution.scenarioTitle.resolve(
              appLanguage,
              fallbackLocale: widget.contentDefaultLocale,
            );

      await Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => LearningActivityCompletedPage(
            activityType: LearningActivityType.dialogue,
            title: title,
            competencyCount: widget.competencyCount,
            returnToLearningMap: widget.returnToLearningMapOnCompletion,
            metrics: <LearningCompletionMetric>[
              LearningCompletionMetric(
                label: copy.turnsMetric,
                value: '${widget.execution.turns.length}',
                icon: Icons.forum_rounded,
              ),
              LearningCompletionMetric(
                label: copy.answersMetric,
                value: '$_answerAttempts',
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
                    constraints: const BoxConstraints(maxWidth: 680),
                    child: _finished
                        ? _FinishedView(
                            copy: copy,
                            onBack: () => Navigator.of(context).pop(),
                          )
                        : ListView(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                            children: <Widget>[
                              _ScenarioHeader(
                                title: widget.execution.scenarioTitle.resolve(
                                  appLanguage,
                                  fallbackLocale: widget.contentDefaultLocale,
                                ),
                                description: widget
                                    .execution
                                    .scenarioDescription
                                    .resolve(
                                      appLanguage,
                                      fallbackLocale:
                                          widget.contentDefaultLocale,
                                    ),
                                copy: copy,
                                turn: _turnIndex + 1,
                                totalTurns: widget.execution.turns.length,
                              ),
                              const SizedBox(height: 14),
                              _PartnerBubble(
                                label: copy.partner,
                                text: _turn.partnerMessage.resolve(
                                  learningLanguage,
                                  fallbackLocale: widget.contentDefaultLocale,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _PromptCard(
                                label: copy.yourTurn,
                                prompt: _turn.prompt.resolve(
                                  appLanguage,
                                  fallbackLocale: widget.contentDefaultLocale,
                                ),
                              ),
                              const SizedBox(height: 12),
                              for (
                                var index = 0;
                                index < _options.length;
                                index++
                              ) ...<Widget>[
                                _OptionCard(
                                  key: ValueKey<String>(
                                    'mission-dialogue-option-${_options[index].id}',
                                  ),
                                  letter: String.fromCharCode(65 + index),
                                  text: _options[index].text.resolve(
                                    learningLanguage,
                                    fallbackLocale: widget.contentDefaultLocale,
                                  ),
                                  selected:
                                      _selectedOptionId == _options[index].id,
                                  answered: _answered,
                                  correct: _options[index].correct,
                                  onTap: () => _select(_options[index]),
                                ),
                                const SizedBox(height: 9),
                              ],
                              const SizedBox(height: 3),
                              _Feedback(
                                copy: copy,
                                answered: _answered,
                                selected: _selectedOption,
                              ),
                              const SizedBox(height: 14),
                              FilledButton.icon(
                                key: const ValueKey<String>(
                                  'mission-dialogue-primary',
                                ),
                                onPressed:
                                    !_answered && _selectedOptionId == null
                                    ? null
                                    : _primaryAction,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(56),
                                  backgroundColor: const Color(0xFF268CF5),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(
                                    0xFFD7E5F0,
                                  ),
                                  disabledForegroundColor: const Color(
                                    0xFF8296A1,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  textStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                icon: Icon(_primaryIcon),
                                label: Text(_primaryLabel(copy)),
                              ),
                            ],
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

  IconData get _primaryIcon {
    if (!_answered) {
      return Icons.check_rounded;
    }
    final selected = _selectedOption;
    if (selected?.correct != true) {
      return Icons.refresh_rounded;
    }
    return _isLastTurn ? Icons.flag_rounded : Icons.arrow_forward_rounded;
  }

  String _primaryLabel(_DialogueRuntimeCopy copy) {
    if (!_answered) {
      return copy.confirm;
    }
    final selected = _selectedOption;
    if (selected?.correct != true) {
      return copy.tryAgain;
    }
    return _isLastTurn ? copy.finish : copy.next;
  }
}

final class _DialogueOption {
  const _DialogueOption({
    required this.id,
    required this.text,
    required this.correct,
  });

  final String id;
  final LocalizedText text;
  final bool correct;
}

final class _ScenarioHeader extends StatelessWidget {
  const _ScenarioHeader({
    required this.title,
    required this.description,
    required this.copy,
    required this.turn,
    required this.totalTurns,
  });

  final String title;
  final String description;
  final _DialogueRuntimeCopy copy;
  final int turn;
  final int totalTurns;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFD5E5F5)),
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
                  color: const Color(0xFFDDEEFF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.forum_rounded,
                  color: Color(0xFF268CF5),
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
                        color: Color(0xFF268CF5),
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      title,
                      key: const ValueKey<String>(
                        'mission-dialogue-scenario-title',
                      ),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$turn/$totalTurns',
                key: const ValueKey<String>('mission-dialogue-progress-count'),
                style: const TextStyle(
                  color: Color(0xFF4B6572),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: turn / totalTurns,
              backgroundColor: const Color(0xFFE8F1F5),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF268CF5),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            key: const ValueKey<String>(
              'mission-dialogue-scenario-description',
            ),
            style: const TextStyle(color: Color(0xFF627985), height: 1.35),
          ),
        ],
      ),
    );
  }
}

final class _PartnerBubble extends StatelessWidget {
  const _PartnerBubble({required this.label, required this.text});

  final String label;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        key: const ValueKey<String>('mission-dialogue-partner-message'),
        constraints: const BoxConstraints(maxWidth: 560),
        padding: const EdgeInsets.fromLTRB(15, 12, 15, 13),
        decoration: const BoxDecoration(
          color: Color(0xFFEAF4FF),
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(6),
            topRight: Radius.circular(18),
            bottomLeft: Radius.circular(18),
            bottomRight: Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF268CF5),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(
                color: Color(0xFF20333D),
                fontSize: 17,
                fontWeight: FontWeight.w800,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final class _PromptCard extends StatelessWidget {
  const _PromptCard({required this.label, required this.prompt});

  final String label;
  final String prompt;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('mission-dialogue-prompt'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD9E5EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF607782),
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            prompt,
            style: const TextStyle(
              color: Color(0xFF20333D),
              fontSize: 17,
              fontWeight: FontWeight.w900,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

final class _OptionCard extends StatelessWidget {
  const _OptionCard({
    super.key,
    required this.letter,
    required this.text,
    required this.selected,
    required this.answered,
    required this.correct,
    required this.onTap,
  });

  final String letter;
  final String text;
  final bool selected;
  final bool answered;
  final bool correct;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final showCorrect = answered && correct;
    final showWrong = answered && selected && !correct;
    final border = showCorrect
        ? const Color(0xFF18A875)
        : showWrong
        ? const Color(0xFFE74C5B)
        : selected
        ? const Color(0xFF268CF5)
        : const Color(0xFFD4E2EA);
    final background = showCorrect
        ? const Color(0xFFEAF9F3)
        : showWrong
        ? const Color(0xFFFFF1F2)
        : selected
        ? const Color(0xFFEAF4FF)
        : Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: answered ? null : onTap,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: border, width: selected ? 2 : 1),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: border.withValues(alpha: .10),
                  shape: BoxShape.circle,
                  border: Border.all(color: border),
                ),
                child: Text(
                  letter,
                  style: TextStyle(color: border, fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    color: Color(0xFF20333D),
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
                ),
              ),
              if (showCorrect)
                const Icon(Icons.check_circle_rounded, color: Color(0xFF18A875))
              else if (showWrong)
                const Icon(Icons.cancel_rounded, color: Color(0xFFE74C5B)),
            ],
          ),
        ),
      ),
    );
  }
}

final class _Feedback extends StatelessWidget {
  const _Feedback({
    required this.copy,
    required this.answered,
    required this.selected,
  });

  final _DialogueRuntimeCopy copy;
  final bool answered;
  final _DialogueOption? selected;

  @override
  Widget build(BuildContext context) {
    if (!answered || selected == null) {
      return Text(
        copy.chooseReply,
        key: const ValueKey<String>('mission-dialogue-feedback'),
        style: const TextStyle(
          color: Color(0xFF657B86),
          fontWeight: FontWeight.w700,
        ),
      );
    }

    final correct = selected!.correct;
    return Container(
      key: const ValueKey<String>('mission-dialogue-feedback'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: correct ? const Color(0xFFEAF9F3) : const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            correct ? Icons.check_circle_rounded : Icons.info_rounded,
            color: correct ? const Color(0xFF18A875) : const Color(0xFFE74C5B),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              correct ? copy.correct : copy.wrong,
              style: const TextStyle(
                color: Color(0xFF29404B),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

final class _FinishedView extends StatelessWidget {
  const _FinishedView({required this.copy, required this.onBack});

  final _DialogueRuntimeCopy copy;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          const CircleAvatar(
            radius: 42,
            backgroundColor: Color(0xFFDDEEFF),
            child: Icon(
              Icons.forum_rounded,
              color: Color(0xFF268CF5),
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            copy.finished,
            key: const ValueKey<String>('mission-dialogue-finished'),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            copy.finishedHint,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF657B86),
              fontSize: 15,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            key: const ValueKey<String>('mission-dialogue-back'),
            onPressed: onBack,
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              backgroundColor: const Color(0xFF268CF5),
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.arrow_back_rounded),
            label: Text(copy.back),
          ),
        ],
      ),
    );
  }
}

final class _DialogueRuntimeCopy {
  const _DialogueRuntimeCopy({
    required this.typeLabel,
    required this.partner,
    required this.yourTurn,
    required this.chooseReply,
    required this.correct,
    required this.wrong,
    required this.confirm,
    required this.tryAgain,
    required this.next,
    required this.finish,
    required this.finished,
    required this.finishedHint,
    required this.back,
    required this.turnsMetric,
    required this.answersMetric,
  });

  final String typeLabel;
  final String partner;
  final String yourTurn;
  final String chooseReply;
  final String correct;
  final String wrong;
  final String confirm;
  final String tryAgain;
  final String next;
  final String finish;
  final String finished;
  final String finishedHint;
  final String back;
  final String turnsMetric;
  final String answersMetric;
}

_DialogueRuntimeCopy _copyFor(String locale) {
  return switch (locale.split('-').first.toLowerCase()) {
    'en' => const _DialogueRuntimeCopy(
      typeLabel: 'Dialogue',
      partner: 'Partner',
      yourTurn: 'Your turn',
      chooseReply: 'Choose the best reply.',
      correct: 'Good choice.',
      wrong: 'That reply does not fit yet. Try again.',
      confirm: 'Confirm',
      tryAgain: 'Try again',
      next: 'Next',
      finish: 'Finish practice',
      finished: 'Practice finished',
      finishedHint: 'You completed every turn in this dialogue.',
      back: 'Back to mission',
      turnsMetric: 'Turns',
      answersMetric: 'Answers',
    ),
    'es' => const _DialogueRuntimeCopy(
      typeLabel: 'Diálogo',
      partner: 'Interlocutor',
      yourTurn: 'Tu turno',
      chooseReply: 'Elige la mejor respuesta.',
      correct: 'Buena elección.',
      wrong: 'Esa respuesta todavía no encaja. Inténtalo de nuevo.',
      confirm: 'Confirmar',
      tryAgain: 'Intentar de nuevo',
      next: 'Siguiente',
      finish: 'Terminar práctica',
      finished: 'Práctica terminada',
      finishedHint: 'Has completado todos los turnos de este diálogo.',
      back: 'Volver a la misión',
      turnsMetric: 'Turnos',
      answersMetric: 'Respuestas',
    ),
    'fr' => const _DialogueRuntimeCopy(
      typeLabel: 'Dialogue',
      partner: 'Interlocuteur',
      yourTurn: 'À toi',
      chooseReply: 'Choisis la meilleure réponse.',
      correct: 'Bon choix.',
      wrong: 'Cette réponse ne convient pas encore. Réessaie.',
      confirm: 'Confirmer',
      tryAgain: 'Réessayer',
      next: 'Suivant',
      finish: 'Terminer la pratique',
      finished: 'Pratique terminée',
      finishedHint: 'Tu as terminé tous les tours de ce dialogue.',
      back: 'Retour à la mission',
      turnsMetric: 'Tours',
      answersMetric: 'Réponses',
    ),
    'it' => const _DialogueRuntimeCopy(
      typeLabel: 'Dialogo',
      partner: 'Interlocutore',
      yourTurn: 'Tocca a te',
      chooseReply: 'Scegli la risposta migliore.',
      correct: 'Buona scelta.',
      wrong: 'Questa risposta non va ancora bene. Riprova.',
      confirm: 'Conferma',
      tryAgain: 'Riprova',
      next: 'Avanti',
      finish: 'Termina pratica',
      finished: 'Pratica terminata',
      finishedHint: 'Hai completato tutti i turni di questo dialogo.',
      back: 'Torna alla missione',
      turnsMetric: 'Turni',
      answersMetric: 'Risposte',
    ),
    'de' => const _DialogueRuntimeCopy(
      typeLabel: 'Dialog',
      partner: 'Gesprächspartner',
      yourTurn: 'Du bist dran',
      chooseReply: 'Wähle die beste Antwort.',
      correct: 'Gute Wahl.',
      wrong: 'Diese Antwort passt noch nicht. Versuche es erneut.',
      confirm: 'Bestätigen',
      tryAgain: 'Noch einmal',
      next: 'Weiter',
      finish: 'Übung beenden',
      finished: 'Übung beendet',
      finishedHint: 'Du hast alle Gesprächsrunden abgeschlossen.',
      back: 'Zurück zur Mission',
      turnsMetric: 'Runden',
      answersMetric: 'Antworten',
    ),
    _ => const _DialogueRuntimeCopy(
      typeLabel: 'Diálogo',
      partner: 'Interlocutor',
      yourTurn: 'A tua vez',
      chooseReply: 'Escolhe a melhor resposta.',
      correct: 'Boa escolha.',
      wrong: 'Essa resposta ainda não encaixa. Tenta novamente.',
      confirm: 'Confirmar',
      tryAgain: 'Tentar novamente',
      next: 'Seguinte',
      finish: 'Terminar prática',
      finished: 'Prática terminada',
      finishedHint: 'Completaste todos os turnos deste diálogo.',
      back: 'Voltar à missão',
      turnsMetric: 'Turnos',
      answersMetric: 'Respostas',
    ),
  };
}
