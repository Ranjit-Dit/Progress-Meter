import '../../progress/domain/progress_types.dart' show ProgressTrack;
import 'lab_models.dart';

abstract final class LabAnalytics {
  /// Newest first, with stable ordering for equal timestamps.
  static List<LabResult> history(
    Iterable<LabResult> results,
    ProgressTrack track,
  ) => results.where((r) => r.track == track).toList()
    ..sort((a, b) {
      final byDate = b.completedAt.compareTo(a.completedAt);
      return byDate == 0 ? b.id.compareTo(a.id) : byDate;
    });

  static List<LabResult> forTrack(
    Iterable<LabResult> results,
    ProgressTrack track,
  ) => history(results, track);

  /// Three distinct assessment days in the last seven local calendar days.
  /// Retests on one date never increase this participation measure.
  static int activeDays(
    Iterable<LabResult> results,
    ProgressTrack track, {
    DateTime? now,
  }) {
    final instant = now ?? DateTime.now();
    final localNow = instant.toLocal();
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    final first = DateTime(today.year, today.month, today.day - 6);
    final days = <String>{};
    for (final result in results) {
      if (result.track != track || result.completedAt.isAfter(instant)) {
        continue;
      }
      final local = result.completedAt.toLocal();
      final date = DateTime(local.year, local.month, local.day);
      if (date.isBefore(first) || date.isAfter(today)) continue;
      days.add('${date.year}-${date.month}-${date.day}');
    }
    return days.length;
  }

  /// Legacy participation statistic; current Consistency is judged only by AI.
  static double consistency(
    Iterable<LabResult> results,
    ProgressTrack track, {
    DateTime? now,
  }) => (activeDays(results, track, now: now).clamp(0, 3) * 100 / 3);

  static LabResult? previousComparable(
    Iterable<LabResult> results,
    LabResult current,
  ) {
    String topic(String value) =>
        value.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    return history(results, current.track)
        .where(
          (r) =>
              r.id != current.id &&
              r.level == current.level &&
              r.questionCount == current.questionCount &&
              topic(r.topic) == topic(current.topic) &&
              !r.completedAt.isAfter(current.completedAt),
        )
        .firstOrNull;
  }
}
