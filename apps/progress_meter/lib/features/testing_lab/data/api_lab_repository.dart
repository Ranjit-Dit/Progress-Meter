import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../ai_coach/domain/coach_models.dart' show CoachHealth;
import '../../progress/domain/progress_types.dart' show ProgressTrack;
import '../domain/lab_models.dart';
import '../domain/lab_repository.dart';

/// Questions and answers go to the configured backend; the OpenAI key stays there.
class ApiLabRepository implements LabRepository {
  ApiLabRepository({
    Uri? baseUrl,
    String? accessToken,
    HttpClient? client,
    this._timeout = const Duration(seconds: 115),
  }) : baseUrl = validateBaseUrl(
         baseUrl ??
             Uri.parse(
               const String.fromEnvironment(
                 'COACH_API_URL',
                 defaultValue: 'http://127.0.0.1:8787',
               ),
             ),
       ),
       _accessToken = accessToken ?? '',
       _client = client ?? HttpClient() {
    if (_accessToken.contains('\r') ||
        _accessToken.contains('\n') ||
        _accessToken.length > 1024) {
      throw ArgumentError('Invalid backend access token.');
    }
    _client.connectionTimeout = const Duration(seconds: 8);
  }
  final Uri baseUrl;
  final String _accessToken;
  final HttpClient _client;
  final Duration _timeout;
  bool _closed = false;
  static const _maximumRequestBytes = 64 * 1024;
  static const _maximumResponseBytes = 2 * 1024 * 1024;

  static Uri validateBaseUrl(Uri uri) {
    final loopback = [
      'localhost',
      '127.0.0.1',
      '::1',
      '[::1]',
      '10.0.2.2',
    ].contains(uri.host.toLowerCase());
    if (!uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.scheme != 'https' && !(uri.scheme == 'http' && loopback))) {
      throw ArgumentError(
        'Use an HTTPS backend URL, or HTTP on localhost for development.',
      );
    }
    return uri.replace(path: uri.path.replaceFirst(RegExp(r'/+$'), ''));
  }

  Uri _endpoint(String path) => baseUrl.replace(path: '${baseUrl.path}/$path');

  @override
  Future<LabSession> generate({
    required String requestId,
    required String topic,
    required String learningNotes,
    required ProgressTrack track,
    required LabLevel level,
    int questionCount = defaultLabQuestionCount,
  }) async {
    _validateGenerate(requestId, topic, learningNotes);
    if (!validLabQuestionCount(questionCount)) {
      throw const LabException(
        'invalid_request',
        'Choose between 2 and 20 questions.',
      );
    }
    final json = await _request(
      'POST',
      'api/lab/generate',
      payload: {
        'requestId': requestId,
        'topic': topic.trim(),
        'learningNotes': learningNotes.trim(),
        'track': track.name,
        'level': level.name,
        'questionCount': questionCount,
      },
    );
    try {
      final session = LabSession.fromJson(json);
      if (session.topic != topic.trim() ||
          session.track != track ||
          session.level != level ||
          session.questionCount != questionCount) {
        throw const FormatException('Mismatched generated session.');
      }
      return session;
    } catch (_) {
      throw const LabException(
        'invalid_response',
        'The lab returned an invalid question set. Please retry.',
      );
    }
  }

  static void _validateGenerate(String requestId, String topic, String notes) {
    if (requestId.trim().isEmpty ||
        requestId.length > 80 ||
        topic.trim().isEmpty ||
        topic.runes.length > 120 ||
        notes.runes.length > 6000) {
      throw const LabException(
        'invalid_request',
        'Enter a topic up to 120 characters and learning notes up to 6,000 characters.',
      );
    }
  }

  @override
  Future<LabResult> grade(
    LabSession session,
    Map<String, String> answers,
  ) async {
    if (answers.length != session.questionCount ||
        session.questions.any((q) => !answers.containsKey(q.id)) ||
        answers.values.any((answer) => answer.runes.length > 6000)) {
      throw const LabException(
        'invalid_request',
        'Provide each answer, using at most 6,000 characters per question. Blank answers receive zero.',
      );
    }
    final json = await _request(
      'POST',
      'api/lab/grade',
      payload: {
        'sessionId': session.sessionId,
        'sessionToken': session.sessionToken,
        'answers': [
          for (final q in session.questions)
            {'questionId': q.id, 'answer': answers[q.id]!},
        ],
      },
    );
    try {
      final result = LabResult.fromJson(json);
      if (result.sessionId != session.sessionId ||
          result.topic != session.topic ||
          result.track != session.track ||
          result.level != session.level ||
          result.questionCount != session.questionCount) {
        throw const FormatException('Mismatched graded session.');
      }
      for (var i = 0; i < result.questions.length; i++) {
        final actual = result.questions[i], expected = session.questions[i];
        if (actual.id != expected.id ||
            actual.prompt != expected.prompt ||
            actual.dimension != expected.dimension ||
            actual.answer != answers[expected.id]!) {
          throw const FormatException('Mismatched graded answers.');
        }
      }
      return result;
    } catch (_) {
      throw const LabException(
        'invalid_response',
        'The marks did not match this test. Retry the submitted answers.',
      );
    }
  }

  @override
  Future<CoachHealth> health() async {
    final json = await _request('GET', 'health');
    try {
      return CoachHealth.fromJson(json);
    } catch (_) {
      throw const LabException(
        'invalid_response',
        'This URL did not return a compatible Progress Meter backend.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? payload,
  }) async {
    if (_closed) {
      throw const LabException(
        'unavailable',
        'The testing lab connection is closed.',
      );
    }
    HttpClientRequest? request;
    Future<Map<String, dynamic>> perform() async {
      final encoded = payload == null ? null : utf8.encode(jsonEncode(payload));
      final maximum = path == 'api/lab/grade'
          ? maxLabSubmissionBytes
          : _maximumRequestBytes;
      if (encoded != null && encoded.length > maximum) {
        throw const LabException(
          'request_too_large',
          'These answers contain too much data. Shorten the text before submitting.',
        );
      }
      request = await _client.openUrl(method, _endpoint(path));
      request!.followRedirects = false;
      request!.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_accessToken.isNotEmpty) {
        request!.headers.set(
          HttpHeaders.authorizationHeader,
          'Bearer $_accessToken',
        );
      }
      if (encoded != null) {
        request!.headers.contentType = ContentType.json;
        request!.contentLength = encoded.length;
        request!.add(encoded);
      }
      final response = await request!.close();
      if (response.contentLength > _maximumResponseBytes) {
        throw const LabException(
          'invalid_response',
          'The testing lab response was too large. Please retry.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (bytes.length + chunk.length > _maximumResponseBytes) {
          throw const LabException(
            'invalid_response',
            'The testing lab response was too large. Please retry.',
          );
        }
        bytes.add(chunk);
      }
      Map<String, dynamic>? decoded;
      try {
        final value = jsonDecode(utf8.decode(bytes.takeBytes()));
        if (value is Map) decoded = Map<String, dynamic>.from(value);
      } catch (_) {
        /* Never expose untrusted server bodies or credentials. */
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _serverError(response.statusCode, decoded);
      }
      if (decoded == null) {
        throw const LabException(
          'invalid_response',
          'The testing lab returned an unreadable response. Please retry.',
        );
      }
      return decoded;
    }

    try {
      return await perform().timeout(_timeout);
    } on LabException {
      request?.abort();
      rethrow;
    } on TimeoutException {
      request?.abort();
      throw const LabException(
        'timeout',
        'The testing lab took too long. Retry to recover the same test or submitted grading.',
      );
    } on SocketException {
      request?.abort();
      throw const LabException(
        'connection_failed',
        'Cannot reach the testing lab backend. Start the server or check the connection URL.',
      );
    } on HandshakeException {
      request?.abort();
      throw const LabException(
        'connection_failed',
        'A secure connection to the testing lab could not be established.',
      );
    } catch (_) {
      request?.abort();
      throw const LabException(
        'connection_failed',
        'The testing lab connection failed. Check the backend URL and retry.',
      );
    }
  }

  LabException _serverError(int status, Map<String, dynamic>? json) {
    final error = json?['error'];
    final code = error is Map ? error['code'] : null;
    const messages = {
      'not_configured': 'Add an OpenAI API key to backend/.env and restart the backend to use the testing lab.',
      'lab_requires_live': 'Testing Lab requires live OpenAI mode. Set COACH_MODE=live and restart the backend.',
      'unauthorized': 'The backend access token was not accepted. Check the connection settings.',
      'session_expired':
          'This test has expired or the backend restarted. Start a new test.',
      'already_submitted': 'This test already has a different submission. Start a new test to answer again.',
      'idempotency_conflict': 'This generation request was already used for another topic. Start again.',
      'submission_conflict': 'This test already has a different submission. Start a new test to answer again.',
      'request_conflict': 'This generation request was already used for another topic. Start again.',
      'invalid_request': 'The lab could not use this request. Check the question count, topic, and answer lengths.',
      'rate_limited': 'The testing lab is receiving too many requests. Wait a moment and retry.',
      'upstream_rate_limited': 'OpenAI is at its usage limit. Check API billing and limits, or retry later.',
      'upstream_auth': 'The OpenAI key or selected model is not authorized. Check backend/.env and model access.',
      'upstream_unavailable':
          'The AI service could not finish this request. Please retry.',
      'timeout': 'The testing lab took too long. Retry to recover the same test or submitted grading.',
      'refused': 'The lab could not assess this topic. Choose a study or professional learning topic.',
      'incomplete_response': 'The AI response was incomplete. Please retry.',
      'invalid_response':
          'The testing lab returned invalid marks or questions. Please retry.',
      'busy': 'The testing lab is busy. Please retry shortly.',
    };
    if (code is String && messages.containsKey(code)) {
      return LabException(code, messages[code]!);
    }
    if (status == 410) {
      return LabException('session_expired', messages['session_expired']!);
    }
    if (status == 409) {
      return LabException(
        'submission_conflict',
        messages['submission_conflict']!,
      );
    }
    if (status == 401 || status == 403) {
      return LabException('unauthorized', messages['unauthorized']!);
    }
    if (status == 429) {
      return LabException('rate_limited', messages['rate_limited']!);
    }
    if (status == 400 || status == 413) {
      return LabException('invalid_request', messages['invalid_request']!);
    }
    return const LabException(
      'service_unavailable',
      'The testing lab is unavailable. Check the backend and retry.',
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _client.close(force: true);
  }
}
