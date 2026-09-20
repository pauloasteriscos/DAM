import 'package:flutter/material.dart';

import '../../domain/learning/learning_enums.dart';
import '../../domain/learning/learning_models.dart';
import '../../screens/dialogue_page.dart';
import '../../screens/quiz_page.dart';
import '../../screens/revision_page.dart';
import '../../screens/speech_practice_page.dart';
import '../../screens/vocabulary_pairs_page.dart';
import 'learning_map_view_model.dart';
import 'learning_mission_detail_page.dart';

/// Result of resolving a Learning Map activity into app navigation.
///
/// This boundary consumes decisions already present in the read model.
/// It never evaluates prerequisites or changes pedagogical state.
enum LearningMapActivityNavigationDisposition {
  ready,
  blocked,
  unsupported,
  invalid,
}

/// Result returned after attempting navigation.
enum LearningMapActivityNavigationOutcome {
  opened,
  blocked,
  unsupported,
  invalid,
}

/// Immutable navigation decision for one Learning Map element.
final class LearningMapActivityNavigationDecision {
  const LearningMapActivityNavigationDecision._({
    required this.disposition,
    this.destination,
  });

  const LearningMapActivityNavigationDecision.ready({
    required Widget destination,
  }) : this._(
         disposition: LearningMapActivityNavigationDisposition.ready,
         destination: destination,
       );

  const LearningMapActivityNavigationDecision.blocked()
    : this._(disposition: LearningMapActivityNavigationDisposition.blocked);

  const LearningMapActivityNavigationDecision.unsupported()
    : this._(disposition: LearningMapActivityNavigationDisposition.unsupported);

  const LearningMapActivityNavigationDecision.invalid()
    : this._(disposition: LearningMapActivityNavigationDisposition.invalid);

  final LearningMapActivityNavigationDisposition disposition;
  final Widget? destination;

  bool get canNavigate =>
      disposition == LearningMapActivityNavigationDisposition.ready &&
      destination != null;
}

/// Single navigation boundary between Learning Map elements and app screens.
///
/// Supported today:
/// - vocabulary
/// - dialogue
/// - quiz
/// - review
/// - speech
///
/// Integrated challenges remain fail-closed until a concrete activity screen
/// is implemented for that type.
abstract final class LearningMapActivityNavigation {
  static LearningMapActivityNavigationDecision resolve(
    LearningMapElementViewModel element,
  ) {
    if (!element.isActivity || element.activityType == null) {
      return const LearningMapActivityNavigationDecision.invalid();
    }

    if (!element.canOpen) {
      return const LearningMapActivityNavigationDecision.blocked();
    }

    final type = element.activityType!;
    final execution = element.execution;

    // Schema 2 certifies an exact revision. Falling back to a generic hardcoded
    // bank here would execute content different from the revision represented
    // by the Learning Map, so the boundary must fail closed.
    if (element.contentSchemaVersion >= 2 &&
        (execution == null || execution.activityType != type)) {
      return const LearningMapActivityNavigationDecision.invalid();
    }

    final destination = _destinationFor(
      type,
      execution: element.contentSchemaVersion >= 2 ? execution : null,
      contentDefaultLocale: element.contentDefaultLocale,
    );

    if (destination == null) {
      return const LearningMapActivityNavigationDecision.unsupported();
    }

    return LearningMapActivityNavigationDecision.ready(
      destination: LearningMissionDetailPage(
        mission: element,
        runtimeDestination: destination,
      ),
    );
  }

  static Future<LearningMapActivityNavigationOutcome> open(
    BuildContext context,
    LearningMapElementViewModel element,
  ) async {
    final decision = resolve(element);

    switch (decision.disposition) {
      case LearningMapActivityNavigationDisposition.blocked:
        return LearningMapActivityNavigationOutcome.blocked;

      case LearningMapActivityNavigationDisposition.unsupported:
        return LearningMapActivityNavigationOutcome.unsupported;

      case LearningMapActivityNavigationDisposition.invalid:
        return LearningMapActivityNavigationOutcome.invalid;

      case LearningMapActivityNavigationDisposition.ready:
        final destination = decision.destination;

        if (destination == null) {
          throw StateError(
            'A ready Learning Map navigation decision requires a destination.',
          );
        }

        await Navigator.of(
          context,
        ).push<void>(MaterialPageRoute<void>(builder: (_) => destination));

        return LearningMapActivityNavigationOutcome.opened;
    }
  }

  static Widget? _destinationFor(
    LearningActivityType type, {
    required ActivityExecution? execution,
    required String contentDefaultLocale,
  }) {
    return switch (type) {
      LearningActivityType.vocabulary => VocabularyPairsPage(
        execution: execution as VocabularyActivityExecution?,
        contentDefaultLocale: contentDefaultLocale,
      ),
      LearningActivityType.dialogue => DialoguePage(
        execution: execution as DialogueActivityExecution?,
        contentDefaultLocale: contentDefaultLocale,
      ),
      LearningActivityType.quiz => QuizPage(
        execution: execution as QuizActivityExecution?,
        contentDefaultLocale: contentDefaultLocale,
      ),
      LearningActivityType.review => RevisionPage(
        execution: execution as ReviewActivityExecution?,
        contentDefaultLocale: contentDefaultLocale,
      ),
      LearningActivityType.speech => SpeechPracticePage(
        execution: execution as SpeechActivityExecution?,
        contentDefaultLocale: contentDefaultLocale,
      ),
      LearningActivityType.integratedChallenge => null,
    };
  }
}
