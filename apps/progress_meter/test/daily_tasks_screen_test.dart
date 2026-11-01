import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/common/app_theme.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/routines/domain/daily_task.dart';
import 'package:progress_meter/features/routines/presentation/routines_screen.dart';

final _today = DateTime(2026, 10, 30);

class _Store implements ProgressRepository {
  _Store(this.data);
  ProgressData data;
  bool fail = false;
  @override
  Future<ProgressData?> load() async => data;
  @override
  Future<void> save(ProgressData next) async {
    if (fail) throw StateError('disk full');
    data = next;
  }
}

Future<(ProgressController, _Store)> _mount(
  WidgetTester t, {
  List<DailyTask> tasks = const [],
  Size size = const Size(1200, 1100),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final store = _Store(ProgressData(dailyTasks: tasks));
  final controller = ProgressController(store);
  await controller.initialize();
  addTearDown(controller.dispose);
  await t.pumpWidget(
    MaterialApp(
      theme: buildTheme(),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: RoutinesScreen(controller: controller, today: _today),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return (controller, store);
}

Future<void> _tap(WidgetTester t, Finder finder) async {
  await t.ensureVisible(finder);
  await t.pumpAndSettle();
  await t.tap(finder);
  await t.pumpAndSettle();
}

void main() {
  testWidgets(
    'adds an exact-date task, checks it off and keeps it off the following week',
    (t) async {
      final (controller, _) = await _mount(t);
      await _tap(t, find.byKey(const Key('task-add')));
      await _tap(t, find.byKey(const Key('task-save')));
      expect(find.text('Please enter a task title.'), findsOneWidget);
      await t.enterText(
        find.byKey(const Key('task-title')),
        'Finish assignment',
      );
      await t.enterText(
        find.byKey(const Key('task-notes')),
        'Solve exercise 4 and submit it.',
      );
      await _tap(t, find.byKey(const Key('task-save')));
      final task = controller.data.dailyTasks.single;
      expect(task.dateKey, '2026-10-30');
      expect(task.timeMinutes, isNull);
      expect(find.text('Finish assignment'), findsOneWidget);
      await _tap(t, find.byKey(ValueKey('task-toggle-${task.id}')));
      expect(controller.data.dailyTasks.single.completed, isTrue);
      expect(find.text('1 / 1 done · 0 to do'), findsOneWidget);
      await _tap(t, find.byKey(const Key('routine-tab-tasks')));
      await _tap(t, find.byKey(const Key('routine-next-week')));
      expect(find.byKey(const Key('tasks-empty')), findsOneWidget);
      expect(find.text('Finish assignment'), findsNothing);
      expect(controller.data.dailyTasks.single.completed, isTrue);
    },
  );
  testWidgets(
    'future task cannot be checked off and deleting asks for confirmation',
    (t) async {
      final task = DailyTask(
        id: 'future',
        title: 'Read next chapter',
        dateKey: '2026-11-06',
      );
      final (controller, _) = await _mount(t, tasks: [task]);
      await _tap(t, find.byKey(const Key('routine-tab-tasks')));
      await _tap(t, find.byKey(const Key('routine-next-week')));
      final checkbox = t.widget<Checkbox>(
        find.byKey(const ValueKey('task-toggle-future')),
      );
      expect(checkbox.onChanged, isNull);
      await _tap(t, find.byKey(const ValueKey('task-menu-future')));
      await _tap(t, find.text('Delete task'));
      expect(controller.data.dailyTasks, hasLength(1));
      await _tap(t, find.byKey(const Key('task-delete-confirm')));
      expect(controller.data.dailyTasks, isEmpty);
    },
  );
  testWidgets('failed save keeps the task draft available for retry', (
    t,
  ) async {
    final (controller, store) = await _mount(t);
    await _tap(t, find.byKey(const Key('task-add')));
    await t.enterText(find.byKey(const Key('task-title')), 'Practice graphs');
    store.fail = true;
    await _tap(t, find.byKey(const Key('task-save')));
    expect(find.byKey(const Key('task-save-error')), findsOneWidget);
    expect(find.text('Practice graphs'), findsOneWidget);
    expect(controller.data.dailyTasks, isEmpty);
    store.fail = false;
    await _tap(t, find.byKey(const Key('task-save')));
    expect(controller.data.dailyTasks.single.title, 'Practice graphs');
    expect(find.byKey(const Key('task-save-error')), findsNothing);
  });
  testWidgets('task forms and lists fit a narrow window with optional time', (
    t,
  ) async {
    await _mount(t, size: const Size(440, 800));
    await _tap(t, find.byKey(const Key('routine-tab-tasks')));
    await _tap(t, find.byKey(const Key('task-add')));
    await t.enterText(
      find.byKey(const Key('task-title')),
      'Study for tomorrow',
    );
    await _tap(t, find.byKey(const Key('task-time')));
    final fields = find.descendant(
      of: find.byType(TimePickerDialog),
      matching: find.byType(TextFormField),
    );
    await t.enterText(fields.at(0), '14');
    await t.enterText(fields.at(1), '30');
    await _tap(t, find.text('OK'));
    expect(find.text('14:30'), findsOneWidget);
    await _tap(t, find.byKey(const Key('task-clear-time')));
    expect(find.text('Any time'), findsOneWidget);
    await _tap(t, find.byKey(const Key('task-save')));
    expect(t.takeException(), isNull);
    expect(find.text('Study for tomorrow'), findsOneWidget);
  });
}
