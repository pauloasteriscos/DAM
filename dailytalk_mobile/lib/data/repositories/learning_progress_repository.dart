import 'dart:collection';
import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/learning/default_progression_engine.dart';
import '../../domain/learning/domain_ids.dart';
import '../../domain/learning/learning_enums.dart';
import '../../domain/learning/learning_models.dart';
import '../../domain/learning/prerequisite_rule.dart';
import '../../domain/learning/progression_engine.dart';

/// Comando local para concluir uma atividade.
///
/// O chamador fornece apenas o facto ocorrido e o percurso oficial utilizado.
/// Competências e projeção pedagógica nunca são fornecidas arbitrariamente
/// pelo chamador:
///
/// - competências são derivadas da ActivityRevision efetivamente concluída;
/// - estados são calculados pelo ProgressionEngine.
///
/// O clientCompletionId é criado uma única vez e permanece estável em retries.
final class CompleteLearningActivityWrite {
  CompleteLearningActivityWrite({
    required this.clientCompletionId,
    required this.accountId,
    required this.learningPath,
    required this.activityId,
    required this.revisionId,
    required this.packageVersion,
    required this.completedAt,
    this.practicePreference = PracticePreference.balanced,
    Iterable<ActivityId> activitiesInProgress = const <ActivityId>[],
  }) : activitiesInProgress = UnmodifiableSetView(
         Set<ActivityId>.of(activitiesInProgress),
       );

  final String clientCompletionId;
  final String accountId;

  final LearningPath learningPath;
  final ActivityId activityId;
  final RevisionId revisionId;

  final int packageVersion;
  final DateTime completedAt;

  final PracticePreference practicePreference;
  final Set<ActivityId> activitiesInProgress;
}

final class CompleteLearningActivityResult {
  const CompleteLearningActivityResult({
    required this.completionId,
    required this.alreadyCompleted,
  });

  final int completionId;
  final bool alreadyCompleted;
}

/// Persistência offline-first do progresso pedagógico.
///
/// A conclusão é uma única transação SQLite:
///
/// completion
///   -> competency evidence
///   -> ProgressionFacts
///   -> ProgressionEngine
///   -> projection
///   -> outbox
///   -> COMMIT
///
/// Não existe dependência de rede neste fluxo.
final class LearningProgressRepository {
  LearningProgressRepository(
    this._db, {
    ProgressionEngine engine = const DefaultProgressionEngine(),
  }) : _engine = engine;

  final Database _db;
  final ProgressionEngine _engine;

  Future<CompleteLearningActivityResult> completeActivity(
    CompleteLearningActivityWrite command,
  ) {
    return _db.transaction((txn) => _completeActivity(txn, command));
  }

  Future<CompleteLearningActivityResult> _completeActivity(
    Transaction txn,
    CompleteLearningActivityWrite command,
  ) async {
    final activity = _resolveActivity(command);
    final revision = _resolveRevision(activity, command.revisionId);

    final pathId = command.learningPath.id.value;

    final existing = await txn.query(
      'learning_progress_completions',
      where: 'client_completion_id = ?',
      whereArgs: <Object?>[command.clientCompletionId],
      limit: 1,
    );

    if (existing.isNotEmpty) {
      final row = existing.single;

      _assertSameCompletion(row, command);

      return CompleteLearningActivityResult(
        completionId: row['id'] as int,
        alreadyCompleted: true,
      );
    }

    final completedAt = command.completedAt.toUtc().toIso8601String();

    final createdAt = DateTime.now().toUtc().toIso8601String();

    // --------------------------------------------------------
    // 1. Facto durável de conclusão
    // --------------------------------------------------------

    final completionId = await txn
        .insert('learning_progress_completions', <String, Object?>{
          'client_completion_id': command.clientCompletionId,
          'account_id': command.accountId,
          'learning_path_id': pathId,
          'activity_id': command.activityId.value,
          'revision_id': command.revisionId.value,
          'package_version': command.packageVersion,
          'completed_at': completedAt,
          'created_at': createdAt,
        });

    // --------------------------------------------------------
    // 2. Evidência derivada da revisão efetivamente concluída
    // --------------------------------------------------------

    final revisionCompetencies = revision.competencies.toList()
      ..sort((a, b) => a.value.compareTo(b.value));

    for (final competencyId in revisionCompetencies) {
      await txn.insert('learning_competency_evidence', <String, Object?>{
        'completion_id': completionId,
        'competency_id': competencyId.value,
        'evidence_type': 'activity_completion',
        'created_at': createdAt,
      });
    }

    // --------------------------------------------------------
    // 3. Reconstruir factos monotónicos a partir do SQLite
    // --------------------------------------------------------

    final facts = await _loadFacts(
      txn,
      accountId: command.accountId,
      learningPathId: pathId,
    );

    // --------------------------------------------------------
    // 4. Motor pedagógico puro
    // --------------------------------------------------------

    final progression = _engine.evaluate(
      ProgressionRequest(
        learningPath: command.learningPath,
        facts: facts,
        practicePreference: command.practicePreference,
        activitiesInProgress: command.activitiesInProgress,
      ),
    );

    // --------------------------------------------------------
    // 5. Persistir projeção derivada
    //
    // Neste primeiro percurso são poucos elementos. Substituímos
    // atomicamente a projeção daquele utilizador/percurso para
    // evitar linhas obsoletas de versões anteriores do conteúdo.
    // --------------------------------------------------------

    await txn.delete(
      'learning_progress_projection',
      where: 'account_id = ? AND learning_path_id = ?',
      whereArgs: <Object?>[command.accountId, pathId],
    );

    final elements = _pathElementsById(command.learningPath);

    final recommendationRanks = <PathElementId, int>{};

    for (var index = 0; index < progression.recommendations.length; index++) {
      recommendationRanks[progression.recommendations[index]] = index;
    }

    for (final entry in progression.decisions.entries) {
      final element = elements[entry.key];

      if (element == null) {
        throw StateError(
          'ProgressionEngine devolveu PathElementId desconhecido: '
          '${entry.key.value}',
        );
      }

      await txn.insert('learning_progress_projection', <String, Object?>{
        'account_id': command.accountId,
        'learning_path_id': pathId,
        'path_element_id': entry.key.value,
        'activity_id': element.activityId?.value,
        'state': entry.value.state.name,
        'reason': entry.value.reason.name,
        'recommendation_rank': recommendationRanks[entry.key],
        'package_version': command.packageVersion,
        'updated_at': createdAt,
      });
    }

    // --------------------------------------------------------
    // 6. Outbox na mesma transação
    // --------------------------------------------------------

    final payload = jsonEncode(<String, Object?>{
      'type': 'ActivityCompleted',
      'clientCompletionId': command.clientCompletionId,
      'learningPathId': pathId,
      'activityId': command.activityId.value,
      'revisionId': command.revisionId.value,
      'packageVersion': command.packageVersion,
      'completedAt': completedAt,
      'competencyIds': revisionCompetencies
          .map((id) => id.value)
          .toList(growable: false),
    });

    await txn.insert('sync_queue', <String, Object?>{
      'entity_type': 'learning_progress_completion',
      'entity_id': completionId,
      'operation': 'ActivityCompleted',
      'endpoint': '/api/sync/progress',
      'method': 'POST',
      'payload_json': payload,
      'sync_status': 'pending',
      'attempt_count': 0,
      'last_error': null,
      'created_at': createdAt,
      'updated_at': createdAt,
      'next_retry_at': null,
      'processed_at': null,
    });

    return CompleteLearningActivityResult(
      completionId: completionId,
      alreadyCompleted: false,
    );
  }

  Activity _resolveActivity(CompleteLearningActivityWrite command) {
    for (final activity in command.learningPath.activities) {
      if (activity.id == command.activityId) {
        return activity;
      }
    }

    throw StateError(
      'ActivityId ${command.activityId.value} não pertence ao percurso '
      '${command.learningPath.id.value}.',
    );
  }

  ActivityRevision _resolveRevision(Activity activity, RevisionId revisionId) {
    for (final revision in activity.revisions) {
      if (revision.id == revisionId) {
        return revision;
      }
    }

    throw StateError(
      'RevisionId ${revisionId.value} não pertence à atividade '
      '${activity.id.value}.',
    );
  }

  Future<ProgressionFacts> _loadFacts(
    Transaction txn, {
    required String accountId,
    required String learningPathId,
  }) async {
    final completedRows = await txn.query(
      'learning_progress_completions',
      columns: const <String>['activity_id'],
      where: 'account_id = ? AND learning_path_id = ?',
      whereArgs: <Object?>[accountId, learningPathId],
    );

    final competencyRows = await txn.rawQuery(
      '''
      SELECT DISTINCT e.competency_id
      FROM learning_competency_evidence e
      INNER JOIN learning_progress_completions c
        ON c.id = e.completion_id
      WHERE c.account_id = ?
        AND c.learning_path_id = ?
        AND e.evidence_type = 'activity_completion'
      ''',
      <Object?>[accountId, learningPathId],
    );

    return ProgressionFacts(
      completedActivities: completedRows.map(
        (row) => ActivityId(row['activity_id']! as String),
      ),
      achievedCompetencies: competencyRows.map(
        (row) => CompetencyId(row['competency_id']! as String),
      ),
    );
  }

  Map<PathElementId, PathElement> _pathElementsById(LearningPath learningPath) {
    final result = <PathElementId, PathElement>{};

    for (final journey in learningPath.journeys) {
      for (final stage in journey.stages) {
        for (final element in stage.elements) {
          result[element.id] = element;
        }
      }
    }

    return result;
  }

  void _assertSameCompletion(
    Map<String, Object?> row,
    CompleteLearningActivityWrite command,
  ) {
    final expectedCompletedAt = command.completedAt.toUtc().toIso8601String();

    final matches =
        row['account_id'] == command.accountId &&
        row['learning_path_id'] == command.learningPath.id.value &&
        row['activity_id'] == command.activityId.value &&
        row['revision_id'] == command.revisionId.value &&
        row['package_version'] == command.packageVersion &&
        row['completed_at'] == expectedCompletedAt;

    if (!matches) {
      throw StateError(
        'clientCompletionId já utilizado por uma conclusão diferente: '
        '${command.clientCompletionId}',
      );
    }
  }
}
