import 'support/benchmark_fixture.dart' show benchmarkLab;
import 'support/judgment_fixture.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/features/ai_coach/application/coach_controller.dart';
import 'package:progress_meter/features/ai_coach/data/api_coach_repository.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';

Map<MetricKind, double> _metrics(double value) => {
  for (final metric in MetricKind.values) metric: value,
};

ProgressEntry _entry(
  String id,
  DateTime date, {
  ProgressTrack track = ProgressTrack.academic,
  double score = 60,
  String note = 'Private reflection',
}) => ProgressEntry(
  id: id,
  title: 'Private check-in title',
  note: note,
  track: track,
  date: date,
  metrics: _metrics(score),
);

Map<String, dynamic> _replyJson({
  String text = 'Focus on consistent practice.',
}) => {
  'reply': text,
  'suggestions': [
    {'title': 'Practice daily', 'metric': 'practice', 'target': 75, 'days': 7},
  ],
  'source': 'openai',
  'model': 'test-model',
};

CoachContext _context([ProgressTrack track = ProgressTrack.academic]) =>
    CoachContext.fromProgressData(ProgressData(), track);

class _FakeCoachRepository implements CoachRepository {
  final questions = <String>[];
  final contexts = <CoachContext>[];
  final histories = <List<CoachTurn>>[];
  CoachException? failure;
  Completer<CoachReply>? gate;
  int closed = 0;

  @override
  Future<CoachReply> ask({
    required String question,
    required CoachContext context,
    List<CoachTurn> conversation = const [],
  }) async {
    questions.add(question);
    contexts.add(context);
    histories.add(List.of(conversation));
    final pending = gate;
    if (pending != null) return pending.future;
    if (failure != null) throw failure!;
    return CoachReply.fromJson(_replyJson(text: 'Answer ${questions.length}'));
  }

  @override
  Future<CoachHealth> health() async =>
      CoachHealth(configured: true, mode: 'live');

  @override
  void close() => closed++;
}

void main() {
  group('Coach context privacy and scope', () {
    test('sends a bounded track snapshot without identities or notes', () {
      final data = ProgressData(
        studentName: 'Private student name',
        entries: [
          for (var index = 0; index < 15; index++)
            _entry(
              'entry-$index',
              DateTime(2026, 10, 1 + index),
              score: 40 + index.toDouble(),
            ),
          _entry(
            'demo-career',
            DateTime(2026, 10, 29),
            track: ProgressTrack.career,
          ),
        ],
        goals: [
          for (var index = 0; index < 14; index++)
            ProgressGoal(
              id: 'goal-$index',
              title: 'Active goal $index',
              track: ProgressTrack.academic,
              metric: MetricKind.practice,
              target: 80,
              deadline: DateTime(2026, 12, index + 1),
            ),
          ProgressGoal(
            id: 'done',
            title: 'Completed goal',
            track: ProgressTrack.academic,
            metric: MetricKind.knowledge,
            target: 90,
            deadline: DateTime(2026, 12, 1),
            completed: true,
          ),
          ProgressGoal(
            id: 'career-goal',
            title: 'Career only goal',
            track: ProgressTrack.career,
            metric: MetricKind.impact,
            target: 80,
            deadline: DateTime(2026, 12, 1),
          ),
        ],
        profiles: [
          TargetProfile(
            id: 'selected',
            name: 'Private benchmark name',
            role: 'Private benchmark role',
            initials: 'PB',
            track: ProgressTrack.academic,
            metrics: _metrics(90),
            isExample: false,
          ),
        ],
        targetProfileId: 'selected',
      );
      final context = CoachContext.fromProgressData(
        data,
        ProgressTrack.academic,
      );
      final json = context.toJson();
      final encoded = jsonEncode(json);
      final history = json['history'] as List;
      final goals = json['goals'] as List;

      expect(context.track, ProgressTrack.academic);
      expect(json['track'], 'academic');
      expect(
        history,
        isEmpty,
        reason: 'Legacy self-ratings must never become current AI evidence.',
      );
      expect(goals, hasLength(12));
      expect(json['isSampleData'], isFalse);
      expect(json['metricLabels'], containsPair('knowledge', 'Understanding'));
      expect(json['rubric'], isA<String>());
      expect((json['benchmark'] as Map)['isExample'], isFalse);
      for (final privateValue in [
        'Private student name',
        'Private check-in title',
        'Private reflection',
        'Private benchmark name',
        'Private benchmark role',
        'Completed goal',
        'Career only goal',
      ]) {
        expect(encoded, isNot(contains(privateValue)), reason: privateValue);
      }
    });

    test(
      'notes require opt-in and remain bounded without changing saved data',
      () {
        final note = List.filled(700, 'x').join();
        final original = _entry('note', DateTime(2026, 10, 29), note: note);
        final results = [
          for (var i = 0; i < 3; i++)
            benchmarkLab(
              id: 'opt-in-$i',
              date: DateTime.now().subtract(Duration(days: i + 1)),
            ),
        ];
        final data = ProgressData(
          entries: [original],
          labResults: results,
          aiJudgments: [judgmentFor(results, complete: true, summary: note)],
        );
        final private = CoachContext.fromProgressData(
          data,
          ProgressTrack.academic,
        ).toJson();
        final shared = CoachContext.fromProgressData(
          data,
          ProgressTrack.academic,
          includeNotes: true,
        ).toJson();

        expect((private['history'] as List).single, isNot(contains('note')));
        expect(
          (((shared['history'] as List).single as Map)['note'] as String)
              .length,
          500,
        );
        expect(original.note.length, 700);
      },
    );

    test('sample indication and benchmark stay within the selected track', () {
      final data = ProgressData(
        entries: [
          _entry('demo-academic', DateTime(2026, 10, 1)),
          _entry(
            'real-career',
            DateTime(2026, 10, 2),
            track: ProgressTrack.career,
          ),
        ],
        profiles: [
          TargetProfile(
            id: 'academic-benchmark',
            name: 'Example',
            role: 'Student',
            initials: 'EX',
            track: ProgressTrack.academic,
            metrics: _metrics(85),
          ),
        ],
        targetProfileId: 'academic-benchmark',
      );
      final academic = CoachContext.fromProgressData(
        data,
        ProgressTrack.academic,
      ).toJson();
      final career = CoachContext.fromProgressData(
        data,
        ProgressTrack.career,
      ).toJson();
      expect(academic['isSampleData'], isFalse);
      expect(career['isSampleData'], isFalse);
      expect(career['benchmark'], isNull);
      expect(
        career['metricLabels'],
        containsPair('knowledge', 'Understanding'),
      );
    });
  });

  group('Coach response validation', () {
    test('valid structured reply preserves typed suggestions and source', () {
      final reply = CoachReply.fromJson(_replyJson());
      expect(reply.reply, 'Focus on consistent practice.');
      expect(reply.source, 'openai');
      expect(reply.model, 'test-model');
      expect(reply.suggestions.single.metric, MetricKind.practice);
      expect(reply.suggestions.single.target, 75);
      expect(reply.suggestions.single.days, 7);
    });

    test(
      'rejects empty output, unknown sources, and malformed suggestions',
      () {
        final cases = <Map<String, dynamic>>[
          {..._replyJson(), 'reply': '  '},
          {..._replyJson(), 'source': 'pretend-live'},
          {
            ..._replyJson(),
            'suggestions': [
              {
                'title': 'Bad target',
                'metric': 'practice',
                'target': double.nan,
                'days': 7,
              },
            ],
          },
          {
            ..._replyJson(),
            'suggestions': [
              {
                'title': 'Bad target',
                'metric': 'practice',
                'target': 101,
                'days': 7,
              },
            ],
          },
          {
            ..._replyJson(),
            'suggestions': [
              {
                'title': 'Bad days',
                'metric': 'practice',
                'target': 70,
                'days': 0,
              },
            ],
          },
          {
            ..._replyJson(),
            'suggestions': [
              {
                'title': 'Unknown metric',
                'metric': 'grades',
                'target': 70,
                'days': 7,
              },
            ],
          },
          {
            ..._replyJson(),
            'suggestions': List.filled(4, {
              'title': 'Too many',
              'metric': 'practice',
              'target': 70,
              'days': 7,
            }),
          },
        ];
        for (final value in cases) {
          expect(
            () => CoachReply.fromJson(value),
            throwsA(isA<FormatException>()),
          );
        }
      },
    );
  });

  group('Coach controller', () {
    test(
      'records successful turns and sends only the latest eight prior turns',
      () async {
        final repository = _FakeCoachRepository();
        final controller = CoachController(repository);
        addTearDown(controller.dispose);
        final context = _context();
        for (var index = 0; index < 6; index++) {
          await controller.ask('  Question $index  ', context);
        }
        expect(repository.questions.first, 'Question 0');
        expect(repository.histories.first, isEmpty);
        expect(repository.histories.last, hasLength(8));
        expect(repository.histories.last.first.text, 'Question 1');
        expect(repository.histories.last.last.text, 'Answer 5');
        expect(controller.turns, hasLength(12));
        expect(controller.turns.last.role, 'assistant');
        expect(controller.latestReply!.reply, 'Answer 6');
        expect(controller.error, isNull);
        expect(controller.busy, isFalse);
      },
    );

    test(
      'failed request stays retryable and does not add invented turns',
      () async {
        final repository = _FakeCoachRepository()
          ..failure = CoachException(
            'not_configured',
            'Configure the backend first.',
          );
        final controller = CoachController(repository);
        addTearDown(controller.dispose);
        await controller.ask('Where should I focus?', _context());
        expect(controller.turns, isEmpty);
        expect(controller.error!.code, 'not_configured');
        expect(controller.lastQuestion, 'Where should I focus?');
        expect(controller.busy, isFalse);
        repository.failure = null;
        await controller.retry();
        expect(repository.questions, [
          'Where should I focus?',
          'Where should I focus?',
        ]);
        expect(controller.error, isNull);
        expect(controller.turns, hasLength(2));
      },
    );

    test(
      'empty and oversized questions fail locally before making a request',
      () async {
        final repository = _FakeCoachRepository();
        final controller = CoachController(repository);
        addTearDown(controller.dispose);
        await controller.ask('   ', _context());
        expect(repository.questions, isEmpty);
        expect(controller.error, isNotNull);
        await controller.ask(List.filled(2001, 'x').join(), _context());
        expect(repository.questions, isEmpty);
        expect(controller.busy, isFalse);
      },
    );

    test('clearing an in-flight request ignores its late answer', () async {
      final repository = _FakeCoachRepository()..gate = Completer<CoachReply>();
      final controller = CoachController(repository);
      addTearDown(controller.dispose);
      final pending = controller.ask('Explain academic progress', _context());
      expect(controller.busy, isTrue);
      controller.clear();
      expect(controller.turns, isEmpty);
      expect(controller.latestReply, isNull);
      expect(controller.busy, isFalse);
      repository.gate!.complete(CoachReply.fromJson(_replyJson()));
      await pending;
      expect(controller.turns, isEmpty);
      expect(controller.latestReply, isNull);
      expect(controller.lastQuestion, isNull);
    });

    test(
      'health status is exposed and disposal closes the connection once',
      () async {
        final repository = _FakeCoachRepository();
        final controller = CoachController(repository);
        final health = await controller.checkHealth();
        expect(health.configured, isTrue);
        expect(health.mode, 'live');
        controller.dispose();
        expect(repository.closed, 1);
      },
    );
  });

  group('Coach HTTP repository', () {
    test('rejects unsafe backend URL configuration', () {
      for (final url in [
        'http://example.com',
        'https://secret@example.com',
        'https://example.com?key=secret',
        'https://example.com#fragment',
        'file:///tmp/coach',
      ]) {
        expect(
          () => ApiCoachRepository(baseUrl: Uri.parse(url)),
          throwsA(anything),
          reason: url,
        );
      }
      for (final url in [
        'http://127.0.0.1:8787',
        'http://localhost:8787',
        'http://10.0.2.2:8787',
        'https://example.com',
      ]) {
        final repository = ApiCoachRepository(baseUrl: Uri.parse(url));
        repository.close();
      }
    });

    test('sends the snapshot and backend token then parses the real response shape', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = Completer<Map<String, dynamic>>();
      final subscription = server.listen((request) async {
        expect(request.method, 'POST');
        expect(request.uri.path, '/api/coach');
        expect(
          request.headers.value(HttpHeaders.authorizationHeader),
          'Bearer test-backend-token',
        );
        expect(request.headers.contentType?.mimeType, 'application/json');
        received.complete(
          Map<String, dynamic>.from(
            jsonDecode(await utf8.decoder.bind(request).join()) as Map,
          ),
        );
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_replyJson()));
        await request.response.close();
      });
      addTearDown(() async {
        await subscription.cancel();
        await server.close(force: true);
      });
      final repository = ApiCoachRepository(
        baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        accessToken: 'test-backend-token',
      );
      addTearDown(repository.close);
      final reply = await repository.ask(
        question: 'What next?',
        context: _context(),
        conversation: [CoachTurn(role: 'user', text: 'Previous question')],
      );
      final json = await received.future;
      expect(json['question'], 'What next?');
      expect((json['context'] as Map)['track'], 'academic');
      expect(json['conversation'], [
        {'role': 'user', 'text': 'Previous question'},
      ]);
      expect(reply.source, 'openai');
      expect(reply.suggestions.single.metric, MetricKind.practice);
    });

    test(
      'surfaces a structured setup error without inventing a demo answer',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final subscription = server.listen((request) async {
          await request.drain<void>();
          request.response.statusCode = 503;
          request.response.headers.contentType = ContentType.json;
          request.response.write(
            jsonEncode({
              'error': {
                'code': 'not_configured',
                'message': 'Set the backend API key.',
              },
            }),
          );
          await request.response.close();
        });
        addTearDown(() async {
          await subscription.cancel();
          await server.close(force: true);
        });
        final repository = ApiCoachRepository(
          baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
        );
        addTearDown(repository.close);
        await expectLater(
          repository.ask(question: 'Explain my progress', context: _context()),
          throwsA(
            isA<CoachException>().having(
              (e) => e.code,
              'code',
              'not_configured',
            ),
          ),
        );
      },
    );
  });
  test('changing note-sharing scope drops the prior conversation', () async {
    final repository = _FakeCoachRepository();
    final controller = CoachController(repository);
    addTearDown(controller.dispose);
    final data = ProgressData(
      entries: [_entry('private', DateTime(2026, 10, 29))],
    );
    final withNotes = CoachContext.fromProgressData(
      data,
      ProgressTrack.academic,
      includeNotes: true,
    );
    final withoutNotes = CoachContext.fromProgressData(
      data,
      ProgressTrack.academic,
    );
    await controller.ask('Reflect on my notes', withNotes);
    expect(controller.turns, hasLength(2));
    await controller.ask('Use scores only', withoutNotes);
    expect(repository.histories.last, isEmpty);
    expect(repository.contexts.last.includesNotes, isFalse);
    expect(controller.turns, hasLength(2));
  });
  test('food and class routines are not forwarded to the AI coach', () {
    final data = ProgressData(
      routines: [
        RoutineItem(
          id: 'private-food',
          title: 'Private meal plan',
          kind: RoutineKind.meal,
          weekdays: {1, 2, 3, 4, 5, 6, 7},
          startMinutes: 480,
          details: 'Private food preferences',
        ),
        RoutineItem(
          id: 'private-class',
          title: 'Private class timetable',
          kind: RoutineKind.classSession,
          weekdays: {4},
          startMinutes: 540,
          endMinutes: 600,
          instructor: 'Private instructor',
          location: 'Private room',
        ),
      ],
    );
    final payload = jsonEncode(
      CoachContext.fromProgressData(
        data,
        ProgressTrack.academic,
        includeNotes: true,
      ).toJson(),
    );
    expect(payload, isNot(contains('Private')));
    expect(payload, isNot(contains('routines')));
    expect(payload, isNot(contains('instructor')));
  });
}
