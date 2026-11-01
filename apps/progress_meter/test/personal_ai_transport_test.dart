import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/features/ai_connection/data/ai_provider_client.dart';
import 'package:progress_meter/features/ai_connection/domain/ai_provider.dart';

class _RoutedClient implements HttpClient {
  _RoutedClient(this.destination);
  final Uri destination;
  final HttpClient inner = HttpClient();
  final urls = <Uri>[];
  @override
  set connectionTimeout(Duration? value) => inner.connectionTimeout = value;
  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    urls.add(url);
    return inner.postUrl(destination.replace(path: url.path));
  }

  @override
  void close({bool force = false}) => inner.close(force: force);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Harness {
  _Harness(this.server, this.client);
  final HttpServer server;
  final _RoutedClient client;
  final bodies = <Map<String, dynamic>>[];
  final headers = <Map<String, String?>>[];
  static Future<_Harness> start(List<(int, Object)> replies) async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final h = _Harness(
      server,
      _RoutedClient(Uri.parse('http://127.0.0.1:${server.port}')),
    );
    server.listen((request) async {
      h.bodies.add(
        Map<String, dynamic>.from(
          jsonDecode(await utf8.decoder.bind(request).join()) as Map,
        ),
      );
      h.headers.add({
        for (final key in ['authorization', 'x-api-key', 'x-goog-api-key'])
          key: request.headers.value(key),
      });
      final reply = replies[h.bodies.length - 1];
      request.response.statusCode = reply.$1;
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        reply.$2 is String ? reply.$2 : jsonEncode(reply.$2),
      );
      await request.response.close();
    });
    addTearDown(() async {
      h.client.close(force: true);
      await server.close(force: true);
    });
    return h;
  }
}

Map<String, dynamic> _openai(Map<String, dynamic> data) => {
  'status': 'completed',
  'output': [
    {
      'type': 'message',
      'content': [
        {'type': 'output_text', 'text': jsonEncode(data)},
      ],
    },
  ],
};
const _key = 'synthetic-private-key';
AiProviderConfig _config(AiProvider p) => AiProviderConfig(
  provider: p,
  model: 'test-model',
  apiKey: _key,
  baseUrl: p == AiProvider.custom
      ? Uri.parse('https://provider.example.com/v1')
      : null,
);

void main() {
  test(
    'successful provider responses cannot echo the credential into app data',
    () async {
      final h = await _Harness.start([
        (200, _openai({'connected': true, 'note': _key})),
      ]);
      final client = AiProviderClient(
        config: _config(AiProvider.openai),
        client: h.client,
      );
      addTearDown(client.close);
      final response = await client.generate(
        instructions: 'Return JSON.',
        messages: [AiMessage('user', 'Test')],
        schema: {'type': 'object'},
        schemaName: 'redaction',
      );
      expect(jsonEncode(response.data), isNot(contains(_key)));
      expect(response.data['note'], '[credential redacted]');
    },
  );

  test('Anthropic schemas move unsupported bounds into descriptions', () async {
    final h = await _Harness.start([
      (
        200,
        {
          'stop_reason': 'end_turn',
          'content': [
            {'type': 'text', 'text': '{"n":5}'},
          ],
        },
      ),
    ]);
    final client = AiProviderClient(
      config: _config(AiProvider.anthropic),
      client: h.client,
    );
    addTearDown(client.close);
    await client.generate(
      instructions: 'Return JSON.',
      messages: [AiMessage('user', 'Test')],
      schema: {
        'type': 'object',
        'additionalProperties': false,
        'required': ['n'],
        'properties': {
          'n': {'type': 'integer', 'minimum': 0, 'maximum': 10},
        },
      },
      schemaName: 'bounds',
    );
    final schema =
        (h.bodies.single['output_config'] as Map)['format']['schema'] as Map;
    final number = (schema['properties'] as Map)['n'] as Map;
    expect(number.containsKey('minimum'), isFalse);
    expect(number['description'], contains('minimum'));
    expect(number['type'], 'integer');
  });

  test('provider configuration rejects insecure destinations and redacts credentials', () {
    for (final url in [
      'http://provider.example.com/v1',
      'https://user:password@example.com',
      'https://example.com?key=secret',
      'https://example.com#secret',
    ]) {
      expect(
        () => AiProviderConfig(
          provider: AiProvider.custom,
          model: 'test',
          apiKey: _key,
          baseUrl: Uri.parse(url),
        ),
        throwsA(isA<AiProviderException>()),
      );
    }
    expect(
      () => AiProviderConfig(
        provider: AiProvider.openai,
        model: 'test',
        apiKey: _key,
        baseUrl: Uri.parse('https://another.example.com/v1'),
      ),
      throwsA(isA<AiProviderException>()),
    );
    expect(
      () => AiProviderConfig(
        provider: AiProvider.openai,
        model: 'test',
        apiKey: 'key\r\nvalue',
      ),
      throwsA(isA<AiProviderException>()),
    );
    expect(_config(AiProvider.openai).toString(), isNot(contains(_key)));
    expect(
      () => AiSource(url: 'https://127.0.0.1/private', title: 'Private'),
      throwsA(isA<AiProviderException>()),
    );
  });

  for (final provider in AiProvider.values) {
    test(
      '${provider.label} uses its protocol and header without putting keys in payloads',
      () async {
        final data = {'connected': true};
        final body = switch (provider) {
          AiProvider.openai => _openai(data),
          AiProvider.anthropic => {
            'stop_reason': 'end_turn',
            'content': [
              {'type': 'text', 'text': jsonEncode(data)},
            ],
          },
          AiProvider.gemini => {
            'candidates': [
              {
                'finishReason': 'STOP',
                'content': {
                  'parts': [
                    {'text': jsonEncode(data)},
                  ],
                },
              },
            ],
          },
          _ => {
            'choices': [
              {
                'finish_reason': 'stop',
                'message': {'content': jsonEncode(data)},
              },
            ],
          },
        };
        final h = await _Harness.start([(200, body)]);
        final client = AiProviderClient(
          config: _config(provider),
          client: h.client,
        );
        addTearDown(client.close);
        await client.testConnection();
        expect(h.bodies, hasLength(1));
        expect(h.client.urls.single.scheme, 'https');
        expect(jsonEncode(h.bodies.single), isNot(contains(_key)));
        switch (provider) {
          case AiProvider.anthropic:
            expect(h.client.urls.single.path, '/v1/messages');
            expect(h.headers.single['x-api-key'], _key);
            expect(h.bodies.single, contains('output_config'));
          case AiProvider.gemini:
            expect(
              h.client.urls.single.path,
              contains('models/test-model:generateContent'),
            );
            expect(h.headers.single['x-goog-api-key'], _key);
            expect(h.client.urls.single.query, isEmpty);
          case AiProvider.openai:
            expect(h.client.urls.single.path, '/v1/responses');
            expect(h.headers.single['authorization'], 'Bearer $_key');
            expect(h.bodies.single['store'], isFalse);
          default:
            expect(h.client.urls.single.path, endsWith('/chat/completions'));
            expect(h.headers.single['authorization'], 'Bearer $_key');
        }
      },
    );
  }

  test(
    'upstream errors and redirects never expose bodies or follow another host',
    () async {
      final h = await _Harness.start([
        (
          401,
          {
            'error': {'message': 'Rejected $_key for private-account'},
          },
        ),
        (302, 'redirect'),
      ]);
      final client = AiProviderClient(
        config: _config(AiProvider.openai),
        client: h.client,
      );
      addTearDown(client.close);
      try {
        await client.testConnection();
        fail('Expected authentication failure.');
      } on AiProviderException catch (error) {
        expect(error.code, 'upstream_auth');
        expect(error.toString(), isNot(contains(_key)));
        expect(error.toString(), isNot(contains('private-account')));
      }
      await expectLater(
        client.testConnection(),
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.code,
            'code',
            'redirect_rejected',
          ),
        ),
      );
      expect(h.client.urls, hasLength(2));
    },
  );

  test(
    'truncated and refused responses cannot become successful JSON',
    () async {
      final h = await _Harness.start([
        (200, {'status': 'incomplete', 'output': []}),
        (
          200,
          {
            'status': 'completed',
            'output': [
              {
                'type': 'message',
                'content': [
                  {'type': 'refusal', 'refusal': 'no'},
                ],
              },
            ],
          },
        ),
      ]);
      final client = AiProviderClient(
        config: _config(AiProvider.openai),
        client: h.client,
      );
      addTearDown(client.close);
      await expectLater(
        client.testConnection(),
        throwsA(
          isA<AiProviderException>().having(
            (e) => e.code,
            'code',
            'incomplete_response',
          ),
        ),
      );
      await expectLater(
        client.testConnection(),
        throwsA(
          isA<AiProviderException>().having((e) => e.code, 'code', 'refused'),
        ),
      );
    },
  );

  test('oversized provider output is rejected', () async {
    final h = await _Harness.start([
      (200, {'data': 'x' * (1024 * 1024 + 10)}),
    ]);
    final client = AiProviderClient(
      config: _config(AiProvider.openai),
      client: h.client,
    );
    addTearDown(client.close);
    await expectLater(
      client.testConnection(),
      throwsA(
        isA<AiProviderException>().having(
          (e) => e.code,
          'code',
          'invalid_response',
        ),
      ),
    );
  });

  test('web research requires real search and supplies only actual public citations', () async {
    final first = _openai({'notes': 'Public documentation.'});
    (first['output'] as List).insert(0, {
      'type': 'web_search_call',
      'status': 'completed',
      'action': {
        'sources': [
          {'url': 'https://dart.dev/guides', 'title': 'Dart guides'},
          {'url': 'https://127.0.0.1/private', 'title': 'Private'},
        ],
      },
    });
    final h = await _Harness.start([
      (200, first),
      (200, _openai({'ready': true})),
    ]);
    final client = AiProviderClient(
      config: _config(AiProvider.openai),
      client: h.client,
    );
    addTearDown(client.close);
    final result = await client.generate(
      instructions: 'Find public learning evidence.',
      messages: [AiMessage('user', 'Dart learning')],
      schema: {'type': 'object'},
      schemaName: 'research',
      webSearch: true,
    );
    expect(result.sources.single.url, 'https://dart.dev/guides');
    expect(jsonEncode(h.bodies.last['input']), contains('s1'));
    expect(jsonEncode(h.bodies.last['input']), isNot(contains('127.0.0.1')));
    expect(h.bodies.first['tool_choice'], 'required');
  });

  test(
    'Anthropic legacy fallback is limited to rejected output_config',
    () async {
      final h = await _Harness.start([
        (
          400,
          {
            'error': {'message': 'output_config is not supported'},
          },
        ),
        (
          200,
          {
            'stop_reason': 'tool_use',
            'content': [
              {
                'type': 'tool_use',
                'name': 'app_result',
                'input': {'connected': true},
              },
            ],
          },
        ),
      ]);
      final client = AiProviderClient(
        config: _config(AiProvider.anthropic),
        client: h.client,
      );
      addTearDown(client.close);
      await client.testConnection();
      expect(h.bodies.last, isNot(contains('output_config')));
      expect(h.bodies.last['tool_choice'], {
        'type': 'tool',
        'name': 'app_result',
      });
    },
  );
}
