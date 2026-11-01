import '../features/assessment/domain/ai_judgment.dart';
import '../features/notifications/domain/reminder_settings.dart';

import 'package:flutter/foundation.dart';

import '../features/progress/data/demo_data.dart';
import '../features/progress/data/progress_repository.dart';
import '../features/progress/domain/models.dart';
import '../features/progress/domain/progress_analytics.dart';
import '../features/testing_lab/domain/lab_models.dart';
import '../features/benchmark_research/domain/benchmark_models.dart';
import '../features/routines/domain/routine_models.dart';
import '../features/routines/domain/daily_task.dart';
import '../features/routine_import/domain/import_identity.dart';
import '../features/routines/domain/routine_analytics.dart';

class ProgressController extends ChangeNotifier {
  ProgressController(this.repository);
  final ProgressRepository repository;
  late ProgressData data;
  ProgressTrack track = ProgressTrack.academic;
  bool saving = false;

  /// Invalidates cached views of data after deletion, replacement, or retargeting.
  int contextRevision = 0;
  int labContextRevision = 0;
  Future<void> initialize() async {
    final saved = await repository.load();
    data = saved ?? createDemoData(DateTime.now());
    if (saved == null) await repository.save(data);
  }

  AiProgressJudgment? get currentJudgment =>
      AiJudgmentAnalytics.current(data.aiJudgments, data.labResults, track);
  bool get judgmentStale =>
      currentJudgment == null && data.aiJudgments.any((j) => j.track == track);
  double? judgedScore(MetricKind metric) =>
      currentJudgment?.metric(metric).score;
  bool goalAchieved(ProgressGoal goal) =>
      goal.track == track &&
      judgedScore(goal.metric) != null &&
      judgedScore(goal.metric)! >= goal.target;
  Future<void> recordAiJudgment(AiProgressJudgment judgment) {
    final evidence = AiEvidenceSnapshot.fromResults(
      data.labResults,
      judgment.track,
    );
    if (!evidence.accepts(judgment)) {
      throw ArgumentError(
        'Assessment evidence changed. Request a fresh AI judgment.',
      );
    }
    if (data.aiJudgments.any((j) => j.id == judgment.id)) return Future.value();
    return _commit(data.copyWith(aiJudgments: [...data.aiJudgments, judgment]));
  }

  Future<void> updateReminderSettings(ReminderSettings settings) {
    if (settings.leadMinutes < 0 || settings.leadMinutes > 60) {
      throw ArgumentError('Choose a reminder time from 0 to 60 minutes.');
    }
    return _commit(data.copyWith(reminderSettings: settings));
  }

  List<ProgressEntry> get history =>
      ProgressAnalytics.history(data.entries, track);
  ProgressEntry? get latest => ProgressAnalytics.latest(data.entries, track);
  ProgressEntry? get previous =>
      ProgressAnalytics.previous(data.entries, track);
  List<ProgressGoal> get goals =>
      data.goals.where((g) => g.track == track).toList();
  List<TargetProfile> get profiles =>
      data.profiles.where((p) => p.track == track).toList();
  TargetProfile? get target {
    for (final profile in profiles) {
      if (profile.id == data.targetProfileId) return profile;
    }
    return null;
  }

  void selectTrack(ProgressTrack value) {
    track = value;
    notifyListeners();
  }

  Future<void> _commit(
    ProgressData next, {
    bool resetContext = false,
    bool resetLabContext = false,
  }) async {
    if (saving) {
      throw StateError('A save is already in progress. Please try again.');
    }
    saving = true;
    notifyListeners();
    try {
      await repository.save(next);
      data = next;
      if (resetContext) contextRevision++;
      if (resetLabContext) labContextRevision++;
    } finally {
      saving = false;
      notifyListeners();
    }
  }

  Future<void> recordLabResult(LabResult result) async {
    if (saving) throw StateError('A save is already in progress.');
    if (data.labResults.any((r) => r.id == result.id)) return;
    await _commit(data.copyWith(labResults: [...data.labResults, result]));
  }

  ResearchPlan? get researchTarget => data.researchPlans
      .where((p) => p.id == data.selectedResearchPlanId && p.track == track)
      .firstOrNull;

  Future<void> adoptResearchPlan(ResearchPlan plan) {
    if (!plan.isReady) {
      throw ArgumentError(
        'Research needs more evidence before it can be a target.',
      );
    }
    return _commit(
      data.copyWith(
        researchPlans: [
          for (final p in data.researchPlans) p,
          if (!data.researchPlans.any((p) => p.id == plan.id)) plan,
        ],
        selectedResearchPlanId: plan.id,
        targetProfileId: null,
      ),
      resetContext: true,
    );
  }

  Future<void> selectResearchPlan(String? id) => _commit(
    data.copyWith(
      selectedResearchPlanId: id,
      targetProfileId: id == null ? data.targetProfileId : null,
    ),
    resetContext: true,
  );
  Future<void> upsertProjectEvidence(RoadmapProjectEvidence item) => _commit(
    data.copyWith(
      projectEvidence: [
        for (final e in data.projectEvidence)
          if (e.key != item.key) e,
        item,
      ],
    ),
  );
  Future<void> deleteResearchPlan(String id) => _commit(
    data.copyWith(
      researchPlans: data.researchPlans.where((p) => p.id != id).toList(),
      projectEvidence: data.projectEvidence
          .where((e) => e.planId != id)
          .toList(),
      selectedResearchPlanId: data.selectedResearchPlanId == id
          ? null
          : data.selectedResearchPlanId,
    ),
    resetContext: true,
  );

  Future<void> deleteLabResult(String id) => _commit(
    data.copyWith(
      labResults: data.labResults.where((r) => r.id != id).toList(),
      aiJudgments: data.aiJudgments
          .where((j) => !j.metrics.any((m) => m.evidenceIds.contains(id)))
          .toList(),
    ),
    resetContext: true,
    resetLabContext: true,
  );

  Future<void> addEntry(ProgressEntry entry) async {
    throw StateError(
      'Manual scoring is disabled. Complete Testing Lab and request an AI judgment.',
    );
  }

  Future<void> deleteEntry(String id) => _commit(
    data.copyWith(entries: data.entries.where((e) => e.id != id).toList()),
    resetContext: true,
  );
  Future<void> addGoal(ProgressGoal goal) =>
      _commit(data.copyWith(goals: [...data.goals, goal]));
  Future<void> toggleGoal(ProgressGoal goal) async {
    throw StateError('Goal attainment is verified by AI judgments.');
  }

  Future<void> deleteGoal(String id) => _commit(
    data.copyWith(goals: data.goals.where((g) => g.id != id).toList()),
    resetContext: true,
  );
  Future<void> setTarget(String? id) => _commit(
    data.copyWith(
      targetProfileId: id,
      selectedResearchPlanId: id == null ? data.selectedResearchPlanId : null,
    ),
    resetContext: true,
  );
  Future<void> addProfile(TargetProfile profile) => _commit(
    data.copyWith(
      profiles: [...data.profiles, profile],
      targetProfileId: profile.id,
      selectedResearchPlanId: null,
    ),
    resetContext: true,
  );
  Future<void> rename(String name) => _commit(data.copyWith(studentName: name));
  Future<void> restore(ProgressData restored) =>
      _commit(restored, resetContext: true, resetLabContext: true);
  Future<void> clearDemo() => _commit(
    ProgressData(
      entries: [],
      goals: [],
      profiles: [],
      studentName: data.studentName,
    ),
    resetContext: true,
    resetLabContext: true,
  );
  List<DailyTask> tasksOn(DateTime date) =>
      DailyTaskAnalytics.forDate(data.dailyTasks, date);

  Future<void> upsertDailyTask(DailyTask task, {DateTime? now}) {
    final existing = data.dailyTasks
        .where((item) => item.id == task.id)
        .firstOrNull;
    final next = existing != null && existing.dateKey != task.dateKey
        ? task.copyWith(completed: false)
        : task;
    if (next.completed &&
        next.date.isAfter(routineDate(now ?? DateTime.now()))) {
      throw ArgumentError('Complete a task on its day or afterward.');
    }
    return _commit(
      data.copyWith(
        dailyTasks: [
          for (final item in data.dailyTasks)
            if (item.id == next.id) next else item,
          if (existing == null) next,
        ],
      ),
    );
  }

  Future<void> toggleDailyTask(String id, {DateTime? now}) {
    final task = data.dailyTasks.where((item) => item.id == id).firstOrNull;
    if (task == null) throw ArgumentError('This task no longer exists.');
    if (!task.completed &&
        task.date.isAfter(routineDate(now ?? DateTime.now()))) {
      throw ArgumentError('Complete a task on its day or afterward.');
    }
    return _commit(
      data.copyWith(
        dailyTasks: [
          for (final item in data.dailyTasks)
            if (item.id == id)
              item.copyWith(completed: !item.completed)
            else
              item,
        ],
      ),
    );
  }

  Future<void> deleteDailyTask(String id) => _commit(
    data.copyWith(
      dailyTasks: data.dailyTasks.where((item) => item.id != id).toList(),
    ),
  );

  List<RoutineItem> routinesOn(DateTime date) =>
      RoutineAnalytics.forDate(data.routines, date);

  bool routineCompleted(String id, DateTime date) =>
      RoutineAnalytics.isCompleted(data.routineCompletions, id, date);

  Future<void> upsertRoutine(RoutineItem item) {
    final existing = data.routines.where((r) => r.id == item.id).firstOrNull;
    if (existing != null && existing.kind != item.kind) {
      throw ArgumentError('A routine cannot change between food and class.');
    }
    return _commit(
      data.copyWith(
        routines: [
          for (final routine in data.routines)
            if (routine.id == item.id) item else routine,
          if (existing == null) item,
        ],
      ),
    );
  }

  Future<List<String>> importRoutines(List<RoutineItem> items) async {
    if (saving) throw StateError('A save is already in progress.');
    final next = [...data.routines];
    final ids = <String>[];
    final batch = DateTime.now().microsecondsSinceEpoch;
    for (final item in items) {
      final days = newImportDays(item, next);
      if (days.isEmpty) continue;
      var id = 'routine-import-$batch-${ids.length}';
      while (next.any((r) => r.id == id)) {
        id = '${id}x';
      }
      next.add(
        RoutineItem(
          id: id,
          title: item.title,
          kind: item.kind,
          weekdays: days,
          startMinutes: item.startMinutes,
          endMinutes: item.endMinutes,
          details: item.details,
          location: item.location,
          instructor: item.instructor,
        ),
      );
      ids.add(id);
    }
    if (ids.isNotEmpty) await _commit(data.copyWith(routines: next));
    return ids;
  }

  Future<void> undoRoutineImport(Set<String> ids) => _commit(
    data.copyWith(
      routines: data.routines.where((r) => !ids.contains(r.id)).toList(),
      routineCompletions: data.routineCompletions
          .where((r) => !ids.contains(r.routineId))
          .toList(),
    ),
  );

  Future<void> deleteRoutine(String id) => _commit(
    data.copyWith(
      routines: data.routines.where((r) => r.id != id).toList(),
      routineCompletions: data.routineCompletions
          .where((r) => r.routineId != id)
          .toList(),
    ),
  );

  Future<void> toggleRoutine(RoutineItem item, DateTime date, {DateTime? now}) {
    final stored = data.routines.where((r) => r.id == item.id).firstOrNull;
    if (stored == null) throw ArgumentError('This routine no longer exists.');
    final day = routineDate(date);
    final key = routineDateKey(day);
    final done = routineCompleted(item.id, day);
    if (!done && day.isAfter(routineDate(now ?? DateTime.now()))) {
      throw ArgumentError('Check off a routine on the day or afterward.');
    }
    if (!done && !stored.weekdays.contains(day.weekday)) {
      throw ArgumentError('This routine is not scheduled for this day.');
    }
    return _commit(
      data.copyWith(
        routineCompletions: [
          for (final completion in data.routineCompletions)
            if (!(completion.routineId == item.id && completion.dateKey == key))
              completion,
          if (!done) RoutineCompletion(routineId: item.id, dateKey: key),
        ],
      ),
    );
  }
}
