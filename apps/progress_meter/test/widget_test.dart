import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/app.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/progress/data/demo_data.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';

class _MemoryRepository implements ProgressRepository {
  _MemoryRepository(this.saved);
  ProgressData? saved;
  int writes = 0;

  @override
  Future<ProgressData?> load() async => saved;

  @override
  Future<void> save(ProgressData data) async {
    saved = data;
    writes++;
  }
}

Future<ProgressController> _mount(
  WidgetTester tester,
  _MemoryRepository repository, {
  Size size = const Size(1440, 1100),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final controller = ProgressController(repository);
  addTearDown(controller.dispose);
  await controller.initialize();
  await tester.pumpWidget(ProgressMeterApp(controller: controller));
  await tester.pumpAndSettle();
  return controller;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

ProgressEntry _snapshot(
  String id,
  String title,
  DateTime date,
  double value, {
  ProgressTrack track = ProgressTrack.academic,
}) => ProgressEntry(
  id: id,
  title: title,
  track: track,
  date: date,
  metrics: {for (final metric in MetricKind.values) metric: value},
);

void main() {
  testWidgets(
    'empty workspace routes learning to Testing Lab without manual scoring',
    (tester) async {
      final repository = _MemoryRepository(ProgressData(studentName: 'Sam'));
      final controller = await _mount(tester, repository);
      expect(find.text('Progress you can prove.'), findsOneWidget);
      expect(find.text('Log check-in'), findsNothing);
      expect(find.byType(Slider), findsNothing);
      await _tapVisible(tester, find.byKey(const Key('overview-ai-test')));
      expect(find.byKey(const Key('lab-generate')), findsOneWidget);
      expect(controller.history, isEmpty);
      expect(repository.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'historical comparison changes baseline and tracks stay separate',
    (tester) async {
      final today = DateUtils.dateOnly(DateTime.now());
      final repository = _MemoryRepository(
        ProgressData(
          entries: [
            _snapshot(
              'a',
              'Algebra baseline',
              today.subtract(const Duration(days: 21)),
              40,
            ),
            _snapshot(
              'b',
              'First practice',
              today.subtract(const Duration(days: 14)),
              60,
            ),
            _snapshot(
              'c',
              'Weekly review',
              today.subtract(const Duration(days: 7)),
              80,
            ),
            _snapshot(
              'career',
              'Portfolio review',
              today,
              49,
              track: ProgressTrack.career,
            ),
          ],
        ),
      );
      final controller = await _mount(tester, repository);
      await tester.tap(find.text('My journey').first);
      await tester.pumpAndSettle();
      expect(controller.history, hasLength(3));
      expect(find.text('+40.0 pts'), findsOneWidget);

      final baseline = find.byKey(
        const ValueKey('Baseline check-in-academic-a'),
      );
      await _tapVisible(tester, baseline);
      await _tapVisible(tester, find.textContaining(' · First practice').last);
      expect(
        find.byKey(const ValueKey('Baseline check-in-academic-b')),
        findsOneWidget,
      );
      expect(find.text('+20.0 pts'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('track-career')));
      await tester.pumpAndSettle();
      expect(controller.track, ProgressTrack.career);
      expect(controller.history.single.title, 'Portfolio review');
      expect(find.text('You, compared with you'), findsNothing);
      expect(repository.saved!.entries, hasLength(4));

      await tester.tap(find.byKey(const ValueKey('track-academic')));
      await tester.pumpAndSettle();
      expect(controller.history, hasLength(3));
      expect(find.text('+40.0 pts'), findsOneWidget);
      expect(
        repository.writes,
        0,
        reason: 'Viewing comparisons must not change saved records.',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('selected benchmark becomes a saved goal that can be completed', (
    tester,
  ) async {
    final repository = _MemoryRepository(createDemoData(DateTime.now()));
    final controller = await _mount(tester, repository);
    final originalGoals = controller.goals.length;
    await tester.tap(find.text('Benchmarks').first);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Example profiles are fictional.'),
      findsOneWidget,
    );

    await _tapVisible(tester, find.text('Set as benchmark').first);
    expect(controller.target!.name, 'Arjun Mehta');
    expect(repository.saved!.targetProfileId, 'demo-arjun');
    await _tapVisible(tester, find.text('Create goal →').first);
    await tester.enterText(
      find.byKey(const Key('goal-title')),
      'Reach my next understanding milestone',
    );
    await tester.tap(find.byKey(const Key('goal-save')));
    await tester.pumpAndSettle();
    expect(controller.goals, hasLength(originalGoals + 1));
    final goal = controller.goals.last;
    expect(goal.metric, MetricKind.knowledge);
    expect(goal.target, 84);
    expect(goal.completed, isFalse);
    expect(repository.saved!.goals.last.id, goal.id);

    await tester.tap(find.text('Goals').first);
    await tester.pumpAndSettle();
    expect(find.byType(Checkbox), findsNothing);
    expect(controller.goalAchieved(goal), isFalse);
    await expectLater(controller.toggleGoal(goal), throwsStateError);
    expect(controller.data.goals.last.completed, isFalse);
    expect(find.text(goal.title), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow workspace opens navigation and renders every main page', (
    tester,
  ) async {
    final repository = _MemoryRepository(ProgressData(studentName: 'Sam'));
    await _mount(tester, repository, size: const Size(390, 844));
    expect(find.byTooltip('Open navigation'), findsOneWidget);
    expect(tester.takeException(), isNull);

    for (final page in [
      'My journey',
      'Benchmarks',
      'Goals',
      'Routines',
      'Testing Lab',
      'Settings',
      'Overview',
    ]) {
      await tester.tap(find.byTooltip('Open navigation'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(page).last);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Open navigation'), findsOneWidget);
      expect(
        tester.takeException(),
        isNull,
        reason: '$page should fit a 390px viewport.',
      );
    }
  });
  testWidgets(
    'routines navigation fits a small desktop window and stays independent of tracks',
    (tester) async {
      final repository = _MemoryRepository(ProgressData(studentName: 'Sam'));
      final controller = await _mount(
        tester,
        repository,
        size: const Size(1100, 680),
      );
      await _tapVisible(tester, find.text('Routines').first);
      expect(find.text('A rhythm that works for you.'), findsOneWidget);
      expect(find.byKey(const ValueKey('track-academic')), findsNothing);
      expect(find.text('Personal routines'), findsOneWidget);
      expect(controller.history, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
