import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/app/app.dart';
import 'package:progress_meter/common/app_theme.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/benchmark_research/domain/benchmark_models.dart';
import 'package:progress_meter/features/benchmark_research/application/benchmark_controller.dart';
import 'package:progress_meter/features/benchmark_research/presentation/benchmark_research_screen.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_repository.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_models.dart';
import 'package:progress_meter/features/testing_lab/application/lab_controller.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';

import 'support/benchmark_fixture.dart';
import 'benchmark_research_core_test.dart' show Store, ResearchFake;

class _Ambiguous extends ResearchFake {
  @override
  Future<ResearchPlan> research({
    required String requestId,
    required BenchmarkKind kind,
    required String query,
    required String context,
    required String postText,
    required ProgressTrack track,
  }) async => ResearchPlan.fromJson(benchmarkJson(status: 'needs_context'));
}

Future<(ProgressController, BenchmarkResearchController)> mount(
  WidgetTester t, {
  ResearchFake? repo,
  ProgressData? data,
  Size size = const Size(1100, 900),
  Future<bool> Function(Uri)? onOpen,
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final p = ProgressController(Store(data ?? ProgressData()));
  await p.initialize();
  final c = BenchmarkResearchController(repo ?? ResearchFake());
  addTearDown(p.dispose);
  addTearDown(c.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: BenchmarkResearchScreen(
              progress: p,
              controller: c,
              baseUrl: Uri.parse('http://127.0.0.1:8787'),
              onTestMilestone: (_, _) {},
              onOpenSource: onOpen,
            ),
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return (p, c);
}

Future<void> tap(WidgetTester t, Finder f) async {
  await t.ensureVisible(f);
  await t.pumpAndSettle();
  await t.tap(f);
  await t.pumpAndSettle();
}

Future<void> research(WidgetTester t) async {
  await t.enterText(
    find.byKey(const Key('research-query')),
    'Sample professional',
  );
  await tap(t, find.byKey(const Key('research-search')));
}

class _LabRepo implements LabRepository {
  String? topic;
  @override
  Future<LabSession> generate({
    required String requestId,
    required String topic,
    required String learningNotes,
    required ProgressTrack track,
    required LabLevel level,
    int questionCount = defaultLabQuestionCount,
  }) async {
    this.topic = topic;
    return LabSession(
      sessionId: 'new-lab',
      sessionToken: 'test-only-token',
      topic: topic,
      track: track,
      level: level,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(const Duration(hours: 2)),
      questions: [
        for (var i = 1; i <= 4; i++)
          LabQuestion(
            id: 'q$i',
            prompt: 'Roadmap question $i',
            dimension: i <= 2
                ? LabDimension.understanding
                : LabDimension.application,
          ),
      ],
      model: 'test-model',
    );
  }

  @override
  Future<LabResult> grade(
    LabSession session,
    Map<String, String> answers,
  ) async => throw UnimplementedError();
  @override
  Future<CoachHealth> health() async =>
      const CoachHealth(configured: true, mode: 'live');
  @override
  void close() {}
}

void main() {
  testWidgets(
    'research preview cites sources and adoption saves a selected target',
    (t) async {
      final opened = <Uri>[];
      final (p, _) = await mount(
        t,
        onOpen: (uri) async {
          opened.add(uri);
          return true;
        },
      );
      await research(t);
      expect(p.data.researchPlans, isEmpty);
      expect(find.byKey(const Key('research-adopt')), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('source-path-one-s1')).first);
      expect(opened.single.host, 'example.com');
      await tap(t, find.byKey(const Key('research-adopt')));
      expect(p.researchTarget!.id, 'path-one');
      expect(find.text('0.0%'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('ambiguous person cannot be adopted without better context', (
    t,
  ) async {
    final (p, _) = await mount(t, repo: _Ambiguous());
    await research(t);
    expect(find.byKey(const Key('research-adopt')), findsNothing);
    expect(p.data.researchPlans, isEmpty);
    expect(find.textContaining('Add a field, organization'), findsOneWidget);
  });
  testWidgets(
    'matching assessments and saved project evidence update readiness and stale AI reviews',
    (t) async {
      final plan = benchmarkPlan();
      final (p, c) = await mount(
        t,
        data: ProgressData(
          researchPlans: [plan],
          selectedResearchPlanId: plan.id,
        ),
      );
      await p.recordLabResult(benchmarkLab());
      await t.pumpAndSettle();
      expect(find.text('10.0%'), findsOneWidget);
      await tap(t, find.byKey(const ValueKey('roadmap-action-m3')));
      await t.enterText(
        find.byKey(const Key('project-notes')),
        'Built and documented a small project.',
      );
      await tap(t, find.byKey(const Key('project-completed')));
      await tap(t, find.byKey(const Key('project-save')));
      expect(p.data.projectEvidence.single.completed, isTrue);
      expect(find.text('30.0%'), findsOneWidget);
      await tap(t, find.byKey(const Key('research-review')));
      expect(c.review, isNotNull);
      expect(find.byKey(const Key('research-review-summary')), findsOneWidget);
      await p.recordLabResult(
        benchmarkLab(id: 'later', marks: 5, date: DateTime.now()),
      );
      await t.pumpAndSettle();
      expect(find.text('32.5%'), findsOneWidget);
      expect(find.byKey(const Key('research-review-summary')), findsNothing);
      expect(find.textContaining('Your evidence has changed'), findsOneWidget);
    },
  );
  testWidgets('research and selected path fit a narrow window', (t) async {
    await mount(t, size: const Size(440, 760));
    await research(t);
    expect(t.takeException(), isNull);
    await tap(t, find.byKey(const Key('research-adopt')));
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'roadmap assessment action opens Testing Lab with the exact skill topic',
    (t) async {
      t.view.physicalSize = const Size(1440, 1050);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final plan = benchmarkPlan();
      final p = ProgressController(
        Store(
          ProgressData(researchPlans: [plan], selectedResearchPlanId: plan.id),
        ),
      );
      await p.initialize();
      addTearDown(p.dispose);
      final repo = _LabRepo();
      final lab = LabController(repo, saveResult: p.recordLabResult);
      addTearDown(lab.dispose);
      final research = BenchmarkResearchController(ResearchFake());
      addTearDown(research.dispose);
      await t.pumpWidget(
        ProgressMeterApp(
          controller: p,
          labController: lab,
          benchmarkController: research,
        ),
      );
      await t.pumpAndSettle();
      await tap(t, find.text('Benchmarks').first);
      await tap(t, find.byKey(const ValueKey('roadmap-action-m1')));
      expect(repo.topic, 'Topic 1');
      expect(find.text('Roadmap question 1'), findsOneWidget);
      expect(lab.session!.level, LabLevel.beginner);
    },
  );
}
