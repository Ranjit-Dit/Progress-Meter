import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:progress_meter/app/progress_controller.dart';
import 'package:progress_meter/common/app_theme.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/progress/data/progress_repository.dart';
import 'package:progress_meter/features/notifications/domain/reminder_settings.dart';
import 'package:progress_meter/features/notifications/domain/reminder_plan.dart';
import 'package:progress_meter/features/notifications/data/reminder_service.dart';
import 'package:progress_meter/features/notifications/application/notification_controller.dart';
import 'package:progress_meter/features/notifications/presentation/notification_settings_card.dart';
import 'package:progress_meter/features/routines/domain/routine_models.dart';
import 'package:progress_meter/features/routines/domain/daily_task.dart';

class _Store implements ProgressRepository {
  _Store(this.data);
  ProgressData data;
  @override
  Future<ProgressData?> load() async => data;
  @override
  Future<void> save(ProgressData d) async => data = d;
}

class _Service implements ReminderService {
  int permissions = 0, tests = 0;
  bool authorized = false;
  bool permissionFails = false;
  List<PlannedReminder> pending = [];
  @override
  Future<ReminderStatus> status() async => ReminderStatus(
    authorized
        ? ReminderAuthorization.authorized
        : ReminderAuthorization.notDetermined,
    pendingCount: pending.length,
  );
  @override
  Future<bool> requestPermission() async {
    permissions++;
    if (permissionFails) throw StateError('OS permission service unavailable');
    authorized = true;
    return true;
  }

  @override
  Future<int> replacePlan(List<PlannedReminder> p) async {
    pending = List.of(p);
    return p.length;
  }

  @override
  Future<void> sendTest() async {
    tests++;
  }

  @override
  Future<void> openSettings() async {}
}

void main() {
  test('weekly reminders handle lead time crossing midnight and Sunday', () {
    final plan = ReminderPlanner.build(
      routines: [
        RoutineItem(
          id: 'monday',
          title: 'Early class',
          kind: RoutineKind.classSession,
          weekdays: {1},
          startMinutes: 5,
          endMinutes: 55,
        ),
      ],
      tasks: [],
      settings: const ReminderSettings(enabled: true, leadMinutes: 10),
      now: DateTime(2026, 10, 25, 12),
    );
    final r = plan.reminders.single;
    expect(r.weekday, 7);
    expect(r.nextFire, DateTime(2026, 10, 25, 23, 55));
  });
  test('dated reminders ignore untimed, completed and past tasks and fall back to event time', () {
    final now = DateTime(2026, 10, 30, 9, 55);
    final tasks = [
      DailyTask(
        id: 'upcoming',
        title: 'Do work',
        dateKey: '2026-10-30',
        timeMinutes: 600,
      ),
      DailyTask(id: 'untimed', title: 'Notes', dateKey: '2026-10-30'),
      DailyTask(
        id: 'done',
        title: 'Done',
        dateKey: '2026-10-30',
        timeMinutes: 700,
        completed: true,
      ),
      DailyTask(
        id: 'past',
        title: 'Past',
        dateKey: '2026-10-29',
        timeMinutes: 600,
      ),
    ];
    final plan = ReminderPlanner.build(
      routines: [],
      tasks: tasks,
      settings: const ReminderSettings(enabled: true),
      now: now,
    );
    expect(plan.reminders.length, 1);
    expect(plan.reminders.single.nextFire, DateTime(2026, 10, 30, 10));
    expect(
      ReminderPlanner.build(
        routines: [],
        tasks: tasks,
        settings: const ReminderSettings(),
        now: now,
      ).reminders,
      isEmpty,
    );
  });
  test('reminder plans have stable IDs and bound the OS schedule', () {
    final tasks = [
      for (var i = 0; i < 70; i++)
        DailyTask(
          id: 'task-$i',
          title: 'Task $i',
          dateKey: '2026-11-01',
          timeMinutes: 600 + i,
        ),
    ];
    final p = ReminderPlanner.build(
      routines: [],
      tasks: tasks,
      settings: const ReminderSettings(enabled: true),
      now: DateTime(2026, 10, 30),
    );
    expect(p.reminders.length, 64);
    expect(p.truncatedCount, 6);
    expect(p.reminders.map((r) => r.id).toSet().length, 64);
    final edited = tasks.first.copyWith(timeMinutes: 800);
    final second = ReminderPlanner.build(
      routines: [],
      tasks: [edited],
      settings: const ReminderSettings(enabled: true),
      now: DateTime(2026, 10, 30),
    );
    expect(second.reminders.single.id, p.reminders.first.id);
  });
  test('initialization never prompts; enabling and schedule edits reconcile without duplicate reminders', () async {
    final task = DailyTask(
      id: 'future',
      title: 'Upcoming work',
      dateKey: '2099-11-01',
      timeMinutes: 600,
    );
    final progress = ProgressController(
      _Store(ProgressData(dailyTasks: [task])),
    );
    await progress.initialize();
    addTearDown(progress.dispose);
    final service = _Service();
    final c = NotificationController(progress: progress, service: service);
    addTearDown(c.dispose);
    await c.initialize();
    expect(service.permissions, 0);
    expect(service.pending, isEmpty);
    await c.setEnabled(true);
    expect(service.permissions, 1);
    expect(service.pending.length, 1);
    expect(progress.data.reminderSettings.enabled, isTrue);
    await progress.upsertDailyTask(task.copyWith(timeMinutes: 700));
    await c.refresh();
    expect(service.pending.length, 1);
    expect(service.pending.single.nextFire.hour, 11);
    await progress.deleteDailyTask(task.id);
    await c.refresh();
    expect(service.pending, isEmpty);
    await c.setEnabled(false);
    expect(service.pending, isEmpty);
  });
  test('reminder settings persist and invalid values cannot replace saved preferences', () async {
    final p = ProgressController(_Store(ProgressData()));
    await p.initialize();
    addTearDown(p.dispose);
    await p.updateReminderSettings(
      const ReminderSettings(enabled: true, leadMinutes: 15),
    );
    final restored = ProgressData.fromJson(p.data.toJson());
    expect(restored.reminderSettings.enabled, isTrue);
    expect(restored.reminderSettings.leadMinutes, 15);
    expect(
      () => ReminderSettings.fromJson({'enabled': true, 'leadMinutes': 100}),
      throwsFormatException,
    );
  });
  test(
    'OS permission failures keep reminders off and expose Settings recovery',
    () async {
      final p = ProgressController(_Store(ProgressData()));
      await p.initialize();
      addTearDown(p.dispose);
      final service = _Service()..permissionFails = true;
      final c = NotificationController(progress: p, service: service);
      addTearDown(c.dispose);
      await c.initialize();
      await c.setEnabled(true);
      expect(p.data.reminderSettings.enabled, isFalse);
      expect(c.permissionProblem, isTrue);
      expect(c.error, contains('macOS Settings'));
      expect(c.busy, isFalse);
      service.permissionFails = false;
      await c.setEnabled(true);
      expect(p.data.reminderSettings.enabled, isTrue);
      expect(c.permissionProblem, isFalse);
    },
  );
  testWidgets(
    'notification controls fit a narrow settings panel and use an explicit permission action',
    (t) async {
      t.view.physicalSize = const Size(390, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final p = ProgressController(_Store(ProgressData()));
      await p.initialize();
      addTearDown(p.dispose);
      final service = _Service();
      final c = NotificationController(progress: p, service: service);
      addTearDown(c.dispose);
      await c.initialize();
      await t.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: NotificationSettingsCard(controller: c),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(service.permissions, 0);
      expect(t.takeException(), isNull);
      await t.tap(find.byKey(const Key('notifications-enabled')));
      await t.pumpAndSettle();
      expect(service.permissions, 1);
      expect(p.data.reminderSettings.enabled, isTrue);
    },
  );
}
