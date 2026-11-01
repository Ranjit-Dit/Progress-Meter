import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../ai_coach/data/api_coach_repository.dart';
import '../domain/ai_judgment.dart';

class ApiJudgmentRepository implements AiJudgmentRepository {
  ApiJudgmentRepository({
    required Uri baseUrl,
    String accessToken = '',
    HttpClient? client,
    this.timeout = const Duration(seconds: 100),
  }) : baseUrl = ApiCoachRepository.validateBaseUrl(baseUrl),
       _token = accessToken,
       _client = client ?? HttpClient() {
    if (_token.contains('\n') ||
        _token.contains('\r') ||
        _token.length > 1024) {
      throw ArgumentError('Invalid backend token.');
    }
    _client.connectionTimeout = const Duration(seconds: 8);
  }
  final Uri baseUrl;
  final String _token;
  final HttpClient _client;
  final Duration timeout;
  bool _closed = false;
  @override
  Future<AiProgressJudgment> review(
    AiEvidenceSnapshot snapshot, {
    required String requestId,
  }) async {
    if (_closed) {
      throw const AiJudgmentException('AI connection is closed.');
    }
    HttpClientRequest? request;
    Future<AiProgressJudgment> perform() async {
      final bytes = utf8.encode(jsonEncode(snapshot.toJson(requestId)));
      if (bytes.length > 64 * 1024) {
        throw const AiJudgmentException('This evidence summary is too large.');
      }
      request = await _client.postUrl(
        baseUrl.replace(
          path:
              '${baseUrl.path.replaceFirst(RegExp(r'/+$'), '')}/api/progress/review',
        ),
      );
      request!.followRedirects = false;
      request!.headers.contentType = ContentType.json;
      if (_token.isNotEmpty) {
        request!.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      }
      request!.add(bytes);
      final response = await request!.close();
      final chunks = <int>[];
      await for (final chunk in response) {
        if (chunks.length + chunk.length > 64 * 1024) {
          throw const AiJudgmentException(
            'The AI review response was too large. Please retry.',
          );
        }
        chunks.addAll(chunk);
      }
      final json = jsonDecode(utf8.decode(chunks)) as Map<String, dynamic>;
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final code = (json['error'] as Map?)?['code'];
        throw AiJudgmentException(switch (code) {
          'not_configured' =>
            'Configure your OpenAI key in the backend and restart it.',
          'review_requires_live' || 'judgment_requires_live' =>
            'AI judgments require the backend in live mode.',
          'insufficient_evidence' => 'Complete a Testing Lab assessment first.',
          'unauthorized' => 'Check the backend connection token.',
          'timeout' => 'The AI review took too long. Retry the same evidence.',
          'upstream_rate_limited' || 'rate_limited' =>
            'The AI usage limit was reached. Please retry later.',
          'upstream_auth' => 'Check the backend OpenAI key and model access.',
          'not_found' => 'Restart the updated backend to enable AI judgments.',
          _ => 'The AI review could not finish. Check the backend and retry.',
        });
      }
      final judgment = AiProgressJudgment.fromJson(json);
      if (!snapshot.accepts(judgment)) {
        throw const AiJudgmentException(
          'The AI judgment did not match this evidence. Retry.',
        );
      }
      return judgment;
    }

    try {
      return await perform().timeout(timeout);
    } on AiJudgmentException {
      rethrow;
    } on TimeoutException {
      request?.abort();
      throw const AiJudgmentException(
        'The AI review took too long. Retry the same evidence.',
      );
    } catch (_) {
      request?.abort();
      throw const AiJudgmentException(
        'The AI review could not be validated. Check your connection and retry.',
      );
    }
  }

  @override
  void close() {
    _closed = true;
    _client.close(force: true);
  }
}
