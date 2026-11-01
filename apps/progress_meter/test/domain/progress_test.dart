import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/features/progress/data/demo_data.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/progress/domain/progress_analytics.dart';

Map<MetricKind, double> metrics(double value) => {
  for (final kind in MetricKind.values) kind: value,
};

ProgressEntry entry(
  String id,
  DateTime date,
  double score, {
  ProgressTrack track = ProgressTrack.academic,
}) => ProgressEntry(
  id: id,
  title: 'Checkpoint',
  track: track,
  date: date,
  metrics: metrics(score),
);

void main() {
  test('score is the equal mean of the four dimensions', () {
    final point = ProgressEntry(
      id: '1',
      title: 'Test',
      track: ProgressTrack.academic,
      date: DateTime(2026),
      metrics: {
        MetricKind.knowledge: 100,
        MetricKind.practice: 80,
        MetricKind.consistency: 60,
        MetricKind.impact: 40,
      },
    );
    expect(point.score, 70);
    expect(
      () => point.metrics[MetricKind.knowledge] = 0,
      throwsUnsupportedError,
    );
  });

  test('missing, nonfinite and out-of-range metrics are rejected', () {
    for (final invalid in [
      <MetricKind, double>{},
      metrics(-1),
      metrics(101),
      metrics(double.nan),
    ]) {
      expect(
        () => ProgressEntry(
          id: '1',
          title: 'Test',
          track: ProgressTrack.academic,
          date: DateTime(2026),
          metrics: invalid,
        ),
        throwsArgumentError,
      );
    }
  });

  test('all saved state survives JSON round trip', () {
    final data = createDemoData(DateTime(2026, 10, 29));
    final restored = ProgressData.fromJson(
      jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
    );
    expect(restored.toJson(), data.toJson());
    expect(restored.entries.length, 26);
    expect(restored.profiles.every((profile) => profile.isExample), isTrue);
    expect(restored.studentName, 'Alex');
    expect(restored.copyWith(targetProfileId: null).targetProfileId, isNull);
    expect(
      restored.copyWith(studentName: 'Ranjit').targetProfileId,
      data.targetProfileId,
    );
  });

  test('latest and previous use dates and isolate the requested track', () {
    final first = entry('first', DateTime(2026, 10, 1), 30);
    final second = entry('second', DateTime(2026, 10, 15), 60);
    final last = entry('last', DateTime(2026, 10, 20), 75);
    final career = entry(
      'career',
      DateTime(2026, 11),
      99,
      track: ProgressTrack.career,
    );
    final points = [last, first, career, second];
    expect(ProgressAnalytics.history(points, ProgressTrack.academic), [
      first,
      second,
      last,
    ]);
    expect(
      ProgressAnalytics.latest(points, ProgressTrack.academic),
      same(last),
    );
    expect(
      ProgressAnalytics.previous(points, ProgressTrack.academic),
      same(second),
    );
    expect(ProgressAnalytics.previous(points, ProgressTrack.career), isNull);
    expect(ProgressAnalytics.latest([], ProgressTrack.academic), isNull);
    expect(ProgressAnalytics.change(last, second), 15);
    expect(
      points.first,
      same(last),
      reason: 'Analytics must not mutate input order.',
    );
  });

  test('empty averages are zero; populated averages reflect every record', () {
    final points = [
      entry('a', DateTime(2026), 40),
      entry('b', DateTime(2026, 2), 80),
    ];
    expect(ProgressAnalytics.averageScore(points), 60);
    expect(ProgressAnalytics.metricAverage(points, MetricKind.practice), 60);
    expect(ProgressAnalytics.averageScore([]), 0);
    expect(ProgressAnalytics.metricAverage([], MetricKind.knowledge), 0);
  });

  test('unsupported schema versions fail explicitly', () {
    expect(
      () => ProgressData.fromJson({'schemaVersion': 99}),
      throwsFormatException,
    );
  });

  test('restored backups reject duplicate IDs in each collection', () {
    final data = createDemoData(DateTime(2026, 10, 29));
    for (final collection in ['entries', 'goals', 'profiles']) {
      final json = data.toJson();
      final values = json[collection] as List;
      values.add(Map<String, dynamic>.from(values.first as Map));
      expect(
        () => ProgressData.fromJson(json),
        throwsArgumentError,
        reason:
            'Duplicate $collection IDs make selection and deletion ambiguous.',
      );
    }
    expect(
      () => data.copyWith(entries: [data.entries.first, data.entries.first]),
      throwsArgumentError,
      reason: 'Validation also protects controller changes made without JSON.',
    );
  });

  test('restored backups reject blank IDs and required display fields', () {
    final data = createDemoData(DateTime(2026, 10, 29));
    for (final fields in {
      'entries': ['id', 'title'],
      'goals': ['id', 'title'],
      'profiles': ['id', 'name', 'role', 'initials'],
    }.entries) {
      for (final field in fields.value) {
        final json = data.toJson();
        final first = (json[fields.key] as List).first as Map<String, dynamic>;
        first[field] = '   ';
        expect(
          () => ProgressData.fromJson(json),
          throwsArgumentError,
          reason: '${fields.key}.$field must not be blank.',
        );
      }
    }
  });

  test(
    'student name is trimmed and bounded when creating or restoring data',
    () {
      expect(ProgressData(studentName: '  Sam  ').studentName, 'Sam');
      for (final invalid in ['', '   ', List.filled(51, 'x').join()]) {
        expect(() => ProgressData(studentName: invalid), throwsArgumentError);
        final json = createDemoData(DateTime(2026)).toJson();
        json['studentName'] = invalid;
        expect(() => ProgressData.fromJson(json), throwsArgumentError);
      }
    },
  );

  test(
    'required display fields have bounds and stale targets remain valid',
    () {
      final data = createDemoData(DateTime(2026, 10, 29));
      final json = data.toJson();
      (json['entries'] as List).first['title'] = List.filled(101, 'x').join();
      expect(() => ProgressData.fromJson(json), throwsArgumentError);
      expect(
        data.copyWith(targetProfileId: 'removed-profile').targetProfileId,
        'removed-profile',
      );
    },
  );

  test('same-day generated entries sort after their seeded snapshot', () {
    final date = DateTime(2026, 10, 29);
    final demo = entry('demo-academic-12', date, 70);
    final first = entry('entry-1793219400000000', date, 75);
    final second = entry('entry-1793219401000000', date, 80);
    expect(
      ProgressAnalytics.history([second, demo, first], ProgressTrack.academic),
      [demo, first, second],
    );
    expect(
      ProgressAnalytics.latest([second, demo, first], ProgressTrack.academic),
      same(second),
    );
  });
}
