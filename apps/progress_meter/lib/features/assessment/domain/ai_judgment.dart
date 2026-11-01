import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../../progress/domain/progress_types.dart';
import '../../testing_lab/domain/lab_models.dart';

String aiMetricLabel(MetricKind metric) => switch (metric) {
  MetricKind.knowledge => 'Understanding',
  MetricKind.practice => 'Practice',
  MetricKind.consistency => 'Consistency',
  MetricKind.impact => 'Outcomes',
};
String _text(Object? value, int maximum) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.runes.length > maximum) {
    throw const FormatException('Invalid AI judgment text.');
  }
  return value.trim();
}

String _bounded(String value, int length) =>
    String.fromCharCodes(value.runes.take(length));

class AiMetricJudgment {
  AiMetricJudgment({
    required this.metric,
    required this.score,
    required this.feedback,
    List<String> evidenceIds = const [],
  }) : evidenceIds = List.unmodifiable(evidenceIds) {
    _text(feedback, 1200);
    if (score != null && (!score!.isFinite || score! < 0 || score! > 100)) {
      throw const FormatException('Invalid AI metric score.');
    }
    if (evidenceIds.length > 12 ||
        evidenceIds.toSet().length != evidenceIds.length ||
        (score != null && evidenceIds.isEmpty)) {
      throw const FormatException('An AI score needs assessment evidence.');
    }
    for (final id in evidenceIds) {
      _text(id, 100);
    }
  }
  final MetricKind metric;
  final double? score;
  final String feedback;
  final List<String> evidenceIds;
  Map<String, dynamic> toJson() => {
    'metric': metric.name,
    'score': score,
    'feedback': feedback,
    'evidenceIds': evidenceIds,
  };
  factory AiMetricJudgment.fromJson(Map<String, dynamic> json) =>
      AiMetricJudgment(
        metric: MetricKind.values.byName(json['metric'] as String),
        score: json['score'] == null ? null : (json['score'] as num).toDouble(),
        feedback: _text(json['feedback'], 1200),
        evidenceIds: (json['evidenceIds'] as List)
            .map((id) => _text(id, 100))
            .toList(),
      );
}

class AiProgressJudgment {
  AiProgressJudgment({
    required this.id,
    required this.track,
    required this.evidenceKey,
    required this.reviewedAt,
    required this.model,
    required this.summary,
    this.source = 'openai',
    required List<AiMetricJudgment> metrics,
  }) : metrics = List.unmodifiable(metrics) {
    _text(id, 100);
    _text(model, 120);
    _text(summary, 2400);
    if (!['openai', 'ai'].contains(source) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(evidenceKey) ||
        metrics.length != 4 ||
        metrics.map((m) => m.metric).toSet().length != 4) {
      throw const FormatException('Invalid AI progress judgment.');
    }
  }
  final String id, evidenceKey, model, summary, source;
  final ProgressTrack track;
  final DateTime reviewedAt;
  final List<AiMetricJudgment> metrics;
  AiMetricJudgment metric(MetricKind kind) =>
      metrics.firstWhere((m) => m.metric == kind);
  Map<String, dynamic> toJson() => {
    'id': id,
    'track': track.name,
    'evidenceKey': evidenceKey,
    'reviewedAt': reviewedAt.toIso8601String(),
    'source': source,
    'model': model,
    'summary': summary,
    'metrics': metrics.map((m) => m.toJson()).toList(),
  };
  factory AiProgressJudgment.fromJson(Map<String, dynamic> json) {
    if (!['openai', 'ai'].contains(json['source'])) {
      throw const FormatException('Only AI judgments are supported.');
    }
    return AiProgressJudgment(
      id: _text(json['id'], 100),
      track: ProgressTrack.values.byName(json['track'] as String),
      evidenceKey: _text(json['evidenceKey'], 128),
      reviewedAt: DateTime.parse(_text(json['reviewedAt'], 40)),
      model: _text(json['model'], 120),
      summary: _text(json['summary'], 2400),
      source: json['source'] as String,
      metrics: (json['metrics'] as List)
          .map(
            (m) =>
                AiMetricJudgment.fromJson(Map<String, dynamic>.from(m as Map)),
          )
          .toList(),
    );
  }
}

String _localTimestamp(DateTime value) {
  final local = value.toLocal();
  final offset = local.timeZoneOffset;
  final minutes = offset.inMinutes.abs();
  return '${local.toIso8601String()}${offset.isNegative ? '-' : '+'}${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
}

class AiEvidenceSnapshot {
  AiEvidenceSnapshot({
    required this.track,
    required List<Map<String, dynamic>> assessments,
  }) : assessments = List.unmodifiable(
         assessments.map((a) => Map<String, dynamic>.unmodifiable(a)),
       );
  final ProgressTrack track;
  final List<Map<String, dynamic>> assessments;
  String get evidenceKey => sha256
      .convert(
        utf8.encode(
          jsonEncode({'track': track.name, 'assessments': assessments}),
        ),
      )
      .toString();
  factory AiEvidenceSnapshot.fromResults(
    Iterable<LabResult> results,
    ProgressTrack track, {
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    final eligible =
        results
            .where((r) => r.track == track && !r.completedAt.isAfter(instant))
            .toList()
          ..sort((a, b) {
            final date = b.completedAt.compareTo(a.completedAt);
            return date == 0 ? b.id.compareTo(a.id) : date;
          });
    return AiEvidenceSnapshot(
      track: track,
      assessments: [
        for (final r in eligible.take(12))
          {
            'id': r.id,
            'topic': r.topic,
            'level': r.level.name,
            'questionCount': r.questionCount,
            'completedAt': _localTimestamp(r.completedAt),
            'totalScore': r.totalScore,
            'understandingScore': r.understandingScore,
            'applicationScore': r.applicationScore,
            'feedback': _bounded(r.feedback, 1200),
            'missingConcepts': r.questions
                .expand((q) => q.missingConcepts)
                .toSet()
                .take(8)
                .map((s) => _bounded(s, 200))
                .toList(),
          },
      ],
    );
  }
  Map<String, dynamic> toJson(String requestId) => {
    'requestId': requestId,
    'track': track.name,
    'evidenceKey': evidenceKey,
    'assessments': assessments,
  };
  bool accepts(AiProgressJudgment judgment) {
    if (judgment.track != track || judgment.evidenceKey != evidenceKey) {
      return false;
    }
    for (final metric in judgment.metrics) {
      final cited = <Map<String, dynamic>>[];
      for (final id in metric.evidenceIds) {
        final assessment = assessments.where((a) => a['id'] == id).firstOrNull;
        if (assessment == null) return false;
        cited.add(assessment);
      }
      if (metric.score == null) continue;
      if (metric.metric == MetricKind.consistency) {
        final recent = cited.where((a) {
          final date = DateTime.parse(a['completedAt'] as String);
          return !date.isAfter(judgment.reviewedAt) &&
              !date.isBefore(
                judgment.reviewedAt.subtract(const Duration(days: 14)),
              );
        });
        if (recent
                .map((a) => (a['completedAt'] as String).substring(0, 10))
                .toSet()
                .length <
            3) {
          return false;
        }
      }
      if (metric.metric == MetricKind.impact) {
        final groups = <String, Set<String>>{};
        for (final a in cited) {
          final topic = (a['topic'] as String).trim().toLowerCase().replaceAll(
            RegExp(r'\s+'),
            ' ',
          );
          final key = '$topic|${a['level']}|${a['questionCount']}';
          (groups[key] ??= {}).add(
            (a['completedAt'] as String).substring(0, 10),
          );
        }
        if (!groups.values.any((dates) => dates.length >= 2)) return false;
      }
    }
    return true;
  }
}

abstract final class AiJudgmentAnalytics {
  static AiProgressJudgment? current(
    Iterable<AiProgressJudgment> judgments,
    Iterable<LabResult> results,
    ProgressTrack track, {
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    final evidence = AiEvidenceSnapshot.fromResults(
      results,
      track,
      now: instant,
    );
    final matching =
        judgments
            .where((j) => !j.reviewedAt.isAfter(instant) && evidence.accepts(j))
            .toList()
          ..sort((a, b) => b.reviewedAt.compareTo(a.reviewedAt));
    return matching.firstOrNull;
  }
}

class AiJudgmentException implements Exception {
  const AiJudgmentException(this.message);
  final String message;
  @override
  String toString() => message;
}

abstract interface class AiJudgmentRepository {
  Future<AiProgressJudgment> review(
    AiEvidenceSnapshot snapshot, {
    required String requestId,
  });
  void close();
}
