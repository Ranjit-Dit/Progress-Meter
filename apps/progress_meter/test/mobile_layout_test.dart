import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/app.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/ai_coach/application/coach_controller.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_repository.dart';
import 'package:progress_meter/features/progress/data/demo_data.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';

import 'support/benchmark_fixture.dart' show benchmarkLab;

class _Store implements ProgressRepository {
  _Store(this.data);
  ProgressData data;
  @override
  Future<ProgressData?> load() async => data;
  @override
  Future<void> save(ProgressData value) async => data = value;
}

class _Coach implements CoachRepository {
  @override
  Future<CoachHealth> health() async =>
      const CoachHealth(configured: false, mode: 'live');
  @override
  Future<CoachReply> ask({
    required String question,
    required CoachContext context,
    List<CoachTurn> conversation = const [],
  }) => throw UnimplementedError();
  @override
  void close() {}
}

Future<void> _mount(
  WidgetTester tester, {
  required Size size,
  double scale = 1,
  FakeViewPadding safe = const FakeViewPadding(top: 59, bottom: 34),
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  tester.view.padding = safe;
  tester.view.viewPadding = safe;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  final data = createDemoData(DateTime.now()).copyWith(
    labResults: [
      for (var i = 0; i < 8; i++)
        benchmarkLab(
          id: 'layout-lab-$i',
          date: DateTime.now().subtract(Duration(days: i + 1)),
          marks: 5,
        ),
    ],
  );
  final progress = ProgressController(_Store(data));
  await progress.initialize();
  final coach = CoachController(_Coach());
  addTearDown(progress.dispose);
  addTearDown(coach.dispose);
  await tester.pumpWidget(
    ProgressMeterApp(controller: progress, coachController: coach),
  );
  await tester.pumpAndSettle();
}

Future<void> _page(WidgetTester tester, String title) async {
  await tester.tap(find.byTooltip('Open navigation'));
  await tester.pumpAndSettle();
  final destination = find.descendant(
    of: find.byType(Drawer),
    matching: find.text(title),
  );
  await tester.ensureVisible(destination);
  await tester.pumpAndSettle();
  await tester.tap(destination);
  await tester.pumpAndSettle();
}

void main() {
  final scenarios = [
    (
      name: 'small phone',
      size: const Size(320, 568),
      scale: 1.0,
      safe: const FakeViewPadding(top: 20),
    ),
    (
      name: 'notched phone',
      size: const Size(390, 844),
      scale: 1.0,
      safe: const FakeViewPadding(top: 59, bottom: 34),
    ),
    (
      name: 'iPhone 15 Pro Max',
      size: const Size(430, 932),
      scale: 1.0,
      safe: const FakeViewPadding(top: 59, bottom: 34),
    ),
    (
      name: 'landscape phone',
      size: const Size(852, 393),
      scale: 1.0,
      safe: const FakeViewPadding(left: 59, right: 59, bottom: 21),
    ),
    (
      name: 'larger text',
      size: const Size(390, 844),
      scale: 1.6,
      safe: const FakeViewPadding(top: 59, bottom: 34),
    ),
    (
      name: 'accessibility text',
      size: const Size(430, 932),
      scale: 2.0,
      safe: const FakeViewPadding(top: 59, bottom: 34),
    ),
  ];
  for (final scenario in scenarios) {
    testWidgets('all pages fit ${scenario.name} and respect safe areas', (
      tester,
    ) async {
      await _mount(
        tester,
        size: scenario.size,
        scale: scenario.scale,
        safe: scenario.safe,
      );
      expect(tester.takeException(), isNull, reason: 'Initial overview');
      final menu = tester.getRect(find.byTooltip('Open navigation'));
      expect(menu.top, greaterThanOrEqualTo(scenario.safe.top));
      expect(menu.left, greaterThanOrEqualTo(scenario.safe.left));
      final layoutErrors = <String>[];
      for (final page in [
        'My journey',
        'Benchmarks',
        'Goals',
        'Routines',
        'AI Coach',
        'Testing Lab',
        'Settings',
        'Overview',
      ]) {
        await _page(tester, page);
        final error = tester.takeException();
        if (error != null) layoutErrors.add('$page: $error');
      }
      expect(layoutErrors, isEmpty, reason: scenario.name);
    });
  }

  testWidgets('goal form remains scrollable above the phone keyboard', (
    tester,
  ) async {
    await _mount(tester, size: const Size(390, 844), scale: 1.6);
    await _page(tester, 'Goals');
    final addGoal = find.byKey(const Key('goals-add-target'));
    await tester.ensureVisible(addGoal);
    await tester.tap(addGoal);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 310);
    tester.view.padding = const FakeViewPadding(top: 59);
    await tester.pumpAndSettle();
    final title = find.byKey(const Key('goal-title'));
    await tester.ensureVisible(title);
    await tester.enterText(title, 'Explain linked lists with confidence');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    final save = find.byKey(const Key('goal-save'));
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    expect(tester.getRect(save).bottom, lessThanOrEqualTo(534));
    expect(tester.takeException(), isNull);
  });

  testWidgets('routine forms and importer fit landscape with larger text', (
    tester,
  ) async {
    await _mount(
      tester,
      size: const Size(852, 393),
      scale: 1.6,
      safe: const FakeViewPadding(left: 59, right: 59, bottom: 21),
    );
    await _page(tester, 'Routines');
    for (final form in [
      (open: 'routine-add-class', action: 'routine-save'),
      (open: 'task-add', action: 'task-save'),
      (open: 'routine-import', action: 'import-cancel'),
    ]) {
      final open = find.byKey(Key(form.open));
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: form.open);
      final action = find.byKey(Key(form.action));
      await tester.ensureVisible(action);
      await tester.pumpAndSettle();
      expect(tester.getRect(action).bottom, lessThanOrEqualTo(372));
      expect(tester.takeException(), isNull, reason: form.action);
      final cancel = find.descendant(
        of: find.byType(Dialog),
        matching: find.text('Cancel'),
      );
      await tester.ensureVisible(cancel);
      await tester.tap(cancel);
      await tester.pumpAndSettle();
    }
  });
}
