import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/common/app_theme.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';
import 'package:progress_meter/features/routines/presentation/routines_screen.dart';

final _today = DateTime(2026, 10, 29);

class _MemoryRepository implements ProgressRepository {
  _MemoryRepository(this.saved);
  ProgressData saved;
  int writes = 0;
  @override
  Future<ProgressData?> load() async => saved;
  @override
  Future<void> save(ProgressData data) async {
    saved = data;
    writes++;
  }
}

RoutineItem _class(String id, String title, {int start = 540, int end = 600}) =>
    RoutineItem(
      id: id,
      title: title,
      kind: RoutineKind.classSession,
      weekdays: {DateTime.thursday},
      startMinutes: start,
      endMinutes: end,
      location: 'Room B-204',
      instructor: 'Prof. Sharma',
    );

RoutineItem _meal() => RoutineItem(
  id: 'breakfast',
  title: 'Breakfast',
  kind: RoutineKind.meal,
  weekdays: {DateTime.thursday},
  startMinutes: 8 * 60,
  details: 'Oats and fruit',
);

Future<(ProgressController, _MemoryRepository)> _mount(
  WidgetTester tester, {
  ProgressData? data,
  DateTime? today,
  Size size = const Size(1440, 1100),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final repository = _MemoryRepository(
    data ?? ProgressData(studentName: 'Sam'),
  );
  final controller = ProgressController(repository);
  addTearDown(controller.dispose);
  await controller.initialize();
  await tester.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: RoutinesScreen(controller: controller, today: today ?? _today),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (controller, repository);
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _enter(WidgetTester tester, String key, String value) async {
  final finder = find.byKey(Key(key));
  await tester.ensureVisible(finder);
  await tester.enterText(finder, value);
  await tester.pumpAndSettle();
}

Future<void> _menu(WidgetTester tester, String id, String action) async {
  await _tap(tester, find.byKey(ValueKey('routine-menu-$id')));
  await tester.tap(find.text(action));
  await tester.pumpAndSettle();
}

Future<void> _setTime(
  WidgetTester tester,
  String buttonKey,
  int hour,
  int minute,
) async {
  await _tap(tester, find.byKey(Key(buttonKey)));
  final fields = find.descendant(
    of: find.byType(TimePickerDialog),
    matching: find.byType(TextFormField),
  );
  expect(fields, findsNWidgets(2));
  await tester.enterText(fields.at(0), '$hour');
  await tester.enterText(fields.at(1), '$minute');
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'adds a recurring class with a required subject, room, and instructor',
    (tester) async {
      final (controller, repository) = await _mount(tester);
      await _tap(tester, find.byKey(const Key('routine-add-class')));
      expect(find.text('09:00'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);
      await tester.tap(find.byKey(const Key('routine-save')));
      await tester.pumpAndSettle();
      expect(find.text('Please enter a title.'), findsOneWidget);
      expect(repository.writes, 0);
      await _enter(tester, 'routine-title', 'Data structures');
      await _tap(tester, find.byKey(const ValueKey('routine-day-2')));
      await _enter(tester, 'routine-location', 'Room B-204');
      await _enter(tester, 'routine-instructor', 'Prof. Sharma');
      await _enter(
        tester,
        'routine-details',
        'Bring the graph theory worksheet.',
      );
      await _tap(tester, find.byKey(const Key('routine-save')));

      final saved = repository.saved.routines.single;
      expect(saved.kind, RoutineKind.classSession);
      expect(saved.title, 'Data structures');
      expect(saved.weekdays, {DateTime.tuesday, DateTime.thursday});
      expect(saved.startMinutes, 540);
      expect(saved.endMinutes, 600);
      expect(saved.location, 'Room B-204');
      expect(saved.instructor, 'Prof. Sharma');
      expect(saved.details, contains('graph theory'));
      expect(controller.routinesOn(_today).single.id, saved.id);
      expect(repository.writes, 1);
      expect(find.byKey(ValueKey('routine-title-${saved.id}')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'editing a weekly class keeps its identity and earlier dated check-off',
    (tester) async {
      final item = _class('class-a', 'Data structures');
      final completion = RoutineCompletion(
        routineId: item.id,
        dateKey: '2026-10-29',
      );
      final (controller, repository) = await _mount(
        tester,
        data: ProgressData(routines: [item], routineCompletions: [completion]),
      );
      await _menu(tester, item.id, 'Edit routine');
      await _enter(tester, 'routine-title', 'Algorithms');
      await _tap(tester, find.byKey(const ValueKey('routine-day-4')));
      await _tap(tester, find.byKey(const ValueKey('routine-day-5')));
      await _tap(tester, find.byKey(const Key('routine-save')));

      final saved = repository.saved.routines.single;
      expect(saved.id, item.id);
      expect(saved.title, 'Algorithms');
      expect(saved.weekdays, {DateTime.friday});
      expect(controller.routinesOn(_today), isEmpty);
      expect(find.text('1 / 1'), findsOneWidget);
      expect(controller.routineCompleted(item.id, _today), isTrue);
      expect(repository.saved.routineCompletions.single.dateKey, '2026-10-29');
      expect(
        find.text('Completed on this date · weekly plan changed'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Checkbox>(
              find.byKey(ValueKey('routine-complete-${item.id}')),
            )
            .value,
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('plans a meal with menu notes and a chosen time for every day', (
    tester,
  ) async {
    final (_, repository) = await _mount(tester);
    await _tap(tester, find.byKey(const Key('routine-add-meal')));
    await _tap(tester, find.text('Lunch'));
    await _tap(tester, find.text('Every day'));
    await _setTime(tester, 'routine-start-time', 12, 30);
    await _enter(tester, 'routine-location', 'Campus café');
    await _enter(tester, 'routine-details', 'Lentils, rice, and vegetables.');
    await _tap(tester, find.byKey(const Key('routine-save')));

    final meal = repository.saved.routines.single;
    expect(meal.kind, RoutineKind.meal);
    expect(meal.title, 'Lunch');
    expect(meal.weekdays, {1, 2, 3, 4, 5, 6, 7});
    expect(meal.startMinutes, 750);
    expect(meal.endMinutes, isNull);
    expect(meal.details, 'Lentils, rice, and vegetables.');
    expect(meal.location, 'Campus café');
    await _tap(tester, find.byKey(const Key('routine-tab-food')));
    expect(find.byKey(ValueKey('routine-title-${meal.id}')), findsOneWidget);
    expect(find.text('Your weekly food routine'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'check-offs belong to one date and future occurrences remain planned',
    (tester) async {
      final item = _class('class-a', 'Algorithms');
      final (controller, repository) = await _mount(
        tester,
        data: ProgressData(routines: [item]),
      );
      final checkbox = find.byKey(ValueKey('routine-complete-${item.id}'));
      await _tap(tester, checkbox);
      expect(controller.routineCompleted(item.id, _today), isTrue);
      expect(repository.saved.routineCompletions.single.dateKey, '2026-10-29');

      await _tap(tester, find.byKey(const Key('routine-prev-week')));
      expect(
        find.byKey(const ValueKey('routine-date-2026-10-22')),
        findsOneWidget,
      );
      expect(tester.widget<Checkbox>(checkbox).value, isFalse);
      await _tap(tester, find.byKey(const Key('routine-next-week')));
      await _tap(tester, find.byKey(const Key('routine-next-week')));
      expect(
        find.byKey(const ValueKey('routine-date-2026-11-05')),
        findsOneWidget,
      );
      expect(tester.widget<Checkbox>(checkbox).onChanged, isNull);
      expect(repository.saved.routineCompletions, hasLength(1));

      await _tap(tester, find.byKey(const Key('routine-jump-today')));
      expect(tester.widget<Checkbox>(checkbox).value, isTrue);
      await _tap(tester, checkbox);
      expect(repository.saved.routineCompletions, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('class overlaps are flagged and deletion requires confirmation', (
    tester,
  ) async {
    final first = _class('class-a', 'Algorithms', start: 480, end: 600);
    final second = _class('class-b', 'Databases', start: 540, end: 660);
    final meal = _meal();
    final (controller, repository) = await _mount(
      tester,
      data: ProgressData(
        routines: [first, second, meal],
        routineCompletions: [
          RoutineCompletion(routineId: first.id, dateKey: '2026-10-29'),
          RoutineCompletion(routineId: meal.id, dateKey: '2026-10-29'),
        ],
      ),
    );
    expect(find.text('TIME OVERLAP'), findsNWidgets(2));
    await _menu(tester, first.id, 'Delete routine');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(controller.data.routines, hasLength(3));
    expect(repository.writes, 0);

    await _menu(tester, first.id, 'Delete routine');
    await tester.tap(find.byKey(const Key('routine-delete-confirm')));
    await tester.pumpAndSettle();
    expect(
      controller.data.routines.map((item) => item.id),
      unorderedEquals([second.id, meal.id]),
    );
    expect(repository.saved.routineCompletions.single.routineId, meal.id);
    expect(find.text('TIME OVERLAP'), findsNothing);
    expect(repository.writes, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'daily, class, food, and meal dialog layouts fit a narrow viewport',
    (tester) async {
      final (_, repository) = await _mount(tester, size: const Size(390, 844));
      expect(
        find.byKey(const ValueKey('routine-date-2026-10-29')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byKey(const Key('routine-tab-classes')));
      expect(find.text('Your recurring classes'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('routine-add-class')));
      await _tap(tester, find.byKey(const Key('routine-save')));
      expect(find.text('Please enter a title.'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      await _tap(tester, find.byKey(const Key('routine-tab-food')));
      expect(find.text('Your weekly food routine'), findsOneWidget);
      await _tap(tester, find.byKey(const Key('routine-add-meal')));
      await _enter(tester, 'routine-details', 'A meal I look forward to.');
      await _tap(tester, find.byKey(const Key('routine-save')));
      expect(repository.saved.routines.single.kind, RoutineKind.meal);
      expect(tester.takeException(), isNull);
      await _tap(tester, find.byKey(const Key('routine-tab-today')));
      expect(
        find.byKey(
          ValueKey('routine-complete-${repository.saved.routines.single.id}'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'calendar boundary days cannot select dates outside the picker range',
    (tester) async {
      await _mount(tester, today: DateTime(2000, 1, 1));
      final unavailable = find.byKey(const ValueKey('routine-date-1999-12-31'));
      expect(tester.widget<InkWell>(unavailable).onTap, isNull);
      await _tap(tester, find.byKey(const Key('routine-pick-date')));
      expect(find.byType(DatePickerDialog), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    },
  );
}
