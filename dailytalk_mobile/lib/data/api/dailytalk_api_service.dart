import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';

/// Serviço responsável pela comunicação com a API DailyTalk.
class DailyTalkApiService {
  DailyTalkApiService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// Obtém parâmetros dinâmicos da atividade.
  ///
  /// Endpoint previsto: GET /json-params.
  Future<List<Map<String, dynamic>>> getJsonParams() async {
    if (AppConfig.useMockApi) {
      return [
        {'name': 'scenario', 'type': 'text/plain'},
        {'name': 'language', 'type': 'text/plain'},
        {'name': 'difficulty', 'type': 'text/plain'},
      ];
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/json-params');

    final response = await _client.get(uri).timeout(
          const Duration(seconds: 10),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Erro ao obter parâmetros da atividade. Código: ${response.statusCode}',
      );
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! List) {
      throw Exception('Formato inválido em /json-params.');
    }

    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  /// Inicia/cria a atividade no backend.
  ///
  /// Endpoint previsto:
  /// GET /deploy?activityID=ID_DA_ATIVIDADE&type=TIPO_DA_ATIVIDADE.
  Future<String> deployActivity({
    required String activityId,
    required String type,
  }) async {
    if (AppConfig.useMockApi) {
      return 'https://dailytalk.pt/activity/$type/$activityId';
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/deploy').replace(
      queryParameters: {
        'activityID': activityId,
        'type': type,
      },
    );

    final response = await _client.get(uri).timeout(
          const Duration(seconds: 10),
        );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception(
        'Erro ao iniciar atividade. Código: ${response.statusCode}',
      );
    }

    final activityUrl = response.body.trim();

    if (activityUrl.isEmpty) {
      throw Exception('O servidor devolveu uma URL vazia.');
    }

    return activityUrl;
  }
}