import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../domain/coach_models.dart';
import '../domain/coach_repository.dart';

/// This backend adapter accepts a gateway token only. Personal provider keys
/// use the separate session-only transport in ai_connection.
class ApiCoachRepository implements CoachRepository {
  ApiCoachRepository({Uri? baseUrl, String? accessToken, HttpClient? client})
    : baseUrl = validateBaseUrl(
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
  bool _closed = false;
  static const _maximumBytes = 64 * 1024;
  static const _timeout = Duration(seconds: 50);

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
    final path = uri.path.replaceFirst(RegExp(r'/+$'), '');
    return uri.replace(path: path);
  }

  Uri _endpoint(String path) => baseUrl.replace(path: '${baseUrl.path}/$path');

  @override
  Future<CoachReply> ask({
    required String question,
    required CoachContext context,
    List<CoachTurn> conversation = const [],
  }) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 2000) {
      throw const CoachException(
        'invalid_request',
        'Enter a question between 1 and 2,000 characters.',
      );
    }
    final payload = {
      'question': trimmed,
      'context': context.toJson(),
      'conversation': conversation
          .skip(conversation.length > 8 ? conversation.length - 8 : 0)
          .map((turn) => turn.toJson())
          .toList(),
    };
    final json = await _request('POST', 'api/coach', payload: payload);
    try {
      return CoachReply.fromJson(json);
    } catch (_) {
      throw const CoachException(
        'invalid_response',
        'The coach returned an unreadable response. Please try again.',
      );
    }
  }

  @override
  Future<CoachHealth> health() async {
    final json = await _request('GET', 'health');
    try {
      return CoachHealth.fromJson(json);
    } catch (_) {
      throw const CoachException(
        'invalid_response',
        'This URL did not return a compatible coach service.',
      );
    }
  }

  Future<Map<String, dynamic>> _request(
    String method,
    String path, {
    Map<String, dynamic>? payload,
  }) async {
    if (_closed) {
      throw const CoachException(
        'unavailable',
        'The coach connection is closed.',
      );
    }
    HttpClientRequest? request;
    Future<Map<String, dynamic>> perform() async {
      final encoded = payload == null ? null : utf8.encode(jsonEncode(payload));
      if (encoded != null && encoded.length > _maximumBytes) {
        throw const CoachException(
          'request_too_large',
          'This conversation is too long. Start a new conversation and try again.',
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
      if (response.contentLength > _maximumBytes) {
        throw const CoachException(
          'invalid_response',
          'The coach response was too large. Please try again.',
        );
      }
      final bytes = BytesBuilder(copy: false);
      await for (final chunk in response) {
        if (bytes.length + chunk.length > _maximumBytes) {
          throw const CoachException(
            'invalid_response',
            'The coach response was too large. Please try again.',
          );
        }
        bytes.add(chunk);
      }
      Map<String, dynamic>? decoded;
      try {
        final value = jsonDecode(utf8.decode(bytes.takeBytes()));
        if (value is Map) decoded = Map<String, dynamic>.from(value);
      } catch (_) {
        // Never show an untrusted server body or an echoed credential in the UI.
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw _serverError(response.statusCode, decoded);
      }
      if (decoded == null) {
        throw const CoachException(
          'invalid_response',
          'The coach returned an unreadable response. Please try again.',
        );
      }
      return decoded;
    }

    try {
      return await perform().timeout(_timeout);
    } on CoachException {
      request?.abort();
      rethrow;
    } on TimeoutException {
      request?.abort();
      throw const CoachException(
        'timeout',
        'The coach took too long to respond. Please try again.',
      );
    } on SocketException {
      request?.abort();
      throw const CoachException(
        'connection_failed',
        'Cannot reach the coach backend. Start the server or check the backend URL.',
      );
    } on HandshakeException {
      request?.abort();
      throw const CoachException(
        'connection_failed',
        'A secure connection to the coach backend could not be established.',
      );
    } catch (_) {
      request?.abort();
      throw const CoachException(
        'connection_failed',
        'The coach connection failed. Check the backend URL and try again.',
      );
    }
  }

  CoachException _serverError(int status, Map<String, dynamic>? json) {
    final error = json?['error'];
    final code = error is Map ? error['code'] : null;
    const messages = {
      'not_configured': 'The backend needs an OpenAI API key. Add it to backend/.env, then restart the server.',
      'unauthorized': 'The backend access token was not accepted. Check the connection settings.',
      'rate_limited': 'The coach is receiving too many requests. Wait a moment and try again.',
      'invalid_request': 'The coach could not use this request. Start a new conversation and try again.',
      'timeout': 'The coach took too long to respond. Please try again.',
      'refused': 'The coach could not help with that request. Try a study or career progress question.',
      'incomplete_response':
          'The coach could not finish its response. Please try again.',
      'upstream_error': 'The AI service could not complete this request. Check the backend configuration or try again later.',
      'invalid_response':
          'The coach returned an unreadable response. Please try again.',
      'service_unavailable':
          'The coach is temporarily unavailable. Please try again later.',
    };
    if (code is String && messages.containsKey(code)) {
      return CoachException(code, messages[code]!);
    }
    if (status == 401 || status == 403) {
      return CoachException('unauthorized', messages['unauthorized']!);
    }
    if (status == 429) {
      return CoachException('rate_limited', messages['rate_limited']!);
    }
    if (status == 400 || status == 413) {
      return CoachException('invalid_request', messages['invalid_request']!);
    }
    return CoachException(
      'service_unavailable',
      messages['service_unavailable']!,
    );
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _client.close(force: true);
  }
}
