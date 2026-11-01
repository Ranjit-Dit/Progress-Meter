import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';
import 'package:progress_meter/features/benchmark_research/domain/benchmark_models.dart';
import 'package:progress_meter/features/benchmark_research/domain/benchmark_analytics.dart';
import 'package:progress_meter/features/benchmark_research/domain/benchmark_repository.dart';
import 'package:progress_meter/features/benchmark_research/data/api_benchmark_repository.dart';
import 'package:progress_meter/features/benchmark_research/application/benchmark_controller.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_models.dart';

import 'support/benchmark_fixture.dart';

class Store implements ProgressRepository {
  Store(this.value);
  ProgressData value;
  int writes = 0;
  bool fail = false;
  @override
  Future<ProgressData?> load() async => value;
  @override
  Future<void> save(ProgressData next) async {
    writes++;
    if (fail) throw StateError('disk');
    value = next;
  }
}

class ResearchFake implements BenchmarkResearchRepository {
  final ids = <String>[];
  BenchmarkException? fail;
  Completer<ResearchPlan>? pending;
  @override
  Future<ResearchPlan> research({
    required String requestId,
    required BenchmarkKind kind,
    required String query,
    required String context,
    required String postText,
    required ProgressTrack track,
  }) async {
    ids.add(requestId);
    if (fail != null) throw fail!;
    return pending == null ? benchmarkPlan() : pending!.future;
  }

  @override
  Future<BenchmarkReview> review(
    BenchmarkProgressSnapshot snapshot, {
    required String requestId,
  }) async => BenchmarkReview(
    planId: snapshot.plan.id,
    reviewedAt: DateTime.now(),
    progressPercent: snapshot.progressPercent,
    summary: 'Practice missing topics.',
    blockers: ['Missing tests.'],
    nextActions: ['Take a test.'],
    model: 'test-model',
  );
  @override
  Future<CoachHealth> health() async =>
      const CoachHealth(configured: true, mode: 'live');
  @override
  void close() {}
}

void main() {
  test(
    'sourced paths round trip and reject unknown citations and unsafe URLs',
    () {
      final p = benchmarkPlan();
      expect(
        ResearchPlan.fromJson(jsonDecode(jsonEncode(p.toJson())))
            .milestones
            .length,
        5,
      );
      final bad = benchmarkJson();
      (bad['milestones'] as List)[0]['sourceIds'] = ['invented'];
      expect(() => ResearchPlan.fromJson(bad), throwsFormatException);
      for (final value in [
        'http://example.com',
        'https://127.0.0.1/a',
        'https://localhost/a',
        'https://x.internal/a',
        'https://user:password@example.com',
        'javascript:alert(1)',
      ]) {
        expect(() => publicBenchmarkUrl(value), throwsFormatException);
      }
      expect(publicBenchmarkUrl('https://example.com/a')!.host, 'example.com');
    },
  );
  test('ambiguous identity is preview only and cannot be adopted', () async {
    final plan = ResearchPlan.fromJson(benchmarkJson(status: 'needs_context'));
    expect(plan.isReady, isFalse);
    final store = Store(ProgressData());
    final c = ProgressController(store);
    await c.initialize();
    addTearDown(c.dispose);
    expect(() => c.adoptResearchPlan(plan), throwsArgumentError);
    expect(store.writes, 0);
  });
  test('latest exact topic, level and track determine partial progress', () {
    final now = DateTime(2026, 10, 30, 12);
    final p = benchmarkPlan();
    final result = BenchmarkAnalytics.evaluate(
      p,
      [
        benchmarkLab(
          id: 'old',
          marks: 5,
          date: now.subtract(const Duration(days: 1)),
        ),
        benchmarkLab(
          id: 'new',
          marks: 4,
          date: now.subtract(const Duration(minutes: 1)),
        ),
        benchmarkLab(
          id: 'future',
          marks: 5,
          date: now.add(const Duration(days: 1)),
        ),
        benchmarkLab(
          id: 'career',
          marks: 5,
          date: now.subtract(const Duration(seconds: 1)),
          track: ProgressTrack.career,
        ),
        benchmarkLab(
          id: 'advanced',
          marks: 5,
          date: now.subtract(const Duration(seconds: 1)),
          level: LabLevel.advanced,
        ),
      ],
      [
        RoadmapProjectEvidence(
          planId: p.id,
          milestoneId: 'm3',
          completed: true,
          notes: 'Built a demonstrable project.',
          url: null,
          updatedAt: now,
        ),
      ],
      now: now,
    );
    expect(result.milestones.first.assessment!.id, 'new');
    expect(result.milestones.first.fraction, .5);
    expect(result.progressPercent, 30);
    expect(
      result.toReviewJson(requestId: 'review').toString(),
      isNot(contains('Written work.')),
    );
    expect(result.projectCount, 1);
  });
  test(
    'schema 1,2,3 migrate, and adopting a path preserves records and drafts',
    () async {
      final original = ProgressData(
        studentName: 'Learner',
        labResults: [benchmarkLab()],
      );
      for (final version in [1, 2, 3]) {
        final json = original.toJson()
          ..['schemaVersion'] = version
          ..remove('researchPlans')
          ..remove('projectEvidence')
          ..remove('selectedResearchPlanId');
        final restored = ProgressData.fromJson(json);
        expect(restored.researchPlans, isEmpty);
        expect(restored.labResults.length, version == 3 ? 1 : 0);
      }
      final store = Store(original);
      final c = ProgressController(store);
      await c.initialize();
      addTearDown(c.dispose);
      await c.adoptResearchPlan(benchmarkPlan());
      expect(c.researchTarget!.id, 'path-one');
      expect(c.data.labResults.length, 1);
      expect(c.labContextRevision, 0);
      await c.adoptResearchPlan(benchmarkPlan());
      expect(c.data.researchPlans.length, 1);
      final e = RoadmapProjectEvidence(
        planId: 'path-one',
        milestoneId: 'm3',
        completed: true,
        notes: 'Project evidence.',
        url: 'https://example.com/project',
        updatedAt: DateTime.now(),
      );
      await c.upsertProjectEvidence(e);
      await c.rename('New name');
      final restored = ProgressData.fromJson(
        jsonDecode(jsonEncode(c.data.toJson())),
      );
      expect(restored.projectEvidence.single.notes, 'Project evidence.');
      expect(restored.selectedResearchPlanId, 'path-one');
      await c.deleteResearchPlan('path-one');
      expect(c.data.projectEvidence, isEmpty);
      expect(c.data.labResults.length, 1);
    },
  );
  test(
    'failed adoption does not change the selected target or existing data',
    () async {
      final store = Store(ProgressData(studentName: 'Learner'))..fail = true;
      final c = ProgressController(store);
      await c.initialize();
      addTearDown(c.dispose);
      final before = c.data;
      await expectLater(c.adoptResearchPlan(benchmarkPlan()), throwsStateError);
      expect(c.data, same(before));
      expect(c.data.researchPlans, isEmpty);
    },
  );
  test(
    'research retries use one request ID and clearing ignores stale replies',
    () async {
      final repo = ResearchFake()
        ..fail = const BenchmarkException('timeout', 'Retry.');
      final c = BenchmarkResearchController(repo);
      addTearDown(c.dispose);
      await c.research(
        kind: BenchmarkKind.person,
        query: 'Sample professional',
        track: ProgressTrack.academic,
      );
      repo.fail = null;
      await c.retry();
      expect(repo.ids[0], repo.ids[1]);
      expect(c.preview, isNotNull);
      repo.pending = Completer<ResearchPlan>();
      final pending = c.research(
        kind: BenchmarkKind.person,
        query: 'Another professional',
        track: ProgressTrack.academic,
      );
      c.clear();
      repo.pending!.complete(benchmarkPlan(id: 'stale'));
      await pending;
      expect(c.preview, isNull);
      expect(c.busy, isFalse);
    },
  );
  test('AI review becomes stale as new evidence changes readiness', () async {
    final c = BenchmarkResearchController(ResearchFake());
    addTearDown(c.dispose);
    final p = benchmarkPlan();
    final first = BenchmarkAnalytics.evaluate(p, [], []);
    await c.reviewProgress(first);
    expect(c.reviewMatches(first), isTrue);
    final changed = BenchmarkAnalytics.evaluate(p, [benchmarkLab()], []);
    expect(c.reviewMatches(changed), isFalse);
  });
  test('HTTP client rejects mismatched and oversized responses without exposing errors', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(() => server.close(force: true));
    final seen = <Map<String, dynamic>>[];
    server.listen((request) async {
      final raw = await utf8.decoder.bind(request).join();
      seen.add(jsonDecode(raw) as Map<String, dynamic>);
      request.response.headers.contentType = ContentType.json;
      request.response.write(
        jsonEncode(benchmarkJson()..['query'] = 'Wrong person'),
      );
      await request.response.close();
    });
    final repo = ApiBenchmarkResearchRepository(
      baseUrl: Uri.parse('http://127.0.0.1:${server.port}'),
    );
    addTearDown(repo.close);
    await expectLater(
      repo.research(
        requestId: 'x',
        kind: BenchmarkKind.person,
        query: 'Sample professional',
        context: '',
        postText: '',
        track: ProgressTrack.academic,
      ),
      throwsA(
        isA<BenchmarkException>().having(
          (e) => e.code,
          'code',
          'invalid_response',
        ),
      ),
    );
    expect(seen.single.containsKey('labResults'), isFalse);
    expect(seen.single.containsKey('OPENAI_API_KEY'), isFalse);
  });
}
