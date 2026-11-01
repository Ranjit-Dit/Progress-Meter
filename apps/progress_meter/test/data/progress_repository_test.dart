import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/features/progress/data/demo_data.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';

void main() {
  late Directory directory;
  late File file;
  late JsonProgressRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('progress-meter-test-');
    file = File('${directory.path}/nested/progress.json');
    repository = JsonProgressRepository(file);
  });
  tearDown(() async => directory.delete(recursive: true));

  test('missing file returns no data', () async {
    expect(await repository.load(), isNull);
  });

  test('save creates parent, persists across instances, and replaces previous data', () async {
    final data = createDemoData(DateTime(2026, 10, 29));
    await repository.save(data);
    final restored = await JsonProgressRepository(file).load();
    expect(restored!.toJson(), data.toJson());
    expect(await File('${file.path}.tmp').exists(), isFalse);
    await repository.save(data.copyWith(studentName: 'Sam', entries: []));
    expect((await repository.load())!.studentName, 'Sam');
    expect((await repository.load())!.entries, isEmpty);
  });

  test('corrupt file surfaces an error and preserves original bytes', () async {
    await file.parent.create(recursive: true);
    const original = '{ invalid json';
    await file.writeAsString(original);
    await expectLater(repository.load(), throwsFormatException);
    expect(await file.readAsString(), original);
  });

  test(
    'unrecognized schema surfaces an error without replacing the file',
    () async {
      await file.parent.create(recursive: true);
      const original = '{"schemaVersion":999}';
      await file.writeAsString(original);
      await expectLater(repository.load(), throwsFormatException);
      expect(await file.readAsString(), original);
    },
  );
  test(
    'legacy disk data migrates and routine records persist across restarts',
    () async {
      final legacy = createDemoData(DateTime(2026, 10, 29)).toJson()
        ..['schemaVersion'] = 1
        ..remove('routines')
        ..remove('routineCompletions');
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(legacy));
      final migrated = (await repository.load())!;
      expect(migrated.routines, isEmpty);
      final meal = RoutineItem(
        id: 'breakfast',
        title: 'Breakfast',
        kind: RoutineKind.meal,
        weekdays: {1},
        startMinutes: 480,
        details: 'Toast and fruit',
      );
      final updated = migrated.copyWith(
        routines: [meal],
        routineCompletions: [
          RoutineCompletion(routineId: meal.id, dateKey: '2026-10-26'),
        ],
      );
      await repository.save(updated);
      final restarted = (await JsonProgressRepository(file).load())!;
      expect(restarted.toJson(), updated.toJson());
      expect(restarted.entries.length, migrated.entries.length);
      expect(jsonDecode(await file.readAsString())['schemaVersion'], 6);
    },
  );
}
