import '../../assessment/domain/ai_judgment.dart';
import '../../notifications/domain/reminder_settings.dart';
import '../../routines/domain/routine_models.dart';
import '../../routines/domain/daily_task.dart';
import '../../testing_lab/domain/lab_models.dart';
import '../../benchmark_research/domain/benchmark_models.dart';

import 'progress_types.dart';
export 'progress_types.dart';

Map<MetricKind, double> _validatedMetrics(Map<MetricKind, double> values) {
  if (values.length != MetricKind.values.length ||
      MetricKind.values.any((kind) => !values.containsKey(kind))) {
    throw ArgumentError('A score is required for every metric.');
  }
  for (final value in values.values) {
    if (!value.isFinite || value < 0 || value > 100) {
      throw ArgumentError.value(
        value,
        'metrics',
        'Scores must be from 0 to 100.',
      );
    }
  }
  return Map.unmodifiable(values);
}

Map<MetricKind, double> _metricsFromJson(Object? json) {
  final map = Map<String, dynamic>.from(json as Map);
  return {
    for (final kind in MetricKind.values)
      kind: (map[kind.name] as num).toDouble(),
  };
}

Map<String, double> _metricsToJson(Map<MetricKind, double> metrics) => {
  for (final entry in metrics.entries) entry.key.name: entry.value,
};

double _score(Map<MetricKind, double> metrics) =>
    metrics.values.reduce((a, b) => a + b) / MetricKind.values.length;

void _validateText(String value, String field, {required int maxLength}) {
  if (value.trim().isEmpty || value.runes.length > maxLength) {
    throw ArgumentError.value(
      value,
      field,
      'Must contain between 1 and $maxLength characters.',
    );
  }
}

void _validateIds(Iterable<String> ids, String collection) {
  final seen = <String>{};
  for (final id in ids) {
    _validateText(id, '$collection.id', maxLength: 256);
    if (!seen.add(id)) {
      throw ArgumentError('Duplicate identifier in $collection: $id');
    }
  }
}

class ProgressEntry {
  ProgressEntry({
    required this.id,
    required this.title,
    this.note = '',
    required this.track,
    required this.date,
    required Map<MetricKind, double> metrics,
  }) : metrics = _validatedMetrics(metrics) {
    _validateText(id, 'entry.id', maxLength: 256);
    _validateText(title, 'entry.title', maxLength: 100);
  }

  final String id;
  final String title;
  final String note;
  final ProgressTrack track;
  final DateTime date;
  final Map<MetricKind, double> metrics;
  double get score => _score(metrics);

  ProgressEntry copyWith({
    String? title,
    String? note,
    ProgressTrack? track,
    DateTime? date,
    Map<MetricKind, double>? metrics,
  }) => ProgressEntry(
    id: id,
    title: title ?? this.title,
    note: note ?? this.note,
    track: track ?? this.track,
    date: date ?? this.date,
    metrics: metrics ?? this.metrics,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'note': note,
    'track': track.name,
    'date': date.toIso8601String(),
    'metrics': _metricsToJson(metrics),
  };

  factory ProgressEntry.fromJson(Map<String, dynamic> json) => ProgressEntry(
    id: json['id'] as String,
    title: json['title'] as String,
    note: json['note'] as String? ?? '',
    track: ProgressTrack.values.byName(json['track'] as String),
    date: DateTime.parse(json['date'] as String),
    metrics: _metricsFromJson(json['metrics']),
  );
}

class TargetProfile {
  TargetProfile({
    required this.id,
    required this.name,
    required this.role,
    required this.initials,
    required this.track,
    required Map<MetricKind, double> metrics,
    this.isExample = true,
  }) : metrics = _validatedMetrics(metrics) {
    _validateText(id, 'profile.id', maxLength: 256);
    _validateText(name, 'profile.name', maxLength: 60);
    _validateText(role, 'profile.role', maxLength: 100);
    _validateText(initials, 'profile.initials', maxLength: 8);
  }

  final String id;
  final String name;
  final String role;
  final String initials;
  final ProgressTrack track;
  final Map<MetricKind, double> metrics;
  final bool isExample;
  double get score => _score(metrics);

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'role': role,
    'initials': initials,
    'track': track.name,
    'metrics': _metricsToJson(metrics),
    'isExample': isExample,
  };

  factory TargetProfile.fromJson(Map<String, dynamic> json) => TargetProfile(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    initials: json['initials'] as String,
    track: ProgressTrack.values.byName(json['track'] as String),
    metrics: _metricsFromJson(json['metrics']),
    isExample: json['isExample'] as bool? ?? true,
  );
}

class ProgressGoal {
  ProgressGoal({
    required this.id,
    required this.title,
    required this.track,
    required this.metric,
    required this.target,
    required this.deadline,
    this.completed = false,
  }) {
    _validateText(id, 'goal.id', maxLength: 256);
    _validateText(title, 'goal.title', maxLength: 100);
    if (!target.isFinite || target < 0 || target > 100) {
      throw ArgumentError.value(target, 'target', 'Must be from 0 to 100.');
    }
  }

  final String id;
  final String title;
  final ProgressTrack track;
  final MetricKind metric;
  final double target;
  final DateTime deadline;
  final bool completed;

  ProgressGoal copyWith({
    String? title,
    ProgressTrack? track,
    MetricKind? metric,
    double? target,
    DateTime? deadline,
    bool? completed,
  }) => ProgressGoal(
    id: id,
    title: title ?? this.title,
    track: track ?? this.track,
    metric: metric ?? this.metric,
    target: target ?? this.target,
    deadline: deadline ?? this.deadline,
    completed: completed ?? this.completed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'track': track.name,
    'metric': metric.name,
    'target': target,
    'deadline': deadline.toIso8601String(),
    'completed': completed,
  };

  factory ProgressGoal.fromJson(Map<String, dynamic> json) => ProgressGoal(
    id: json['id'] as String,
    title: json['title'] as String,
    track: ProgressTrack.values.byName(json['track'] as String),
    metric: MetricKind.values.byName(json['metric'] as String),
    target: (json['target'] as num).toDouble(),
    deadline: DateTime.parse(json['deadline'] as String),
    completed: json['completed'] as bool? ?? false,
  );
}

const _notProvided = Object();

class ProgressData {
  ProgressData({
    List<ProgressEntry> entries = const [],
    List<ProgressGoal> goals = const [],
    List<TargetProfile> profiles = const [],
    List<RoutineItem> routines = const [],
    List<DailyTask> dailyTasks = const [],
    List<AiProgressJudgment> aiJudgments = const [],
    this.reminderSettings = const ReminderSettings(),
    List<RoutineCompletion> routineCompletions = const [],
    List<LabResult> labResults = const [],
    List<ResearchPlan> researchPlans = const [],
    List<RoadmapProjectEvidence> projectEvidence = const [],
    this.selectedResearchPlanId,
    this.targetProfileId,
    String studentName = 'Alex',
  }) : entries = List.unmodifiable(entries),
       goals = List.unmodifiable(goals),
       profiles = List.unmodifiable(profiles),
       routines = List.unmodifiable(routines),
       dailyTasks = List.unmodifiable(dailyTasks),
       aiJudgments = List.unmodifiable(aiJudgments),
       routineCompletions = List.unmodifiable(routineCompletions),
       labResults = List.unmodifiable(labResults),
       researchPlans = List.unmodifiable(researchPlans),
       projectEvidence = List.unmodifiable(projectEvidence),
       studentName = studentName.trim() {
    _validateText(this.studentName, 'studentName', maxLength: 50);
    _validateIds(this.entries.map((entry) => entry.id), 'entries');
    _validateIds(this.goals.map((goal) => goal.id), 'goals');
    _validateIds(this.profiles.map((profile) => profile.id), 'profiles');
    _validateIds(this.routines.map((routine) => routine.id), 'routines');
    _validateIds(this.dailyTasks.map((task) => task.id), 'daily tasks');
    _validateIds(this.aiJudgments.map((j) => j.id), 'AI judgments');
    for (final judgment in this.aiJudgments) {
      final ids = this.labResults
          .where((r) => r.track == judgment.track)
          .map((r) => r.id)
          .toSet();
      if (judgment.metrics.any(
        (m) => m.evidenceIds.any((id) => !ids.contains(id)),
      )) {
        throw ArgumentError(
          'AI judgment refers to missing assessment evidence.',
        );
      }
    }
    _validateIds(this.labResults.map((result) => result.id), 'labResults');
    _validateIds(this.researchPlans.map((p) => p.id), 'researchPlans');
    if (this.researchPlans.any((p) => !p.isReady)) {
      throw ArgumentError('Only ready research paths can be saved.');
    }
    if (selectedResearchPlanId != null &&
        !this.researchPlans.any((p) => p.id == selectedResearchPlanId)) {
      throw ArgumentError('Selected path does not exist.');
    }
    final evidenceKeys = <String>{};
    for (final e in this.projectEvidence) {
      final plan = this.researchPlans
          .where((p) => p.id == e.planId)
          .firstOrNull;
      if (plan == null ||
          !plan.milestones.any(
            (m) =>
                m.id == e.milestoneId && m.kind == RoadmapMilestoneKind.project,
          ) ||
          !evidenceKeys.add(e.key)) {
        throw ArgumentError('Invalid roadmap project evidence.');
      }
    }
    final byId = {for (final routine in this.routines) routine.id: routine};
    final completionKeys = <String>{};
    for (final completion in this.routineCompletions) {
      final routine = byId[completion.routineId];
      if (routine == null) {
        throw ArgumentError(
          'A routine completion must reference an existing routine.',
        );
      }
      if (!completionKeys.add(completion.key)) {
        throw ArgumentError('Duplicate routine completion: ${completion.key}');
      }
    }
  }

  final List<ProgressEntry> entries;
  final List<ProgressGoal> goals;
  final List<TargetProfile> profiles;
  final List<RoutineItem> routines;
  final List<DailyTask> dailyTasks;
  final List<AiProgressJudgment> aiJudgments;
  final ReminderSettings reminderSettings;
  final List<RoutineCompletion> routineCompletions;
  final List<LabResult> labResults;
  final List<ResearchPlan> researchPlans;
  final List<RoadmapProjectEvidence> projectEvidence;
  final String? selectedResearchPlanId;
  final String? targetProfileId;
  final String studentName;

  ProgressData copyWith({
    List<ProgressEntry>? entries,
    List<ProgressGoal>? goals,
    List<TargetProfile>? profiles,
    List<RoutineItem>? routines,
    List<DailyTask>? dailyTasks,
    List<AiProgressJudgment>? aiJudgments,
    ReminderSettings? reminderSettings,
    List<RoutineCompletion>? routineCompletions,
    List<LabResult>? labResults,
    List<ResearchPlan>? researchPlans,
    List<RoadmapProjectEvidence>? projectEvidence,
    Object? selectedResearchPlanId = _notProvided,
    Object? targetProfileId = _notProvided,
    String? studentName,
  }) => ProgressData(
    entries: entries ?? this.entries,
    goals: goals ?? this.goals,
    profiles: profiles ?? this.profiles,
    routines: routines ?? this.routines,
    dailyTasks: dailyTasks ?? this.dailyTasks,
    aiJudgments: aiJudgments ?? this.aiJudgments,
    reminderSettings: reminderSettings ?? this.reminderSettings,
    routineCompletions: routineCompletions ?? this.routineCompletions,
    labResults: labResults ?? this.labResults,
    researchPlans: researchPlans ?? this.researchPlans,
    projectEvidence: projectEvidence ?? this.projectEvidence,
    selectedResearchPlanId: identical(selectedResearchPlanId, _notProvided)
        ? this.selectedResearchPlanId
        : selectedResearchPlanId as String?,
    targetProfileId: identical(targetProfileId, _notProvided)
        ? this.targetProfileId
        : targetProfileId as String?,
    studentName: studentName ?? this.studentName,
  );

  Map<String, dynamic> toJson() => {
    'schemaVersion': 6,
    'aiJudgments': aiJudgments.map((j) => j.toJson()).toList(),
    'reminderSettings': reminderSettings.toJson(),
    'dailyTasks': dailyTasks.map((task) => task.toJson()).toList(),
    'researchPlans': researchPlans.map((p) => p.toJson()).toList(),
    'projectEvidence': projectEvidence.map((e) => e.toJson()).toList(),
    'selectedResearchPlanId': selectedResearchPlanId,
    'labResults': labResults.map((result) => result.toJson()).toList(),
    'entries': entries.map((item) => item.toJson()).toList(),
    'goals': goals.map((item) => item.toJson()).toList(),
    'profiles': profiles.map((item) => item.toJson()).toList(),
    'routines': routines.map((item) => item.toJson()).toList(),
    'routineCompletions': routineCompletions
        .map((item) => item.toJson())
        .toList(),
    'targetProfileId': targetProfileId,
    'studentName': studentName,
  };

  factory ProgressData.fromJson(Map<String, dynamic> json) {
    final version = json['schemaVersion'];
    if (version != 1 &&
        version != 2 &&
        version != 3 &&
        version != 4 &&
        version != 5 &&
        version != 6) {
      throw const FormatException('Unsupported Progress Meter data version.');
    }
    return ProgressData(
      entries: (json['entries'] as List)
          .map(
            (item) =>
                ProgressEntry.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      goals: (json['goals'] as List)
          .map(
            (item) =>
                ProgressGoal.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      profiles: (json['profiles'] as List)
          .map(
            (item) =>
                TargetProfile.fromJson(Map<String, dynamic>.from(item as Map)),
          )
          .toList(),
      routines: version == 1
          ? []
          : (json['routines'] as List)
                .map(
                  (item) => RoutineItem.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(),
      routineCompletions: version == 1
          ? []
          : (json['routineCompletions'] as List)
                .map(
                  (item) => RoutineCompletion.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList(),
      labResults: version >= 3
          ? (json['labResults'] as List)
                .map(
                  (item) => LabResult.fromJson(
                    Map<String, dynamic>.from(item as Map),
                  ),
                )
                .toList()
          : [],
      researchPlans: version >= 4
          ? (json['researchPlans'] as List)
                .map(
                  (p) => ResearchPlan.fromJson(
                    Map<String, dynamic>.from(p as Map),
                  ),
                )
                .toList()
          : [],
      projectEvidence: version >= 4
          ? (json['projectEvidence'] as List)
                .map(
                  (e) => RoadmapProjectEvidence.fromJson(
                    Map<String, dynamic>.from(e as Map),
                  ),
                )
                .toList()
          : [],
      selectedResearchPlanId: version >= 4
          ? json['selectedResearchPlanId'] as String?
          : null,
      dailyTasks: version >= 5
          ? (json['dailyTasks'] as List)
                .map(
                  (task) => DailyTask.fromJson(
                    Map<String, dynamic>.from(task as Map),
                  ),
                )
                .toList()
          : [],
      aiJudgments: version >= 6
          ? (json['aiJudgments'] as List)
                .map(
                  (j) => AiProgressJudgment.fromJson(
                    Map<String, dynamic>.from(j as Map),
                  ),
                )
                .toList()
          : [],
      reminderSettings: version >= 6
          ? ReminderSettings.fromJson(
              Map<String, dynamic>.from(json['reminderSettings'] as Map),
            )
          : const ReminderSettings(),
      targetProfileId: json['targetProfileId'] as String?,
      studentName: json['studentName'] as String,
    );
  }
}
