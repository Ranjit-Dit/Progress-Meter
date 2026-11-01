import 'dart:convert';

import '../../assessment/domain/ai_judgment.dart';
import '../../progress/domain/progress_types.dart';
import '../domain/ai_provider.dart';
import 'ai_provider_client.dart';
import 'personal_ai_instructions.dart';
import 'personal_ai_validation.dart';

class _Review {
  const _Review(this.fingerprint, this.expires, this.result);
  final String fingerprint;
  final DateTime expires;
  final Future<AiProgressJudgment> result;
}

class PersonalJudgmentRepository implements AiJudgmentRepository {
  PersonalJudgmentRepository({
    required this.config,
    AiProviderClient? client,
    DateTime Function()? now,
  }) : _client = client ?? AiProviderClient(config: config),
       _now = now ?? DateTime.now;
  final AiProviderConfig config;
  final AiProviderClient _client;
  final DateTime Function() _now;
  final _reviews = <String, _Review>{};
  bool _closed = false;

  Map<MetricKind, bool> _eligibility(
    AiEvidenceSnapshot evidence,
    DateTime now,
  ) {
    final dates = <String>{};
    final groups = <String, Set<String>>{};
    for (final a in evidence.assessments) {
      final completed = DateTime.parse(a['completedAt'] as String);
      final day = (a['completedAt'] as String).substring(0, 10);
      if (!completed.isAfter(now) &&
          !completed.isBefore(now.subtract(const Duration(days: 14)))) {
        dates.add(day);
      }
      final topic = (a['topic'] as String).trim().toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );
      (groups['$topic|${a['level']}|${a['questionCount']}'] ??= {}).add(day);
    }
    return {
      MetricKind.consistency: dates.length >= 3,
      MetricKind.impact: groups.values.any((d) => d.length >= 2),
    };
  }

  @override
  Future<AiProgressJudgment> review(
    AiEvidenceSnapshot evidence, {
    required String requestId,
  }) async {
    if (_closed) {
      throw const AiJudgmentException('The personal AI connection is closed.');
    }
    if (!personalRequestId(requestId) ||
        evidence.assessments.isEmpty ||
        evidence.assessments.length > 12) {
      throw const AiJudgmentException(
        'Complete a Testing Lab assessment before requesting a progress judgment.',
      );
    }
    final now = _now();
    _reviews.removeWhere((_, v) => !v.expires.isAfter(now));
    final fingerprint = evidence.evidenceKey;
    final old = _reviews[requestId];
    if (old != null) {
      if (old.fingerprint != fingerprint) {
        throw const AiJudgmentException(
          'Start a new review for changed assessment evidence.',
        );
      }
      return old.result;
    }
    if (_reviews.length >= 100) {
      throw const AiJudgmentException('Progress reviews are busy. Try later.');
    }
    final future = _review(evidence, now);
    final cached = _Review(
      fingerprint,
      now.add(const Duration(minutes: 30)),
      future,
    );
    _reviews[requestId] = cached;
    try {
      return await future;
    } catch (_) {
      if (identical(_reviews[requestId], cached)) _reviews.remove(requestId);
      rethrow;
    }
  }

  Future<AiProgressJudgment> _review(
    AiEvidenceSnapshot evidence,
    DateTime now,
  ) async {
    try {
      final eligible = _eligibility(evidence, now);
      final response = await _client.generate(
        instructions: personalJudgmentInstructions,
        messages: [
          AiMessage(
            'user',
            jsonEncode({
              'track': evidence.track.name,
              'reviewedAt': now.toIso8601String(),
              'eligibility': {
                for (final e in eligible.entries) e.key.name: e.value,
              },
              'assessments': evidence.assessments,
            }),
          ),
        ],
        schema: _schema,
        schemaName: 'progress_judgment',
        maxOutputTokens: 4096,
      );
      if (_closed) {
        throw const AiJudgmentException(
          'The personal AI connection is closed.',
        );
      }
      final rows = response.data['metrics'];
      if (rows is! List || rows.length != 4) {
        throw const FormatException('Four judgments required.');
      }
      final metrics = <AiMetricJudgment>[];
      for (final value in rows) {
        final row = personalMap(value);
        final metric = MetricKind.values.byName(row['metric'] as String);
        final gated = eligible[metric] == false;
        metrics.add(
          AiMetricJudgment.fromJson({
            ...row,
            if (gated) 'score': null,
            if (gated)
              'feedback': metric == MetricKind.consistency
                  ? 'Not assessed. Supply assessments on at least three distinct dates within fourteen days.'
                  : 'Not assessed. Supply comparable assessments of the same topic, level, and question count on different dates.',
          }),
        );
      }
      final result = AiProgressJudgment(
        id: 'personal-review-${personalRandomId()}',
        track: evidence.track,
        evidenceKey: evidence.evidenceKey,
        reviewedAt: now,
        model: config.auditModel,
        source: 'ai',
        summary: personalText(response.data['summary'], 2400),
        metrics: metrics,
      );
      if (!evidence.accepts(result)) {
        throw const FormatException('Unsupported assessment citations.');
      }
      return result;
    } on AiJudgmentException {
      rethrow;
    } on AiProviderException catch (error) {
      throw AiJudgmentException(error.message);
    } catch (_) {
      throw const AiJudgmentException(
        'The model returned judgments that could not be validated against your evidence. Retry or select another model.',
      );
    }
  }

  static final _schema = personalObjectSchema({
    'summary': personalStringSchema(2400),
    'metrics': {
      'type': 'array',
      'minItems': 4,
      'maxItems': 4,
      'items': personalObjectSchema({
        'metric': {
          'type': 'string',
          'enum': MetricKind.values.map((m) => m.name).toList(),
        },
        'score': {
          'type': ['number', 'null'],
          'minimum': 0,
          'maximum': 100,
        },
        'feedback': personalStringSchema(1200),
        'evidenceIds': {
          'type': 'array',
          'maxItems': 12,
          'items': personalStringSchema(100),
        },
      }),
    },
  });
  @override
  void close() {
    _closed = true;
    _reviews.clear();
    _client.close();
  }
}
