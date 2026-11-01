import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/features/ai_connection/data/ai_provider_client.dart';
import 'package:progress_meter/features/ai_connection/data/personal_coach_repository.dart';
import 'package:progress_meter/features/ai_connection/data/personal_lab_repository.dart';
import 'package:progress_meter/features/ai_connection/data/personal_judgment_repository.dart';
import 'package:progress_meter/features/ai_connection/data/personal_benchmark_repository.dart';
import 'package:progress_meter/features/ai_connection/domain/ai_provider.dart';
import 'package:progress_meter/features/ai_coach/domain/coach_models.dart';
import 'package:progress_meter/features/assessment/domain/ai_judgment.dart';
import 'package:progress_meter/features/benchmark_research/domain/benchmark_analytics.dart';
import 'package:progress_meter/features/benchmark_research/domain/benchmark_models.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_models.dart';

import 'support/benchmark_fixture.dart';

final _config = AiProviderConfig(
  provider: AiProvider.deepseek,
  model: 'test-model',
  apiKey: 'synthetic-secret',
);

class _Client extends AiProviderClient {
  _Client(this.reply) : super(config: _config);
  final Map<String, dynamic> Function(String, List<AiMessage>) reply;
  final calls = <String>[];
  @override
  Future<AiJsonResponse> generate({
    required String instructions,
    required List<AiMessage> messages,
    required Map<String, dynamic> schema,
    required String schemaName,
    int maxOutputTokens = 4000,
    bool webSearch = false,
  }) async {
    calls.add(schemaName);
    expect(instructions, isNotEmpty);
    expect(schema['type'], 'object');
    return AiJsonResponse(
      data: reply(schemaName, messages),
      model: _config.auditModel,
    );
  }
}

Map<String, dynamic> _question(int i) => {
  'prompt': 'Explain concept number $i.',
  'referenceAnswer': 'Reference for $i.',
  'rubric': {
    'correctness': 'Correct facts.',
    'reasoning': 'Justified steps.',
    'precision': 'Exact wording.',
  },
};
Map<String, dynamic> _grades(Iterable<String> ids) => {
  'feedback': 'Give more justification.',
  'nextSteps': ['Practice edge cases.'],
  'grades': [
    for (final id in ids)
      {
        'questionId': id,
        'correctness': 5,
        'reasoning': 3,
        'precision': 2,
        'feedback': 'All requested steps present.',
        'missingConcepts': <String>[],
      },
  ],
};
Map<String, dynamic> _judgment(String id) => {
  'summary': 'Evidence supports these ratings.',
  'metrics': [
    for (final m in MetricKind.values)
      {
        'metric': m.name,
        'score': 90,
        'feedback': 'Assessment supports this judgment.',
        'evidenceIds': [id],
      },
  ],
};

void main() {
  test('twenty-question personal tests batch and grade every question exactly once', () async {
    var generated = 0;
    final client = _Client((name, messages) {
      if (name == 'lab_questions') {
        return {'questions': List.generate(4, (_) => _question(++generated))};
      }
      final text = messages.last.text;
      final input = jsonDecode(text.substring(text.indexOf('\n') + 1)) as Map;
      return _grades(
        (input['questions'] as List).map((q) => q['id'] as String),
      );
    });
    final repo = PersonalLabRepository(config: _config, client: client);
    addTearDown(repo.close);
    final session = await repo.generate(
      requestId: 'twenty-test',
      topic: 'Algebra',
      learningNotes: '',
      track: ProgressTrack.academic,
      level: LabLevel.beginner,
      questionCount: 20,
    );
    expect(session.questions.last.id, 'q20');
    expect(client.calls, hasLength(5));
    final answers = {
      for (final q in session.questions) q.id: 'A complete answer.',
    };
    final result = await repo.grade(session, answers);
    expect(result.questionCount, 20);
    expect(result.totalScore, 100);
    expect(client.calls, hasLength(10));
    expect(identical(await repo.grade(session, answers), result), isTrue);
    expect(client.calls, hasLength(10));
  });

  test('coach personal provider produces validated AI output without automatic requests', () async {
    final client = _Client(
      (_, _) => {'reply': 'Practice a small example.', 'suggestions': []},
    );
    final repo = PersonalCoachRepository(config: _config, client: client);
    addTearDown(repo.close);
    expect((await repo.health()).configured, isTrue);
    expect(client.calls, isEmpty);
    final reply = await repo.ask(
      question: 'What next?',
      context: CoachContext.fromProgressData(
        ProgressData(),
        ProgressTrack.academic,
      ),
    );
    expect(reply.source, 'ai');
    expect(reply.model, 'deepseek/test-model');
    expect(reply.isDemo, isFalse);
  });

  test('personal Lab validates sessions, grades exact answers and replays without extra calls', () async {
    var generated = 0;
    final client = _Client((name, messages) {
      if (name == 'lab_questions') {
        return {'questions': List.generate(4, (_) => _question(++generated))};
      }
      return _grades(['q1', 'q2', 'q3', 'q4']);
    });
    final repo = PersonalLabRepository(config: _config, client: client);
    addTearDown(repo.close);
    final session = await repo.generate(
      requestId: 'test-one',
      topic: 'Algebra',
      learningNotes: '',
      track: ProgressTrack.academic,
      level: LabLevel.beginner,
    );
    expect(session.source, 'ai');
    expect(session.questionCount, 4);
    final same = await repo.generate(
      requestId: 'test-one',
      topic: 'Algebra',
      learningNotes: '',
      track: ProgressTrack.academic,
      level: LabLevel.beginner,
    );
    expect(identical(same, session), isTrue);
    await expectLater(
      repo.grade(session, {'q1': 'missing others'}),
      throwsA(isA<LabException>()),
    );
    expect(client.calls, hasLength(1));
    final answers = {
      for (final q in session.questions)
        q.id: q.id == 'q1' ? '' : 'A justified answer.',
    };
    final result = await repo.grade(session, answers);
    expect(result.questions.first.earnedPoints, 0);
    expect(result.totalScore, 75);
    expect(result.source, 'ai');
    expect(LabResult.fromJson(result.toJson()).source, 'ai');
    expect(identical(await repo.grade(session, answers), result), isTrue);
    expect(client.calls, hasLength(2));
    await expectLater(
      repo.grade(session, {...answers, 'q1': 'Changed'}),
      throwsA(isA<LabException>()),
    );
    expect(jsonEncode(result.toJson()), isNot(contains(_config.apiKey)));
    expect(jsonEncode(result.toJson()), isNot(contains(session.sessionToken)));
  });

  test('personal Lab rejects foreign grades and expired sessions', () async {
    var now = DateTime(2026, 11, 1, 12);
    final client = _Client(
      (name, _) => name == 'lab_questions'
          ? {
              'questions': [
                _question(1),
                _question(2),
                _question(3),
                _question(4),
              ],
            }
          : _grades(['q1', 'q2', 'q3', 'q99']),
    );
    final repo = PersonalLabRepository(
      config: _config,
      client: client,
      now: () => now,
    );
    addTearDown(repo.close);
    final session = await repo.generate(
      requestId: 'test-two',
      topic: 'Algebra',
      learningNotes: '',
      track: ProgressTrack.academic,
      level: LabLevel.beginner,
    );
    final answers = {for (final q in session.questions) q.id: 'Answer'};
    await expectLater(
      repo.grade(session, answers),
      throwsA(isA<LabException>()),
    );
    now = now.add(const Duration(hours: 3));
    await expectLater(
      repo.grade(session, answers),
      throwsA(isA<LabException>()),
    );
    expect(client.calls, hasLength(2));
  });

  test(
    'personal judgments enforce evidence gates, provenance and replay',
    () async {
      final now = DateTime(2026, 11, 1, 12);
      final lab = benchmarkLab(
        id: 'evidence-one',
        date: now.subtract(const Duration(days: 1)),
      );
      final snapshot = AiEvidenceSnapshot.fromResults(
        [lab],
        ProgressTrack.academic,
        now: now,
      );
      final client = _Client((_, _) => _judgment(lab.id));
      final repo = PersonalJudgmentRepository(
        config: _config,
        client: client,
        now: () => now,
      );
      addTearDown(repo.close);
      final result = await repo.review(snapshot, requestId: 'review-one');
      expect(result.metric(MetricKind.knowledge).score, 90);
      expect(result.metric(MetricKind.consistency).score, isNull);
      expect(result.metric(MetricKind.impact).score, isNull);
      expect(snapshot.accepts(result), isTrue);
      expect(AiProgressJudgment.fromJson(result.toJson()).source, 'ai');
      expect(
        identical(await repo.review(snapshot, requestId: 'review-one'), result),
        isTrue,
      );
      expect(client.calls, hasLength(1));
      final backup = ProgressData(
        labResults: [lab],
        aiJudgments: [result],
      ).toJson();
      expect(jsonEncode(backup), isNot(contains(_config.apiKey)));
      expect(ProgressData.fromJson(backup).aiJudgments.single.source, 'ai');
    },
  );

  test('personal judgments reject fabricated citations', () async {
    final snapshot = AiEvidenceSnapshot.fromResults([
      benchmarkLab(),
    ], ProgressTrack.academic);
    final client = _Client((_, _) => _judgment('invented-assessment'));
    final repo = PersonalJudgmentRepository(config: _config, client: client);
    addTearDown(repo.close);
    await expectLater(
      repo.review(snapshot, requestId: 'review-bad'),
      throwsA(isA<AiJudgmentException>()),
    );
  });

  test('pasted post research is explicitly unverified and works with compatible providers', () async {
    final raw = benchmarkJson();
    for (final row in raw['evidence'] as List) {
      row['sourceIds'] = ['s0'];
    }
    for (final row in raw['milestones'] as List) {
      row['sourceIds'] = ['s0'];
    }
    final client = _Client(
      (name, _) => name == 'personal_path_review'
          ? {
              'summary': 'More evidence is needed.',
              'blockers': ['No assessed work.'],
              'nextActions': ['Take the first assessment.'],
            }
          : raw,
    );
    final repo = PersonalBenchmarkResearchRepository(
      config: _config,
      client: client,
    );
    addTearDown(repo.close);
    await expectLater(
      () => repo.research(
        requestId: 'person-one',
        kind: BenchmarkKind.person,
        query: 'A person',
        context: '',
        postText: '',
        track: ProgressTrack.academic,
      ),
      throwsA(isA<BenchmarkException>()),
    );
    final plan = await repo.research(
      requestId: 'post-one',
      kind: BenchmarkKind.post,
      query: 'Role requirements',
      context: '',
      postText: 'The role asks for programming and testing.',
      track: ProgressTrack.academic,
    );
    expect(plan.source, 'ai');
    expect(plan.sources.single.url, isNull);
    expect(plan.warnings.join(' '), contains('no web search'));
    final snapshot = BenchmarkAnalytics.evaluate(plan, [], []);
    final review = await repo.review(snapshot, requestId: 'path-review');
    expect(review.progressPercent, 0);
    expect(ResearchPlan.fromJson(plan.toJson()).source, 'ai');
  });
}
