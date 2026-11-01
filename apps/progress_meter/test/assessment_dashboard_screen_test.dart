import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/common/app_theme.dart';
import 'package:progress_meter/features/assessment/presentation/assessment_overview.dart';
import 'package:progress_meter/features/assessment/presentation/assessed_goals_screen.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';

import 'support/benchmark_fixture.dart' show benchmarkLab;

class _Store implements ProgressRepository {
  _Store(this.value);
  ProgressData value;
  @override
  Future<ProgressData?> load() async => value;
  @override
  Future<void> save(ProgressData value) async => this.value = value;
}

Future<ProgressController> _controller({bool evidence = false}) async {
  final c = ProgressController(
    _Store(
      ProgressData(
        studentName: 'Sam',
        entries: [
          ProgressEntry(
            id: 'old-manual',
            title: 'Earlier self-rating',
            track: ProgressTrack.academic,
            date: DateTime(2026, 1, 1),
            metrics: {for (final metric in MetricKind.values) metric: 99},
          ),
        ],
        goals: [
          ProgressGoal(
            id: 'old-goal',
            title: 'Learn data structures',
            track: ProgressTrack.academic,
            metric: MetricKind.knowledge,
            target: 85,
            deadline: DateTime(2027),
            completed: true,
          ),
        ],
        labResults: evidence
            ? [
                benchmarkLab(
                  date: DateTime.now().subtract(const Duration(days: 1)),
                ),
              ]
            : [],
      ),
    ),
  );
  await c.initialize();
  addTearDown(c.dispose);
  return c;
}

Future<void> _mount(
  WidgetTester t,
  Widget child, {
  Size size = const Size(1200, 1100),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

AssessmentOverview _overview(
  ProgressController c, {
  VoidCallback? onTest,
  VoidCallback? onReview,
}) => AssessmentOverview(
  controller: c,
  reviewing: false,
  onReview: onReview ?? () {},
  onTest: onTest ?? () {},
  onGoals: () {},
  onRoutines: () {},
  onBenchmarks: () {},
);
AssessedGoalsScreen _goals(
  ProgressController c, {
  ValueChanged<ProgressGoal>? onDelete,
}) => AssessedGoalsScreen(
  controller: c,
  reviewing: false,
  onReview: () {},
  onTest: () {},
  onAdd: () {},
  onDelete: onDelete ?? (_) {},
);

void main() {
  testWidgets('overview never turns old manual scores into AI judgments', (
    t,
  ) async {
    final c = await _controller();
    await _mount(t, _overview(c));
    for (final metric in MetricKind.values) {
      final value = t.widget<Text>(
        find.byKey(ValueKey('overview-ai-${metric.name}')),
      );
      expect(value.data, 'Not assessed');
    }
    expect(find.byType(Slider), findsNothing);
    expect(find.byType(Checkbox), findsNothing);
    expect(find.text('Progress you can prove.'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'review requires assessed evidence and take-test action remains available',
    (t) async {
      final c = await _controller();
      var tests = 0;
      await _mount(t, _overview(c, onTest: () => tests++));
      final review = t.widget<FilledButton>(
        find.byKey(const Key('overview-ai-review')),
      );
      expect(review.onPressed, isNull);
      await t.tap(find.byKey(const Key('overview-ai-test')));
      expect(tests, 1);
    },
  );
  testWidgets(
    'goals ignore legacy manual completion and only expose evidence-driven status',
    (t) async {
      final c = await _controller();
      await _mount(t, _goals(c));
      expect(
        t
            .widget<Text>(find.byKey(const ValueKey('goal-ai-score-old-goal')))
            .data,
        '—',
      );
      expect(find.byType(Checkbox), findsNothing);
      await t.ensureVisible(find.byKey(const ValueKey('goals-filter-2')));
      await t.tap(find.byKey(const ValueKey('goals-filter-2')));
      await t.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('assessed-goal-old-goal')),
        findsNothing,
      );
      expect(find.text('No goals in this view yet.'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'overview and goals fit a narrow viewport with saved assessment evidence',
    (t) async {
      final c = await _controller(evidence: true);
      await _mount(t, _overview(c), size: const Size(440, 800));
      expect(t.takeException(), isNull);
      await _mount(t, _goals(c), size: const Size(440, 800));
      expect(t.takeException(), isNull);
      expect(
        t
            .widget<FilledButton>(find.byKey(const Key('goals-ai-review')))
            .onPressed,
        isNotNull,
      );
    },
  );
}
