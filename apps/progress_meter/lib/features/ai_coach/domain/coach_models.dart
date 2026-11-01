import 'dart:convert';

import '../../progress/domain/models.dart';
import '../../assessment/domain/ai_judgment.dart';

String _text(Object? value, String field, int maximum) {
  if (value is! String ||
      value.trim().isEmpty ||
      value.runes.length > maximum) {
    throw FormatException('Invalid $field in coach response.');
  }
  return value.trim();
}

class CoachSuggestion {
  CoachSuggestion({
    required String title,
    required this.metric,
    required this.target,
    required this.days,
  }) : title = _text(title, 'goal title', 100) {
    if (!target.isFinite ||
        target < 0 ||
        target > 100 ||
        days < 1 ||
        days > 365) {
      throw const FormatException('Invalid suggested goal target or deadline.');
    }
  }

  final String title;
  final MetricKind metric;
  final double target;
  final int days;

  factory CoachSuggestion.fromJson(Map<String, dynamic> json) {
    final target = json['target'];
    final days = json['days'];
    if (target is! num || days is! int || json['metric'] is! String) {
      throw const FormatException('Invalid suggested goal.');
    }
    final metric = MetricKind.values
        .where((m) => m.name == json['metric'])
        .firstOrNull;
    if (metric == null) {
      throw const FormatException('Unknown suggested goal dimension.');
    }
    return CoachSuggestion(
      title: _text(json['title'], 'goal title', 100),
      metric: metric,
      target: target.toDouble(),
      days: days,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'metric': metric.name,
    'target': target,
    'days': days,
  };
}

class CoachReply {
  CoachReply({
    required String reply,
    List<CoachSuggestion> suggestions = const [],
    required this.source,
    this.model,
  }) : reply = _text(reply, 'reply', 12000),
       suggestions = List.unmodifiable(suggestions) {
    if (!['openai', 'ai', 'demo'].contains(source) || suggestions.length > 3) {
      throw const FormatException(
        'Invalid coach response source or suggestions.',
      );
    }
    if (model != null && (model!.trim().isEmpty || model!.length > 120)) {
      throw const FormatException('Invalid coach model identifier.');
    }
  }

  final String reply;
  final List<CoachSuggestion> suggestions;
  final String source;
  final String? model;
  bool get isDemo => source == 'demo';

  factory CoachReply.fromJson(Map<String, dynamic> json) {
    if (json['suggestions'] is! List ||
        json['source'] is! String ||
        (json['model'] != null && json['model'] is! String)) {
      throw const FormatException('Invalid coach response.');
    }
    final values = json['suggestions'] as List;
    if (values.length > 3 || values.any((value) => value is! Map)) {
      throw const FormatException('Invalid coach suggestions.');
    }
    return CoachReply(
      reply: _text(json['reply'], 'reply', 12000),
      suggestions: values
          .map(
            (value) => CoachSuggestion.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      source: json['source'] as String,
      model: json['model'] as String?,
    );
  }
}

class CoachTurn {
  CoachTurn({required this.role, required String text})
    : text = _text(text, 'message', 12000) {
    if (!['user', 'assistant'].contains(role)) {
      throw const FormatException('Invalid coach message role.');
    }
  }
  final String role;
  final String text;
  Map<String, String> toJson() => {'role': role, 'text': text};
}

class CoachHealth {
  const CoachHealth({required this.configured, required this.mode});
  final bool configured;
  final String mode;
  factory CoachHealth.fromJson(Map<String, dynamic> json) {
    if (json['status'] != 'ok' ||
        json['configured'] is! bool ||
        !['live', 'demo'].contains(json['mode'])) {
      throw const FormatException('Invalid coach service health response.');
    }
    return CoachHealth(
      configured: json['configured'] as bool,
      mode: json['mode'] as String,
    );
  }
}

class CoachException implements Exception {
  const CoachException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

/// A bounded snapshot of the currently selected track, without profile identity.
/// Notes are included only after an explicit choice in the coach screen.
class CoachContext {
  CoachContext._(this.track, this._payload, {required this.includesNotes});
  final ProgressTrack track;
  final Map<String, dynamic> _payload;
  final bool includesNotes;
  int get entryCount => (_payload['history'] as List).length;
  int get goalCount => (_payload['goals'] as List).length;
  bool get hasBenchmark => _payload['benchmark'] != null;
  bool get isSampleData => _payload['isSampleData'] as bool;

  factory CoachContext.fromProgressData(
    ProgressData data,
    ProgressTrack track, {
    bool includeNotes = false,
  }) {
    final current = AiJudgmentAnalytics.current(
      data.aiJudgments,
      data.labResults,
      track,
    );
    final recent =
        current != null && current.metrics.every((m) => m.score != null)
        ? [current]
        : <AiProgressJudgment>[];
    final active = data.goals
        .where(
          (g) =>
              g.track == track &&
              !(current?.metric(g.metric).score != null &&
                  current!.metric(g.metric).score! >= g.target),
        )
        .take(12);
    final target = data.profiles
        .where((p) => p.id == data.targetProfileId && p.track == track)
        .firstOrNull;
    Map<String, double> metrics(Map<MetricKind, double> source) => {
      for (final metric in MetricKind.values) metric.name: source[metric]!,
    };
    return CoachContext._(track, {
      'track': track.name,
      'metricLabels': {
        for (final metric in MetricKind.values)
          metric.name: aiMetricLabel(metric),
      },
      'rubric': 'AI-judged formative progress only. Never award or update scores in chat. Overview and Goals require the dedicated AI judgment from assessed Testing Lab evidence. Missing or partial judgments are not evidence of a zero score. Legacy manual check-ins are excluded. Goal target values are aspirations, not current ratings.',
      'history': [
        for (final entry in recent)
          {
            'date': entry.reviewedAt.toIso8601String(),
            'score':
                entry.metrics.fold<double>(0, (sum, m) => sum + m.score!) / 4,
            'metrics': {for (final m in entry.metrics) m.metric.name: m.score!},
            if (includeNotes)
              'note': String.fromCharCodes(entry.summary.runes.take(500)),
          },
      ],
      'goals': [
        for (final goal in active)
          {
            'title': goal.title,
            'metric': goal.metric.name,
            'target': goal.target,
            'deadline': goal.deadline.toIso8601String(),
          },
      ],
      'benchmark': target == null
          ? null
          : {
              'metrics': metrics(target.metrics),
              'score': target.score,
              'isExample': target.isExample,
            },
      'isSampleData': false,
    }, includesNotes: includeNotes);
  }

  /// Return a copy so callers cannot change the snapshot while a request runs.
  Map<String, dynamic> toJson() =>
      Map<String, dynamic>.from(jsonDecode(jsonEncode(_payload)) as Map);
}
