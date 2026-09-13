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

/// Facto recebido do servidor através do Secure Sync.
///
/// O servidor nunca fornece competências nem estados pedagógicos.
/// Esses valores continuam a ser derivados do conteúdo oficial local.
final class RemoteLearningCompletionFact {
  const RemoteLearningCompletionFact({
    required this.serverCompletionId,
    required this.clientCompletionId,
    required this.learningPathId,
    required this.activityId,
    required this.revisionId,
    required this.packageVersion,
    required this.completedAt,
  });

  final String serverCompletionId;
  final String clientCompletionId;
  final String learningPathId;

  final ActivityId activityId;
  final RevisionId revisionId;

  final int packageVersion;
  final DateTime completedAt;
}

/// Página remota que será fundida atomicamente no SQLite.
final class MergeRemoteLearningProgressWrite {
  MergeRemoteLearningProgressWrite({
    required this.accountId,
    required this.learningPath,
    required this.activePackageVersion,
    required this.expectedCursor,
    required this.nextCursor,
    required Iterable<RemoteLearningCompletionFact> completions,
    this.practicePreference = PracticePreference.balanced,
  }) : completions = List<RemoteLearningCompletionFact>.unmodifiable(
         completions,
       );

  final String accountId;
  final LearningPath learningPath;

  /// Versão oficial atualmente validada neste dispositivo.
  final int activePackageVersion;

  /// Cursor usado para produzir esta página.
  final String? expectedCursor;

  /// Cursor confirmado pelo servidor após esta página.
  final String? nextCursor;

  final List<RemoteLearningCompletionFact> completions;
  final PracticePreference practicePreference;
}

final class MergeRemoteLearningProgressResult {
  const MergeRemoteLearningProgressResult({
    required this.insertedCount,
    required this.duplicateCount,
    required this.cursor,
  });

  final int insertedCount;
  final int duplicateCount;
  final String? cursor;
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

  Future<bool> ensureProjection({
    required String accountId,
    required LearningPath learningPath,
    required int activePackageVersion,
    PracticePreference practicePreference = PracticePreference.balanced,
    bool forceRebuild = false,
  }) {
    final normalizedAccountId = accountId.trim();

    if (normalizedAccountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'não pode estar vazio');
    }

    if (activePackageVersion <= 0) {
      throw ArgumentError.value(
        activePackageVersion,
        'activePackageVersion',
        'deve ser positivo',
      );
    }

    return _db.transaction((txn) async {
      final pathId = learningPath.id.value;
      final elements = _pathElementsById(learningPath);

      final elementsByValue = <String, PathElement>{
        for (final entry in elements.entries) entry.key.value: entry.value,
      };

      final existingRows = await txn.query(
        'learning_progress_projection',
        columns: const <String>[
          'path_element_id',
          'activity_id',
          'state',
          'reason',
          'recommendation_rank',
          'package_version',
        ],
        where: 'account_id = ? AND learning_path_id = ?',
        whereArgs: <Object?>[normalizedAccountId, pathId],
      );

      var projectionIsCurrent = existingRows.length == elementsByValue.length;

      if (projectionIsCurrent) {
        for (final row in existingRows) {
          final pathElementId = row['path_element_id'];
          final element = pathElementId is String
              ? elementsByValue[pathElementId]
              : null;

          if (element == null ||
              row['package_version'] != activePackageVersion ||
              row['activity_id'] != element.activityId?.value) {
            projectionIsCurrent = false;
            break;
          }

          final state = row['state'];
          final reason = row['reason'];
          final recommendationRank = row['recommendation_rank'];

          if (state is! String ||
              !LearningActivityState.values.any(
                (candidate) => candidate.name == state,
              ) ||
              reason is! String ||
              !ProgressionReason.values.any(
                (candidate) => candidate.name == reason,
              ) ||
              (recommendationRank != null && recommendationRank is! int)) {
            projectionIsCurrent = false;
            break;
          }
        }
      }

      if (!forceRebuild && projectionIsCurrent) {
        return false;
      }

      // O progresso parcial é local ao dispositivo. Deve sobreviver tanto
      // a atualizações/fallback do catálogo como a reconstruções forçadas.
      final activitiesInProgress = existingRows
          .where(
            (row) =>
                row['state'] == LearningActivityState.inProgress.name &&
                row['activity_id'] is String,
          )
          .map((row) => row['activity_id']! as String)
          .where((activityId) => activityId.trim().isNotEmpty)
          .map(ActivityId.new)
          .toSet();

      final facts = await _loadFacts(
        txn,
        accountId: normalizedAccountId,
        learningPathId: pathId,
      );

      final progression = _engine.evaluate(
        ProgressionRequest(
          learningPath: learningPath,
          facts: facts,
          practicePreference: practicePreference,
          activitiesInProgress: activitiesInProgress,
        ),
      );

      await _replaceProjection(
        txn,
        accountId: normalizedAccountId,
        learningPath: learningPath,
        packageVersion: activePackageVersion,
        progression: progression,
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      );

      return true;
    });
  }

  /// Lê a posição confirmada do feed remoto para a conta/percurso.
  Future<String?> readSyncCursor({
    required String accountId,
    required String learningPathId,
  }) async {
    final rows = await _db.query(
      'learning_progress_sync_state',
      columns: const <String>['cursor'],
      where: 'account_id = ? AND learning_path_id = ?',
      whereArgs: <Object?>[accountId, learningPathId],
      limit: 1,
    );

    if (rows.isEmpty) {
      return null;
    }

    return rows.single['cursor']! as String;
  }

  /// Número global de atividades distintas concluídas pela conta.
  ///
  /// Esta é a base canónica de progressão para a Fase 3:
  ///
  /// - independe do dispositivo;
  /// - independe do percurso;
  /// - múltiplos factos da mesma ActivityId contam apenas uma vez.
  ///
  /// Uma camada de gamificação poderá futuramente atribuir pesos/XP sem
  /// alterar esta invariável de deduplicação.
  Future<int> readGlobalDistinctCompletedActivityCount({
    required String accountId,
  }) async {
    final normalizedAccountId = accountId.trim();

    if (normalizedAccountId.isEmpty) {
      throw ArgumentError.value(accountId, 'accountId', 'não pode estar vazio');
    }

    final rows = await _db.rawQuery(
      '''
      SELECT COUNT(DISTINCT activity_id) AS activity_count
      FROM learning_progress_completions
      WHERE account_id = ?
      ''',
      <Object?>[normalizedAccountId],
    );

    final value = rows.single['activity_count'];

    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toInt();
    }

    throw StateError('COUNT(DISTINCT activity_id) devolveu tipo inesperado.');
  }

  /// Funde uma página recebida pelo Secure Sync.
  ///
  /// Invariantes:
  /// - não cria outbox;
  /// - não confia em competências vindas da rede;
  /// - valida activity/revision contra o conteúdo oficial local;
  /// - conclusão é monotónica;
  /// - projeção é sempre recalculada;
  /// - cursor só avança na mesma transação do merge.
  Future<MergeRemoteLearningProgressResult> mergeRemoteProgress(
    MergeRemoteLearningProgressWrite command,
  ) {
    return _db.transaction((txn) => _mergeRemoteProgress(txn, command));
  }

  Future<MergeRemoteLearningProgressResult> _mergeRemoteProgress(
    Transaction txn,
    MergeRemoteLearningProgressWrite command,
  ) async {
    final accountId = command.accountId.trim();

    if (accountId.isEmpty) {
      throw ArgumentError.value(
        command.accountId,
        'accountId',
        'não pode estar vazio',
      );
    }

    if (command.activePackageVersion < 1) {
      throw ArgumentError.value(
        command.activePackageVersion,
        'activePackageVersion',
        'deve ser igual ou superior a 1',
      );
    }

    final pathId = command.learningPath.id.value;

    String? normalizeCursor(String? value, String fieldName) {
      if (value == null) {
        return null;
      }

      final normalized = value.trim();

      if (normalized.isEmpty) {
        throw ArgumentError.value(value, fieldName, 'não pode estar vazio');
      }

      return normalized;
    }

    final expectedCursor = normalizeCursor(
      command.expectedCursor,
      'expectedCursor',
    );

    final nextCursor = normalizeCursor(command.nextCursor, 'nextCursor');

    // --------------------------------------------------------
    // 1. Compare-and-set do cursor
    //
    // Duas sincronizações concorrentes nunca podem fazer uma
    // página antiga sobrescrever uma posição mais nova.
    // --------------------------------------------------------

    final stateRows = await txn.query(
      'learning_progress_sync_state',
      columns: const <String>['cursor'],
      where: 'account_id = ? AND learning_path_id = ?',
      whereArgs: <Object?>[accountId, pathId],
      limit: 1,
    );

    final storedCursor = stateRows.isEmpty
        ? null
        : stateRows.single['cursor']! as String;

    if (storedCursor != expectedCursor) {
      throw StateError(
        'Cursor local mudou durante a sincronização. '
        'Esperado=${expectedCursor ?? '<início>'}, '
        'atual=${storedCursor ?? '<início>'}.',
      );
    }

    // Contrato da Fase 3.5A:
    //
    // página vazia mantém o cursor;
    // página não vazia devolve como cursor o completionId do último facto.
    if (command.completions.isEmpty) {
      if (nextCursor != expectedCursor) {
        throw StateError(
          'Página vazia não pode alterar o cursor de progresso.',
        );
      }
    } else {
      final lastServerCompletionId = command.completions.last.serverCompletionId
          .trim();

      if (lastServerCompletionId.isEmpty) {
        throw const FormatException('serverCompletionId remoto vazio.');
      }

      if (nextCursor != lastServerCompletionId) {
        throw StateError(
          'nextCursor não corresponde ao último facto da página.',
        );
      }
    }

    final createdAt = DateTime.now().toUtc().toIso8601String();

    var insertedCount = 0;
    var duplicateCount = 0;

    // --------------------------------------------------------
    // 2. União monotónica das conclusões
    // --------------------------------------------------------

    for (final fact in command.completions) {
      final serverCompletionId = fact.serverCompletionId.trim();
      final clientCompletionId = fact.clientCompletionId.trim();

      if (serverCompletionId.isEmpty) {
        throw const FormatException('serverCompletionId remoto vazio.');
      }

      if (clientCompletionId.isEmpty) {
        throw const FormatException('clientCompletionId remoto vazio.');
      }

      if (fact.learningPathId != pathId) {
        throw StateError(
          'Facto remoto pertence a outro percurso: '
          '${fact.learningPathId}.',
        );
      }

      if (fact.packageVersion < 1) {
        throw StateError(
          'packageVersion remoto inválido: ${fact.packageVersion}.',
        );
      }

      // Se outro dispositivo já está numa versão oficial mais nova,
      // este dispositivo deve primeiro atualizar o conteúdo e só depois
      // aceitar o facto. O cursor NÃO avançará porque toda a transação
      // será revertida.
      if (fact.packageVersion > command.activePackageVersion) {
        throw StateError(
          'Conteúdo local desatualizado. '
          'Facto remoto usa packageVersion=${fact.packageVersion}, '
          'local=${command.activePackageVersion}.',
        );
      }

      final activity = _resolveActivityInPath(
        command.learningPath,
        fact.activityId,
      );

      final revision = _resolveRevision(activity, fact.revisionId);

      final existing = await txn.query(
        'learning_progress_completions',
        where: 'client_completion_id = ?',
        whereArgs: <Object?>[clientCompletionId],
        limit: 1,
      );

      if (existing.isNotEmpty) {
        _assertSameRemoteCompletion(
          existing.single,
          accountId: accountId,
          fact: fact,
        );

        duplicateCount += 1;
        continue;
      }

      final completionId = await txn
          .insert('learning_progress_completions', <String, Object?>{
            'client_completion_id': clientCompletionId,
            'account_id': accountId,
            'learning_path_id': pathId,
            'activity_id': fact.activityId.value,
            'revision_id': fact.revisionId.value,
            'package_version': fact.packageVersion,
            'completed_at': fact.completedAt.toUtc().toIso8601String(),
            'created_at': createdAt,
          });

      // Competências vêm SEMPRE da ActivityRevision oficial local.
      final competencies = revision.competencies.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      for (final competencyId in competencies) {
        await txn.insert('learning_competency_evidence', <String, Object?>{
          'completion_id': completionId,
          'competency_id': competencyId.value,
          'evidence_type': 'activity_completion',
          'created_at': createdAt,
        });
      }

      insertedCount += 1;
    }

    // --------------------------------------------------------
    // 3. Preservar inProgress deste dispositivo
    //
    // O estado parcial continua local ao dispositivo. Uma sincronização
    // remota não pode apagá-lo ao reconstruir a projeção.
    // --------------------------------------------------------

    final inProgressRows = await txn.query(
      'learning_progress_projection',
      columns: const <String>['activity_id'],
      where:
          'account_id = ? AND learning_path_id = ? '
          'AND state = ? AND activity_id IS NOT NULL',
      whereArgs: <Object?>[
        accountId,
        pathId,
        LearningActivityState.inProgress.name,
      ],
    );

    final activitiesInProgress = inProgressRows
        .map((row) => row['activity_id'])
        .whereType<String>()
        .map(ActivityId.new)
        .toSet();

    // --------------------------------------------------------
    // 4. Reconstruir factos globais e recalcular o motor
    // --------------------------------------------------------

    final facts = await _loadFacts(
      txn,
      accountId: accountId,
      learningPathId: pathId,
    );

    final progression = _engine.evaluate(
      ProgressionRequest(
        learningPath: command.learningPath,
        facts: facts,
        practicePreference: command.practicePreference,
        activitiesInProgress: activitiesInProgress,
      ),
    );

    await _replaceProjection(
      txn,
      accountId: accountId,
      learningPath: command.learningPath,
      packageVersion: command.activePackageVersion,
      progression: progression,
      updatedAt: createdAt,
    );

    // --------------------------------------------------------
    // 5. Cursor confirmado na MESMA transação
    // --------------------------------------------------------

    if (nextCursor != null) {
      await txn.insert('learning_progress_sync_state', <String, Object?>{
        'account_id': accountId,
        'learning_path_id': pathId,
        'cursor': nextCursor,
        'updated_at': createdAt,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }

    return MergeRemoteLearningProgressResult(
      insertedCount: insertedCount,
      duplicateCount: duplicateCount,
      cursor: nextCursor,
    );
  }

  Future<void> _replaceProjection(
    Transaction txn, {
    required String accountId,
    required LearningPath learningPath,
    required int packageVersion,
    required ProgressionResult progression,
    required String updatedAt,
  }) async {
    final pathId = learningPath.id.value;

    await txn.delete(
      'learning_progress_projection',
      where: 'account_id = ? AND learning_path_id = ?',
      whereArgs: <Object?>[accountId, pathId],
    );

    final elements = _pathElementsById(learningPath);
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
        'account_id': accountId,
        'learning_path_id': pathId,
        'path_element_id': entry.key.value,
        'activity_id': element.activityId?.value,
        'state': entry.value.state.name,
        'reason': entry.value.reason.name,
        'recommendation_rank': recommendationRanks[entry.key],
        'package_version': packageVersion,
        'updated_at': updatedAt,
      });
    }
  }

  Activity _resolveActivityInPath(
    LearningPath learningPath,
    ActivityId activityId,
  ) {
    for (final activity in learningPath.activities) {
      if (activity.id == activityId) {
        return activity;
      }
    }

    throw StateError(
      'ActivityId ${activityId.value} não pertence ao percurso '
      '${learningPath.id.value}.',
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

    // As conclusões permanecem específicas do percurso avaliado.
    //
    // As competências, porém, pertencem à conta: se foram adquiridas
    // validamente noutro percurso ou dispositivo, podem satisfazer um
    // pré-requisito baseado na mesma CompetencyId.
    final competencyRows = await txn.rawQuery(
      '''
      SELECT DISTINCT e.competency_id
      FROM learning_competency_evidence e
      INNER JOIN learning_progress_completions c
        ON c.id = e.completion_id
      WHERE c.account_id = ?
        AND e.evidence_type = 'activity_completion'
      ''',
      <Object?>[accountId],
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

  void _assertSameRemoteCompletion(
    Map<String, Object?> row, {
    required String accountId,
    required RemoteLearningCompletionFact fact,
  }) {
    final storedCompletedAt = DateTime.tryParse(
      row['completed_at']?.toString() ?? '',
    );

    // O backend normaliza timestamps para milissegundos através de
    // Date.toISOString(). A comparação temporal usa por isso a mesma
    // resolução e não a representação textual.
    final sameCompletedAt =
        storedCompletedAt != null &&
        storedCompletedAt.toUtc().millisecondsSinceEpoch ==
            fact.completedAt.toUtc().millisecondsSinceEpoch;

    final matches =
        row['account_id'] == accountId &&
        row['learning_path_id'] == fact.learningPathId &&
        row['activity_id'] == fact.activityId.value &&
        row['revision_id'] == fact.revisionId.value &&
        row['package_version'] == fact.packageVersion &&
        sameCompletedAt;

    if (!matches) {
      throw StateError(
        'clientCompletionId remoto já existe com outro facto: '
        '${fact.clientCompletionId}',
      );
    }
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
