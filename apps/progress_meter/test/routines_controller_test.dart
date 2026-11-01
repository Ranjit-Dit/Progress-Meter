import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/progress/data/demo_data.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';

Map<String, dynamic> _clone(Map<String, dynamic> json) =>
    jsonDecode(jsonEncode(json)) as Map<String, dynamic>;

/// JSON round trips make this fake behave like persistent storage on restart.
class _JsonMemoryRepository implements ProgressRepository {
  _JsonMemoryRepository(ProgressData data) : stored = data.toJson();
  _JsonMemoryRepository.legacy(Map<String, dynamic> json)
    : stored = _clone(json);
  Map<String, dynamic> stored;
  int writes = 0;
  Object? error;
  Completer<void>? gate;

  @override
  Future<ProgressData?> load() async => ProgressData.fromJson(_clone(stored));

  @override
  Future<void> save(ProgressData data) async {
    writes++;
    final pending = gate;
    if (pending != null) await pending.future;
    if (error != null) throw error!;
    stored = _clone(data.toJson());
  }
}

RoutineItem _class(String id, {Set<int> weekdays = const {1, 2}}) =>
    RoutineItem(
      id: id,
      title: 'Algorithms',
      kind: RoutineKind.classSession,
      weekdays: weekdays,
      startMinutes: 540,
      endMinutes: 600,
      location: 'Room 203',
    );

RoutineItem _meal(String id) => RoutineItem(
  id: id,
  title: 'Breakfast',
  kind: RoutineKind.meal,
  weekdays: {1, 2, 3, 4, 5, 6, 7},
  startMinutes: 480,
  details: 'Toast and fruit',
);

Future<ProgressController> _load(_JsonMemoryRepository repository) async {
  final controller = ProgressController(repository);
  addTearDown(controller.dispose);
  await controller.initialize();
  return controller;
}

void main() {
  final monday = DateTime(2026, 10, 26);
  final tuesday = DateTime(2026, 10, 27);
  final today = DateTime(2026, 10, 29, 16);

  test(
    'add and edit preserve exact-date completion history and existing progress',
    () async {
      final original = createDemoData(today);
      final repository = _JsonMemoryRepository(original);
      final controller = await _load(repository);
      final item = _class('algorithms', weekdays: {1});
      await controller.upsertRoutine(item);
      await controller.toggleRoutine(item, monday, now: today);
      expect(controller.routinesOn(monday).single.id, item.id);
      expect(controller.routineCompleted(item.id, monday), isTrue);

      final edited = item.copyWith(
        title: 'Advanced algorithms',
        weekdays: {2},
        startMinutes: 600,
        endMinutes: 660,
      );
      await controller.upsertRoutine(edited);

      expect(controller.data.routines, hasLength(1));
      expect(controller.data.routines.single.title, 'Advanced algorithms');
      expect(controller.routinesOn(monday), isEmpty);
      expect(controller.routinesOn(tuesday).single.id, item.id);
      expect(controller.routineCompleted(item.id, monday), isTrue);
      expect(controller.data.routineCompletions.single.dateKey, '2026-10-26');
      expect(
        controller.data.entries.map((entry) => entry.toJson()),
        original.entries.map((entry) => entry.toJson()),
      );
      expect(
        controller.data.goals.map((goal) => goal.toJson()),
        original.goals.map((goal) => goal.toJson()),
      );
      expect(controller.data.targetProfileId, original.targetProfileId);

      // Historical completion remains undoable after the recurring day changes.
      await controller.toggleRoutine(edited, monday, now: today);
      expect(controller.routineCompleted(item.id, monday), isFalse);
      expect(controller.data.routineCompletions, isEmpty);
    },
  );

  test('weekly occurrences are checked and unchecked independently', () async {
    final item = _class('algorithms');
    final repository = _JsonMemoryRepository(ProgressData(routines: [item]));
    final controller = await _load(repository);
    await controller.toggleRoutine(item, monday, now: today);
    await controller.toggleRoutine(item, tuesday, now: today);

    expect(controller.data.routineCompletions, hasLength(2));
    expect(controller.routineCompleted(item.id, monday), isTrue);
    expect(controller.routineCompleted(item.id, tuesday), isTrue);
    expect(
      controller.routineCompleted(item.id, DateTime(2026, 11, 2)),
      isFalse,
    );
    await controller.toggleRoutine(item, monday, now: today);
    expect(controller.routineCompleted(item.id, monday), isFalse);
    expect(controller.routineCompleted(item.id, tuesday), isTrue);
    expect(controller.data.routineCompletions.single.dateKey, '2026-10-27');
  });

  test('future, unscheduled and deleted routine checks are rejected without writing', () async {
    final item = _class('algorithms', weekdays: {1});
    final repository = _JsonMemoryRepository(ProgressData(routines: [item]));
    final controller = await _load(repository);
    final before = controller.data;

    expect(
      () => controller.toggleRoutine(item, DateTime(2026, 11, 2), now: today),
      throwsArgumentError,
    );
    expect(
      () => controller.toggleRoutine(item, tuesday, now: today),
      throwsArgumentError,
    );
    expect(
      () => controller.toggleRoutine(_meal('missing'), monday, now: today),
      throwsArgumentError,
    );
    expect(repository.writes, 0);
    expect(controller.data, same(before));
    expect(controller.saving, isFalse);

    // The stored recurrence, not a stale editor's recurrence, is authoritative.
    await controller.upsertRoutine(item.copyWith(weekdays: {2}));
    final writes = repository.writes;
    expect(
      () => controller.toggleRoutine(item, monday, now: today),
      throwsArgumentError,
    );
    expect(repository.writes, writes);
    await controller.toggleRoutine(item, tuesday, now: today);
    expect(controller.routineCompleted(item.id, tuesday), isTrue);
  });

  test(
    'deletion cascades only the removed routine completion records',
    () async {
      final first = _class('algorithms');
      final second = _meal('breakfast');
      final original = createDemoData(today).copyWith(
        routines: [first, second],
        routineCompletions: [
          RoutineCompletion(routineId: first.id, dateKey: '2026-10-26'),
          RoutineCompletion(routineId: first.id, dateKey: '2026-10-27'),
          RoutineCompletion(routineId: second.id, dateKey: '2026-10-26'),
        ],
      );
      final repository = _JsonMemoryRepository(original);
      final controller = await _load(repository);
      await controller.deleteRoutine(first.id);

      expect(controller.data.routines.map((item) => item.id), [second.id]);
      expect(controller.data.routineCompletions, hasLength(1));
      expect(controller.data.routineCompletions.single.routineId, second.id);
      expect(controller.routineCompleted(second.id, monday), isTrue);
      expect(controller.data.entries.length, original.entries.length);
      expect(controller.data.goals.length, original.goals.length);
      final restarted = await _load(repository);
      expect(restarted.data.toJson(), controller.data.toJson());
    },
  );

  test(
    'failed routine saves preserve the full workspace and release busy state',
    () async {
      final item = _class('algorithms');
      final original = createDemoData(today).copyWith(
        routines: [item],
        routineCompletions: [
          RoutineCompletion(routineId: item.id, dateKey: '2026-10-26'),
        ],
      );
      final repository = _JsonMemoryRepository(original);
      final controller = await _load(repository);
      final before = controller.data;
      final storedBefore = _clone(repository.stored);
      final states = <bool>[];
      controller.addListener(() => states.add(controller.saving));

      for (final action in <Future<void> Function()>[
        () => controller.upsertRoutine(item.copyWith(title: 'Edited title')),
        () => controller.toggleRoutine(item, tuesday, now: today),
        () => controller.deleteRoutine(item.id),
      ]) {
        repository.error = StateError('Storage unavailable');
        repository.gate = Completer<void>();
        final operation = action();
        expect(controller.saving, isTrue);
        expect(controller.data, same(before));
        final failure = expectLater(operation, throwsStateError);
        repository.gate!.complete();
        await failure;
        expect(controller.saving, isFalse);
        expect(controller.data, same(before));
        expect(repository.stored, storedBefore);
      }
      expect(states, [true, false, true, false, true, false]);
      repository.error = null;
      repository.gate = null;
      await controller.upsertRoutine(_meal('breakfast'));
      expect(controller.data.routines, hasLength(2));
      expect(controller.data.routineCompletions, hasLength(1));
      expect(controller.saving, isFalse);
    },
  );

  test('schema one load keeps goals and profiles while new routines persist on restart', () async {
    final original = createDemoData(today).copyWith(studentName: 'Sam');
    final legacy = original.toJson()
      ..['schemaVersion'] = 1
      ..remove('routines')
      ..remove('routineCompletions');
    final repository = _JsonMemoryRepository.legacy(legacy);
    final controller = await _load(repository);

    expect(repository.writes, 0);
    expect(controller.data.studentName, 'Sam');
    expect(controller.data.routines, isEmpty);
    expect(controller.data.routineCompletions, isEmpty);
    expect(
      controller.data.profiles.map((profile) => profile.toJson()),
      original.profiles.map((profile) => profile.toJson()),
    );
    expect(
      controller.data.goals.map((goal) => goal.toJson()),
      original.goals.map((goal) => goal.toJson()),
    );
    expect(controller.data.targetProfileId, original.targetProfileId);
    final meal = _meal('breakfast');
    await controller.upsertRoutine(meal);
    await controller.toggleRoutine(meal, monday, now: today);
    expect(repository.stored['schemaVersion'], 6);

    final restarted = await _load(repository);
    expect(restarted.data.routines.single.toJson(), meal.toJson());
    expect(restarted.routineCompleted(meal.id, monday), isTrue);
    expect(
      restarted.data.profiles.map((profile) => profile.toJson()),
      original.profiles.map((profile) => profile.toJson()),
    );
    expect(
      restarted.data.goals.map((goal) => goal.toJson()),
      original.goals.map((goal) => goal.toJson()),
    );
    expect(restarted.data.studentName, 'Sam');
  });

  test('editing cannot turn an existing class into a food routine', () async {
    final item = _class('same-id');
    final repository = _JsonMemoryRepository(ProgressData(routines: [item]));
    final controller = await _load(repository);
    expect(() => controller.upsertRoutine(_meal(item.id)), throwsArgumentError);
    expect(controller.data.routines.single.kind, RoutineKind.classSession);
    expect(repository.writes, 0);
  });
}
