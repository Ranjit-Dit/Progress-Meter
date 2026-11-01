import 'package:flutter/material.dart';

import '../../../common/app_theme.dart';
import '../domain/routine_analytics.dart';
import '../domain/routine_models.dart';

Future<RoutineItem?> showRoutineDialog(
  BuildContext context, {
  required RoutineKind kind,
  required int weekday,
  RoutineItem? existing,
  List<RoutineItem> siblings = const [],
}) => showDialog<RoutineItem>(
  context: context,
  builder: (_) => _RoutineDialog(
    kind: existing?.kind ?? kind,
    weekday: weekday,
    existing: existing,
    siblings: siblings,
  ),
);

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String _clock(int minutes) =>
    '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}';

class _RoutineDialog extends StatefulWidget {
  const _RoutineDialog({
    required this.kind,
    required this.weekday,
    required this.existing,
    required this.siblings,
  });
  final RoutineKind kind;
  final int weekday;
  final RoutineItem? existing;
  final List<RoutineItem> siblings;

  @override
  State<_RoutineDialog> createState() => _RoutineDialogState();
}

class _RoutineDialogState extends State<_RoutineDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _details;
  late final TextEditingController _location;
  late final TextEditingController _instructor;
  late Set<int> _weekdays;
  late int _start;
  late int _end;
  bool _submitted = false;
  String? _modelError;
  bool get _isClass => widget.kind == RoutineKind.classSession;
  bool get _editing => widget.existing != null;
  late final String _id =
      widget.existing?.id ?? 'routine-${DateTime.now().microsecondsSinceEpoch}';

  @override
  void initState() {
    super.initState();
    final item = widget.existing;
    _title = TextEditingController(
      text: item?.title ?? (_isClass ? '' : 'Breakfast'),
    );
    _details = TextEditingController(text: item?.details ?? '');
    _location = TextEditingController(text: item?.location ?? '');
    _instructor = TextEditingController(text: item?.instructor ?? '');
    _weekdays = Set.of(
      item?.weekdays ??
          (_isClass
              ? {
                  widget.weekday >= 1 && widget.weekday <= 7
                      ? widget.weekday
                      : 1,
                }
              : {1, 2, 3, 4, 5, 6, 7}),
    );
    _start = item?.startMinutes ?? (_isClass ? 9 * 60 : 8 * 60);
    _end = item?.endMinutes ?? 10 * 60;
  }

  @override
  void dispose() {
    _title.dispose();
    _details.dispose();
    _location.dispose();
    _instructor.dispose();
    super.dispose();
  }

  String? _validateText(String? value, int maximum, {bool required = false}) {
    final text = value?.trim() ?? '';
    if (required && text.isEmpty) return 'Please enter a title.';
    if (text.runes.length > maximum) return 'Use $maximum characters or fewer.';
    return null;
  }

  Future<void> _pickTime({required bool end}) async {
    final minutes = end ? _end : _start;
    final result = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      initialEntryMode: TimePickerEntryMode.input,
      helpText: end
          ? 'When does the class finish?'
          : _isClass
          ? 'When does the class start?'
          : 'When is this meal?',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (end) {
        _end = result.hour * 60 + result.minute;
      } else {
        _start = result.hour * 60 + result.minute;
      }
      _modelError = null;
    });
  }

  RoutineItem _candidate() => RoutineItem(
    id: _id,
    title: _title.text.trim().isEmpty ? 'Untitled class' : _title.text.trim(),
    kind: widget.kind,
    weekdays: _weekdays,
    startMinutes: _start,
    endMinutes: _isClass ? _end : null,
    details: _details.text.trim(),
    location: _location.text.trim(),
    instructor: _isClass ? _instructor.text.trim() : '',
  );

  List<RoutineItem> _conflicts() {
    if (!_isClass || _weekdays.isEmpty || _end <= _start) return const [];
    try {
      return RoutineAnalytics.conflicts(_candidate(), widget.siblings);
    } on ArgumentError {
      return const [];
    }
  }

  void _save() {
    setState(() {
      _submitted = true;
      _modelError = null;
    });
    final fieldsValid = _form.currentState!.validate();
    if (!fieldsValid || _weekdays.isEmpty || (_isClass && _end <= _start)) {
      return;
    }
    try {
      Navigator.of(context).pop(_candidate());
    } on ArgumentError {
      setState(
        () => _modelError = 'Check the title, days, and times, then try again.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final conflicts = _conflicts();
    final title = _editing
        ? _isClass
              ? 'Edit class routine'
              : 'Edit food routine'
        : _isClass
        ? 'Add a class'
        : 'Plan a meal';
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 23, 12, 19),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.headlineMedium,
                          ),
                          const SizedBox(height: 7),
                          Text(
                            _isClass
                                ? 'Give your learning a place in the week.'
                                : 'Make time for the meals you choose.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close routine form',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (!_isClass) ...[
                        Wrap(
                          spacing: 7,
                          runSpacing: 6,
                          children: [
                            for (final meal in [
                              'Breakfast',
                              'Lunch',
                              'Dinner',
                              'Snack',
                            ])
                              ChoiceChip(
                                label: Text(
                                  meal,
                                  style: const TextStyle(fontSize: 11),
                                ),
                                selected: _title.text.trim() == meal,
                                onSelected: (_) =>
                                    setState(() => _title.text = meal),
                              ),
                          ],
                        ),
                        const SizedBox(height: 17),
                      ],
                      TextFormField(
                        key: const Key('routine-title'),
                        controller: _title,
                        autofocus: _isClass,
                        maxLength: 100,
                        validator: (value) =>
                            _validateText(value, 100, required: true),
                        textInputAction: TextInputAction.next,
                        onChanged: (_) => setState(() => _modelError = null),
                        decoration: InputDecoration(
                          labelText: _isClass
                              ? 'Subject or class name'
                              : 'Meal name',
                          hintText: _isClass
                              ? 'e.g. Data structures'
                              : 'e.g. Afternoon snack',
                        ),
                      ),
                      const SizedBox(height: 17),
                      const Text(
                        'REPEATS EACH WEEK',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w600,
                          color: AppColors.green,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (var day = 1; day <= 7; day++)
                            ChoiceChip(
                              key: ValueKey('routine-day-$day'),
                              label: Text(
                                _days[day - 1],
                                style: const TextStyle(fontSize: 11),
                              ),
                              selected: _weekdays.contains(day),
                              onSelected: (selected) => setState(() {
                                if (selected) {
                                  _weekdays.add(day);
                                } else {
                                  _weekdays.remove(day);
                                }
                                _modelError = null;
                              }),
                            ),
                        ],
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          TextButton(
                            onPressed: () =>
                                setState(() => _weekdays = {1, 2, 3, 4, 5}),
                            child: const Text(
                              'Weekdays',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          TextButton(
                            onPressed: () => setState(
                              () => _weekdays = {1, 2, 3, 4, 5, 6, 7},
                            ),
                            child: const Text(
                              'Every day',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                      if (_submitted && _weekdays.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3, bottom: 7),
                          child: Text(
                            'Choose at least one day.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 10),
                      if (_isClass)
                        LayoutBuilder(
                          builder: (context, box) {
                            final start = _timeButton(
                              'Start time',
                              _start,
                              end: false,
                            );
                            final end = _timeButton(
                              'End time',
                              _end,
                              end: true,
                            );
                            if (box.maxWidth < 340) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  start,
                                  const SizedBox(height: 12),
                                  end,
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(child: start),
                                const SizedBox(width: 12),
                                Expanded(child: end),
                              ],
                            );
                          },
                        )
                      else
                        SizedBox(
                          width: double.infinity,
                          child: _timeButton('Meal time', _start, end: false),
                        ),
                      if (_submitted && _isClass && _end <= _start)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            'End time must be after the start time on the same day.',
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (conflicts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(13),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFAF7F0),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.schedule_outlined,
                                  size: 17,
                                  color: AppColors.gold,
                                ),
                                const SizedBox(width: 9),
                                Expanded(
                                  child: Text(
                                    'Overlaps with ${conflicts.map((item) => item.title).take(2).join(' and ')} on a shared day. You can still save this class.',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      height: 1.7,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(height: 23),
                      TextFormField(
                        key: const Key('routine-location'),
                        controller: _location,
                        maxLength: 160,
                        validator: (value) => _validateText(value, 160),
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          labelText: _isClass
                              ? 'Room or location (optional)'
                              : 'Location (optional)',
                          hintText: _isClass
                              ? 'e.g. Room B-204 or Online'
                              : 'e.g. Home or Campus café',
                        ),
                      ),
                      if (_isClass) ...[
                        const SizedBox(height: 10),
                        TextFormField(
                          key: const Key('routine-instructor'),
                          controller: _instructor,
                          maxLength: 160,
                          validator: (value) => _validateText(value, 160),
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Instructor (optional)',
                            hintText: 'e.g. Prof. Sharma',
                          ),
                        ),
                      ],
                      const SizedBox(height: 11),
                      TextFormField(
                        key: const Key('routine-details'),
                        controller: _details,
                        minLines: 2,
                        maxLines: 4,
                        maxLength: 1200,
                        validator: (value) => _validateText(value, 1200),
                        decoration: InputDecoration(
                          labelText: _isClass
                              ? 'Notes (optional)'
                              : 'Menu or meal notes (optional)',
                          hintText: _isClass
                              ? 'What should you prepare or bring?'
                              : 'e.g. Oats, fruit, and yogurt',
                        ),
                      ),
                      if (_editing)
                        const Padding(
                          padding: EdgeInsets.only(top: 12),
                          child: Text(
                            'Changes update the recurring plan. Previous check-offs are kept.',
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.7,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      if (_modelError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            _modelError!,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 15, 24, 19),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      key: const Key('routine-save'),
                      onPressed: _save,
                      child: Text(
                        _editing
                            ? 'Save changes'
                            : _isClass
                            ? 'Add class'
                            : 'Save meal',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeButton(String label, int value, {required bool end}) =>
      OutlinedButton(
        key: Key(end ? 'routine-end-time' : 'routine-start-time'),
        onPressed: () => _pickTime(end: end),
        style: OutlinedButton.styleFrom(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            const SizedBox(height: 5),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: AppColors.green,
                ),
                const SizedBox(width: 8),
                Text(
                  _clock(value),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}
