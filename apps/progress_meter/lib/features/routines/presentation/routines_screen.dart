import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/progress_controller.dart';
import '../../../common/app_theme.dart';
import '../domain/routine_models.dart';
import '../domain/daily_task.dart';
import '../domain/routine_analytics.dart';
import 'routine_dialog.dart';
import 'daily_task_dialog.dart';
import 'daily_tasks_section.dart';
import '../../routine_import/presentation/routine_import_dialog.dart';

const routineWeekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
String routineClock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';
String routineDays(Set<int> days) {
  if (days.length == 7) return 'Every day';
  if (days.length == 5 && days.every((d) => d <= 5)) return 'Mon–Fri';
  final sorted = days.toList()..sort();
  return sorted.map((d) => routineWeekdays[d - 1].substring(0, 3)).join(' · ');
}

String routineDateLabel(DateTime date) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

class RoutinesScreen extends StatefulWidget {
  const RoutinesScreen({super.key, required this.controller, this.today});
  final ProgressController controller;
  final DateTime? today;
  @override
  State<RoutinesScreen> createState() => _RoutinesScreenState();
}

class _RoutinesScreenState extends State<RoutinesScreen> {
  ProgressController get c => widget.controller;
  DateTime get today => routineDate(widget.today ?? DateTime.now());
  late DateTime selected = today;
  int view = 0;
  bool _available(DateTime date) =>
      !date.isBefore(DateTime(2000)) && !date.isAfter(DateTime(2100, 12, 31));

  Future<void> _edit(RoutineKind kind, [RoutineItem? existing]) async {
    final result = await showRoutineDialog(
      context,
      kind: kind,
      weekday: selected.weekday,
      existing: existing,
      siblings: c.data.routines,
    );
    if (result != null && mounted) {
      await _save(
        () => c.upsertRoutine(result),
        existing == null
            ? '${kind.label} routine added.'
            : 'Your weekly routine has been updated.',
      );
    }
  }

  Future<void> _editTask([DailyTask? existing]) async {
    final result = await showDailyTaskDialog(
      context,
      date: selected,
      existing: existing,
      onSave: c.upsertDailyTask,
    );
    if (result != null && mounted) {
      setState(() {
        selected = result.date;
        if (view != 0 && view != 3) view = 3;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null ? 'Task added to your day.' : 'Task updated.',
          ),
        ),
      );
    }
  }

  Future<void> _taskAction(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this task. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _deleteTask(DailyTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete this task?'),
        content: Text(
          '“${task.title}” will be removed from this date. Other tasks and routines are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('task-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete task'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await _taskAction(() => c.deleteDailyTask(task.id));
    }
  }

  Widget _tasks() => DailyTasksSection(
    tasks: c.tasksOn(selected),
    date: selected,
    today: today,
    saving: c.saving,
    onAdd: _editTask,
    onEdit: _editTask,
    onToggle: (task) =>
        _taskAction(() => c.toggleDailyTask(task.id, now: today)),
    onDelete: _deleteTask,
  );

  Future<void> _save(Future<void> Function() action, String message) async {
    try {
      await action();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your routine. Please try again.'),
          ),
        );
      }
    }
  }

  Future<void> _import() async {
    final ids = await showRoutineImportDialog(
      context,
      controller: c,
      initialKind: view == 2 ? RoutineKind.meal : RoutineKind.classSession,
    );
    if (!mounted || ids == null || ids.isEmpty) return;
    final first = c.data.routines.where((r) => r.id == ids.first).firstOrNull;
    setState(() => view = first?.kind == RoutineKind.meal ? 2 : 1);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${ids.length} routines added to your week.'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => _save(
            () => c.undoRoutineImport(ids.toSet()),
            'Imported routines removed.',
          ),
        ),
      ),
    );
  }

  Future<void> _delete(RoutineItem item) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Delete this weekly routine?'),
        content: SizedBox(
          width: 380,
          child: Text(
            '“${item.title}” and its date-specific check-offs will be removed. Your other routines and progress will be kept.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('routine-delete-confirm'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete routine'),
          ),
        ],
      ),
    );
    if (result == true && mounted) {
      await _save(() => c.deleteRoutine(item.id), 'Routine deleted.');
    }
  }

  void _shiftWeek(int amount) => setState(
    () => selected = DateTime(
      selected.year,
      selected.month,
      selected.day + amount * 7,
    ),
  );
  void _showDay(int weekday) {
    final start = RoutineAnalytics.weekStart(selected);
    setState(() {
      selected = DateTime(start.year, start.month, start.day + weekday - 1);
      view = 0;
    });
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: selected.isBefore(DateTime(2000))
          ? DateTime(2000)
          : selected.isAfter(DateTime(2100, 12, 31))
          ? DateTime(2100, 12, 31)
          : selected,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      helpText: 'Choose a routine date',
    );
    if (result != null && mounted) {
      setState(() {
        selected = routineDate(result);
        if (view != 3) view = 0;
      });
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 16,
          children: [
            SizedBox(
              width: math.min(MediaQuery.sizeOf(context).width - 40, 650),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'MAKE ROOM FOR A GOOD DAY',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Text(
                    'A rhythm that works for you.',
                    style: Theme.of(context).textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Plan your classes, meals, and daily tasks. Build your week, one day at a time.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.7,
                    ),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  key: const Key('task-add'),
                  onPressed: c.saving ? null : _editTask,
                  icon: const Icon(Icons.add_task_outlined, size: 17),
                  label: const Text('Add task'),
                ),
                OutlinedButton.icon(
                  key: const Key('routine-import'),
                  onPressed: c.saving ? null : _import,
                  icon: const Icon(Icons.upload_file_outlined, size: 17),
                  label: const Text('Import file'),
                ),
                OutlinedButton.icon(
                  key: const Key('routine-add-meal'),
                  onPressed: c.saving ? null : () => _edit(RoutineKind.meal),
                  icon: const Icon(Icons.restaurant_outlined, size: 16),
                  label: const Text('Plan a meal'),
                ),
                FilledButton.icon(
                  key: const Key('routine-add-class'),
                  onPressed: c.saving
                      ? null
                      : () => _edit(RoutineKind.classSession),
                  icon: const Icon(Icons.add_rounded, size: 17),
                  label: const Text('Add a class'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 25),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, label, icon, key) in [
              (0, 'Daily routine', Icons.today_outlined, 'today'),
              (1, 'Class routine', Icons.school_outlined, 'classes'),
              (2, 'Food routine', Icons.restaurant_outlined, 'food'),
              (3, 'Daily tasks', Icons.checklist_rounded, 'tasks'),
            ])
              ChoiceChip(
                key: ValueKey('routine-tab-$key'),
                avatar: Icon(
                  icon,
                  size: 16,
                  color: view == index ? AppColors.green : AppColors.muted,
                ),
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: view == index,
                onSelected: (_) => setState(() => view = index),
              ),
          ],
        ),
        const SizedBox(height: 24),
        if (view == 0 || view == 3) ...[
          _dateStrip(),
          const SizedBox(height: 21),
          if (view == 0) _dailyView() else _tasks(),
        ] else
          _weeklyPlan(view == 1 ? RoutineKind.classSession : RoutineKind.meal),
        const SizedBox(height: 22),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: AppColors.muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Classes and meals repeat weekly. Tasks belong to one calendar date. Check-offs are saved on this device, separately from progress scores and AI Coach context.',
                style: TextStyle(
                  fontSize: 10,
                  height: 1.7,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _panel(
    Widget child, {
    Color color = Colors.white,
    EdgeInsets padding = const EdgeInsets.all(23),
  }) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: AppColors.line),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );

  Widget _dateStrip() {
    final monday = RoutineAnalytics.weekStart(selected);
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${routineWeekdays[selected.weekday - 1]}, ${routineDateLabel(selected)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -.3,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    '${routineDateLabel(monday)} – ${routineDateLabel(sunday)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const Key('routine-prev-week'),
                    tooltip: 'Previous week',
                    onPressed:
                        _available(
                          DateTime(
                            selected.year,
                            selected.month,
                            selected.day - 7,
                          ),
                        )
                        ? () => _shiftWeek(-1)
                        : null,
                    icon: const Icon(Icons.chevron_left, size: 19),
                  ),
                  TextButton(
                    key: const Key('routine-jump-today'),
                    onPressed: () => setState(() => selected = today),
                    child: const Text('Today'),
                  ),
                  IconButton(
                    key: const Key('routine-next-week'),
                    tooltip: 'Next week',
                    onPressed:
                        _available(
                          DateTime(
                            selected.year,
                            selected.month,
                            selected.day + 7,
                          ),
                        )
                        ? () => _shiftWeek(1)
                        : null,
                    icon: const Icon(Icons.chevron_right, size: 19),
                  ),
                  IconButton(
                    key: const Key('routine-pick-date'),
                    tooltip: 'Choose a date',
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_outlined, size: 18),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                for (int index = 0; index < 7; index++) ...[
                  if (index > 0) const SizedBox(width: 6),
                  Expanded(
                    child: _dayButton(
                      DateTime(monday.year, monday.month, monday.day + index),
                      compact: box.maxWidth < 480,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayButton(DateTime date, {required bool compact}) {
    final active = routineDateKey(selected) == routineDateKey(date);
    final items = c.routinesOn(date);
    final tasks = c.tasksOn(date);
    final isToday = routineDateKey(date) == routineDateKey(today);
    return Semantics(
      selected: active,
      label:
          '${routineWeekdays[date.weekday - 1]}, ${routineDateLabel(date)}, ${items.length + tasks.length} planned',
      child: Material(
        color: active ? AppColors.green : AppColors.background,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          key: ValueKey('routine-date-${routineDateKey(date)}'),
          borderRadius: BorderRadius.circular(10),
          onTap: _available(date)
              ? () => setState(() => selected = date)
              : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 11),
            child: Column(
              children: [
                Text(
                  compact
                      ? routineWeekdays[date.weekday - 1][0]
                      : routineWeekdays[date.weekday - 1].substring(0, 3),
                  style: TextStyle(
                    fontSize: 10,
                    color: active ? Colors.white70 : AppColors.muted,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  '${date.day}',
                  style: TextStyle(
                    fontSize: compact ? 16 : 17,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.white : AppColors.ink,
                  ),
                ),
                const SizedBox(height: 7),
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isToday || items.isNotEmpty || tasks.isNotEmpty
                        ? active
                              ? Colors.white
                              : AppColors.green
                        : Colors.transparent,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _dailyView() {
    final due = c.routinesOn(selected);
    final historical = c.data.routines
        .where(
          (item) =>
              !item.weekdays.contains(selected.weekday) &&
              c.routineCompleted(item.id, selected),
        )
        .toList();
    final completed =
        due.where((item) => c.routineCompleted(item.id, selected)).length +
        historical.length;
    final classes = due
        .where((item) => item.kind == RoutineKind.classSession)
        .length;
    final meals = due.length - classes;
    final future = selected.isAfter(today);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LayoutBuilder(
          builder: (context, box) {
            final widgets = [
              _stat(Icons.school_outlined, 'Classes planned', '$classes'),
              _stat(Icons.restaurant_outlined, 'Meals planned', '$meals'),
              _stat(
                Icons.check_circle_outline,
                future ? 'Scheduled' : 'Checked off',
                future
                    ? '${due.length} routines'
                    : '$completed / ${due.length + historical.length}',
              ),
            ];
            if (box.maxWidth < 600) {
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final stat in widgets)
                    SizedBox(width: box.maxWidth, child: stat),
                ],
              );
            }
            return Row(
              children: [
                for (int i = 0; i < widgets.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: widgets[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 21),
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Your day, in order',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  _badge(
                    future
                        ? 'PLANNED AHEAD'
                        : selected == today
                        ? 'TODAY'
                        : 'PAST DATE',
                  ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                future
                    ? 'Plan ahead now. Check off routines on the day or afterward.'
                    : 'A class attended. A meal enjoyed. Notice the small steps.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 18),
              if (due.isEmpty && historical.isEmpty)
                _empty(
                  'A little space to shape your day.',
                  'Add a class or plan a meal for ${routineWeekdays[selected.weekday - 1]}.',
                  Icons.wb_sunny_outlined,
                )
              else ...[
                for (final item in due)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _routineTile(item, daily: true),
                  ),
                if (historical.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'EARLIER CHECK-OFFS · WEEKLY PLAN CHANGED',
                    style: TextStyle(
                      fontSize: 9,
                      letterSpacing: .8,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final item in historical)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _routineTile(item, daily: true, historical: true),
                    ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 21),
        _tasks(),
      ],
    );
  }

  Widget _stat(IconData icon, String label, String value) => _panel(
    Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.pale,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: AppColors.green),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
    padding: const EdgeInsets.all(18),
  );

  Widget _weeklyPlan(RoutineKind kind) {
    final items = c.data.routines.where((item) => item.kind == kind).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final meal = kind == RoutineKind.meal;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                meal
                    ? 'Make space for your meals.'
                    : 'A clear view of your classes.',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.5,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                meal
                    ? 'Plan what you’d like to eat and when. Your menu is yours to choose.'
                    : 'Set your subjects, times, rooms, and instructors. Overlapping classes are flagged.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
              const SizedBox(height: 22),
              LayoutBuilder(
                builder: (context, box) {
                  final columns = box.maxWidth >= 980
                      ? 7
                      : box.maxWidth >= 650
                      ? 4
                      : box.maxWidth >= 430
                      ? 3
                      : 2;
                  final width = (box.maxWidth - (columns - 1) * 9) / columns;
                  return Wrap(
                    spacing: 9,
                    runSpacing: 9,
                    children: [
                      for (var day = 1; day <= 7; day++)
                        SizedBox(
                          width: width,
                          child: _weekPreview(day, items, meal),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Row(
          children: [
            Expanded(
              child: Text(
                meal ? 'Your weekly food routine' : 'Your recurring classes',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            _badge('${items.length} TOTAL'),
          ],
        ),
        const SizedBox(height: 7),
        const Text(
          'Edit the weekly template here. Daily check-offs are kept by date.',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: 17),
        if (items.isEmpty)
          _panel(
            _empty(
              meal
                  ? 'What’s on your plate this week?'
                  : 'Your timetable starts here.',
              meal
                  ? 'Add breakfast, lunch, dinner, or your own meal routine.'
                  : 'Add a class, choose its days, and give it a time.',
              meal ? Icons.restaurant_outlined : Icons.school_outlined,
            ),
          ),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 13),
            child: _routineTile(item),
          ),
      ],
    );
  }

  Widget _weekPreview(int day, List<RoutineItem> items, bool meal) {
    final due = items.where((item) => item.weekdays.contains(day)).toList();
    return Material(
      color: due.isEmpty ? AppColors.background : AppColors.pale,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        key: ValueKey('routine-week-day-$day'),
        borderRadius: BorderRadius.circular(11),
        onTap:
            _available(
              DateTime(
                RoutineAnalytics.weekStart(selected).year,
                RoutineAnalytics.weekStart(selected).month,
                RoutineAnalytics.weekStart(selected).day + day - 1,
              ),
            )
            ? () => _showDay(day)
            : null,
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                routineWeekdays[day - 1].substring(0, 3).toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: .9,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 9),
              Text(
                '${due.length} ${meal ? 'meals' : 'classes'}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 10),
              if (due.isEmpty)
                const Text(
                  'A clear day',
                  style: TextStyle(fontSize: 10, color: AppColors.muted),
                )
              else
                for (final item in due.take(2))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          routineClock(item.startMinutes),
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.green,
                          ),
                        ),
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 10,
                            color: AppColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
              if (due.length > 2)
                Text(
                  '+${due.length - 2} more',
                  style: const TextStyle(fontSize: 9, color: AppColors.muted),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _routineTile(
    RoutineItem item, {
    bool daily = false,
    bool historical = false,
  }) {
    final meal = item.kind == RoutineKind.meal;
    final complete = daily && c.routineCompleted(item.id, selected);
    final future = selected.isAfter(today);
    final conflicts = RoutineAnalytics.conflicts(item, c.data.routines);
    final conflictingToday = daily
        ? conflicts
              .where((other) => other.weekdays.contains(selected.weekday))
              .toList()
        : conflicts;
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: meal ? const Color(0xFFF5EEDD) : AppColors.pale,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  meal ? Icons.restaurant_outlined : Icons.school_outlined,
                  size: 20,
                  color: meal ? AppColors.gold : AppColors.green,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      key: ValueKey('routine-title-${item.id}'),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: complete ? AppColors.muted : AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      historical
                          ? 'Completed on this date · weekly plan changed'
                          : '${routineClock(item.startMinutes)}${meal ? '' : ' – ${routineClock(item.endMinutes!)}'}${daily ? '' : ' · ${routineDays(item.weekdays)}'}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
              ),
              if (daily)
                Tooltip(
                  message: complete
                      ? 'Undo this date’s check-off'
                      : future
                      ? 'Check off on the day or afterward'
                      : meal
                      ? 'Mark meal done'
                      : 'Mark class attended',
                  child: Checkbox(
                    key: ValueKey('routine-complete-${item.id}'),
                    semanticLabel:
                        '${complete ? 'Undo' : 'Complete'} ${item.title} on ${routineDateLabel(selected)}',
                    value: complete,
                    onChanged: c.saving || (future && !complete)
                        ? null
                        : (_) => _save(
                            () => c.toggleRoutine(item, selected, now: today),
                            complete
                                ? 'Check-off removed for this date.'
                                : meal
                                ? 'Meal checked off for this date.'
                                : 'Class marked attended for this date.',
                          ),
                  ),
                ),
              PopupMenuButton<String>(
                key: ValueKey('routine-menu-${item.id}'),
                tooltip: 'Manage ${item.title}',
                icon: const Icon(
                  Icons.more_horiz,
                  size: 19,
                  color: AppColors.muted,
                ),
                onSelected: (value) {
                  if (value == 'edit') _edit(item.kind, item);
                  if (value == 'delete') _delete(item);
                  if (value == 'details') _details(item);
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'details', child: Text('View details')),
                  PopupMenuItem(value: 'edit', child: Text('Edit routine')),
                  PopupMenuItem(value: 'delete', child: Text('Delete routine')),
                ],
              ),
            ],
          ),
          if (item.details.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                item.details,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: AppColors.muted,
                ),
              ),
            ),
          if (item.location.isNotEmpty ||
              item.instructor.isNotEmpty ||
              conflictingToday.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Wrap(
                spacing: 13,
                runSpacing: 8,
                children: [
                  if (item.location.isNotEmpty)
                    _meta(Icons.location_on_outlined, item.location),
                  if (item.instructor.isNotEmpty)
                    _meta(Icons.person_outline, item.instructor),
                  if (conflictingToday.isNotEmpty)
                    _badge('TIME OVERLAP', color: AppColors.gold),
                ],
              ),
            ),
        ],
      ),
      padding: const EdgeInsets.all(17),
    );
  }

  Widget _meta(IconData icon, String label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.muted),
      const SizedBox(width: 4),
      Flexible(
        child: Text(
          label,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ),
    ],
  );
  Widget _badge(String text, {Color color = AppColors.green}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color),
    ),
  );
  Widget _empty(String title, String message, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 30),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.green),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              height: 1.7,
              color: AppColors.muted,
            ),
          ),
        ],
      ),
    ),
  );
  Future<void> _details(RoutineItem item) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: Text(item.title),
      content: SizedBox(
        width: 450,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${routineDays(item.weekdays)}\n${routineClock(item.startMinutes)}${item.endMinutes == null ? '' : ' – ${routineClock(item.endMinutes!)}'}',
                style: const TextStyle(height: 1.8),
              ),
              if (item.location.isNotEmpty) Text('Location: ${item.location}'),
              if (item.instructor.isNotEmpty)
                Text('Instructor: ${item.instructor}'),
              if (item.details.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: SelectableText(
                    item.details,
                    style: const TextStyle(height: 1.8),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
