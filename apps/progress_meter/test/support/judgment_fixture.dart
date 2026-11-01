import 'package:progress_meter/features/assessment/domain/ai_judgment.dart';
import 'package:progress_meter/features/progress/domain/progress_types.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_models.dart';

AiProgressJudgment judgmentFor(
  List<LabResult> results, {
  String id = 'judgment-one',
  double knowledge = 90,
  bool complete = false,
  String summary = 'AI assessed evidence summary.',
}) {
  final track = results.first.track;
  return AiProgressJudgment(
    id: id,
    track: track,
    evidenceKey: AiEvidenceSnapshot.fromResults(results, track).evidenceKey,
    reviewedAt: DateTime.now().subtract(const Duration(seconds: 1)),
    model: 'test-model',
    summary: summary,
    metrics: [
      for (final m in MetricKind.values)
        AiMetricJudgment(
          metric: m,
          score: m == MetricKind.knowledge
              ? knowledge
              : m == MetricKind.practice
              ? 70
              : complete
              ? 65
              : null,
          feedback:
              'Specific AI feedback based on the saved assessed evidence.',
          evidenceIds: results.map((r) => r.id).toList(),
        ),
    ],
  );
}
