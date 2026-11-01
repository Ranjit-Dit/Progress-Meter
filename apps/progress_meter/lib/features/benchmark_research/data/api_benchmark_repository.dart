import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../ai_coach/data/api_coach_repository.dart';
import '../../ai_coach/domain/coach_models.dart' show CoachHealth;
import '../../progress/domain/progress_types.dart';
import '../domain/benchmark_models.dart';
import '../domain/benchmark_analytics.dart';
import '../domain/benchmark_repository.dart';

class ApiBenchmarkResearchRepository implements BenchmarkResearchRepository {
  ApiBenchmarkResearchRepository({
    Uri? baseUrl,
    String accessToken = '',
    HttpClient? client,
    this._timeout = const Duration(seconds: 165),
  }) : baseUrl = ApiCoachRepository.validateBaseUrl(
         baseUrl ??
             Uri.parse(
               const String.fromEnvironment(
                 'COACH_API_URL',
                 defaultValue: 'http://127.0.0.1:8787',
               ),
             ),
       ),
       _token = accessToken,
       _client = client ?? HttpClient() {
    if (accessToken.contains('\r') ||
        accessToken.contains('\n') ||
        accessToken.length > 1024) {
      throw ArgumentError('Invalid backend token.');
    }
    _client.connectionTimeout = const Duration(seconds: 8);
  }
  final Uri baseUrl;
  final String _token;
  final HttpClient _client;
  final Duration _timeout;
  bool _closed = false;
  @override
  Future<ResearchPlan> research({
    required String requestId,
    required BenchmarkKind kind,
    required String query,
    required String context,
    required String postText,
    required ProgressTrack track,
  }) async {
    if (query.trim().isEmpty ||
        query.runes.length > 300 ||
        context.runes.length > 3000 ||
        postText.runes.length > 10000) {
      throw const BenchmarkException(
        'invalid_request',
        'Enter a specific name, public URL, or post title within the field limits.',
      );
    }
    final data = await _request('api/benchmarks/research', {
      'requestId': requestId,
      'kind': kind.name,
      'query': query.trim(),
      'context': context.trim(),
      'postText': postText.trim(),
      'track': track.name,
    });
    try {
      final plan = ResearchPlan.fromJson(data);
      if (plan.query != query.trim() ||
          plan.kind != kind ||
          plan.track != track) {
        throw const FormatException('Wrong research.');
      }
      return plan;
    } catch (_) {
      throw const BenchmarkException(
        'invalid_response',
        'The research did not contain a valid sourced path. Please retry.',
      );
    }
  }

  @override
  Future<BenchmarkReview> review(
    BenchmarkProgressSnapshot snapshot, {
    required String requestId,
  }) async {
    final data = await _request(
      'api/benchmarks/review',
      snapshot.toReviewJson(requestId: requestId),
    );
    try {
      final review = BenchmarkReview.fromJson(data);
      if (review.planId != snapshot.plan.id ||
          (review.progressPercent - snapshot.progressPercent).abs() > .001) {
        throw const FormatException('Inconsistent readiness.');
      }
      return review;
    } catch (_) {
      throw const BenchmarkException(
        'invalid_response',
        'The progress review did not match your current evidence. Please retry.',
      );
    }
  }

  @override
  Future<CoachHealth> health() async =>
      CoachHealth.fromJson(await _request('health', null));
  Future<Map<String, dynamic>> _request(
    String path,
    Map<String, dynamic>? data,
  ) async {
    if (_closed) {
      throw const BenchmarkException(
        'unavailable',
        'The research connection is closed.',
      );
    }
    HttpClientRequest? request;
    Future<Map<String, dynamic>> perform() async {
      final encoded = data == null ? null : utf8.encode(jsonEncode(data));
      if (encoded != null && encoded.length > 64 * 1024) {
        throw const BenchmarkException(
          'request_too_large',
          'This research request contains too much text. Shorten the notes or pasted post.',
        );
      }
      request = await _client.openUrl(
        data == null ? 'GET' : 'POST',
        baseUrl.replace(path: '${baseUrl.path}/$path'),
      );
      request!.followRedirects = false;
      request!.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_token.isNotEmpty) {
        request!.headers.set(HttpHeaders.authorizationHeader, 'Bearer $_token');
      }
      if (encoded != null) {
        request!.headers.contentType = ContentType.json;
        request!.contentLength = encoded.length;
        request!.add(encoded);
      }
      final response = await request!.close();
      final bytes = BytesBuilder(copy: false);
      if (response.contentLength > 256 * 1024) {
        throw const BenchmarkException(
          'invalid_response',
          'The research response was too large.',
        );
      }
      await for (final part in response) {
        if (bytes.length + part.length > 256 * 1024) {
          throw const BenchmarkException(
            'invalid_response',
            'The research response was too large.',
          );
        }
        bytes.add(part);
      }
      Map<String, dynamic>? decoded;
      try {
        final value = jsonDecode(utf8.decode(bytes.takeBytes()));
        if (value is Map) decoded = Map<String, dynamic>.from(value);
      } catch (_) {}
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final e = decoded?['error'];
        final code = e is Map ? e['code'] : null;
        throw _error(code, response.statusCode);
      }
      if (decoded == null) {
        throw const BenchmarkException(
          'invalid_response',
          'The research service returned an unreadable response.',
        );
      }
      return decoded;
    }

    try {
      return await perform().timeout(_timeout);
    } on BenchmarkException {
      request?.abort();
      rethrow;
    } on TimeoutException {
      request?.abort();
      throw const BenchmarkException(
        'timeout',
        'Research took too long. Retry to recover this request.',
      );
    } catch (_) {
      request?.abort();
      throw const BenchmarkException(
        'connection_failed',
        'Cannot reach the AI backend. Start the service or check connection settings.',
      );
    }
  }

  BenchmarkException _error(Object? code, int status) {
    const messages = {
      'not_configured': 'The backend needs your OpenAI key. Configure it and restart the service.',
      'research_requires_live': 'Research requires live OpenAI mode. Demo mode does not research people or posts.',
      'upstream_auth': 'The OpenAI key or model access was not accepted. Check the backend configuration.',
      'upstream_unavailable': 'The AI model could not complete research. Check web-search support or retry.',
      'upstream_rate_limited': 'OpenAI is at its usage limit. Check billing and limits or retry later.',
      'rate_limited': 'Too many requests. Wait a moment and retry.',
      'unauthorized': 'The backend access token was not accepted.',
      'invalid_request':
          'Check the public URL, topic, notes, and field lengths.',
      'timeout': 'Research took too long. Retry the same request.',
      'incomplete_response': 'The AI response was incomplete. Please retry.',
      'invalid_response':
          'The research did not form a valid, sourced path. Please retry.',
      'refused': 'The service could not research this request. Use a public professional profile or role.',
      'idempotency_conflict':
          'This request was already used. Start a new search.',
      'busy': 'Research is busy. Please try again shortly.',
    };
    if (code is String && messages.containsKey(code)) {
      return BenchmarkException(code, messages[code]!);
    }
    if (status == 404) {
      return const BenchmarkException(
        'service_outdated',
        'Restart the updated backend to enable benchmark research.',
      );
    }
    return const BenchmarkException(
      'unavailable',
      'Research is unavailable. Check the backend and retry.',
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _client.close(force: true);
  }
}
