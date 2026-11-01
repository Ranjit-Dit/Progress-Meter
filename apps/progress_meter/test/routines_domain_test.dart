import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/features/progress/data/demo_data.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/routines/domain/routine_analytics.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';

RoutineItem _class(
  String id, {
  Set<int> days = const {1, 3},
  int start = 540,
  int end = 600,
}) => RoutineItem(
  id: id,
  title: 'Algorithms',
  kind: RoutineKind.classSession,
  weekdays: days,
  startMinutes: start,
  endMinutes: end,
  location: 'Room 203',
  instructor: 'Dr Shah',
  details: 'Bring the lab notebook',
);
RoutineItem _meal(
  String id, {
  Set<int> days = const {1, 2, 3, 4, 5, 6, 7},
  int time = 480,
}) => RoutineItem(
  id: id,
  title: 'Breakfast',
  kind: RoutineKind.meal,
  weekdays: days,
  startMinutes: time,
  details: 'Toast and fruit',
);

void main() {
  test('weekly routines are immutable and preserve all fields in JSON', () {
    final days = <int>{5, 1, 3};
    final item = _class('algorithms', days: days);
    days.add(6);
    expect(item.weekdays, {1, 3, 5});
    expect(() => item.weekdays.add(7), throwsUnsupportedError);
    expect(item.toJson()['weekdays'], [1, 3, 5]);
    final restored = RoutineItem.fromJson(
      jsonDecode(jsonEncode(item.toJson())) as Map<String, dynamic>,
    );
    expect(restored.toJson(), item.toJson());
    final edited = restored.copyWith(
      title: ' Advanced algorithms ',
      startMinutes: 600,
      endMinutes: 660,
      weekdays: {2},
      details: '',
      location: '',
      instructor: 'Dr Lee',
    );
    expect(edited.id, item.id);
    expect(edited.kind, RoutineKind.classSession);
    expect(edited.title, 'Advanced algorithms');
    expect(edited.weekdays, {2});
    expect(edited.details, isEmpty);
    expect(edited.location, isEmpty);
    expect(edited.instructor, 'Dr Lee');
    expect(item.startMinutes, 540);
    expect(
      RoutineItem.fromJson(_meal('breakfast').toJson()).endMinutes,
      isNull,
    );
  });

  test(
    'invalid recurrence, class intervals, and meal intervals are rejected',
    () {
      for (final days in <Set<int>>[
        {},
        {0},
        {8},
        {1, -1},
      ]) {
        expect(() => _class('bad', days: days), throwsArgumentError);
      }
      for (final (start, end) in [
        (-1, 600),
        (1440, 1450),
        (600, 600),
        (610, 600),
        (600, 1440),
      ]) {
        expect(
          () => _class('bad', start: start, end: end),
          throwsArgumentError,
        );
      }
      expect(
        () => RoutineItem(
          id: 'bad',
          title: 'No end',
          kind: RoutineKind.classSession,
          weekdays: {1},
          startMinutes: 600,
        ),
        throwsArgumentError,
      );
      expect(
        () => RoutineItem(
          id: 'bad',
          title: 'Food',
          kind: RoutineKind.meal,
          weekdays: {1},
          startMinutes: 600,
          endMinutes: 630,
        ),
        throwsArgumentError,
      );
      expect(_meal('late', time: 1439).startMinutes, 1439);
      final malformed = _class('bad').toJson()..['weekdays'] = [1, 1];
      expect(() => RoutineItem.fromJson(malformed), throwsFormatException);
    },
  );

  test('required and optional fields have safe bounds', () {
    for (final title in ['', '  ', List.filled(101, 'x').join()]) {
      expect(() => _class('one').copyWith(title: title), throwsArgumentError);
    }
    expect(() => _class(' '), throwsArgumentError);
    expect(
      () => _meal('meal').copyWith(details: List.filled(1201, 'x').join()),
      throwsArgumentError,
    );
    expect(
      () => _class('one').copyWith(location: List.filled(161, 'x').join()),
      throwsArgumentError,
    );
    expect(
      () => _class('one').copyWith(instructor: List.filled(161, 'x').join()),
      throwsArgumentError,
    );
  });

  test(
    'date filtering sorts times without mutating input or showing other days',
    () {
      final lunch = _meal('lunch', time: 780);
      final late = _class('late', start: 660, end: 720);
      final early = _class('early');
      final tuesday = _class('tuesday', days: {2});
      final source = [lunch, late, tuesday, early];
      expect(RoutineAnalytics.forDate(source, DateTime(2026, 10, 26)), [
        early,
        late,
        lunch,
      ]);
      expect(source.first, same(lunch));
      expect(RoutineAnalytics.forDate(source, DateTime(2026, 10, 27)), [
        tuesday,
        lunch,
      ]);
    },
  );

  test('class conflicts use shared days and half-open intervals', () {
    final base = _class('base');
    final overlap = _class('overlap', days: {3}, start: 570, end: 630);
    final adjacent = _class('adjacent', start: 600, end: 660);
    final separateDay = _class('other-day', days: {2}, start: 540, end: 600);
    final encompassing = _class('long', start: 500, end: 660);
    final meal = _meal('food', time: 560);
    expect(
      RoutineAnalytics.conflicts(base, [
        base,
        adjacent,
        separateDay,
        meal,
        overlap,
        encompassing,
      ]),
      [encompassing, overlap],
    );
    expect(RoutineAnalytics.conflicts(meal, [base]), isEmpty);
    expect(
      RoutineAnalytics.conflicts(base, [base.copyWith(title: 'Edited')]),
      isEmpty,
    );
  });

  test(
    'completions belong to exact dates, not all occurrences of a weekday',
    () {
      final monday = DateTime(2026, 10, 26);
      final nextMonday = DateTime(2026, 11, 2);
      final item = _class('one');
      final completions = [
        RoutineCompletion(routineId: item.id, dateKey: routineDateKey(monday)),
      ];
      expect(RoutineAnalytics.isCompleted(completions, 'one', monday), isTrue);
      expect(
        RoutineAnalytics.isCompleted(completions, 'one', nextMonday),
        isFalse,
      );
      expect(RoutineAnalytics.completedCount([item], completions, monday), 1);
      expect(
        RoutineAnalytics.completedCount([item], completions, nextMonday),
        0,
      );
      expect(
        RoutineCompletion.fromJson(completions.single.toJson()).key,
        completions.single.key,
      );
    },
  );

  test('completion dates reject impossible or noncanonical date strings', () {
    for (final date in [
      '2026-02-29',
      '2026-13-01',
      '2026-00-01',
      '2026-01-00',
      '2026-1-2',
      '2026-01-01T00:00:00',
      '0000-01-01',
      'not-a-date',
    ]) {
      expect(
        () => RoutineCompletion(routineId: 'one', dateKey: date),
        throwsArgumentError,
        reason: date,
      );
    }
    expect(
      RoutineCompletion(routineId: 'one', dateKey: '2024-02-29').date,
      DateTime(2024, 2, 29),
    );
    expect(routineDateKey(DateTime(2026, 1, 2, 23, 59)), '2026-01-02');
    expect(routineDate(DateTime(2026, 10, 29, 16)), DateTime(2026, 10, 29));
    expect(
      RoutineAnalytics.weekStart(DateTime(2026, 11, 1, 18)),
      DateTime(2026, 10, 26),
    );
  });

  test(
    'schema one backups migrate without inventing routines or losing progress',
    () {
      final original = createDemoData(DateTime(2026, 10, 29));
      final legacy = original.toJson()
        ..['schemaVersion'] = 1
        ..remove('routines')
        ..remove('routineCompletions');
      final restored = ProgressData.fromJson(legacy);
      expect(restored.entries.length, original.entries.length);
      expect(
        restored.goals.map((goal) => goal.toJson()),
        original.goals.map((goal) => goal.toJson()),
      );
      expect(restored.studentName, original.studentName);
      expect(restored.targetProfileId, original.targetProfileId);
      expect(restored.routines, isEmpty);
      expect(restored.routineCompletions, isEmpty);
      expect(restored.toJson()['schemaVersion'], 6);
    },
  );

  test('schema two round trip and copyWith retain all routine records', () {
    final routines = [_class('class'), _meal('meal')];
    final completions = [
      RoutineCompletion(routineId: 'class', dateKey: '2026-10-26'),
      RoutineCompletion(routineId: 'meal', dateKey: '2026-10-27'),
    ];
    final data = createDemoData(DateTime(2026, 10, 29))
        .copyWith(routines: routines, routineCompletions: completions);
    final restored = ProgressData.fromJson(
      jsonDecode(jsonEncode(data.toJson())) as Map<String, dynamic>,
    );
    expect(restored.toJson(), data.toJson());
    expect(restored.copyWith(studentName: 'Sam').routines.length, 2);
    expect(restored.copyWith(entries: []).routineCompletions.length, 2);
    expect(() => restored.routines.add(_meal('new')), throwsUnsupportedError);
    expect(() => restored.routineCompletions.clear(), throwsUnsupportedError);
    expect(
      restored.copyWith(routineCompletions: []).routineCompletions,
      isEmpty,
    );
  });

  test('malformed backups reject duplicate and dangling routine data', () {
    final item = _class('one');
    final completion = RoutineCompletion(
      routineId: 'one',
      dateKey: '2026-10-26',
    );
    expect(() => ProgressData(routines: [item, item]), throwsArgumentError);
    expect(
      () => ProgressData(
        routines: [item],
        routineCompletions: [completion, completion],
      ),
      throwsArgumentError,
    );
    expect(
      () => ProgressData(routineCompletions: [completion]),
      throwsArgumentError,
    );
    final json = ProgressData(routines: [item]).toJson();
    (json['routines'] as List).first['startMinutes'] = -5;
    expect(() => ProgressData.fromJson(json), throwsArgumentError);
    final missing = ProgressData().toJson()..remove('routines');
    expect(() => ProgressData.fromJson(missing), throwsA(anything));
  });

  test('changing recurrence preserves dated historical completion records', () {
    final monday = _class('one', days: {1});
    final completion = RoutineCompletion(
      routineId: 'one',
      dateKey: '2026-10-26',
    );
    final data = ProgressData(
      routines: [monday],
      routineCompletions: [completion],
    );
    final edited = data.copyWith(
      routines: [
        monday.copyWith(weekdays: {2}),
      ],
    );
    expect(edited.routineCompletions.single.key, completion.key);
    expect(RoutineAnalytics.forDate(edited.routines, completion.date), isEmpty);
    expect(
      RoutineAnalytics.isCompleted(
        edited.routineCompletions,
        'one',
        completion.date,
      ),
      isTrue,
    );
  });
}
