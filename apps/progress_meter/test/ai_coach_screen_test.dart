import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/app.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/features/ai_coach/application/coach_controller.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_repository.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';

class _MemoryProgressRepository implements ProgressRepository {
  _MemoryProgressRepository(this.saved);
  ProgressData saved;
  int writes = 0;
  @override
  Future<ProgressData?> load() async => saved;
  @override
  Future<void> save(ProgressData data) async {
    saved = data;
    writes++;
  }
}

CoachReply _reply({String source = 'openai'}) => CoachReply(
  reply: 'Your practice is improving. Keep your next step small and specific.',
  suggestions: [
    CoachSuggestion(
      title: 'Practice a little every day',
      metric: MetricKind.practice,
      target: 75,
      days: 7,
    ),
  ],
  source: source,
  model: source == 'openai' ? 'test-model' : null,
);

class _FakeCoachRepository implements CoachRepository {
  final questions = <String>[];
  final contexts = <CoachContext>[];
  final conversations = <List<CoachTurn>>[];
  CoachException? failure;
  CoachReply response = _reply();
  CoachHealth status = const CoachHealth(configured: true, mode: 'live');
  Completer<CoachReply>? pending;

  @override
  Future<CoachHealth> health() async => status;
  @override
  Future<CoachReply> ask({
    required String question,
    required CoachContext context,
    List<CoachTurn> conversation = const [],
  }) async {
    questions.add(question);
    contexts.add(context);
    conversations.add(List.of(conversation));
    if (pending != null) return pending!.future;
    if (failure != null) throw failure!;
    return response;
  }

  @override
  void close() {}
}

ProgressData _workspaceData() => ProgressData(
  studentName: 'Private student',
  entries: [
    for (var index = 0; index < 15; index++)
      ProgressEntry(
        id: 'snapshot-$index',
        title: 'Private snapshot title',
        note: 'Private academic reflection $index',
        track: ProgressTrack.academic,
        date: DateTime(2026, 1, index + 1),
        metrics: {
          for (final metric in MetricKind.values) metric: 40 + index.toDouble(),
        },
      ),
    ProgressEntry(
      id: 'career-snapshot',
      title: 'Private career title',
      note: 'Private career reflection',
      track: ProgressTrack.career,
      date: DateTime(2026, 1, 15),
      metrics: {for (final metric in MetricKind.values) metric: 55},
    ),
  ],
);

Future<(ProgressController, CoachController, _MemoryProgressRepository)> _mount(
  WidgetTester tester,
  _FakeCoachRepository repository, {
  Size size = const Size(1440, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final storage = _MemoryProgressRepository(_workspaceData());
  final progress = ProgressController(storage);
  final coach = CoachController(repository);
  addTearDown(progress.dispose);
  addTearDown(coach.dispose);
  await progress.initialize();
  await tester.pumpWidget(
    ProgressMeterApp(controller: progress, coachController: coach),
  );
  await tester.pumpAndSettle();
  if (size.width < 1000) {
    await tester.tap(find.byTooltip('Open navigation'));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text('AI Coach').last);
  await tester.pumpAndSettle();
  return (progress, coach, storage);
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _ask(WidgetTester tester, String question) async {
  final field = find.byKey(const Key('coach-question'));
  await tester.ensureVisible(field);
  await tester.enterText(field, question);
  await _tapVisible(tester, find.byKey(const Key('coach-send')));
}

void main() {
  testWidgets(
    'coach sends a private bounded snapshot and saves a suggestion only after review',
    (tester) async {
      final repository = _FakeCoachRepository();
      final (progress, coach, storage) = await _mount(tester, repository);
      expect(find.text('Meet your progress coach.'), findsOneWidget);
      expect(find.text('Connected to your coach'), findsOneWidget);

      await _ask(tester, 'What should I focus on this week?');
      expect(repository.questions, ['What should I focus on this week?']);
      final context = repository.contexts.single.toJson();
      expect((context['history'] as List), isEmpty);
      expect(context['track'], 'academic');
      expect(jsonEncode(context), isNot(contains('Private student')));
      expect(jsonEncode(context), isNot(contains('Private snapshot title')));
      expect(
        jsonEncode(context),
        isNot(contains('Private academic reflection')),
      );
      expect(coach.turns, hasLength(2));
      expect(progress.data.goals, isEmpty);
      expect(
        storage.writes,
        0,
        reason: 'AI guidance must not change saved progress automatically.',
      );

      final review = find.byKey(
        const ValueKey('coach-goal-Practice a little every day'),
      );
      await _tapVisible(tester, review);
      final goalTitle = tester.widget<TextFormField>(
        find.byKey(const Key('goal-title')),
      );
      expect(goalTitle.controller!.text, 'Practice a little every day');
      expect(tester.widget<Slider>(find.byType(Slider)).value, 75);
      expect(find.text('Practice').last, findsOneWidget);
      expect(progress.data.goals, isEmpty);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(storage.writes, 0);

      await _tapVisible(tester, review);
      await tester.enterText(
        find.byKey(const Key('goal-title')),
        'My reviewed practice goal',
      );
      await tester.tap(find.byKey(const Key('goal-save')));
      await tester.pumpAndSettle();
      expect(progress.data.goals, hasLength(1));
      final saved = storage.saved.goals.single;
      expect(saved.title, 'My reviewed practice goal');
      expect(saved.metric, MetricKind.practice);
      expect(saved.target, 75);
      expect(saved.track, ProgressTrack.academic);
      expect(
        saved.deadline,
        DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 7)),
      );
      expect(saved.completed, isFalse);
      expect(storage.writes, 1);
      expect(find.text('Added to Goals'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'coach failure remains retryable and demo responses are identified honestly',
    (tester) async {
      final repository = _FakeCoachRepository()
        ..failure = const CoachException('timeout', 'Controlled retry needed.')
        ..status = const CoachHealth(configured: true, mode: 'demo');
      final (_, coach, storage) = await _mount(tester, repository);
      await _tapVisible(tester, find.text('Build a 7-day plan'));
      expect(find.text('Controlled retry needed.'), findsOneWidget);
      expect(coach.turns, isEmpty);
      expect(storage.writes, 0);
      repository.failure = null;
      repository.response = _reply(source: 'demo');
      await _tapVisible(tester, find.byKey(const Key('coach-retry')));
      expect(repository.questions, hasLength(2));
      expect(repository.questions[0], repository.questions[1]);
      expect(coach.turns, hasLength(2));
      expect(coach.error, isNull);
      expect(
        find.textContaining('it is not an OpenAI response.'),
        findsOneWidget,
      );
      expect(find.text('Connected · demo mode'), findsOneWidget);
      expect(storage.writes, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'notes opt-in and track changes reset conversation and ignore old pending replies',
    (tester) async {
      final repository = _FakeCoachRepository();
      final (_, coach, _) = await _mount(tester, repository);
      await _ask(tester, 'Explain my academic progress');
      expect(coach.turns, hasLength(2));
      await _tapVisible(tester, find.byKey(const Key('coach-share-notes')));
      expect(coach.turns, isEmpty);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('coach-share-notes')),
            )
            .value,
        isTrue,
      );
      await _ask(tester, 'Consider my notes too');
      expect(repository.contexts.last.includesNotes, isTrue);
      expect(
        jsonEncode(repository.contexts.last.toJson()),
        isNot(contains('Private academic reflection')),
      );
      expect(repository.conversations.last, isEmpty);
      await tester.enterText(
        find.byKey(const Key('coach-question')),
        'Private academic draft',
      );

      await _tapVisible(tester, find.byKey(const ValueKey('track-career')));
      expect(coach.turns, isEmpty);
      expect(coach.latestReply, isNull);
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const Key('coach-share-notes')),
            )
            .value,
        isFalse,
      );
      expect(
        tester
            .widget<TextFormField>(find.byKey(const Key('coach-question')))
            .controller!
            .text,
        isEmpty,
      );
      repository.pending = Completer<CoachReply>();
      final field = find.byKey(const Key('coach-question'));
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Explain my career progress');
      await tester.ensureVisible(find.byKey(const Key('coach-send')));
      await tester.tap(find.byKey(const Key('coach-send')));
      await tester.pump();
      expect(coach.busy, isTrue);
      expect(repository.contexts.last.track, ProgressTrack.career);
      await tester.tap(find.byKey(const ValueKey('track-academic')));
      await tester.pump();
      expect(coach.busy, isFalse);
      repository.pending!.complete(_reply());
      await tester.pumpAndSettle();
      expect(coach.turns, isEmpty);
      expect(coach.latestReply, isNull);
      expect(find.text('What would help you move forward?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'connection form rejects insecure URLs and an OpenAI key in the app',
    (tester) async {
      final repository = _FakeCoachRepository();
      await _mount(tester, repository);
      await _tapVisible(tester, find.byKey(const Key('coach-connection')));
      await tester.enterText(
        find.byKey(const Key('coach-url')),
        'http://untrusted.example',
      );
      await tester.tap(find.byKey(const Key('coach-connect-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('Use HTTPS, or HTTP for a local development service.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('coach-connect-save')), findsOneWidget);
      await tester.enterText(
        find.byKey(const Key('coach-url')),
        'https://coach.example',
      );
      await tester.enterText(
        find.byKey(const Key('coach-access-token')),
        'sk-test-not-a-real-key',
      );
      await tester.tap(find.byKey(const Key('coach-connect-save')));
      await tester.pumpAndSettle();
      expect(
        find.text('Keep your OpenAI API key on the backend only.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('coach-connect-save')), findsOneWidget);
      expect(repository.questions, isEmpty);
      await tester.tap(find.text('Cancel').last);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'AI Coach works within a 390px viewport without hiding the send action',
    (tester) async {
      final repository = _FakeCoachRepository();
      final (_, coach, storage) = await _mount(
        tester,
        repository,
        size: const Size(390, 844),
      );
      expect(find.byTooltip('Open navigation'), findsOneWidget);
      expect(find.text('Meet your progress coach.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await _ask(tester, 'Give me one practical next step');
      expect(coach.turns, hasLength(2));
      expect(repository.questions.single, 'Give me one practical next step');
      expect(storage.writes, 0);
      expect(find.byKey(const Key('coach-send')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('note sharing stays explicit after returning to the coach', (
    tester,
  ) async {
    final repository = _FakeCoachRepository();
    await _mount(tester, repository);
    await _tapVisible(tester, find.byKey(const Key('coach-share-notes')));
    await _ask(tester, 'Reflect on my notes');
    await _tapVisible(tester, find.text('Goals').first);
    await _tapVisible(tester, find.text('AI Coach').first);
    expect(
      tester
          .widget<CheckboxListTile>(find.byKey(const Key('coach-share-notes')))
          .value,
      isTrue,
    );
    await _tapVisible(tester, find.byKey(const Key('coach-share-notes')));
    await _ask(tester, 'Use scores only');
    expect(repository.contexts.last.includesNotes, isFalse);
    expect(repository.conversations.last, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'replacing or deleting workspace data clears coaching snapshots',
    (tester) async {
      final repository = _FakeCoachRepository();
      final (progress, coach, _) = await _mount(tester, repository);
      await _ask(tester, 'Explain my progress');
      expect(coach.turns, isNotEmpty);
      await progress.clearDemo();
      await tester.pumpAndSettle();
      expect(coach.turns, isEmpty);
      expect(coach.lastContext, isNull);
      await progress.restore(_workspaceData());
      await tester.pumpAndSettle();
      await _ask(tester, 'Explain the restored workspace');
      await progress.deleteEntry(progress.history.first.id);
      await tester.pumpAndSettle();
      expect(coach.turns, isEmpty);
      expect(coach.lastContext, isNull);
      expect(tester.takeException(), isNull);
    },
  );
}
