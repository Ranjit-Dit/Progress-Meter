import 'dart:convert';

import '../../testing_lab/domain/lab_models.dart';
import 'benchmark_models.dart';

String benchmarkTopicKey(String s) =>
    s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

class MilestoneProgress {
  const MilestoneProgress(
    this.milestone,
    this.assessment,
    this.projectEvidence,
    this.fraction,
  );
  final RoadmapMilestone milestone;
  final LabResult? assessment;
  final RoadmapProjectEvidence? projectEvidence;
  final double fraction;
  bool get complete => fraction >= 1;
  double? get score => assessment?.totalScore;
}

class BenchmarkProgressSnapshot {
  BenchmarkProgressSnapshot(this.plan, List<MilestoneProgress> items)
    : milestones = List.unmodifiable(items);
  final ResearchPlan plan;
  final List<MilestoneProgress> milestones;
  double get progressPercent => milestones.isEmpty
      ? 0
      : milestones.fold<double>(0, (n, m) => n + m.fraction) *
            100 /
            milestones.length;
  int get completeCount => milestones.where((m) => m.complete).length;
  int get assessmentCount =>
      milestones.where((m) => m.assessment != null).length;
  int get projectCount =>
      milestones.where((m) => m.projectEvidence?.completed == true).length;
  Map<String, dynamic> toReviewJson({required String requestId}) => {
    'requestId': requestId,
    'plan': plan.toJson(),
    'assessments': [
      for (final m in milestones)
        if (m.assessment != null)
          {
            'milestoneId': m.milestone.id,
            'score': m.assessment!.totalScore,
            'resultId': m.assessment!.id,
            'completedAt': m.assessment!.completedAt.toIso8601String(),
          },
    ],
    'projectEvidence': [
      for (final m in milestones)
        if (m.projectEvidence != null)
          {
            'milestoneId': m.milestone.id,
            'completed': m.projectEvidence!.completed,
            'notes': m.projectEvidence!.notes,
            'url': m.projectEvidence!.url,
          },
    ],
  };
  String get evidenceKey => jsonEncode(toReviewJson(requestId: ''));
}

abstract final class BenchmarkAnalytics {
  static BenchmarkProgressSnapshot evaluate(
    ResearchPlan plan,
    Iterable<LabResult> results,
    Iterable<RoadmapProjectEvidence> evidence, {
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    final sorted =
        results
            .where(
              (r) => r.track == plan.track && !r.completedAt.isAfter(instant),
            )
            .toList()
          ..sort((a, b) {
            final d = b.completedAt.compareTo(a.completedAt);
            return d == 0 ? b.id.compareTo(a.id) : d;
          });
    return BenchmarkProgressSnapshot(plan, [
      for (final m in plan.milestones) _item(m, plan, sorted, evidence),
    ]);
  }

  static MilestoneProgress _item(
    RoadmapMilestone m,
    ResearchPlan p,
    List<LabResult> results,
    Iterable<RoadmapProjectEvidence> evidence,
  ) {
    if (m.kind == RoadmapMilestoneKind.assessment) {
      final result = results
          .where(
            (r) =>
                r.level == m.level &&
                benchmarkTopicKey(r.topic) == benchmarkTopicKey(m.topic),
          )
          .firstOrNull;
      return MilestoneProgress(
        m,
        result,
        null,
        result == null
            ? 0
            : (result.totalScore / m.targetScore!).clamp(0.0, 1.0),
      );
    }
    final e = evidence
        .where((e) => e.planId == p.id && e.milestoneId == m.id)
        .firstOrNull;
    return MilestoneProgress(m, null, e, e?.completed == true ? 1 : 0);
  }
}
