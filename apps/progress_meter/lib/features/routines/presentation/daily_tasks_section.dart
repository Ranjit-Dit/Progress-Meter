import 'package:flutter/material.dart';

import '../../../common/app_theme.dart';
import '../domain/daily_task.dart';
import '../domain/routine_models.dart';

class DailyTasksSection extends StatelessWidget {
  const DailyTasksSection({
    super.key,
    required this.tasks,
    required this.date,
    required this.today,
    required this.saving,
    required this.onAdd,
    required this.onEdit,
    required this.onToggle,
    required this.onDelete,
  });
  final List<DailyTask> tasks;
  final DateTime date, today;
  final bool saving;
  final VoidCallback onAdd;
  final ValueChanged<DailyTask> onEdit, onToggle, onDelete;
  @override
  Widget build(BuildContext context) {
    final done = tasks.where((t) => t.completed).length;
    final future = routineDate(date).isAfter(routineDate(today));
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: const EdgeInsets.all(23),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 16,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Tasks for the day',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                Text(
                  '$done / ${tasks.length} done · ${tasks.length - done} to do',
                  key: const Key('task-summary'),
                  style: const TextStyle(fontSize: 12, color: AppColors.green),
                ),
                TextButton.icon(
                  key: const Key('task-section-add'),
                  onPressed: saving ? null : onAdd,
                  icon: const Icon(Icons.add, size: 17),
                  label: const Text('Add task'),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              future
                  ? 'Plan ahead. Mark tasks done on the day or afterward.'
                  : 'A short list of what needs doing on this date.',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 16),
            if (tasks.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Text(
                  'No tasks planned for this day. Add an assignment, errand, study session, or anything you need to do.',
                  key: Key('tasks-empty'),
                  style: TextStyle(color: AppColors.muted, height: 1.7),
                ),
              ),
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: task.completed ? AppColors.pale : AppColors.background,
                  borderRadius: BorderRadius.circular(11),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(4, 8, 8, 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Checkbox(
                          key: ValueKey('task-toggle-${task.id}'),
                          value: task.completed,
                          semanticLabel: task.completed
                              ? 'Mark ${task.title} to do'
                              : 'Mark ${task.title} done',
                          onChanged: saving || (future && !task.completed)
                              ? null
                              : (_) => onToggle(task),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  task.title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    decoration: task.completed
                                        ? TextDecoration.lineThrough
                                        : null,
                                    color: task.completed
                                        ? AppColors.muted
                                        : AppColors.ink,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${task.timeMinutes == null ? 'Any time' : '${(task.timeMinutes! ~/ 60).toString().padLeft(2, '0')}:${(task.timeMinutes! % 60).toString().padLeft(2, '0')}'} · ${task.completed ? 'Done' : 'To do'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.muted,
                                  ),
                                ),
                                if (task.notes.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      task.notes,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        height: 1.6,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                        PopupMenuButton<String>(
                          key: ValueKey('task-menu-${task.id}'),
                          enabled: !saving,
                          tooltip: 'Manage task',
                          onSelected: (action) =>
                              action == 'edit' ? onEdit(task) : onDelete(task),
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'edit',
                              child: Text('Edit task'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete task'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
