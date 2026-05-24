import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../storage/auth_token_storage.dart';

/// Serviço responsável pela comunicação com a API DailyTalk.
class DailyTalkApiService {
  DailyTalkApiService({
    http.Client? client,
    AuthTokenStorage? tokenStorage,
  })  : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? AuthTokenStorage();

  final http.Client _client;
  final AuthTokenStorage _tokenStorage;

  /// Obtém parâmetros dinâmicos da atividade.
  Future<List<Map<String, dynamic>>> getJsonParams() async {
    if (AppConfig.useMockApi) {
      return [
        {'name': 'scenario', 'type': 'text/plain'},
        {'name': 'language', 'type': 'text/plain'},
        {'name': 'difficulty', 'type': 'text/plain'},
      ];
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/json-params');

    final response = await _client.get(uri).timeout(AppConfig.apiTimeout);

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

    final response = await _client
        .get(uri, headers: await _authHeaders())
        .timeout(AppConfig.apiTimeout);

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

  /// Submete as respostas da atividade.
  ///
  /// Endpoint real: POST /api/activities/submissions.
  Future<Map<String, dynamic>> submitActivity({
    required String activityId,
    required Map<String, dynamic> submission,
  }) async {
    if (AppConfig.useMockApi) {
      final answers = submission['answers'];

      final answerText = answers is List && answers.isNotEmpty
          ? answers.first['value']?.toString() ?? ''
          : '';

      final score = answerText.trim().length >= 20 ? 90.0 : 70.0;

      return {
        'activityID': activityId,
        'score': score,
        'feedback': score >= 80
            ? 'Boa resposta. A comunicação está clara e adequada ao contexto.'
            : 'Resposta válida, mas pode ser melhorada com mais detalhe e vocabulário.',
        'metrics': {
          'totalInteractions': 1,
          'answerLength': answerText.length,
          'evaluatedBy': 'mock',
        },
      };
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/activities/submissions');

    final response = await _client
        .post(
          uri,
          headers: await _authHeaders(),
          body: jsonEncode({
            'activityID': activityId,
            'submission': submission,
          }),
        )
        .timeout(AppConfig.apiTimeout);

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      final message = decoded is Map && decoded['error'] != null
          ? decoded['error'].toString()
          : 'Erro ao submeter atividade. Código: ${response.statusCode}';
      throw Exception(message);
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map) {
      throw Exception('Formato inválido em /activities/submissions.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _tokenStorage.readToken();

    if (token == null || token.isEmpty) {
      throw Exception('Sessão expirada. Inicia sessão novamente.');
    }

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }
}
