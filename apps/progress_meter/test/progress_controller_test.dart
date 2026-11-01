import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';

class _MemoryRepository implements ProgressRepository {
  _MemoryRepository(this.saved);

  ProgressData? saved;
  int writes = 0;
  Object? saveError;
  Completer<void>? saveGate;

  @override
  Future<ProgressData?> load() async => saved;

  @override
  Future<void> save(ProgressData data) async {
    writes++;
    final gate = saveGate;
    if (gate != null) await gate.future;
    if (saveError != null) throw saveError!;
    saved = data;
  }
}

ProgressEntry _entry(
  String id,
  DateTime date, {
  ProgressTrack track = ProgressTrack.academic,
}) => ProgressEntry(
  id: id,
  title: id,
  track: track,
  date: date,
  metrics: {for (final metric in MetricKind.values) metric: 60},
);

void main() {
  test('first launch seeds and saves both progress tracks', () async {
    final repository = _MemoryRepository(null);
    final controller = ProgressController(repository);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(repository.writes, 1);
    expect(repository.saved, same(controller.data));
    expect(
      controller.data.entries.any(
        (entry) => entry.track == ProgressTrack.academic,
      ),
      isTrue,
    );
    expect(
      controller.data.entries.any(
        (entry) => entry.track == ProgressTrack.career,
      ),
      isTrue,
    );
    expect(controller.latest, isNotNull);
  });

  test('existing saved data is preserved, including an intentionally empty workspace', () async {
    final saved = ProgressData(studentName: 'Sam');
    final repository = _MemoryRepository(saved);
    final controller = ProgressController(repository);
    addTearDown(controller.dispose);

    await controller.initialize();

    expect(controller.data, same(saved));
    expect(controller.data.studentName, 'Sam');
    expect(controller.history, isEmpty);
    expect(repository.writes, 0);
  });

  test('failed save keeps previous data and releases saving state', () async {
    final saved = ProgressData(studentName: 'Before');
    final repository = _MemoryRepository(saved)
      ..saveGate = Completer<void>()
      ..saveError = StateError('Disk is full');
    final controller = ProgressController(repository);
    addTearDown(controller.dispose);
    await controller.initialize();
    final states = <bool>[];
    controller.addListener(() => states.add(controller.saving));

    final operation = controller.rename('After');
    expect(controller.saving, isTrue);
    expect(controller.data, same(saved));
    final failure = expectLater(operation, throwsStateError);
    repository.saveGate!.complete();
    await failure;

    expect(controller.saving, isFalse);
    expect(controller.data, same(saved));
    expect(repository.saved, same(saved));
    expect(states, [true, false]);

    // A failed write must not strand the controller in a permanently busy state.
    repository.saveGate = null;
    repository.saveError = null;
    await controller.rename('Recovered');
    expect(controller.data.studentName, 'Recovered');
    expect(repository.saved!.studentName, 'Recovered');
  });

  test('target is scoped to the selected track and can be removed', () async {
    final careerProfile = TargetProfile(
      id: 'career-peer',
      name: 'Taylor',
      role: 'Developer',
      initials: 'T',
      track: ProgressTrack.career,
      metrics: {for (final metric in MetricKind.values) metric: 80},
    );
    final repository = _MemoryRepository(
      ProgressData(
        profiles: [careerProfile],
        targetProfileId: careerProfile.id,
      ),
    );
    final controller = ProgressController(repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    expect(controller.track, ProgressTrack.academic);
    expect(controller.target, isNull);
    controller.selectTrack(ProgressTrack.career);
    expect(controller.target, same(careerProfile));
    controller.selectTrack(ProgressTrack.academic);
    expect(controller.target, isNull);
    expect(controller.data.targetProfileId, careerProfile.id);
    await controller.setTarget(null);
    controller.selectTrack(ProgressTrack.career);
    expect(controller.target, isNull);
    expect(repository.saved!.targetProfileId, isNull);
  });

  test('backdated records and deletion use event dates rather than insertion order', () async {
    final oldest = _entry('oldest', DateTime(2026, 1, 1));
    final latest = _entry('latest', DateTime(2026, 3, 1));
    final career = _entry(
      'career',
      DateTime(2026, 4, 1),
      track: ProgressTrack.career,
    );
    final repository = _MemoryRepository(
      ProgressData(
        entries: [
          latest,
          career,
          oldest,
          _entry('backdated', DateTime(2026, 2, 1)),
        ],
      ),
    );
    final controller = ProgressController(repository);
    addTearDown(controller.dispose);
    await controller.initialize();

    await expectLater(
      controller.addEntry(_entry('new-manual', DateTime(2026, 2, 1))),
      throwsStateError,
    );

    expect(controller.history.map((entry) => entry.id), [
      'oldest',
      'backdated',
      'latest',
    ]);
    expect(controller.latest!.id, 'latest');
    expect(controller.previous!.id, 'backdated');
    await controller.deleteEntry('latest');
    expect(controller.latest!.id, 'backdated');
    expect(controller.previous!.id, 'oldest');
    expect(
      repository.saved!.entries.any((entry) => entry.id == 'latest'),
      isFalse,
    );
    controller.selectTrack(ProgressTrack.career);
    expect(controller.latest, same(career));
    expect(controller.previous, isNull);
  });
}
