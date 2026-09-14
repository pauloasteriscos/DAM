import 'package:flutter/material.dart';

import '../../domain/learning/learning_enums.dart';
import '../../screens/dialogue_page.dart';
import '../../screens/quiz_page.dart';
import '../../screens/revision_page.dart';
import '../../screens/vocabulary_pairs_page.dart';
import 'learning_map_view_model.dart';

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
///
/// Speech and integrated challenges remain fail-closed until a concrete
/// activity screen is implemented for those types.
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

    final destination = _destinationFor(element.activityType!);

    if (destination == null) {
      return const LearningMapActivityNavigationDecision.unsupported();
    }

    return LearningMapActivityNavigationDecision.ready(
      destination: destination,
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

  static Widget? _destinationFor(LearningActivityType type) {
    return switch (type) {
      LearningActivityType.vocabulary => const VocabularyPairsPage(),
      LearningActivityType.dialogue => const DialoguePage(),
      LearningActivityType.quiz => const QuizPage(),
      LearningActivityType.review => const RevisionPage(),
      LearningActivityType.speech => null,
      LearningActivityType.integratedChallenge => null,
    };
  }
}
