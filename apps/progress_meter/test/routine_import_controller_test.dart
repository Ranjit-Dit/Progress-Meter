import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';

class MemoryRepository implements ProgressRepository {
  MemoryRepository(this.data);
  ProgressData data;
  bool fail = false;
  int writes = 0;
  @override
  Future<ProgressData?> load() async => data;
  @override
  Future<void> save(ProgressData next) async {
    writes++;
    if (fail) throw StateError('Disk full');
    data = next;
  }
}

RoutineItem item(
  String id, {
  String title = 'Algorithms',
  Set<int> days = const {1, 2},
}) => RoutineItem(
  id: id,
  title: title,
  kind: RoutineKind.classSession,
  weekdays: days,
  startMinutes: 540,
  endMinutes: 600,
);
void main() {
  test(
    'batch saves once, skips covered days, preserves existing and allows undo',
    () async {
      final existing = item('manual', days: {1});
      final completion = RoutineCompletion(
        routineId: existing.id,
        dateKey: '2026-10-26',
      );
      final repo = MemoryRepository(
        ProgressData(
          studentName: 'Student',
          routines: [existing],
          routineCompletions: [completion],
        ),
      );
      final controller = ProgressController(repo);
      await controller.initialize();
      addTearDown(controller.dispose);
      final ids = await controller.importRoutines([
        item('manual', title: 'ALGORITHMS', days: {1, 2}),
        item('other', days: {1, 2}),
        item('other', title: 'Physics', days: {3}),
      ]);
      expect(repo.writes, 1);
      expect(ids, hasLength(2));
      expect(ids, isNot(contains('manual')));
      expect(controller.data.routines.first, same(existing));
      expect(controller.data.routines[1].weekdays, {2});
      expect(controller.data.routineCompletions.single, same(completion));
      expect(controller.data.studentName, 'Student');
      expect(
        await controller.importRoutines([
          item('new'),
          item('new', title: 'Physics', days: {3}),
        ]),
        isEmpty,
      );
      expect(repo.writes, 1);
      await controller.undoRoutineImport(ids.toSet());
      expect(controller.data.routines.single, same(existing));
      expect(controller.data.routineCompletions.single, same(completion));
    },
  );
  test('failed batch never publishes partial routines', () async {
    final repo = MemoryRepository(ProgressData(routines: []))..fail = true;
    final c = ProgressController(repo);
    await c.initialize();
    addTearDown(c.dispose);
    final before = c.data;
    await expectLater(
      c.importRoutines([item('a'), item('b', title: 'Physics')]),
      throwsStateError,
    );
    expect(c.data, same(before));
    expect(c.saving, isFalse);
    expect(repo.writes, 1);
  });
  test('course names preserve meaningful C++ and C# differences', () async {
    final repo = MemoryRepository(ProgressData());
    final c = ProgressController(repo);
    await c.initialize();
    addTearDown(c.dispose);
    final ids = await c.importRoutines([
      item('a', title: 'C++ programming'),
      item('b', title: 'C# programming'),
    ]);
    expect(ids.length, 2);
  });
}
