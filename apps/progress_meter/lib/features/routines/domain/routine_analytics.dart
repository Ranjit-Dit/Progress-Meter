import 'routine_models.dart';

abstract final class RoutineAnalytics {
  static List<RoutineItem> forDate(
    Iterable<RoutineItem> items,
    DateTime date,
  ) =>
      items.where((item) => item.weekdays.contains(date.weekday)).toList()
        ..sort((a, b) {
          final byTime = a.startMinutes.compareTo(b.startMinutes);
          if (byTime != 0) return byTime;
          final byKind = a.kind.index.compareTo(b.kind.index);
          return byKind != 0 ? byKind : a.id.compareTo(b.id);
        });

  /// Half-open class intervals: a 10:00 end and 10:00 start do not conflict.
  static List<RoutineItem> conflicts(
    RoutineItem item,
    Iterable<RoutineItem> others,
  ) {
    if (item.kind != RoutineKind.classSession) return [];
    return others
        .where(
          (other) =>
              other.id != item.id &&
              other.kind == RoutineKind.classSession &&
              item.weekdays.any(other.weekdays.contains) &&
              item.startMinutes < other.endMinutes! &&
              other.startMinutes < item.endMinutes!,
        )
        .toList()
      ..sort((a, b) {
        final byTime = a.startMinutes.compareTo(b.startMinutes);
        return byTime != 0 ? byTime : a.id.compareTo(b.id);
      });
  }

  static bool isCompleted(
    Iterable<RoutineCompletion> completions,
    String id,
    DateTime date,
  ) {
    final day = routineDateKey(date);
    return completions.any(
      (completion) => completion.routineId == id && completion.dateKey == day,
    );
  }

  static int completedCount(
    Iterable<RoutineItem> items,
    Iterable<RoutineCompletion> completions,
    DateTime date,
  ) => forDate(
    items,
    date,
  ).where((item) => isCompleted(completions, item.id, date)).length;

  static DateTime weekStart(DateTime date) {
    final day = routineDate(date);
    // Construct a calendar date, rather than subtracting a fixed duration across DST.
    return DateTime(
      day.year,
      day.month,
      day.day - (day.weekday - DateTime.monday),
    );
  }
}
