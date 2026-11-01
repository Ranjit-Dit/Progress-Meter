import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';
import 'package:progress_meter/features/progress/data/demo_data.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_models.dart';

LabResult _result(String id) => LabResult.fromJson({
  'sessionId': id,
  'topic': 'Binary search',
  'track': 'academic',
  'level': 'intermediate',
  'completedAt': '2026-10-30T09:00:00.000Z',
  'source': 'openai',
  'model': 'test-model',
  'feedback': 'Check the loop invariant.',
  'nextSteps': ['Explain termination.'],
  'totalScore': 70,
  'understandingScore': 70,
  'applicationScore': 70,
  'questions': [
    for (var i = 1; i <= 4; i++)
      {
        'id': 'q$i',
        'prompt': 'Private test question $i',
        'dimension': i <= 2 ? 'understanding' : 'application',
        'maxPoints': 10,
        'answer': 'Private written solution',
        'correctness': 4,
        'reasoning': 2,
        'precision': 1,
        'feedback': 'State the invariant.',
        'missingConcepts': ['Termination argument'],
        'referenceAnswer': 'Keep the target inside the remaining interval.',
      },
  ],
});

class _Repository implements ProgressRepository {
  _Repository(this.stored);
  ProgressData stored;
  bool fail = false;
  int writes = 0;
  @override
  Future<ProgressData?> load() async => stored;
  @override
  Future<void> save(ProgressData data) async {
    writes++;
    if (fail) throw StateError('disk full');
    stored = data;
  }
}

void main() {
  test('legacy schema 1 and 2 backups upgrade with empty lab results', () {
    final original = createDemoData(DateTime(2026, 10, 30));
    for (final version in [1, 2]) {
      final json = original.toJson()
        ..['schemaVersion'] = version
        ..remove('labResults');
      final restored = ProgressData.fromJson(json);
      expect(restored.labResults, isEmpty);
      expect(restored.entries.length, original.entries.length);
      expect(restored.toJson()['schemaVersion'], 6);
    }
  });
  test(
    'automatic result save is atomic, idempotent, and preserves other features',
    () async {
      final routine = RoutineItem(
        id: 'meal',
        title: 'Lunch',
        kind: RoutineKind.meal,
        weekdays: {5},
        startMinutes: 780,
      );
      final original = createDemoData(DateTime(2026, 10, 30)).copyWith(
        routines: [routine],
        routineCompletions: [
          RoutineCompletion(routineId: 'meal', dateKey: '2026-10-30'),
        ],
      );
      final repo = _Repository(original);
      final c = ProgressController(repo);
      await c.initialize();
      addTearDown(c.dispose);
      await c.recordLabResult(_result('session-one'));
      await c.recordLabResult(_result('session-one'));
      expect(repo.writes, 1);
      expect(c.data.labResults.single.totalScore, 70);
      expect(c.data.entries, original.entries);
      expect(c.data.routines.single, routine);
      expect(c.data.routineCompletions.length, 1);
      await c.rename('Learner');
      expect(c.data.labResults.length, 1);
      final backup = ProgressData.fromJson(
        jsonDecode(jsonEncode(c.data.toJson())),
      );
      expect(
        backup.labResults.single.questions.first.answer,
        'Private written solution',
      );
      expect(backup.labResults.single.totalScore, 70);
      expect(backup.studentName, 'Learner');
      final context = jsonEncode(
        CoachContext.fromProgressData(backup, ProgressTrack.academic).toJson(),
      );
      expect(context, isNot(contains('Private test question')));
      expect(context, isNot(contains('Private written solution')));
      expect(context, isNot(contains('sessionToken')));
    },
  );
  test('failed writes retain the last data; retry saves without another assessment', () async {
    final repo = _Repository(ProgressData(studentName: 'Learner'))..fail = true;
    final c = ProgressController(repo);
    await c.initialize();
    addTearDown(c.dispose);
    final before = c.data;
    await expectLater(c.recordLabResult(_result('one')), throwsStateError);
    expect(c.data, same(before));
    expect(c.data.labResults, isEmpty);
    expect(c.saving, isFalse);
    repo.fail = false;
    await c.recordLabResult(_result('one'));
    expect(c.data.labResults.length, 1);
    expect(repo.writes, 2);
    await c.clearDemo();
    expect(c.data.labResults, isEmpty);
    expect(c.data.studentName, 'Learner');
  });
  test(
    'graded records survive a real disk restart without session secrets',
    () async {
      final dir = await Directory.systemTemp.createTemp('progress-lab-');
      addTearDown(() => dir.delete(recursive: true));
      final file = File('${dir.path}/progress_v1.json');
      final repo = JsonProgressRepository(file);
      await repo.save(
        ProgressData(
          studentName: 'Learner',
          labResults: [_result('saved-test')],
        ),
      );
      final reopened = await JsonProgressRepository(file).load();
      expect(
        reopened!.labResults.single.questions.last.referenceAnswer,
        isNotEmpty,
      );
      expect(reopened.labResults.single.totalScore, 70);
      final raw = await file.readAsString();
      expect(raw, isNot(contains('sessionToken')));
      expect(raw, isNot(contains('OPENAI_API_KEY')));
    },
  );
}
