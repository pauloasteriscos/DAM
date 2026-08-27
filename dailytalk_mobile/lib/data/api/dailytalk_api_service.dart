import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../config/app_config.dart';
import '../../security/auth_session_service.dart';
import '../../security/secure_sync_service.dart';
import '../storage/auth_token_storage.dart';

/// Serviço responsável pela comunicação com a API DailyTalk.
class DailyTalkApiService {
  DailyTalkApiService({
    http.Client? client,
    AuthTokenStorage? tokenStorage,
    AuthSessionService? authSessionService,
    SecureSyncService? secureSyncService,
  }) : _client = client ?? http.Client(),
       _authSessionService =
           authSessionService ??
           AuthSessionService(client: client, tokenStorage: tokenStorage),
       _secureSyncService =
           secureSyncService ??
           SecureSyncService(
             client: client,
             tokenStorage: tokenStorage,
             authSessionService: authSessionService,
           );

  final http.Client _client;
  final AuthSessionService _authSessionService;
  final SecureSyncService _secureSyncService;

  Future<List<Map<String, dynamic>>> getJsonParams() async {
    if (AppConfig.useMockApi) {
      return [
        {'name': 'scenario', 'type': 'text/plain'},
        {'name': 'language', 'type': 'text/plain'},
        {'name': 'difficulty', 'type': 'text/plain'},
      ];
    }

    final uri = Uri.parse('${AppConfig.apiBaseUrl}/json-params');
    final response = await _client
        .get(uri, headers: AppConfig.environmentHeaders)
        .timeout(AppConfig.apiTimeout);
    final decoded = _decodeResponse(response);
    if (decoded is! List) {
      throw Exception('Formato inválido em /json-params.');
    }
    return decoded
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Future<String> deployActivity({
    required String activityId,
    required String type,
  }) async {
    if (AppConfig.useMockApi) {
      return '${AppConfig.applicationBaseUrl}/activity/$type/$activityId';
    }

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/deploy',
    ).replace(queryParameters: {'activityID': activityId, 'type': type});
    final response = await _client
        .get(
          uri,
          headers: await _authSessionService.authenticatedHeaders(
            method: 'GET',
            uri: uri,
          ),
        )
        .timeout(AppConfig.apiTimeout);

    AppConfig.assertResponseEnvironment(response.headers);

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

  /// Endpoint antigo mantido para submissão imediata.
  /// A ação manual "Sincronizar progresso" usa secureSyncProgress.
  Future<Map<String, dynamic>> submitActivity({
    required String activityId,
    required Map<String, dynamic> submission,
  }) async {
    if (AppConfig.useMockApi) {
      final answers = submission['answers'];
      final answerText = answers is List && answers.isNotEmpty
          ? (answers.first as Map)['value']?.toString() ?? ''
          : '';
      final score = answerText.trim().length >= 20 ? 90.0 : 70.0;
      return {
        'activityID': activityId,
        'score': score,
        'feedback': score >= 80
            ? 'Boa resposta. A comunicacao esta clara e adequada ao contexto.'
            : 'Resposta valida, mas pode ser melhorada com mais detalhe e vocabulario.',
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
          headers: await _authSessionService.authenticatedHeaders(
            method: 'POST',
            uri: uri,
          ),
          body: jsonEncode({
            'activityID': activityId,
            'submission': submission,
          }),
        )
        .timeout(AppConfig.apiTimeout);
    final decoded = _decodeResponse(response);
    if (decoded is! Map) {
      throw Exception('Formato inválido em /activities/submissions.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// Envia até 50 submissões num único lote assinado e cifrado.
  Future<Map<String, dynamic>> secureSyncProgress(
    List<Map<String, dynamic>> items,
  ) {
    if (AppConfig.useMockApi) {
      return Future.value({
        'version': 1,
        'batchId': 'mock-batch',
        'results': items
            .map(
              (item) => {
                'clientSubmissionId': item['clientSubmissionId'],
                'submissionId': 'mock-${item['clientSubmissionId']}',
                'status': 'accepted',
                'remoteActivityId': item['remoteActivityId'],
                'score': 80,
                'feedback': 'Sincronização segura simulada.',
                'metrics': {'evaluatedBy': 'mock-secure-sync'},
              },
            )
            .toList(),
      });
    }

    return _secureSyncService.synchronizeProgress(items);
  }

  Future<List<Map<String, dynamic>>> getMySubmissions() async {
    if (AppConfig.useMockApi) return <Map<String, dynamic>>[];

    final uri = Uri.parse(
      '${AppConfig.apiBaseUrl}/activities/submissions/mine',
    );
    final response = await _client
        .get(
          uri,
          headers: await _authSessionService.authenticatedHeaders(
            method: 'GET',
            uri: uri,
          ),
        )
        .timeout(AppConfig.apiTimeout);
    final decoded = _decodeResponse(response);
    if (decoded is! Map || decoded['submissions'] is! List) {
      throw Exception('Formato inválido em /activities/submissions/mine.');
    }
    return (decoded['submissions'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  Object _decodeResponse(http.Response response) {
    AppConfig.assertResponseEnvironment(response.headers);

    final Object decoded;
    try {
      decoded = response.body.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(response.body);
    } on FormatException {
      throw Exception(
        'A API devolveu JSON inválido (HTTP ${response.statusCode}).',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final message = decoded is Map && decoded['error'] != null
          ? decoded['error'].toString()
          : 'Erro HTTP ${response.statusCode}.';
      throw Exception(message);
    }
    return decoded;
  }
}
