import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/common/app_theme.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/testing_lab/application/lab_controller.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_models.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_repository.dart';
import 'package:progress_meter/features/testing_lab/presentation/testing_lab_screen.dart';

final _now = DateTime(2026, 10, 30, 12);
List<LabQuestion> _questions([int count = defaultLabQuestionCount]) => [
  for (var i = 0; i < count; i++)
    LabQuestion(
      id: 'q${i + 1}',
      prompt: 'Explain SQL joins, question ${i + 1}.',
      dimension: i < (count + 1) ~/ 2
          ? LabDimension.understanding
          : LabDimension.application,
    ),
];
LabSession _session({
  String id = 'session-1',
  String topic = 'SQL joins',
  ProgressTrack track = ProgressTrack.academic,
  LabLevel level = LabLevel.intermediate,
  int questionCount = defaultLabQuestionCount,
}) => LabSession(
  sessionId: id,
  sessionToken: 'memory-only-test-bearer-token',
  topic: topic,
  track: track,
  level: level,
  createdAt: _now,
  expiresAt: _now.add(const Duration(hours: 2)),
  questions: _questions(questionCount),
  model: 'controlled-test-model',
);
LabResult _result(
  LabSession session,
  Map<String, String> answers, {
  DateTime? completedAt,
}) => LabResult(
  sessionId: session.sessionId,
  topic: session.topic,
  track: session.track,
  level: session.level,
  completedAt: completedAt ?? _now.subtract(const Duration(minutes: 10)),
  model: 'controlled-test-model',
  feedback: 'Your answer misses NULL semantics. Be precise.',
  nextSteps: ['Compare INNER JOIN with LEFT JOIN on a small table.'],
  questions: [
    for (final q in session.questions)
      LabQuestionGrade(
        question: q,
        answer: answers[q.id] ?? '',
        correctness: (answers[q.id] ?? '').trim().isEmpty ? 0 : 4,
        reasoning: (answers[q.id] ?? '').trim().isEmpty ? 0 : 2,
        precision: (answers[q.id] ?? '').trim().isEmpty ? 0 : 1,
        feedback: 'Question ${q.id}: justify the effect of NULL.',
        missingConcepts: ['Explain treatment of NULL.'],
        referenceAnswer:
            'Reference explanation for ${q.id}: matching rows and NULL behavior.',
      ),
  ],
);

class _Storage implements ProgressRepository {
  _Storage({ProgressData? data}) : stored = data ?? ProgressData();
  ProgressData stored;
  int writes = 0;
  bool fail = false;
  @override
  Future<ProgressData?> load() async => stored;
  @override
  Future<void> save(ProgressData data) async {
    writes++;
    if (fail) throw StateError('disk unavailable');
    stored = data;
  }
}

class _Repository implements LabRepository {
  int gradeCalls = 0;
  final requests = <String>[];
  String? topic, notes;
  int? questionCount;
  LabException? generateFailure, gradeFailure;
  CoachHealth status = const CoachHealth(configured: true, mode: 'live');
  Completer<LabSession>? pending;
  @override
  Future<LabSession> generate({
    required String requestId,
    required String topic,
    required String learningNotes,
    required ProgressTrack track,
    required LabLevel level,
    int questionCount = defaultLabQuestionCount,
  }) async {
    requests.add(requestId);
    this.topic = topic;
    notes = learningNotes;
    this.questionCount = questionCount;
    if (pending != null) return pending!.future;
    if (generateFailure != null) throw generateFailure!;
    return _session(
      topic: topic,
      track: track,
      level: level,
      questionCount: questionCount,
    );
  }

  @override
  Future<LabResult> grade(
    LabSession session,
    Map<String, String> answers,
  ) async {
    gradeCalls++;
    if (gradeFailure != null) throw gradeFailure!;
    return _result(session, answers);
  }

  @override
  Future<CoachHealth> health() async => status;
  @override
  void close() {}
}

Future<(ProgressController, LabController, _Storage)> _mount(
  WidgetTester tester,
  _Repository repository, {
  Size size = const Size(1100, 950),
  _Storage? storage,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final store = storage ?? _Storage();
  final progress = ProgressController(store);
  await progress.initialize();
  final controller = LabController(
    repository,
    saveResult: progress.recordLabResult,
  );
  addTearDown(progress.dispose);
  addTearDown(controller.dispose);
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: TestingLabScreen(
            progress: progress,
            controller: controller,
            baseUrl: Uri.parse('http://127.0.0.1:8787'),
            now: _now,
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (progress, controller, store);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _generate(WidgetTester tester) async {
  await tester.enterText(find.byKey(const Key('lab-topic')), 'SQL joins');
  await tester.enterText(
    find.byKey(const Key('lab-learning-notes')),
    'INNER and LEFT JOIN.',
  );
  await _tap(tester, find.byKey(const Key('lab-generate')));
}

Future<void> _answerAll(
  WidgetTester tester, {
  int count = defaultLabQuestionCount,
}) async {
  for (var i = 1; i <= count; i++) {
    final field = find.byKey(ValueKey('lab-answer-q$i'));
    await tester.ensureVisible(field);
    await tester.enterText(field, 'A reasoned answer for question $i.');
  }
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'generates a topic test, grades written answers and saves detailed feedback',
    (tester) async {
      final repository = _Repository();
      final (progress, controller, storage) = await _mount(tester, repository);
      expect(find.text('Live AI examiner connected'), findsOneWidget);
      await _generate(tester);
      expect(repository.topic, 'SQL joins');
      expect(repository.notes, 'INNER and LEFT JOIN.');
      expect(repository.questionCount, defaultLabQuestionCount);
      expect(find.text('4 QUESTIONS · 40 MARKS'), findsOneWidget);
      expect(find.textContaining('Reference explanation'), findsNothing);
      expect(find.byType(Slider), findsNothing);
      await _answerAll(tester);
      await _tap(tester, find.byKey(const Key('lab-submit')));
      expect(repository.gradeCalls, 1);
      expect(controller.saved, isTrue);
      expect(progress.data.labResults, hasLength(1));
      expect(progress.data.entries, isEmpty);
      expect(storage.writes, 1);
      expect(find.byKey(const Key('lab-total-score')), findsOneWidget);
      expect(
        tester.widget<Text>(find.byKey(const Key('lab-total-score'))).data,
        '70',
      );
      expect(
        find.text('Your answer misses NULL semantics. Be precise.'),
        findsOneWidget,
      );
      expect(find.text('Practice / application'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('lab-marking-details-q1')));
      expect(
        find.textContaining('Reference explanation for q1'),
        findsOneWidget,
      );
      expect(
        find.textContaining('come only from AI judgments'),
        findsOneWidget,
      );
    },
  );
  testWidgets('custom count generates and grades every requested question', (
    tester,
  ) async {
    final repository = _Repository();
    final (progress, controller, _) = await _mount(tester, repository);
    await tester.enterText(find.byKey(const Key('lab-question-count')), '7');
    await _generate(tester);
    expect(repository.questionCount, 7);
    expect(controller.session!.questionCount, 7);
    expect(find.text('7 QUESTIONS · 70 MARKS'), findsOneWidget);
    expect(find.byKey(const ValueKey('lab-answer-q7')), findsOneWidget);
    await _answerAll(tester, count: 7);
    await _tap(tester, find.byKey(const Key('lab-submit')));
    final result = progress.data.labResults.single;
    expect(result.questionCount, 7);
    expect(result.earnedPoints, 49);
    expect(result.maxPoints, 70);
    expect(result.totalScore, 70);
    expect(find.text('7 QUESTIONS · 49 / 70 MARKS'), findsOneWidget);
    await _tap(tester, find.byKey(const Key('lab-retest')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('lab-question-count')))
          .controller!
          .text,
      '7',
    );
    await _tap(tester, find.byKey(const Key('lab-default-question-count')));
    expect(
      tester
          .widget<TextFormField>(find.byKey(const Key('lab-question-count')))
          .controller!
          .text,
      '$defaultLabQuestionCount',
    );
  });
  testWidgets('invalid question counts do not send generation requests', (
    tester,
  ) async {
    final repository = _Repository();
    await _mount(tester, repository);
    await tester.enterText(find.byKey(const Key('lab-topic')), 'SQL joins');
    for (final value in ['', '0', '1', '21', '2.5', 'abc']) {
      await tester.enterText(
        find.byKey(const Key('lab-question-count')),
        value,
      );
      await _tap(tester, find.byKey(const Key('lab-generate')));
      expect(find.text('Enter a whole number from 2 to 20.'), findsOneWidget);
      expect(repository.requests, isEmpty);
    }
    await _tap(tester, find.byKey(const Key('lab-default-question-count')));
    await _tap(tester, find.byKey(const Key('lab-generate')));
    expect(repository.questionCount, defaultLabQuestionCount);
  });
  testWidgets(
    'unanswered questions require confirmation and receive zero marks',
    (tester) async {
      final repository = _Repository();
      final (progress, _, _) = await _mount(tester, repository);
      await _generate(tester);
      await _tap(tester, find.byKey(const Key('lab-submit')));
      expect(find.text('Submit 4 unanswered questions?'), findsOneWidget);
      expect(repository.gradeCalls, 0);
      await _tap(tester, find.text('Keep working'));
      expect(progress.data.labResults, isEmpty);
      await _tap(tester, find.byKey(const Key('lab-submit')));
      await _tap(tester, find.byKey(const Key('lab-confirm-submit')));
      expect(progress.data.labResults.single.totalScore, 0);
      expect(repository.gradeCalls, 1);
    },
  );
  testWidgets(
    'a failed local save keeps the marked paper and retries without another AI call',
    (tester) async {
      final repository = _Repository();
      final storage = _Storage()..fail = true;
      final (progress, controller, _) = await _mount(
        tester,
        repository,
        storage: storage,
      );
      await _generate(tester);
      await _answerAll(tester);
      await _tap(tester, find.byKey(const Key('lab-submit')));
      expect(repository.gradeCalls, 1);
      expect(controller.saved, isFalse);
      expect(progress.data.labResults, isEmpty);
      expect(find.byKey(const Key('lab-total-score')), findsOneWidget);
      expect(find.byKey(const Key('lab-new-topic')), findsNothing);
      storage.fail = false;
      await _tap(tester, find.byKey(const Key('lab-retry-save')));
      expect(repository.gradeCalls, 1);
      expect(controller.saved, isTrue);
      expect(progress.data.labResults, hasLength(1));
    },
  );
  testWidgets(
    'generation retry uses the same request and does not expose private keys',
    (tester) async {
      final repository = _Repository()
        ..generateFailure = const LabException(
          'timeout',
          'The examiner took too long. Retry this request.',
        );
      await _mount(tester, repository);
      await _generate(tester);
      expect(
        find.text('The examiner took too long. Retry this request.'),
        findsOneWidget,
      );
      repository.generateFailure = null;
      await _tap(tester, find.byKey(const Key('lab-retry')));
      expect(repository.requests, hasLength(2));
      expect(repository.requests[0], repository.requests[1]);
      expect(
        find.textContaining('memory-only-test-bearer-token'),
        findsNothing,
      );
      expect(find.byKey(const Key('lab-answer-q1')), findsOneWidget);
    },
  );
  testWidgets(
    'saved history opens a marked assessment and compares the same topic and level',
    (tester) async {
      final first = _result(_session(id: 'earlier'), {
        for (var i = 1; i <= 4; i++) 'q$i': 'Earlier answer.',
      }, completedAt: _now.subtract(const Duration(days: 1)));
      final second = _result(_session(id: 'later'), {
        for (var i = 1; i <= 4; i++) 'q$i': 'Later answer.',
      });
      await _mount(
        tester,
        _Repository(),
        storage: _Storage(data: ProgressData(labResults: [first, second])),
      );
      await _tap(tester, find.byKey(const Key('lab-history-result-later')));
      expect(find.text('Assessment details'), findsOneWidget);
      expect(
        find.textContaining(
          '+0.0 points from your previous 4-question intermediate assessment',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('lab-total-score')), findsOneWidget);
    },
  );
  testWidgets(
    'demo mode explains live grading requirement and cannot generate fake grades',
    (tester) async {
      final repository = _Repository()
        ..status = const CoachHealth(configured: true, mode: 'demo');
      await _mount(tester, repository);
      expect(find.text('Live AI is required for grading'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.byKey(const Key('lab-generate')),
      );
      expect(button.onPressed, isNull);
      expect(repository.requests, isEmpty);
    },
  );
  testWidgets('setup, question form, and marked paper fit a narrow window', (
    tester,
  ) async {
    await _mount(tester, _Repository(), size: const Size(440, 800));
    expect(tester.takeException(), isNull);
    await tester.enterText(find.byKey(const Key('lab-question-count')), '5');
    await _generate(tester);
    expect(tester.takeException(), isNull);
    await _answerAll(tester, count: 5);
    await _tap(tester, find.byKey(const Key('lab-submit')));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('lab-total-score')), findsOneWidget);
  });
}
