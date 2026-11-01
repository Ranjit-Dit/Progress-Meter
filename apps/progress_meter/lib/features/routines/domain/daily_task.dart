import 'routine_models.dart';

const _unchangedTime = Object();

/// One task on one local calendar day, independent of weekly routines.
class DailyTask {
  DailyTask({
    required this.id,
    required String title,
    required this.dateKey,
    String notes = '',
    this.timeMinutes,
    this.completed = false,
  }) : title = title.trim(),
       notes = notes.trim() {
    if (id.trim().isEmpty || id.runes.length > 256) {
      throw ArgumentError('A task needs an ID of 1–256 characters.');
    }
    if (this.title.isEmpty || title.runes.length > 100) {
      throw ArgumentError('A task needs a title of 1–100 characters.');
    }
    if (notes.runes.length > 1200) {
      throw ArgumentError('Task notes must contain at most 1,200 characters.');
    }
    routineDateFromKey(dateKey);
    if (timeMinutes != null && (timeMinutes! < 0 || timeMinutes! > 1439)) {
      throw ArgumentError('Choose a task time within the day.');
    }
  }

  final String id, title, dateKey, notes;
  final int? timeMinutes;
  final bool completed;
  DateTime get date => routineDateFromKey(dateKey);

  DailyTask copyWith({
    String? title,
    String? dateKey,
    String? notes,
    Object? timeMinutes = _unchangedTime,
    bool? completed,
  }) => DailyTask(
    id: id,
    title: title ?? this.title,
    dateKey: dateKey ?? this.dateKey,
    notes: notes ?? this.notes,
    timeMinutes: identical(timeMinutes, _unchangedTime)
        ? this.timeMinutes
        : timeMinutes as int?,
    completed: completed ?? this.completed,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'dateKey': dateKey,
    'notes': notes,
    'timeMinutes': timeMinutes,
    'completed': completed,
  };

  factory DailyTask.fromJson(Map<String, dynamic> json) => DailyTask(
    id: json['id'] as String,
    title: json['title'] as String,
    dateKey: json['dateKey'] as String,
    notes: json['notes'] as String? ?? '',
    timeMinutes: json['timeMinutes'] as int?,
    completed: json['completed'] as bool,
  );
}

abstract final class DailyTaskAnalytics {
  static List<DailyTask> forDate(Iterable<DailyTask> tasks, DateTime date) {
    final key = routineDateKey(date);
    return tasks.where((task) => task.dateKey == key).toList()..sort((a, b) {
      if (a.completed != b.completed) return a.completed ? 1 : -1;
      final time = (a.timeMinutes ?? 1440).compareTo(b.timeMinutes ?? 1440);
      return time == 0 ? a.id.compareTo(b.id) : time;
    });
  }
}
