import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';
import 'package:progress_meter/features/benchmark_research/domain/benchmark_analytics.dart';
import 'package:progress_meter/features/progress/data/demo_data.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_analytics.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_models.dart';

import 'support/benchmark_fixture.dart' show benchmarkPlan;

LabResult _result(int count, {String? id, DateTime? date}) => LabResult(
  sessionId: id ?? 'count-$count',
  topic: 'Topic 1',
  track: ProgressTrack.academic,
  level: LabLevel.beginner,
  completedAt: date ?? DateTime(2026, 10, 30, 10, count),
  model: 'test-model',
  feedback: 'Private overall assessment feedback.',
  nextSteps: ['Explain each step more carefully.'],
  questions: [
    for (var i = 1; i <= count; i++)
      LabQuestionGrade(
        question: LabQuestion(
          id: 'q$i',
          prompt: 'Private question $i.',
          dimension: i <= (count + 1) ~/ 2
              ? LabDimension.understanding
              : LabDimension.application,
        ),
        answer: 'Private written response $i.',
        correctness: i <= (count + 1) ~/ 2 ? 5 : 3,
        reasoning: i <= (count + 1) ~/ 2 ? 2 : 1,
        precision: 1,
        feedback: 'Private question feedback $i.',
        missingConcepts: ['Explain the justification.'],
        referenceAnswer: 'Private reference solution $i.',
      ),
  ],
);

void main() {
  test(
    'odd-sized tests use actual dimension totals and survive a JSON backup',
    () {
      final result = _result(7);
      expect(result.maxPoints, 70);
      expect(result.earnedPoints, 47);
      expect(result.totalScore, closeTo(470 / 7, .000001));
      expect(result.understandingScore, 80);
      expect(result.applicationScore, 50);
      final restored = LabResult.fromJson(
        Map<String, dynamic>.from(
          jsonDecode(jsonEncode(result.toJson())) as Map,
        ),
      );
      expect(restored.questions.length, 7);
      expect(restored.totalScore, result.totalScore);
      expect(restored.questions.last.id, 'q7');
      expect(restored.questions.last.answer, 'Private written response 7.');
      expect(
        restored.questions.last.referenceAnswer,
        'Private reference solution 7.',
      );
    },
  );

  test('legacy four and variable tests reopen without altering other saved features', () async {
    final directory = await Directory.systemTemp.createTemp(
      'variable-lab-save-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/progress_v1.json');
    final repository = JsonProgressRepository(file);
    final initial = createDemoData(DateTime(2026, 10, 30));
    await repository.save(initial);
    final controller = ProgressController(repository);
    await controller.initialize();
    addTearDown(controller.dispose);
    for (final count in [4, 7, 20]) {
      await controller.recordLabResult(_result(count));
    }
    final reopened = (await repository.load())!;
    expect(reopened.labResults.map((r) => r.questions.length), [4, 7, 20]);
    expect(reopened.labResults.last.questions.last.id, 'q20');
    expect(
      reopened.entries.map((r) => r.toJson()),
      initial.entries.map((r) => r.toJson()),
    );
    expect(
      reopened.goals.map((r) => r.toJson()),
      initial.goals.map((r) => r.toJson()),
    );
    expect(
      reopened.profiles.map((r) => r.toJson()),
      initial.profiles.map((r) => r.toJson()),
    );
    final persisted = await file.readAsString();
    expect(persisted, isNot(contains('sessionToken')));
    expect(persisted, isNot(contains('OPENAI_API_KEY')));
    final coach = jsonEncode(
      CoachContext.fromProgressData(reopened, ProgressTrack.academic).toJson(),
    );
    expect(coach, isNot(contains('Private written response')));
    expect(coach, isNot(contains('Private reference solution')));
  });

  test(
    'historical comparisons use the same question count as the current test',
    () {
      final earlier = _result(7, id: 'earlier-seven');
      final shorter = _result(
        4,
        id: 'later-four',
        date: DateTime(2026, 10, 30, 11),
      );
      final current = _result(
        7,
        id: 'current-seven',
        date: DateTime(2026, 10, 30, 12),
      );
      expect(
        LabAnalytics.previousComparable([earlier, shorter], current)?.id,
        earlier.id,
      );
      expect(LabAnalytics.previousComparable([shorter], current), isNull);
    },
  );

  test(
    'research readiness accepts the normalized score from a custom-length test',
    () {
      final plan = benchmarkPlan();
      final result = _result(7);
      final snapshot = BenchmarkAnalytics.evaluate(
        plan,
        [result],
        [],
        now: DateTime(2026, 10, 30, 12),
      );
      expect(snapshot.assessmentCount, 1);
      expect(
        snapshot.progressPercent,
        closeTo((result.totalScore / 80) * 20, .000001),
      );
      final shared = jsonEncode(
        snapshot.toReviewJson(requestId: 'review-custom-count'),
      );
      expect(shared, isNot(contains('Private written response')));
      expect(shared, isNot(contains('Private reference solution')));
    },
  );
}
