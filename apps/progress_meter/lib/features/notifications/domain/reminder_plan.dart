import '../../routines/domain/daily_task.dart';
import '../../routines/domain/routine_models.dart';
import 'reminder_settings.dart';

class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.title,
    required this.body,
    required this.nextFire,
    this.weekday,
  });
  final String id, title, body;
  final DateTime nextFire;

  /// Dart weekday, Monday 1 through Sunday 7; null for a dated task.
  final int? weekday;

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'body': body,
    'year': nextFire.year,
    'month': nextFire.month,
    'day': nextFire.day,
    'hour': nextFire.hour,
    'minute': nextFire.minute,
    'weekday': weekday,
  };
}

class ReminderPlan {
  ReminderPlan(List<PlannedReminder> reminders, this.truncatedCount)
    : reminders = List.unmodifiable(reminders);
  final List<PlannedReminder> reminders;
  final int truncatedCount;
}

abstract final class ReminderPlanner {
  static ReminderPlan build({
    required Iterable<RoutineItem> routines,
    required Iterable<DailyTask> tasks,
    required ReminderSettings settings,
    DateTime? now,
    int maximum = 64,
  }) {
    if (!settings.enabled) return ReminderPlan([], 0);
    final instant = (now ?? DateTime.now()).toLocal();
    final dated = <PlannedReminder>[];
    final weekly = <PlannedReminder>[];
    String clock(int minutes) =>
        '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
    for (final task in tasks) {
      if (task.completed || task.timeMinutes == null) continue;
      final date = task.date;
      final event = DateTime(
        date.year,
        date.month,
        date.day,
        task.timeMinutes! ~/ 60,
        task.timeMinutes! % 60,
      );
      if (!event.isAfter(instant)) continue;
      final early = event.subtract(Duration(minutes: settings.leadMinutes));
      // If the lead time already passed, remind at the actual task time.
      final fire = early.isAfter(instant) ? early : event;
      dated.add(
        PlannedReminder(
          id: 'pm.reminder.task.${Uri.encodeComponent(task.id)}',
          title: task.title,
          body: 'Task at ${clock(task.timeMinutes!)}',
          nextFire: fire,
        ),
      );
    }
    for (final routine in routines) {
      for (final day in routine.weekdays) {
        final shifted = routine.startMinutes - settings.leadMinutes;
        final minute = shifted % 1440;
        final reminderDay = ((day - 1 + (shifted < 0 ? -1 : 0)) % 7) + 1;
        final delta = (reminderDay - instant.weekday) % 7;
        var next = DateTime(
          instant.year,
          instant.month,
          instant.day + delta,
          minute ~/ 60,
          minute % 60,
        );
        if (!next.isAfter(instant)) {
          next = DateTime(
            next.year,
            next.month,
            next.day + 7,
            minute ~/ 60,
            minute % 60,
          );
        }
        weekly.add(
          PlannedReminder(
            id: 'pm.reminder.routine.${Uri.encodeComponent(routine.id)}.$day',
            title: routine.title,
            body:
                '${routine.kind == RoutineKind.classSession ? 'Class' : 'Meal'} at ${clock(routine.startMinutes)}${routine.location.isEmpty ? '' : ' · ${routine.location}'}',
            nextFire: next,
            weekday: reminderDay,
          ),
        );
      }
    }
    int order(PlannedReminder a, PlannedReminder b) {
      final date = a.nextFire.compareTo(b.nextFire);
      return date != 0 ? date : a.id.compareTo(b.id);
    }

    dated.sort(order);
    weekly.sort(order);
    // Dated tasks cannot repeat; reserve their slots before weekly requests.
    final all = [...dated, ...weekly];
    final kept = all.take(maximum.clamp(0, 64)).toList()..sort(order);
    return ReminderPlan(kept, all.length - kept.length);
  }
}
