import 'dart:convert';

import 'package:sqflite/sqflite.dart';

/// DAO responsável pela área de análises do professor.
class AnalyticsDao {
  AnalyticsDao(this.db);

  final Database db;

  /// Guarda definições de métricas recebidas do endpoint GET /analytics-list.
  ///
  /// A estrutura exata pode variar, por isso o método aceita mapas flexíveis.
  Future<void> replaceAnalyticsDefinitions(
    List<Map<String, dynamic>> definitions,
  ) async {
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete('analytics_definitions');

      for (final definition in definitions) {
        final code = (definition['code'] ??
                definition['id'] ??
                definition['name'] ??
                'metric_${definitions.indexOf(definition)}')
            .toString();

        await txn.insert('analytics_definitions', {
          'code': code,
          'name': (definition['name'] ?? code).toString(),
          'analytics_type': (definition['analytics_type'] ??
                  definition['type'] ??
                  'quant')
              .toString(),
          'value_type': definition['value_type']?.toString(),
          'description': definition['description']?.toString(),
          'created_at': now,
          'updated_at': now,
        });
      }
    });
  }

  /// Lista definições de métricas.
  Future<List<Map<String, Object?>>> getAnalyticsDefinitions() async {
    return db.query(
      'analytics_definitions',
      orderBy: 'analytics_type ASC, name ASC',
    );
  }

  /// Guarda registos analíticos recebidos por POST /analytics.
  ///
  /// Exemplo esperado por item:
  /// {
  ///   "inveniraStdID": "...",
  ///   "quantAnalytics": [...],
  ///   "qualAnalytics": [...]
  /// }
  Future<void> replaceAnalyticsRecordsForActivity({
    required int? activityId,
    required String remoteActivityId,
    required List<Map<String, dynamic>> records,
  }) async {
    final now = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      await txn.delete(
        'analytics_records',
        where: 'remote_activity_id = ?',
        whereArgs: [remoteActivityId],
      );

      for (final record in records) {
        final inveniraStdId =
            (record['inveniraStdID'] ?? record['invenira_std_id']).toString();

        int? studentId;

        final existingStudent = await txn.query(
          'students',
          where: 'invenira_std_id = ?',
          whereArgs: [inveniraStdId],
          limit: 1,
        );

        if (existingStudent.isEmpty) {
          studentId = await txn.insert('students', {
            'invenira_std_id': inveniraStdId,
            'display_name': record['displayName']?.toString(),
            'class_name': record['className']?.toString(),
            'created_at': now,
            'updated_at': now,
            'last_seen_at': now,
          });
        } else {
          studentId = existingStudent.first['id'] as int;
        }

        final quantAnalytics = record['quantAnalytics'];
        final qualAnalytics = record['qualAnalytics'];

        await txn.insert(
          'analytics_records',
          {
            'activity_id': activityId,
            'student_id': studentId,
            'remote_activity_id': remoteActivityId,
            'invenira_std_id': inveniraStdId,
            'quant_analytics_json':
                quantAnalytics == null ? null : jsonEncode(quantAnalytics),
            'qual_analytics_json':
                qualAnalytics == null ? null : jsonEncode(qualAnalytics),
            'total_interactions': _extractIntMetric(
              quantAnalytics,
              ['totalInteracoes', 'total_interactions', 'total interactions'],
            ),
            'activity_time_seconds': _extractIntMetric(
              quantAnalytics,
              ['tempoAtividade', 'activity_time_seconds', 'time'],
            ),
            'student_profile': _extractStringMetric(
              qualAnalytics,
              ['perfilEstudante', 'student_profile', 'profile'],
            ),
            'heatmap_url': _extractStringMetric(
              qualAnalytics,
              ['heatmapURL', 'heatmap_url', 'heatmap'],
            ),
            'fetched_at': now,
            'created_at': now,
            'updated_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  /// Lista análises de uma atividade para o ecrã do professor.
  Future<List<Map<String, Object?>>> getAnalyticsForActivity(
    String remoteActivityId,
  ) async {
    return db.query(
      'analytics_records',
      where: 'remote_activity_id = ?',
      whereArgs: [remoteActivityId],
      orderBy: 'invenira_std_id ASC',
    );
  }

  /// Tenta extrair um valor inteiro de uma lista/mapa de métricas.
  int? _extractIntMetric(dynamic analytics, List<String> possibleKeys) {
    final value = _extractMetricValue(analytics, possibleKeys);

    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(value.toString());
  }

  /// Tenta extrair texto de uma lista/mapa de métricas.
  String? _extractStringMetric(dynamic analytics, List<String> possibleKeys) {
    final value = _extractMetricValue(analytics, possibleKeys);
    return value?.toString();
  }

  /// Extrai uma métrica de estruturas flexíveis.
  ///
  /// Suporta:
  /// - mapa direto: { "tempoAtividade": 120 }
  /// - lista de mapas: [{ "name": "tempoAtividade", "value": 120 }]
  dynamic _extractMetricValue(dynamic analytics, List<String> possibleKeys) {
    if (analytics == null) return null;

    final normalizedKeys = possibleKeys.map(_normalize).toSet();

    if (analytics is Map) {
      for (final entry in analytics.entries) {
        if (normalizedKeys.contains(_normalize(entry.key.toString()))) {
          return entry.value;
        }
      }
    }

    if (analytics is List) {
      for (final item in analytics) {
        if (item is Map) {
          final name = (item['name'] ?? item['code'] ?? item['key'])?.toString();

          if (name != null && normalizedKeys.contains(_normalize(name))) {
            return item['value'] ?? item['result'];
          }

          for (final entry in item.entries) {
            if (normalizedKeys.contains(_normalize(entry.key.toString()))) {
              return entry.value;
            }
          }
        }
      }
    }

    return null;
  }

  String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll('_', '')
        .replaceAll('-', '')
        .replaceAll(' ', '');
  }
}
