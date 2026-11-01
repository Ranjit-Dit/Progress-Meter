import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';
import 'package:progress_meter/features/progress/data/demo_data.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/routines/domain/daily_task.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';

import 'support/benchmark_fixture.dart';

class _Store implements ProgressRepository {
  _Store(ProgressData data) : stored = data.toJson();
  Map<String, dynamic> stored;
  int writes = 0;
  bool fail = false;
  Completer<void>? gate;
  @override
  Future<ProgressData?> load() async => ProgressData.fromJson(
    jsonDecode(jsonEncode(stored)) as Map<String, dynamic>,
  );
  @override
  Future<void> save(ProgressData data) async {
    writes++;
    if (gate != null) await gate!.future;
    if (fail) throw StateError('disk full');
    stored = data.toJson();
  }
}

DailyTask _task(
  String id, {
  String date = '2026-10-30',
  int? time,
  bool completed = false,
}) => DailyTask(
  id: id,
  title: 'Private task $id',
  dateKey: date,
  notes: 'Private task notes $id',
  timeMinutes: time,
  completed: completed,
);
Future<ProgressController> _load(_Store store) async {
  final controller = ProgressController(store);
  addTearDown(controller.dispose);
  await controller.initialize();
  return controller;
}

void main() {
  test(
    'daily task fields validate and optional time can be cleared on edit',
    () {
      final task = DailyTask(
        id: 'task-one',
        title: '  Finish assignment  ',
        dateKey: '2026-10-30',
        notes: '  Review chapter three.  ',
        timeMinutes: 17 * 60,
      );
      expect(task.title, 'Finish assignment');
      expect(task.notes, 'Review chapter three.');
      expect(task.date, DateTime(2026, 10, 30));
      expect(task.completed, isFalse);
      expect(DailyTask.fromJson(task.toJson()).toJson(), task.toJson());
      expect(task.copyWith(timeMinutes: null).timeMinutes, isNull);
      expect(task.copyWith(title: 'Submit assignment').timeMinutes, 17 * 60);
      for (final invalid in <DailyTask Function()>[
        () => DailyTask(id: '', title: 'Task', dateKey: '2026-10-30'),
        () => DailyTask(id: 'a', title: ' ', dateKey: '2026-10-30'),
        () => DailyTask(id: 'a', title: 'x' * 101, dateKey: '2026-10-30'),
        () => DailyTask(id: 'a', title: 'Task', dateKey: '2026-02-30'),
        () => DailyTask(id: 'a', title: 'Task', dateKey: '2026-1-3'),
        () => DailyTask(id: 'a', title: 'Task', dateKey: '0000-01-01'),
        () => DailyTask(
          id: 'a',
          title: 'Task',
          dateKey: '2026-10-30',
          timeMinutes: -1,
        ),
        () => DailyTask(
          id: 'a',
          title: 'Task',
          dateKey: '2026-10-30',
          timeMinutes: 1440,
        ),
        () => DailyTask(
          id: 'a',
          title: 'Task',
          dateKey: '2026-10-30',
          notes: 'x' * 1201,
        ),
      ]) {
        expect(invalid, throwsA(anything));
      }
    },
  );

  test(
    'dated tasks do not repeat weekly and sort pending before completed',
    () {
      final tasks = [
        _task('anytime'),
        _task('done-early', time: 300, completed: true),
        _task('later', time: 1000),
        _task('earlier', time: 600),
        _task('next-week', date: '2026-11-06'),
      ];
      expect(
        DailyTaskAnalytics.forDate(
          tasks,
          DateTime(2026, 10, 30, 21),
        ).map((t) => t.id),
        ['earlier', 'later', 'anytime', 'done-early'],
      );
      expect(
        DailyTaskAnalytics.forDate(
          tasks,
          DateTime(2026, 11, 6),
        ).map((t) => t.id),
        ['next-week'],
      );
      expect(
        DailyTaskAnalytics.forDate(tasks, DateTime(2026, 11, 13)),
        isEmpty,
      );
      expect(tasks.first.id, 'anytime');
    },
  );

  test('task edits, completion, and deletion persist without changing weekly routines', () async {
    final routine = RoutineItem(
      id: 'class',
      title: 'Algorithms',
      kind: RoutineKind.classSession,
      weekdays: {5},
      startMinutes: 540,
      endMinutes: 600,
    );
    final original = createDemoData(DateTime(2026, 10, 30)).copyWith(
      routines: [routine],
      routineCompletions: [
        RoutineCompletion(routineId: 'class', dateKey: '2026-10-30'),
      ],
    );
    final store = _Store(original);
    final controller = await _load(store);
    await controller.upsertDailyTask(_task('first', time: 900));
    await controller.upsertDailyTask(_task('second'));
    await controller.toggleDailyTask('first', now: DateTime(2026, 10, 30));
    await controller.upsertDailyTask(
      controller.data.dailyTasks.first.copyWith(title: 'Revised task'),
      now: DateTime(2026, 10, 30),
    );
    expect(controller.data.dailyTasks.first.completed, isTrue);
    expect(controller.tasksOn(DateTime(2026, 10, 30)).length, 2);
    await controller.deleteDailyTask('second');
    final restarted = await _load(store);
    expect(restarted.data.dailyTasks.single.title, 'Revised task');
    expect(restarted.data.dailyTasks.single.completed, isTrue);
    expect(restarted.data.routines.single.toJson(), routine.toJson());
    expect(restarted.data.routineCompletions.single.dateKey, '2026-10-30');
    expect(restarted.data.entries.length, original.entries.length);
    expect(restarted.data.goals.length, original.goals.length);
    expect(restarted.data.profiles.length, original.profiles.length);
  });

  test(
    'completion uses the stored task date and future check-offs are rejected',
    () async {
      final store = _Store(
        ProgressData(
          dailyTasks: [
            _task('today'),
            _task('future', date: '2026-11-01'),
          ],
        ),
      );
      final controller = await _load(store);
      final now = DateTime(2026, 10, 30, 22);
      final before = controller.data;
      await expectLater(
        Future.sync(() => controller.toggleDailyTask('future', now: now)),
        throwsArgumentError,
      );
      await expectLater(
        Future.sync(() => controller.toggleDailyTask('missing', now: now)),
        throwsArgumentError,
      );
      expect(store.writes, 0);
      expect(controller.data, same(before));
      await controller.toggleDailyTask('today', now: now);
      expect(controller.data.dailyTasks.first.completed, isTrue);
      await controller.toggleDailyTask('today', now: now);
      expect(controller.data.dailyTasks.first.completed, isFalse);
      await controller.upsertDailyTask(_task('today', date: '2026-11-02'));
      await expectLater(
        Future.sync(() => controller.toggleDailyTask('today', now: now)),
        throwsArgumentError,
      );
      expect(controller.data.dailyTasks.first.completed, isFalse);
    },
  );

  test(
    'moving a completed task to another day resets its completion',
    () async {
      final store = _Store(
        ProgressData(dailyTasks: [_task('move', completed: true)]),
      );
      final controller = await _load(store);
      await controller.upsertDailyTask(
        controller.data.dailyTasks.single.copyWith(dateKey: '2026-11-01'),
      );
      expect(controller.data.dailyTasks.single.completed, isFalse);
      expect(controller.tasksOn(DateTime(2026, 10, 30)), isEmpty);
      expect(controller.tasksOn(DateTime(2026, 11, 1)).single.id, 'move');
    },
  );

  test('failed writes retain committed tasks and retry persists only the requested change', () async {
    final store = _Store(ProgressData(dailyTasks: [_task('keep')]));
    final controller = await _load(store);
    final before = controller.data;
    store.fail = true;
    await expectLater(
      controller.upsertDailyTask(_task('new')),
      throwsStateError,
    );
    expect(controller.data, same(before));
    expect(controller.saving, isFalse);
    expect((await store.load())!.dailyTasks.single.id, 'keep');
    store.fail = false;
    await controller.upsertDailyTask(_task('new'));
    expect(controller.data.dailyTasks.map((t) => t.id), ['keep', 'new']);
  });

  test('overlapping task saves cannot overwrite an in-flight commit', () async {
    final store = _Store(ProgressData())..gate = Completer<void>();
    final controller = await _load(store);
    final pending = controller.upsertDailyTask(_task('first'));
    expect(controller.saving, isTrue);
    await expectLater(
      controller.upsertDailyTask(_task('second')),
      throwsStateError,
    );
    store.gate!.complete();
    await pending;
    expect(controller.data.dailyTasks.single.id, 'first');
    expect(store.writes, 1);
    expect(controller.saving, isFalse);
  });

  test('schema four migration and schema five disk backups retain other feature data', () async {
    final directory = await Directory.systemTemp.createTemp('daily-task-save-');
    addTearDown(() => directory.delete(recursive: true));
    final plan = benchmarkPlan();
    final initial = createDemoData(DateTime(2026, 10, 30)).copyWith(
      labResults: [benchmarkLab()],
      researchPlans: [plan],
      selectedResearchPlanId: plan.id,
    );
    final legacy = initial.toJson()
      ..['schemaVersion'] = 4
      ..remove('dailyTasks');
    final migrated = ProgressData.fromJson(legacy);
    expect(migrated.dailyTasks, isEmpty);
    expect(
      migrated.labResults.single.toJson(),
      initial.labResults.single.toJson(),
    );
    expect(migrated.researchPlans.single.toJson(), plan.toJson());
    expect(migrated.selectedResearchPlanId, plan.id);
    final withTask = migrated.copyWith(dailyTasks: [_task('private')]);
    final repository = JsonProgressRepository(
      File('${directory.path}/progress_v1.json'),
    );
    await repository.save(withTask);
    final restored = (await repository.load())!;
    expect(restored.toJson()['schemaVersion'], 6);
    expect(restored.toJson(), withTask.toJson());
    expect(() => restored.dailyTasks.clear(), throwsUnsupportedError);
    final duplicate = restored.toJson();
    (duplicate['dailyTasks'] as List).add(restored.dailyTasks.single.toJson());
    expect(() => ProgressData.fromJson(duplicate), throwsA(anything));
  });

  test('daily task content is excluded from AI coach snapshots and start fresh removes tasks', () async {
    final original = createDemoData(DateTime(2026, 10, 30))
        .copyWith(dailyTasks: [_task('private')]);
    final coach = jsonEncode(
      CoachContext.fromProgressData(original, ProgressTrack.academic).toJson(),
    );
    expect(coach, isNot(contains('Private task')));
    expect(coach, isNot(contains('dailyTasks')));
    final store = _Store(original);
    final controller = await _load(store);
    await controller.rename('Student');
    expect(controller.data.dailyTasks.length, 1);
    await controller.clearDemo();
    expect(controller.data.dailyTasks, isEmpty);
    expect(controller.data.studentName, 'Student');
  });
}
