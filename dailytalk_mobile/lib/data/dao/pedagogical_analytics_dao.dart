import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../models/user_profile.dart';

/// DAO para analytics pedagógicos locais.
///
/// Estes dados servem para perceber dificuldades de aprendizagem,
/// sem guardar dados sensíveis do utilizador.
///
/// Exemplo correto:
/// - perfil: anfitrião;
/// - cenário: pequeno-almoço;
/// - tipo de atividade: diálogo;
/// - total de tentativas;
/// - total de erros;
/// - pontuação média.
///
/// Exemplo incorreto:
/// - guardar que um aluno tem uma alergia real.
/// - guardar informação de saúde.
/// - guardar dados pessoais sensíveis.
class PedagogicalAnalyticsDao {
  PedagogicalAnalyticsDao(this.db);

  final Database db;

  static const String _localUserId = 'local_user';

  /// Regista uma tentativa de atividade para fins pedagógicos.
  ///
  /// Este método atualiza um agregado local por:
  /// - perfil;
  /// - cenário;
  /// - tipo de atividade.
  Future<void> recordPracticeAttempt({
    required UserProfileType profile,
    required String scenario,
    required String activityType,
    double? score,
    String? feedbackText,
  }) async {
    final now = DateTime.now().toIso8601String();

    final analyticsKey =
        'analytics_${profile.databaseValue}_${scenario}_$activityType';

    final rows = await db.query(
      'analytics_records',
      where: 'remote_activity_id = ? AND invenira_std_id = ?',
      whereArgs: [analyticsKey, _localUserId],
      limit: 1,
    );

    var totalAttempts = 0;
    var totalErrors = 0;
    var averageScore = 0.0;

    if (rows.isNotEmpty) {
      final row = rows.first;
      final quantJson = row['quant_analytics_json']?.toString();

      if (quantJson != null && quantJson.isNotEmpty) {
        final decoded = jsonDecode(quantJson);

        if (decoded is Map) {
          totalAttempts = _asInt(decoded['totalAttempts']);
          totalErrors = _asInt(decoded['totalErrors']);
          averageScore = _asDouble(decoded['averageScore']);
        }
      }
    }

    final normalizedScore = _normalizeScore(score);

    final nextTotalAttempts = totalAttempts + 1;
    final nextTotalErrors = normalizedScore == null
        ? totalErrors
        : normalizedScore < 60
        ? totalErrors + 1
        : totalErrors;

    final nextAverageScore = normalizedScore == null
        ? averageScore
        : ((averageScore * totalAttempts) + normalizedScore) /
              nextTotalAttempts;

    final quantAnalytics = {
      'profile': profile.databaseValue,
      'scenario': scenario,
      'activityType': activityType,
      'totalAttempts': nextTotalAttempts,
      'totalErrors': nextTotalErrors,
      'averageScore': nextAverageScore,
      'lastScore': normalizedScore,
      'updatedAt': now,
    };

    final qualAnalytics = {
      'lastFeedback': feedbackText,
      'privacyNote':
          'Dados pedagógicos agregados. Não contém dados sensíveis reais.',
    };

    if (rows.isEmpty) {
      await db.insert('analytics_records', {
        'activity_id': null,
        'student_id': null,
        'remote_activity_id': analyticsKey,
        'invenira_std_id': _localUserId,
        'quant_analytics_json': jsonEncode(quantAnalytics),
        'qual_analytics_json': jsonEncode(qualAnalytics),
        'total_interactions': nextTotalAttempts,
        'activity_time_seconds': null,
        'student_profile': profile.databaseValue,
        'heatmap_url': null,
        'fetched_at': now,
        'created_at': now,
        'updated_at': now,
      });

      return;
    }

    await db.update(
      'analytics_records',
      {
        'quant_analytics_json': jsonEncode(quantAnalytics),
        'qual_analytics_json': jsonEncode(qualAnalytics),
        'total_interactions': nextTotalAttempts,
        'student_profile': profile.databaseValue,
        'fetched_at': now,
        'updated_at': now,
      },
      where: 'id = ?',
      whereArgs: [rows.first['id']],
    );
  }

  /// Lista analytics pedagógicos locais.
  Future<List<Map<String, Object?>>> getPedagogicalAnalytics({
    int limit = 30,
  }) async {
    final rows = await db.query(
      'analytics_records',
      where: 'remote_activity_id LIKE ?',
      whereArgs: ['analytics_%'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );

    return rows.map(_mapAnalyticsRow).toList();
  }

  Map<String, Object?> _mapAnalyticsRow(Map<String, Object?> row) {
    final quantJson = row['quant_analytics_json']?.toString();

    var profile = row['student_profile']?.toString();
    var scenario = '-';
    var activityType = '-';
    var totalAttempts = 0;
    var totalErrors = 0;
    var averageScore = 0.0;
    Object? lastScore;

    if (quantJson != null && quantJson.isNotEmpty) {
      final decoded = jsonDecode(quantJson);

      if (decoded is Map) {
        profile = decoded['profile']?.toString() ?? profile;
        scenario = decoded['scenario']?.toString() ?? '-';
        activityType = decoded['activityType']?.toString() ?? '-';
        totalAttempts = _asInt(decoded['totalAttempts']);
        totalErrors = _asInt(decoded['totalErrors']);
        averageScore = _asDouble(decoded['averageScore']);
        lastScore = decoded['lastScore'];
      }
    }

    return {
      'profile': profile,
      'scenario': scenario,
      'activity_type': activityType,
      'total_attempts': totalAttempts,
      'total_errors': totalErrors,
      'average_score': averageScore,
      'last_score': lastScore,
      'updated_at': row['updated_at'],
    };
  }

  int _asInt(Object? value) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value.toString()) ?? 0;
  }

  double _asDouble(Object? value) {
    if (value == null) {
      return 0;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  /// Normaliza a pontuação para escala 0-100.
  ///
  /// Se o backend/mock devolver 0-1, converte para 0-100.
  /// Se devolver 0-100, mantém.
  double? _normalizeScore(double? score) {
    if (score == null) {
      return null;
    }

    if (score <= 1) {
      return (score * 100).clamp(0, 100).toDouble();
    }

    return score.clamp(0, 100).toDouble();
  }
}
