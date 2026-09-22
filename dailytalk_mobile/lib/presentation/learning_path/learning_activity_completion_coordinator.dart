import 'dart:math';

import '../../data/repositories/learning_progress_repository.dart';
import '../../domain/learning/domain_ids.dart';
import '../../domain/learning/learning_models.dart';
import 'learning_map_view_model.dart';

typedef LearningActivityCompletionAction = Future<void> Function();

typedef LearningActivityCompletionActionFactory =
    LearningActivityCompletionAction? Function(
      LearningMapElementViewModel element,
    );

typedef LearningActivityCompletionWriter =
    Future<CompleteLearningActivityResult> Function(
      CompleteLearningActivityWrite command,
    );

/// Liga uma execução do Learning Map ao repositório durável de progresso.
///
/// Cada action cria um clientCompletionId apenas uma vez e reutiliza o mesmo
/// identificador em retries. Assim, a UI não inventa factos duplicados quando
/// uma escrita local é repetida.
typedef LearningActivityCompletionPersisted = void Function();

final class LearningActivityCompletionCoordinator {
  LearningActivityCompletionCoordinator({
    required this.accountId,
    required this.learningPath,
    required this.packageVersion,
    required LearningActivityCompletionWriter completeActivity,
    LearningActivityCompletionPersisted? onCompletionPersisted,
    DateTime Function()? clock,
    String Function()? clientCompletionIdFactory,
  }) : _completeActivity = completeActivity,
       _onCompletionPersisted = onCompletionPersisted,
       _clock = clock ?? DateTime.now,
       _clientCompletionIdFactory =
           clientCompletionIdFactory ?? _defaultClientCompletionId;

  factory LearningActivityCompletionCoordinator.fromRepository({
    required String accountId,
    required LearningPath learningPath,
    required int packageVersion,
    required LearningProgressRepository repository,
    LearningActivityCompletionPersisted? onCompletionPersisted,
  }) {
    return LearningActivityCompletionCoordinator(
      accountId: accountId,
      learningPath: learningPath,
      packageVersion: packageVersion,
      completeActivity: repository.completeActivity,
      onCompletionPersisted: onCompletionPersisted,
    );
  }

  final String accountId;
  final LearningPath learningPath;
  final int packageVersion;

  final LearningActivityCompletionWriter _completeActivity;
  final LearningActivityCompletionPersisted? _onCompletionPersisted;
  final DateTime Function() _clock;
  final String Function() _clientCompletionIdFactory;

  LearningActivityCompletionAction? actionFor(
    LearningMapElementViewModel element,
  ) {
    final rawActivityId = element.activityId?.trim();
    final rawRevisionId = element.revisionId?.trim();

    if (rawActivityId == null ||
        rawActivityId.isEmpty ||
        rawRevisionId == null ||
        rawRevisionId.isEmpty) {
      return null;
    }

    String? clientCompletionId;
    Future<void>? inFlight;
    var persisted = false;

    return () {
      if (persisted) {
        return Future<void>.value();
      }

      final current = inFlight;
      if (current != null) {
        return current;
      }

      clientCompletionId ??= _clientCompletionIdFactory();

      final write = CompleteLearningActivityWrite(
        clientCompletionId: clientCompletionId!,
        accountId: accountId,
        learningPath: learningPath,
        activityId: ActivityId(rawActivityId),
        revisionId: RevisionId(rawRevisionId),
        packageVersion: packageVersion,
        completedAt: _clock(),
        practicePreference: element.practicePreference,
      );

      late Future<void> guarded;

      guarded = _completeActivity(write)
          .then<void>((_) {
            persisted = true;

            // A conclusão já está duravelmente persistida e a aprendizagem
            // local não espera rede. Apenas agenda a convergência em background.
            _onCompletionPersisted?.call();
          })
          .whenComplete(() {
            if (identical(inFlight, guarded)) {
              inFlight = null;
            }
          });

      inFlight = guarded;
      return guarded;
    };
  }

  static String _defaultClientCompletionId() {
    final random = Random.secure();
    final entropy = List<int>.generate(12, (_) => random.nextInt(256));
    final suffix = entropy
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();

    return 'dt-${DateTime.now().toUtc().microsecondsSinceEpoch}-$suffix';
  }
}
