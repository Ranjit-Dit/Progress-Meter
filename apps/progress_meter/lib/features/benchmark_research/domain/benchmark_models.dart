import 'dart:io';

import '../../progress/domain/progress_types.dart';
import '../../testing_lab/domain/lab_models.dart' show LabLevel;

enum BenchmarkKind { person, post }

enum ResearchStatus { ready, needsContext, insufficientSources }

enum RoadmapMilestoneKind { assessment, project }

String researchStatusWire(ResearchStatus s) => switch (s) {
  ResearchStatus.ready => 'ready',
  ResearchStatus.needsContext => 'needs_context',
  ResearchStatus.insufficientSources => 'insufficient_sources',
};
String _text(Object? v, int max, {bool empty = false}) {
  if (v is! String || v.runes.length > max || (!empty && v.trim().isEmpty)) {
    throw const FormatException('Invalid benchmark text.');
  }
  return v.trim();
}

Map<String, dynamic> _map(Object? v) {
  if (v is! Map) throw const FormatException('Invalid benchmark object.');
  return Map<String, dynamic>.from(v);
}

List<T> _list<T>(Object? v, int max, T Function(Object?) read) {
  if (v is! List || v.length > max) {
    throw const FormatException('Invalid benchmark list.');
  }
  return List.unmodifiable(v.map(read));
}

T _enum<T extends Enum>(Object? v, List<T> values) => values.firstWhere(
  (x) => x.name == v,
  orElse: () => throw const FormatException('Invalid benchmark option.'),
);
DateTime _date(Object? v) {
  final s = _text(v, 40);
  final d = DateTime.tryParse(s);
  if (d == null) throw const FormatException('Invalid benchmark date.');
  return d;
}

bool _bool(Object? v) {
  if (v is! bool) throw const FormatException('Invalid completion.');
  return v;
}

Uri? publicBenchmarkUrl(String? value) {
  if (value == null || value.trim().isEmpty) return null;
  final uri = Uri.tryParse(value.trim());
  if (uri == null ||
      value.length > 2048 ||
      uri.scheme != 'https' ||
      !uri.hasAuthority ||
      uri.userInfo.isNotEmpty ||
      (uri.hasPort && uri.port != 443)) {
    throw const FormatException('Use a public HTTPS link.');
  }
  final h = uri.host.toLowerCase();
  if (!h.contains('.') ||
      h.endsWith('.') ||
      InternetAddress.tryParse(h) != null ||
      [
        'localhost',
        'local',
        'internal',
        'test',
        'invalid',
        'example',
      ].any((s) => h == s || h.endsWith('.$s')) ||
      h == 'metadata.google.internal') {
    throw const FormatException('Use a public HTTPS link.');
  }
  return uri;
}

class ResearchSource {
  ResearchSource({required this.id, required this.title, required this.url}) {
    _text(id, 16);
    _text(title, 240);
    if (url == null && id != 's0') {
      throw const FormatException('Missing source URL.');
    }
    if (url != null) publicBenchmarkUrl(url);
  }
  final String id, title;
  final String? url;
  factory ResearchSource.fromJson(Map<String, dynamic> j) => ResearchSource(
    id: _text(j['id'], 16),
    title: _text(j['title'], 240),
    url: j['url'] == null ? null : _text(j['url'], 2048),
  );
  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'url': url};
}

class BenchmarkEvidence {
  BenchmarkEvidence({required this.text, required List<String> sourceIds})
    : sourceIds = List.unmodifiable(sourceIds) {
    _text(text, 700);
    if (sourceIds.isEmpty || sourceIds.length > 12) {
      throw const FormatException('Evidence needs a source.');
    }
  }
  final String text;
  final List<String> sourceIds;
  factory BenchmarkEvidence.fromJson(Map<String, dynamic> j) =>
      BenchmarkEvidence(
        text: _text(j['text'], 700),
        sourceIds: _list(j['sourceIds'], 12, (v) => _text(v, 16)),
      );
  Map<String, dynamic> toJson() => {'text': text, 'sourceIds': sourceIds};
}

class RoadmapMilestone {
  RoadmapMilestone({
    required this.id,
    required this.title,
    required this.description,
    required this.kind,
    required this.topic,
    required this.level,
    required this.targetScore,
    required List<String> sourceIds,
  }) : sourceIds = List.unmodifiable(sourceIds) {
    _text(id, 16);
    _text(title, 120);
    _text(description, 1600);
    _text(topic, 120);
    if (sourceIds.isEmpty ||
        sourceIds.length > 12 ||
        (kind == RoadmapMilestoneKind.assessment &&
            (targetScore == null || targetScore! < 50 || targetScore! > 100)) ||
        (kind == RoadmapMilestoneKind.project && targetScore != null)) {
      throw const FormatException('Invalid roadmap milestone.');
    }
  }
  final String id, title, description, topic;
  final RoadmapMilestoneKind kind;
  final LabLevel level;
  final int? targetScore;
  final List<String> sourceIds;
  factory RoadmapMilestone.fromJson(Map<String, dynamic> j) => RoadmapMilestone(
    id: _text(j['id'], 16),
    title: _text(j['title'], 120),
    description: _text(j['description'], 1600),
    kind: _enum(j['kind'], RoadmapMilestoneKind.values),
    topic: _text(j['topic'], 120),
    level: _enum(j['level'], LabLevel.values),
    targetScore: j['targetScore'] as int?,
    sourceIds: _list(j['sourceIds'], 12, (v) => _text(v, 16)),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'description': description,
    'kind': kind.name,
    'topic': topic,
    'level': level.name,
    'targetScore': targetScore,
    'sourceIds': sourceIds,
  };
}

class ResearchPlan {
  ResearchPlan({
    required this.id,
    required this.kind,
    required this.query,
    required this.track,
    required this.researchedAt,
    required this.model,
    required this.status,
    required this.subjectName,
    required this.headline,
    required this.summary,
    required List<String> warnings,
    required List<BenchmarkEvidence> evidence,
    required List<RoadmapMilestone> milestones,
    required List<ResearchSource> sources,
    this.source = 'openai',
  }) : warnings = List.unmodifiable(warnings),
       evidence = List.unmodifiable(evidence),
       milestones = List.unmodifiable(milestones),
       sources = List.unmodifiable(sources) {
    _text(id, 100);
    _text(query, 300);
    _text(model, 120);
    _text(subjectName, 120);
    _text(headline, 240);
    _text(summary, 2400);
    if (!['openai', 'ai'].contains(source) ||
        sources.length > 12 ||
        evidence.length > 8 ||
        warnings.length > 6 ||
        warnings.any((w) => w.runes.length > 500)) {
      throw const FormatException('Invalid research plan.');
    }
    final ids = sources.map((s) => s.id).toSet();
    if (ids.length != sources.length) {
      throw const FormatException('Duplicate sources.');
    }
    if (evidence.any((e) => e.sourceIds.any((id) => !ids.contains(id))) ||
        milestones.any((m) => m.sourceIds.any((id) => !ids.contains(id)))) {
      throw const FormatException('A citation has no source.');
    }
    if (status == ResearchStatus.ready) {
      if (milestones.length != 5 ||
          sources.isEmpty ||
          evidence.isEmpty ||
          !milestones.any((m) => m.kind == RoadmapMilestoneKind.assessment) ||
          !milestones.any((m) => m.kind == RoadmapMilestoneKind.project)) {
        throw const FormatException('A path needs five sourced milestones.');
      }
      for (var i = 0; i < 5; i++) {
        if (milestones[i].id != 'm${i + 1}') {
          throw const FormatException('Invalid milestone IDs.');
        }
      }
    } else if (milestones.isNotEmpty) {
      throw const FormatException('Unresolved research cannot set a target.');
    }
  }
  final String id, query, model, subjectName, headline, summary, source;
  final BenchmarkKind kind;
  final ProgressTrack track;
  final DateTime researchedAt;
  final ResearchStatus status;
  final List<String> warnings;
  final List<BenchmarkEvidence> evidence;
  final List<RoadmapMilestone> milestones;
  final List<ResearchSource> sources;
  bool get isReady => status == ResearchStatus.ready;
  factory ResearchPlan.fromJson(Map<String, dynamic> j) => ResearchPlan(
    id: _text(j['id'], 100),
    kind: _enum(j['kind'], BenchmarkKind.values),
    query: _text(j['query'], 300),
    track: _enum(j['track'], ProgressTrack.values),
    researchedAt: _date(j['researchedAt']),
    model: _text(j['model'], 120),
    status: switch (j['status']) {
      'ready' => ResearchStatus.ready,
      'needs_context' => ResearchStatus.needsContext,
      'insufficient_sources' => ResearchStatus.insufficientSources,
      _ => throw const FormatException('Invalid research status.'),
    },
    subjectName: _text(j['subjectName'], 120),
    headline: _text(j['headline'], 240),
    summary: _text(j['summary'], 2400),
    warnings: _list(j['warnings'], 6, (v) => _text(v, 500)),
    evidence: _list(
      j['evidence'],
      8,
      (v) => BenchmarkEvidence.fromJson(_map(v)),
    ),
    milestones: _list(
      j['milestones'],
      5,
      (v) => RoadmapMilestone.fromJson(_map(v)),
    ),
    sources: _list(j['sources'], 12, (v) => ResearchSource.fromJson(_map(v))),
    source: _text(j['source'], 20),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'query': query,
    'track': track.name,
    'researchedAt': researchedAt.toIso8601String(),
    'model': model,
    'status': researchStatusWire(status),
    'subjectName': subjectName,
    'headline': headline,
    'summary': summary,
    'warnings': warnings,
    'evidence': evidence.map((v) => v.toJson()).toList(),
    'milestones': milestones.map((v) => v.toJson()).toList(),
    'sources': sources.map((v) => v.toJson()).toList(),
    'source': source,
  };
}

class RoadmapProjectEvidence {
  RoadmapProjectEvidence({
    required this.planId,
    required this.milestoneId,
    required this.completed,
    required this.notes,
    required this.url,
    required this.updatedAt,
  }) {
    _text(planId, 100);
    _text(milestoneId, 16);
    _text(notes, 1200, empty: true);
    if (completed && notes.trim().isEmpty && url == null) {
      throw const FormatException(
        'Completed projects need evidence notes or a link.',
      );
    }
    if (url != null) publicBenchmarkUrl(url);
  }
  final String planId, milestoneId, notes;
  final bool completed;
  final String? url;
  final DateTime updatedAt;
  String get key => '$planId|$milestoneId';
  factory RoadmapProjectEvidence.fromJson(Map<String, dynamic> j) =>
      RoadmapProjectEvidence(
        planId: _text(j['planId'], 100),
        milestoneId: _text(j['milestoneId'], 16),
        completed: _bool(j['completed']),
        notes: _text(j['notes'], 1200, empty: true),
        url: j['url'] == null ? null : _text(j['url'], 2048),
        updatedAt: _date(j['updatedAt']),
      );
  Map<String, dynamic> toJson() => {
    'planId': planId,
    'milestoneId': milestoneId,
    'completed': completed,
    'notes': notes,
    'url': url,
    'updatedAt': updatedAt.toIso8601String(),
  };
}

class BenchmarkReview {
  BenchmarkReview({
    required this.planId,
    required this.reviewedAt,
    required this.progressPercent,
    required this.summary,
    required List<String> blockers,
    required List<String> nextActions,
    required this.model,
  }) : blockers = List.unmodifiable(blockers),
       nextActions = List.unmodifiable(nextActions) {
    _text(planId, 100);
    _text(summary, 2400);
    _text(model, 120);
    if (!progressPercent.isFinite ||
        progressPercent < 0 ||
        progressPercent > 100 ||
        blockers.length > 6 ||
        nextActions.length > 6) {
      throw const FormatException('Invalid progress review.');
    }
  }
  final String planId, summary, model;
  final DateTime reviewedAt;
  final double progressPercent;
  final List<String> blockers, nextActions;
  factory BenchmarkReview.fromJson(Map<String, dynamic> j) {
    if (!['openai', 'ai'].contains(j['source'])) {
      throw const FormatException('Invalid review source.');
    }
    return BenchmarkReview(
      planId: _text(j['planId'], 100),
      reviewedAt: _date(j['reviewedAt']),
      progressPercent: (j['progressPercent'] as num).toDouble(),
      summary: _text(j['summary'], 2400),
      blockers: _list(j['blockers'], 6, (v) => _text(v, 500)),
      nextActions: _list(j['nextActions'], 6, (v) => _text(v, 600)),
      model: _text(j['model'], 120),
    );
  }
}

class BenchmarkException implements Exception {
  const BenchmarkException(this.code, this.message);
  final String code, message;
  @override
  String toString() => message;
}
