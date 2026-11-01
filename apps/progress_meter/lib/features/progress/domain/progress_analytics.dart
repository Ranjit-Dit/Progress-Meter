import 'models.dart';

/// All scores are self-reported, equally weighted averages on a 0–100 scale.
class ProgressAnalytics {
  static List<ProgressEntry> history(
    Iterable<ProgressEntry> entries,
    ProgressTrack track,
  ) => entries.where((entry) => entry.track == track).toList()
    ..sort((a, b) {
      final order = a.date.compareTo(b.date);
      return order != 0 ? order : a.id.compareTo(b.id);
    });

  static ProgressEntry? latest(
    Iterable<ProgressEntry> entries,
    ProgressTrack track,
  ) {
    final sorted = history(entries, track);
    return sorted.isEmpty ? null : sorted.last;
  }

  static ProgressEntry? previous(
    Iterable<ProgressEntry> entries,
    ProgressTrack track,
  ) {
    final sorted = history(entries, track);
    return sorted.length < 2 ? null : sorted[sorted.length - 2];
  }

  static double averageScore(Iterable<ProgressEntry> entries) {
    final values = entries.toList();
    if (values.isEmpty) return 0;
    return values.fold<double>(0, (sum, entry) => sum + entry.score) /
        values.length;
  }

  static double metricAverage(
    Iterable<ProgressEntry> entries,
    MetricKind metric,
  ) {
    final values = entries.toList();
    if (values.isEmpty) return 0;
    return values.fold<double>(
          0,
          (sum, entry) => sum + entry.metrics[metric]!,
        ) /
        values.length;
  }

  /// Positive means improvement, expressed in percentage points, not percent.
  static double change(ProgressEntry current, ProgressEntry previous) =>
      current.score - previous.score;
}
