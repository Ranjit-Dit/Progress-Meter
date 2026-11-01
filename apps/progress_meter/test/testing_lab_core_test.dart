import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';
import 'package:progress_meter/features/progress/domain/progress_types.dart';
import 'package:progress_meter/features/testing_lab/application/lab_controller.dart';
import 'package:progress_meter/features/testing_lab/data/api_lab_repository.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_analytics.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_models.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_repository.dart';

List<LabQuestion> _questions([int count = defaultLabQuestionCount]) => [
  for (var i = 0; i < count; i++)
    LabQuestion(
      id: 'q${i + 1}',
      prompt: 'Explain concept ${i + 1}.',
      dimension: labQuestionDimension(i, count),
    ),
];
LabSession _session({
  String id = 'test-session',
  DateTime? date,
  int count = defaultLabQuestionCount,
}) {
  final start = date ?? DateTime.now();
  return LabSession(
    sessionId: id,
    sessionToken: 'private-session-bearer-token',
    topic: 'Algorithms',
    track: ProgressTrack.academic,
    level: LabLevel.intermediate,
    createdAt: start,
    expiresAt: start.add(const Duration(hours: 2)),
    questions: _questions(count),
    model: 'test-model',
  );
}

Map<String, dynamic> _sessionJson({
  String id = 'test-session',
  int count = defaultLabQuestionCount,
}) {
  final value = _session(id: id, count: count);
  return {
    'sessionId': value.sessionId,
    'sessionToken': value.sessionToken,
    'topic': value.topic,
    'track': value.track.name,
    'level': value.level.name,
    'createdAt': value.createdAt.toIso8601String(),
    'expiresAt': value.expiresAt.toIso8601String(),
    'questions': value.questions.map((q) => q.toJson()).toList(),
    'source': value.source,
    'model': value.model,
  };
}

LabResult _result({
  String id = 'test-session',
  DateTime? date,
  ProgressTrack track = ProgressTrack.academic,
  String topic = 'Algorithms',
  LabLevel level = LabLevel.intermediate,
  Map<String, String>? answers,
  int count = defaultLabQuestionCount,
}) => LabResult(
  sessionId: id,
  topic: topic,
  track: track,
  level: level,
  completedAt: date ?? DateTime.now(),
  model: 'test-model',
  feedback: 'Explain every deduction.',
  nextSteps: ['Review the missed definitions.'],
  questions: [
    for (final q in _questions(count))
      LabQuestionGrade(
        question: q,
        answer: answers?[q.id] ?? 'My reasoned answer.',
        correctness: 4,
        reasoning: 2,
        precision: 1,
        feedback: 'One claim needs evidence.',
        missingConcepts: ['Invariant'],
        referenceAnswer: 'A complete explanation.',
      ),
  ],
);
Matcher _labError(String code) =>
    isA<LabException>().having((e) => e.code, 'code', code);

class _FakeRepository implements LabRepository {
  final requestIds = <String>[];
  final questionCounts = <int>[];
  final submissions = <Map<String, String>>[];
  LabException? failure;
  Completer<LabSession>? generateGate;
  Completer<LabResult>? gradeGate;
  bool closed = false;
  @override
  Future<LabSession> generate({
    required String requestId,
    required String topic,
    required String learningNotes,
    required ProgressTrack track,
    required LabLevel level,
    int questionCount = defaultLabQuestionCount,
  }) async {
    requestIds.add(requestId);
    questionCounts.add(questionCount);
    if (generateGate != null) return generateGate!.future;
    if (failure != null) throw failure!;
    return _session(count: questionCount);
  }

  @override
  Future<LabResult> grade(
    LabSession session,
    Map<String, String> answers,
  ) async {
    submissions.add(Map.of(answers));
    if (gradeGate != null) return gradeGate!.future;
    if (failure != null) throw failure!;
    return _result(answers: answers, count: session.questionCount);
  }

  @override
  Future<CoachHealth> health() async =>
      const CoachHealth(configured: true, mode: 'live');
  @override
  void close() {
    closed = true;
  }
}

Future<void> _generate(LabController c) => c.generate(
  topic: 'Algorithms',
  track: ProgressTrack.academic,
  level: LabLevel.intermediate,
);
void _fill(LabController c) {
  for (final q in c.session!.questions) {
    c.setAnswer(q.id, 'My reasoned answer.');
  }
}

Future<Uri> _serve(Future<void> Function(HttpRequest) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handler(request);
    } catch (_) {
      await request.response.close();
    }
  });
  addTearDown(() => server.close(force: true));
  return Uri.parse('http://127.0.0.1:${server.port}');
}

Future<void> _json(
  HttpRequest request,
  Object value, {
  int status = 200,
}) async {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(value));
  await request.response.close();
}

void main() {
  group('Variable-length lab requests', () {
    test('generation retries retain count and changed counts receive a new request ID', () async {
      final repo = _FakeRepository()
        ..failure = const LabException('timeout', 'Retry');
      final controller = LabController(repo, saveResult: (_) async {});
      addTearDown(controller.dispose);
      await controller.generate(
        topic: 'Algorithms',
        track: ProgressTrack.academic,
        level: LabLevel.intermediate,
        questionCount: 7,
      );
      await controller.retry();
      expect(repo.questionCounts, [7, 7]);
      expect(repo.requestIds[0], repo.requestIds[1]);
      repo.failure = null;
      await controller.generate(
        topic: 'Algorithms',
        track: ProgressTrack.academic,
        level: LabLevel.intermediate,
        questionCount: 20,
      );
      expect(repo.requestIds.last, isNot(repo.requestIds.first));
      expect(controller.session!.questionCount, 20);
      _fill(controller);
      await controller.submit();
      expect(controller.saved, isTrue);
      expect(controller.result!.maxPoints, 200);
      expect(controller.result!.totalScore, 70);
      expect(repo.submissions.single.length, 20);
    });
    test('out of range counts leave the current test untouched and never reach the repository', () async {
      final repo = _FakeRepository();
      final controller = LabController(repo, saveResult: (_) async {});
      addTearDown(controller.dispose);
      await _generate(controller);
      final session = controller.session;
      for (final count in [0, 1, 21]) {
        await controller.generate(
          topic: 'Algorithms',
          track: ProgressTrack.academic,
          level: LabLevel.intermediate,
          questionCount: count,
        );
        expect(controller.error?.code, 'invalid_request');
        expect(controller.session, same(session));
      }
      expect(repo.requestIds.length, 1);
    });
    test('HTTP generation enforces requested count and grading rejects a shorter valid result', () async {
      var shortGeneration = true;
      final base = await _serve((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        if (request.uri.path.endsWith('/generate')) {
          expect(body['questionCount'], 7);
          await _json(request, _sessionJson(count: shortGeneration ? 4 : 7));
        } else {
          expect((body['answers'] as List).length, 7);
          await _json(request, _result(count: 4).toJson());
        }
      });
      final repo = ApiLabRepository(baseUrl: base);
      addTearDown(repo.close);
      Future<LabSession> generate() => repo.generate(
        requestId: 'seven',
        topic: 'Algorithms',
        learningNotes: '',
        track: ProgressTrack.academic,
        level: LabLevel.intermediate,
        questionCount: 7,
      );
      await expectLater(generate(), throwsA(_labError('invalid_response')));
      shortGeneration = false;
      final session = await generate();
      expect(session.questionCount, 7);
      await expectLater(
        repo.grade(session, {
          for (final q in session.questions) q.id: 'My reasoned answer.',
        }),
        throwsA(_labError('invalid_response')),
      );
    });
    test('HTTP grading accepts maximum-size Unicode answers and returns all twenty marked answers', () async {
      final text = '学' * 6000;
      final answers = {for (var i = 1; i <= 20; i++) 'q$i': text};
      final base = await _serve((request) async {
        final body = await utf8.decoder.bind(request).join();
        expect(utf8.encode(body).length, greaterThan(64 * 1024));
        await _json(request, _result(count: 20, answers: answers).toJson());
      });
      final repo = ApiLabRepository(baseUrl: base);
      addTearDown(repo.close);
      final result = await repo.grade(_session(count: 20), answers);
      expect(result.questionCount, 20);
      expect(result.questions.last.answer, text);
    });
  });
  group('Lab evidence models', () {
    test(
      'rubric totals are derived, immutable, round trip and omit bearer tokens',
      () {
        final result = _result();
        expect(result.totalScore, 70);
        expect(result.understandingScore, 70);
        expect(result.applicationScore, 70);
        expect(result.earnedPoints, 28);
        final json = result.toJson();
        expect(jsonEncode(json), isNot(contains('sessionToken')));
        expect(jsonEncode(json), isNot(contains('learningNotes')));
        expect(LabResult.fromJson(json).toJson(), json);
        expect(() => result.questions.clear(), throwsUnsupportedError);
        expect(
          () => result.questions.first.missingConcepts.clear(),
          throwsUnsupportedError,
        );
      },
    );
    test('inconsistent totals and demo sources are rejected', () {
      final json = _result().toJson()..['totalScore'] = 99;
      expect(() => LabResult.fromJson(json), throwsFormatException);
      json['totalScore'] = 70;
      json['source'] = 'demo';
      expect(() => LabResult.fromJson(json), throwsFormatException);
    });
    test('invalid criterion marks, duplicate questions, and positive blank marks fail', () {
      final result = _result().toJson();
      final questions = result['questions'] as List;
      (questions[0] as Map)['correctness'] = 6;
      expect(() => LabResult.fromJson(result), throwsFormatException);
      final duplicate = _sessionJson();
      final rows = duplicate['questions'] as List;
      (rows[1] as Map)['id'] = 'q1';
      expect(() => LabSession.fromJson(duplicate), throwsFormatException);
      final blank = _result().toJson();
      ((blank['questions'] as List)[0] as Map)['answer'] = '   ';
      expect(() => LabResult.fromJson(blank), throwsFormatException);
    });
    test('answer text preserves code indentation rather than stripping it', () {
      const raw = '  if value:\n    return value\n';
      final result = _result(
        answers: {for (var i = 1; i <= 4; i++) 'q$i': raw},
      );
      expect(result.questions.first.answer, raw);
      expect(LabResult.fromJson(result.toJson()).questions.first.answer, raw);
    });
    test('consistency counts distinct local days and excludes future and other tracks', () {
      final now = DateTime(2026, 10, 30, 15);
      final results = [
        _result(id: 'a', date: DateTime(2026, 10, 30, 10)),
        _result(id: 'b', date: DateTime(2026, 10, 30, 11)),
        _result(id: 'c', date: DateTime(2026, 10, 28)),
        _result(id: 'old', date: DateTime(2026, 10, 23)),
        _result(id: 'future', date: DateTime(2026, 10, 30, 16)),
        _result(
          id: 'career',
          date: DateTime(2026, 10, 29),
          track: ProgressTrack.career,
        ),
      ];
      expect(
        LabAnalytics.activeDays(results, ProgressTrack.academic, now: now),
        2,
      );
      expect(
        LabAnalytics.consistency(results, ProgressTrack.academic, now: now),
        closeTo(200 / 3, .0001),
      );
      results.add(_result(id: 'd', date: DateTime(2026, 10, 24)));
      expect(
        LabAnalytics.consistency(results, ProgressTrack.academic, now: now),
        100,
      );
    });
    test('comparison requires the same topic, difficulty and track', () {
      final current = _result(id: 'now', date: DateTime(2026, 10, 30));
      final comparable = _result(
        id: 'prior',
        date: DateTime(2026, 10, 28),
        topic: ' algorithms ',
      );
      final results = [
        current,
        comparable,
        _result(
          id: 'easy',
          date: DateTime(2026, 10, 29),
          level: LabLevel.beginner,
        ),
        _result(id: 'other', date: DateTime(2026, 10, 29), topic: 'Databases'),
      ];
      expect(
        LabAnalytics.previousComparable(results, current),
        same(comparable),
      );
      expect(
        LabAnalytics.history(results, ProgressTrack.academic).first,
        same(current),
      );
    });
  });

  group('Lab controller', () {
    test(
      'generation retry reuses request ID; reset creates a new test request',
      () async {
        final repo = _FakeRepository()
          ..failure = const LabException('timeout', 'Try again');
        final c = LabController(repo, saveResult: (_) async {});
        addTearDown(c.dispose);
        await _generate(c);
        expect(c.error?.code, 'timeout');
        repo.failure = null;
        await c.retry();
        expect(repo.requestIds[0], repo.requestIds[1]);
        c.reset();
        await _generate(c);
        expect(repo.requestIds.last, isNot(repo.requestIds.first));
      },
    );
    test(
      'save failure retains grade; retrySave does not call grading again',
      () async {
        final repo = _FakeRepository();
        var saveFails = true;
        var saves = 0;
        final c = LabController(
          repo,
          saveResult: (_) async {
            saves++;
            if (saveFails) throw StateError('Disk full');
          },
        );
        addTearDown(c.dispose);
        await _generate(c);
        _fill(c);
        await c.submit();
        expect(c.result, isNotNull);
        expect(c.saved, isFalse);
        expect(c.error?.code, 'save_failed');
        expect(c.answersLocked, isTrue);
        c.setAnswer('q1', 'Changed answer');
        expect(c.answers['q1'], 'My reasoned answer.');
        saveFails = false;
        await c.retrySave();
        expect(c.saved, isTrue);
        expect(c.error, isNull);
        expect(saves, 2);
        expect(repo.submissions.length, 1);
      },
    );
    test(
      'large UTF-8 answers remain editable before any grading request',
      () async {
        final repo = _FakeRepository();
        final controller = LabController(repo, saveResult: (_) async {});
        addTearDown(controller.dispose);
        await controller.generate(
          topic: 'Algorithms',
          track: ProgressTrack.academic,
          level: LabLevel.intermediate,
          questionCount: 20,
        );
        for (final q in controller.session!.questions) {
          controller.setAnswer(q.id, '\u0001' * 6000);
        }
        await controller.submit();
        expect(controller.error?.code, 'request_too_large');
        expect(controller.answersLocked, isFalse);
        expect(repo.submissions, isEmpty);
        _fill(controller);
        await controller.submit();
        expect(controller.saved, isTrue);
        expect(repo.submissions.length, 1);
      },
    );

    test('grading retry locks and resends the original submission', () async {
      final repo = _FakeRepository();
      final c = LabController(repo, saveResult: (_) async {});
      addTearDown(c.dispose);
      await _generate(c);
      _fill(c);
      repo.failure = const LabException('connection_failed', 'Retry');
      await c.submit();
      c.setAnswer('q1', 'Altered');
      repo.failure = null;
      await c.retry();
      expect(repo.submissions, hasLength(2));
      expect(repo.submissions[0], repo.submissions[1]);
      expect(c.saved, isTrue);
    });
    test('clear ignores pending generation and grading and never saves stale results', () async {
      final repo = _FakeRepository()..generateGate = Completer<LabSession>();
      var saves = 0;
      final c = LabController(
        repo,
        saveResult: (_) async {
          saves++;
        },
      );
      addTearDown(c.dispose);
      final pending = _generate(c);
      c.clear();
      repo.generateGate!.complete(_session());
      await pending;
      expect(c.session, isNull);
      expect(c.busy, isFalse);
      repo.generateGate = null;
      await _generate(c);
      _fill(c);
      repo.gradeGate = Completer<LabResult>();
      final grading = c.submit();
      c.clear();
      repo.gradeGate!.complete(_result());
      await grading;
      expect(c.result, isNull);
      expect(saves, 0);
    });
  });

  group('Lab HTTP boundary', () {
    test('rejects credentials and insecure remote URLs', () {
      expect(
        () => ApiLabRepository.validateBaseUrl(Uri.parse('http://example.com')),
        throwsArgumentError,
      );
      expect(
        () => ApiLabRepository.validateBaseUrl(
          Uri.parse('https://user:secret@example.com'),
        ),
        throwsArgumentError,
      );
      expect(
        () => ApiLabRepository.validateBaseUrl(
          Uri.parse('https://example.com?token=secret'),
        ),
        throwsArgumentError,
      );
      expect(
        ApiLabRepository.validateBaseUrl(Uri.parse('http://127.0.0.1:8787/'))
            .path,
        '',
      );
    });
    test('generation sends only requested learning context and authenticates backend', () async {
      final base = await _serve((request) async {
        expect(request.uri.path, '/prefix/api/lab/generate');
        expect(
          request.headers.value('authorization'),
          'Bearer session-only-access',
        );
        final body = jsonDecode(await utf8.decoder.bind(request).join()) as Map;
        expect(body.keys.toSet(), {
          'requestId',
          'topic',
          'learningNotes',
          'questionCount',
          'track',
          'level',
        });
        expect(body['topic'], 'Algorithms');
        await _json(request, _sessionJson());
      });
      final repo = ApiLabRepository(
        baseUrl: base.replace(path: '/prefix'),
        accessToken: 'session-only-access',
      );
      addTearDown(repo.close);
      final session = await repo.generate(
        requestId: 'request-1',
        topic: 'Algorithms',
        learningNotes: 'Sorting invariants',
        track: ProgressTrack.academic,
        level: LabLevel.intermediate,
      );
      expect(session.questions.length, 4);
    });
    test(
      'grading validates the returned question, answer and mark identity',
      () async {
        var mismatch = true;
        final base = await _serve((request) async {
          final json = _result().toJson();
          if (mismatch) {
            ((json['questions'] as List)[0] as Map)['prompt'] =
                'A different prompt';
          }
          await _json(request, json);
        });
        final repo = ApiLabRepository(baseUrl: base);
        addTearDown(repo.close);
        final answers = {
          for (var i = 1; i <= 4; i++) 'q$i': 'My reasoned answer.',
        };
        await expectLater(
          repo.grade(_session(), answers),
          throwsA(_labError('invalid_response')),
        );
        mismatch = false;
        expect((await repo.grade(_session(), answers)).totalScore, 70);
      },
    );
    test('untrusted error text is replaced with a public message', () async {
      final base = await _serve(
        (request) => _json(request, {
          'error': {'code': 'upstream_auth', 'message': 'secret-private-key'},
        }, status: 502),
      );
      final repo = ApiLabRepository(baseUrl: base);
      addTearDown(repo.close);
      try {
        await repo.health();
        fail('Expected a lab error');
      } on LabException catch (e) {
        expect(e.code, 'upstream_auth');
        expect(e.message, isNot(contains('secret-private-key')));
      }
    });
    test('oversized and timed out responses produce bounded errors', () async {
      final base = await _serve((request) async {
        request.response.write('x' * (2 * 1024 * 1024 + 1));
        await request.response.close();
      });
      final repo = ApiLabRepository(baseUrl: base);
      addTearDown(repo.close);
      await expectLater(repo.health(), throwsA(_labError('invalid_response')));
      final slow = await _serve((request) async {
        await Future<void>.delayed(const Duration(milliseconds: 150));
        await _json(request, {
          'status': 'ok',
          'configured': true,
          'mode': 'live',
        });
      });
      final timed = ApiLabRepository(
        baseUrl: slow,
        timeout: const Duration(milliseconds: 30),
      );
      addTearDown(timed.close);
      await expectLater(timed.health(), throwsA(_labError('timeout')));
    });
  });
}
