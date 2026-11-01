import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/assessment/domain/ai_judgment.dart';
import 'package:progress_meter/features/assessment/application/ai_judgment_controller.dart';
import 'package:progress_meter/features/assessment/data/api_judgment_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';

import 'support/benchmark_fixture.dart';
import 'support/judgment_fixture.dart';

class _Store implements ProgressRepository {
  _Store(this.data);
  ProgressData data;
  bool fail = false;
  @override
  Future<ProgressData?> load() async => data;
  @override
  Future<void> save(ProgressData value) async {
    if (fail) throw StateError('full');
    data = value;
  }
}

class _Repo implements AiJudgmentRepository {
  int calls = 0;
  Completer<AiProgressJudgment>? gate;
  final List<String> ids = [];
  late List<dynamic> results;
  @override
  Future<AiProgressJudgment> review(
    AiEvidenceSnapshot snapshot, {
    required String requestId,
  }) async {
    calls++;
    ids.add(requestId);
    return gate != null ? gate!.future : judgmentFor(results.cast());
  }

  @override
  void close() {}
}

Future<ProgressController> _load(_Store s) async {
  final c = ProgressController(s);
  await c.initialize();
  addTearDown(c.dispose);
  return c;
}

void main() {
  test('AI evidence excludes manual ratings, written answers, private identity and future tests', () {
    final result = benchmarkLab();
    final snapshot = AiEvidenceSnapshot.fromResults([
      result,
      benchmarkLab(
        id: 'future',
        date: DateTime.now().add(const Duration(days: 1)),
      ),
    ], ProgressTrack.academic);
    expect(snapshot.assessments.length, 1);
    expect(snapshot.evidenceKey.length, 64);
    expect(
      jsonEncode(snapshot.toJson('test')),
      isNot(contains('Written work.')),
    );
    expect(
      snapshot.evidenceKey,
      AiEvidenceSnapshot.fromResults([
        result,
      ], ProgressTrack.academic).evidenceKey,
    );
    final judgment = judgmentFor([result]);
    expect(
      AiProgressJudgment.fromJson(judgment.toJson())
          .metric(MetricKind.impact)
          .score,
      isNull,
    );
    expect(
      () => AiProgressJudgment.fromJson({
        ...judgment.toJson(),
        'source': 'manual',
      }),
      throwsFormatException,
    );
  });
  test('goal verification ignores manual flags and requires fresh AI judgment evidence', () async {
    final result = benchmarkLab();
    final judgment = judgmentFor([result]);
    final goal = ProgressGoal(
      id: 'g',
      title: 'Master concepts',
      track: ProgressTrack.academic,
      metric: MetricKind.knowledge,
      target: 85,
      deadline: DateTime.now(),
      completed: true,
    );
    final c = await _load(
      _Store(ProgressData(labResults: [result], goals: [goal])),
    );
    expect(c.goalAchieved(goal), isFalse);
    expect(c.judgedScore(MetricKind.knowledge), isNull);
    await expectLater(c.toggleGoal(goal), throwsStateError);
    await c.recordAiJudgment(judgment);
    expect(c.goalAchieved(goal), isTrue);
    expect(c.judgedScore(MetricKind.consistency), isNull);
    await c.recordLabResult(benchmarkLab(id: 'newer', date: DateTime.now()));
    expect(c.currentJudgment, isNull);
    expect(c.judgmentStale, isTrue);
    expect(c.goalAchieved(goal), isFalse);
  });
  test(
    'AI save failures retry persistence without another model call',
    () async {
      final result = benchmarkLab();
      final store = _Store(ProgressData(labResults: [result]));
      final c = await _load(store);
      final repo = _Repo()..results = [result];
      final review = AiJudgmentController(progress: c, repository: repo);
      addTearDown(review.dispose);
      store.fail = true;
      await review.review();
      expect(review.error, contains('saved'));
      expect(c.data.aiJudgments, isEmpty);
      store.fail = false;
      await review.review();
      expect(repo.calls, 1);
      expect(c.currentJudgment, isNotNull);
      final restored = ProgressData.fromJson(
        jsonDecode(jsonEncode(c.data.toJson())) as Map<String, dynamic>,
      );
      expect(restored.aiJudgments.single.id, c.currentJudgment!.id);
      expect(restored.toJson()['schemaVersion'], 6);
    },
  );
  test('late AI responses cannot save a judgment after assessment evidence changes', () async {
    final result = benchmarkLab();
    final c = await _load(_Store(ProgressData(labResults: [result])));
    final repo = _Repo()
      ..results = [result]
      ..gate = Completer<AiProgressJudgment>();
    final review = AiJudgmentController(progress: c, repository: repo);
    addTearDown(review.dispose);
    final pending = review.review();
    await c.recordLabResult(benchmarkLab(id: 'changed'));
    repo.gate!.complete(judgmentFor([result]));
    await pending;
    expect(c.data.aiJudgments, isEmpty);
    expect(review.error, isNotNull);
  });
  test(
    'old backups retain legacy records and never promote them to AI judgments',
    () {
      final data = ProgressData(
        labResults: [benchmarkLab()],
        researchPlans: [benchmarkPlan()],
      );
      for (final version in [1, 2, 3, 4, 5]) {
        final json = data.toJson()
          ..['schemaVersion'] = version
          ..remove('aiJudgments')
          ..remove('reminderSettings');
        final restored = ProgressData.fromJson(json);
        expect(restored.aiJudgments, isEmpty);
        expect(restored.reminderSettings.enabled, isFalse);
        if (version >= 3) expect(restored.labResults.length, 1);
        if (version >= 4) expect(restored.researchPlans.length, 1);
      }
    },
  );
  test('deleting assessment evidence removes dependent AI judgments and preserves goals', () async {
    final result = benchmarkLab();
    final c = await _load(
      _Store(
        ProgressData(
          labResults: [result],
          aiJudgments: [
            judgmentFor([result]),
          ],
        ),
      ),
    );
    await c.deleteLabResult(result.id);
    expect(c.data.aiJudgments, isEmpty);
    expect(c.currentJudgment, isNull);
  });
  test('AI HTTP requests contain only assessed summaries and reject mismatched source IDs', () async {
    final result = benchmarkLab();
    final snapshot = AiEvidenceSnapshot.fromResults([
      result,
    ], ProgressTrack.academic);
    var wrong = false;
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    server.listen((r) async {
      expect(r.uri.path, '/api/progress/review');
      expect(r.headers.value('authorization'), 'Bearer runtime-token');
      final body = jsonDecode(await utf8.decoder.bind(r).join()) as Map;
      expect(body.keys.toSet(), {
        'requestId',
        'track',
        'evidenceKey',
        'assessments',
      });
      final json = judgmentFor([result]).toJson();
      if (wrong) {
        ((json['metrics'] as List).first as Map)['evidenceIds'] = ['foreign'];
      }
      r.response.headers.contentType = ContentType.json;
      r.response.write(jsonEncode(json));
      await r.response.close();
    });
    final repo = ApiJudgmentRepository(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
      accessToken: 'runtime-token',
    );
    addTearDown(repo.close);
    expect(
      (await repo.review(
        snapshot,
        requestId: 'first',
      )).metric(MetricKind.knowledge).score,
      90,
    );
    wrong = true;
    await expectLater(
      repo.review(snapshot, requestId: 'second'),
      throwsA(isA<AiJudgmentException>()),
    );
  });
  test(
    'coach only shares current complete AI judgments and optional AI details',
    () {
      final results = [
        for (var i = 0; i < 3; i++)
          benchmarkLab(
            id: 'coach-$i',
            date: DateTime.now().subtract(Duration(days: i + 1)),
          ),
      ];
      final data = ProgressData(
        labResults: results,
        aiJudgments: [
          judgmentFor(
            results,
            complete: true,
            summary: 'Private AI explanation',
          ),
        ],
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
      expect((private['history'] as List).length, 1);
      expect(jsonEncode(private), isNot(contains('Private AI explanation')));
      expect(jsonEncode(shared), contains('Private AI explanation'));
    },
  );
}
