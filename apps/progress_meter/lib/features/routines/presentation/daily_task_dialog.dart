import 'dart:math';

import 'package:flutter/material.dart';

import '../domain/daily_task.dart';
import '../domain/routine_models.dart';

Future<DailyTask?> showDailyTaskDialog(
  BuildContext context, {
  required DateTime date,
  DailyTask? existing,
  required Future<void> Function(DailyTask) onSave,
}) => showDialog<DailyTask>(
  context: context,
  barrierDismissible: false,
  builder: (_) =>
      _DailyTaskDialog(date: date, existing: existing, onSave: onSave),
);

class _DailyTaskDialog extends StatefulWidget {
  const _DailyTaskDialog({
    required this.date,
    required this.existing,
    required this.onSave,
  });
  final DateTime date;
  final DailyTask? existing;
  final Future<void> Function(DailyTask) onSave;
  @override
  State<_DailyTaskDialog> createState() => _DailyTaskDialogState();
}

class _DailyTaskDialogState extends State<_DailyTaskDialog> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late DateTime _date = widget.existing?.date ?? routineDate(widget.date);
  late int? _time = widget.existing?.timeMinutes;
  late final _id =
      widget.existing?.id ??
      'task-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final first = DateTime(2000), last = DateTime(2100, 12, 31);
    final initial = _date.isBefore(first)
        ? first
        : _date.isAfter(last)
        ? last
        : _date;
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      helpText: 'When will you do this task?',
    );
    if (result != null && mounted) setState(() => _date = routineDate(result));
  }

  Future<void> _pickTime() async {
    final minutes = _time ?? 9 * 60;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      initialEntryMode: TimePickerEntryMode.input,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (result != null && mounted) {
      setState(() => _time = result.hour * 60 + result.minute);
    }
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final task = DailyTask(
        id: _id,
        title: _title.text,
        dateKey: routineDateKey(_date),
        notes: _notes.text,
        timeMinutes: _time,
        completed: widget.existing?.completed ?? false,
      );
      await widget.onSave(task);
      if (mounted) Navigator.pop(context, task);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save this task. Your details are kept here; please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validate(String? value, int maximum, {bool required = false}) {
    if (required && (value?.trim().isEmpty ?? true)) {
      return 'Please enter a task title.';
    }
    if ((value?.runes.length ?? 0) > maximum) {
      return 'Use $maximum characters or fewer.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      scrollable: true,
      title: Text(widget.existing == null ? 'Add a task' : 'Edit task'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Plan something to do on one specific day.'),
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('task-title'),
                  controller: _title,
                  enabled: !_saving,
                  maxLength: 100,
                  decoration: const InputDecoration(
                    labelText: 'What needs to be done?',
                  ),
                  validator: (v) => _validate(v, 100, required: true),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const Key('task-date'),
                      onPressed: _saving ? null : _pickDate,
                      icon: const Icon(Icons.calendar_today_outlined, size: 16),
                      label: Text(
                        MaterialLocalizations.of(context)
                            .formatMediumDate(_date),
                      ),
                    ),
                    OutlinedButton.icon(
                      key: const Key('task-time'),
                      onPressed: _saving ? null : _pickTime,
                      icon: const Icon(Icons.schedule, size: 17),
                      label: Text(
                        _time == null
                            ? 'Any time'
                            : '${(_time! ~/ 60).toString().padLeft(2, '0')}:${(_time! % 60).toString().padLeft(2, '0')}',
                      ),
                    ),
                    if (_time != null)
                      TextButton(
                        key: const Key('task-clear-time'),
                        onPressed: _saving
                            ? null
                            : () => setState(() => _time = null),
                        child: const Text('Clear time'),
                      ),
                  ],
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const Key('task-notes'),
                  controller: _notes,
                  enabled: !_saving,
                  maxLength: 1200,
                  minLines: 2,
                  maxLines: 5,
                  decoration: const InputDecoration(
                    labelText: 'Notes · optional',
                  ),
                  validator: (v) => _validate(v, 1200),
                ),
                if (widget.existing?.completed == true)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'Moving a completed task to another date marks it to do again.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      key: const Key('task-save-error'),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const Key('task-save'),
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save task'),
        ),
      ],
    ),
  );
}
