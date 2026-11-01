import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/progress_controller.dart';
import '../../../common/app_theme.dart';
import '../../routines/domain/routine_models.dart';
import '../data/document_import_service.dart';
import '../domain/import_identity.dart';
import '../domain/import_models.dart';

Future<List<String>?> showRoutineImportDialog(
  BuildContext context, {
  required ProgressController controller,
  RoutineKind initialKind = RoutineKind.classSession,
  RoutineImportService? service,
}) => showDialog<List<String>>(
  context: context,
  barrierDismissible: false,
  builder: (_) => RoutineImportDialog(
    controller: controller,
    initialKind: initialKind,
    service: service ?? LocalRoutineImportService(),
  ),
);

const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
String _clock(int? value) => value == null
    ? 'Missing time'
    : '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';
String _dayLabel(Set<int> values) => values.isEmpty
    ? 'Choose days'
    : (values.toList()..sort()).map((d) => _days[d - 1]).join(' · ');

class RoutineImportDialog extends StatefulWidget {
  const RoutineImportDialog({
    super.key,
    required this.controller,
    required this.service,
    this.initialKind = RoutineKind.classSession,
  });
  final ProgressController controller;
  final RoutineImportService service;
  final RoutineKind initialKind;
  @override
  State<RoutineImportDialog> createState() => _RoutineImportDialogState();
}

class _RoutineImportDialogState extends State<RoutineImportDialog> {
  late RoutineKind _kind = widget.initialKind;
  ImportResult? _result;
  List<ImportDraft> _drafts = [];
  final Set<String> _selected = {};
  bool _loading = false, _saving = false;
  String? _error, _name;

  List<RoutineItem> _items({int? before}) {
    final pending = <RoutineItem>[];
    for (var i = 0; i < (before ?? _drafts.length); i++) {
      final draft = _drafts[i];
      if (!_selected.contains(draft.id) || !draft.isValid) continue;
      final item = draft.toRoutineItem();
      final days = newImportDays(item, [
        ...widget.controller.data.routines,
        ...pending,
      ]);
      if (days.isNotEmpty) pending.add(item.copyWith(weekdays: days));
    }
    return pending;
  }

  Set<int> _newDays(int index) {
    final draft = _drafts[index];
    if (!draft.isValid) return {};
    return newImportDays(draft.toRoutineItem(), [
      ...widget.controller.data.routines,
      ..._items(before: index),
    ]);
  }

  void _selectReady() {
    _selected.clear();
    for (var i = 0; i < _drafts.length; i++) {
      if (_newDays(i).isNotEmpty) _selected.add(_drafts[i].id);
    }
  }

  Future<void> _pick() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = await widget.service.pickFile();
      if (!mounted) return;
      if (file == null) {
        setState(() => _loading = false);
        return;
      }
      final result = await widget.service.extract(file, defaultKind: _kind);
      if (!mounted) return;
      setState(() {
        _result = result;
        _name = file.name;
        _drafts = [...result.drafts];
        _selectReady();
        _loading = false;
      });
    } on ImportFailure catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Extraction could not finish. Try a clearer image, a smaller workbook, or an unlocked PDF.';
        });
      }
    }
  }

  Future<void> _edit(int index) async {
    final updated = await showDialog<ImportDraft>(
      context: context,
      builder: (_) => _DraftEditor(draft: _drafts[index]),
    );
    if (updated != null && mounted) {
      setState(() {
        _drafts[index] = updated;
        if (_newDays(index).isNotEmpty) _selected.add(updated.id);
      });
    }
  }

  Future<void> _save() async {
    final items = _items();
    if (items.isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final ids = await widget.controller.importRoutines(items);
      if (mounted) Navigator.pop(context, ids);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Your routines could not be saved. Your existing plan is unchanged. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final count = _items().length;
    final missing = _drafts.where((d) => !d.isValid).length;
    return PopScope(
      canPop: !_saving,
      child: Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: SizedBox(
          width: 860,
          height: math.min(820, MediaQuery.sizeOf(context).height - 40),
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: LayoutBuilder(
              builder: (context, box) {
                final scrollWholeForm = box.maxHeight < 600;
                final content = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Import your routine',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Choose a timetable or meal plan. Review the extracted entries, then add them to your week.',
                      style: TextStyle(color: AppColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        for (final kind in RoutineKind.values)
                          ChoiceChip(
                            label: Text(
                              kind == RoutineKind.meal
                                  ? 'Food routine'
                                  : 'Class routine',
                            ),
                            selected: _kind == kind,
                            onSelected: _loading || _saving || _result != null
                                ? null
                                : (_) => setState(() => _kind = kind),
                          ),
                        OutlinedButton.icon(
                          key: const Key('import-choose-file'),
                          onPressed: _loading || _saving ? null : _pick,
                          icon: const Icon(
                            Icons.upload_file_outlined,
                            size: 19,
                          ),
                          label: Text(
                            _result == null
                                ? 'Choose file'
                                : 'Choose another file',
                          ),
                        ),
                        if (_result != null)
                          TextButton(
                            onPressed: _saving || _loading
                                ? null
                                : () => setState(() {
                                    _result = null;
                                    _drafts = [];
                                    _selected.clear();
                                    _name = null;
                                    _error = null;
                                  }),
                            child: const Text('Start again'),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          key: const Key('import-error'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    _importViewport(
                      scrollWholeForm,
                      _loading
                          ? const Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 18),
                                  Text('Reading your file on this device…'),
                                  SizedBox(height: 6),
                                  Text(
                                    'Images and scanned pages may take a moment.',
                                  ),
                                ],
                              ),
                            )
                          : _result == null
                          ? _intro()
                          : ListView(
                              children: [
                                Text(
                                  _name ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Text(
                                  '${_drafts.length} extracted · $count selected${missing == 0 ? '' : ' · $missing need correction'}',
                                  key: const Key('import-summary'),
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                  ),
                                ),
                                if (_result!.warnings.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(
                                      _result!.warnings.join('\n'),
                                      maxLines: 4,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.gold,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                Wrap(
                                  spacing: 10,
                                  children: [
                                    TextButton(
                                      onPressed: _saving
                                          ? null
                                          : () => setState(_selectReady),
                                      child: const Text('Select all ready'),
                                    ),
                                    TextButton(
                                      onPressed: _saving
                                          ? null
                                          : () => setState(_selected.clear),
                                      child: const Text('Clear selection'),
                                    ),
                                  ],
                                ),
                                if (_drafts.isEmpty)
                                  const Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Text(
                                      'No routines found. Try a clearer file or a table with Day, Subject/Meal, Start, and End columns.',
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                for (
                                  var index = 0;
                                  index < _drafts.length;
                                  index++
                                )
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: _row(index),
                                  ),
                              ],
                            ),
                    ),
                    const Divider(height: 24),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        TextButton(
                          key: const Key('import-cancel'),
                          onPressed: _saving
                              ? null
                              : () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        FilledButton.icon(
                          key: const Key('import-save'),
                          onPressed: count == 0 || _loading || _saving
                              ? null
                              : _save,
                          icon: _saving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.playlist_add, size: 20),
                          label: Text(
                            _saving
                                ? 'Saving…'
                                : 'Import $count ${count == 1 ? 'routine' : 'routines'}',
                          ),
                        ),
                      ],
                    ),
                  ],
                );
                return scrollWholeForm
                    ? SingleChildScrollView(child: content)
                    : content;
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _importViewport(bool scrollWholeForm, Widget child) => scrollWholeForm
      ? SizedBox(height: 360, child: child)
      : Expanded(child: child);

  Widget _intro() => const Center(
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.document_scanner_outlined,
            size: 52,
            color: AppColors.green,
          ),
          SizedBox(height: 18),
          Text(
            'Your schedule, without all the typing.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          ),
          SizedBox(height: 12),
          Text(
            'PDF · PNG · JPEG · HEIC · WebP · Excel (.xlsx / .xls)\nPDFs and images up to 20 MB; Excel up to 10 MB.\nUp to 12 PDF pages and 200 routines per import.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted, height: 1.8),
          ),
          SizedBox(height: 18),
          Text(
            'Files are read locally. No API key is needed.\nMissing days and times can be filled in before saving.\nExisting routines and daily check-offs are kept.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.8),
          ),
        ],
      ),
    ),
  );

  Widget _row(int index) {
    final draft = _drafts[index];
    final valid = draft.isValid;
    final days = _newDays(index);
    final duplicate = valid && days.isEmpty;
    final checked = _selected.contains(draft.id) && !duplicate && valid;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.line),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            key: ValueKey('import-select-${draft.id}'),
            value: checked,
            onChanged: _saving || duplicate || !valid
                ? null
                : (value) => setState(() {
                    if (value == true) {
                      _selected.add(draft.id);
                    } else {
                      _selected.remove(draft.id);
                    }
                  }),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  draft.title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 5),
                Text(
                  '${_dayLabel(draft.weekdays)} · ${_clock(draft.startMinutes)}${draft.kind == RoutineKind.meal ? '' : ' – ${_clock(draft.endMinutes)}'}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
                if (draft.location.isNotEmpty || draft.instructor.isNotEmpty)
                  Text(
                    [
                      draft.location,
                      draft.instructor,
                    ].where((s) => s.isNotEmpty).join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                if (draft.details.isNotEmpty)
                  Text(
                    draft.details,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  ),
                if (duplicate)
                  const Text(
                    'Already in your plan or selected above',
                    style: TextStyle(fontSize: 12, color: AppColors.green),
                  ),
                if (valid &&
                    days.isNotEmpty &&
                    days.length < draft.weekdays.length)
                  Text(
                    'Adds only ${_dayLabel(days)}; other days already planned.',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.green,
                    ),
                  ),
                if (!valid || draft.warnings.isNotEmpty)
                  Text(
                    !valid
                        ? 'Needs correction: check days, times, and title.'
                        : draft.warnings.join(' '),
                    style: const TextStyle(fontSize: 12, color: AppColors.gold),
                  ),
              ],
            ),
          ),
          IconButton(
            key: ValueKey('import-edit-${draft.id}'),
            tooltip: 'Edit extracted routine',
            onPressed: _saving ? null : () => _edit(index),
            icon: const Icon(Icons.edit_outlined, size: 19),
          ),
        ],
      ),
    );
  }
}

class _DraftEditor extends StatefulWidget {
  const _DraftEditor({required this.draft});
  final ImportDraft draft;
  @override
  State<_DraftEditor> createState() => _DraftEditorState();
}

class _DraftEditorState extends State<_DraftEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.draft.title);
  late final _start = TextEditingController(
    text: widget.draft.startMinutes == null
        ? ''
        : _clock(widget.draft.startMinutes),
  );
  late final _end = TextEditingController(
    text: widget.draft.endMinutes == null
        ? ''
        : _clock(widget.draft.endMinutes),
  );
  late final _location = TextEditingController(text: widget.draft.location);
  late final _instructor = TextEditingController(text: widget.draft.instructor);
  late final _details = TextEditingController(text: widget.draft.details);
  late final Set<int> _weekdays = {...widget.draft.weekdays};
  bool _dayError = false;
  int? _minutes(String text) {
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(text.trim());
    if (match == null) return null;
    final hour = int.parse(match[1]!), minute = int.parse(match[2]!);
    return hour > 23 || minute > 59 ? null : hour * 60 + minute;
  }

  @override
  void dispose() {
    for (final c in [_title, _start, _end, _location, _instructor, _details]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    setState(() => _dayError = _weekdays.isEmpty);
    if (!_form.currentState!.validate() || _dayError) return;
    Navigator.pop(
      context,
      widget.draft.copyWith(
        title: _title.text.trim(),
        weekdays: _weekdays,
        startMinutes: _minutes(_start.text),
        endMinutes: widget.draft.kind == RoutineKind.meal
            ? null
            : _minutes(_end.text),
        location: _location.text.trim(),
        instructor: _instructor.text.trim(),
        details: _details.text.trim(),
        warnings: [],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Review extracted routine'),
    content: SizedBox(
      width: 500,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('import-edit-title'),
                controller: _title,
                maxLength: 100,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (s) =>
                    s == null || s.trim().isEmpty ? 'Enter a title.' : null,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (var d = 1; d <= 7; d++)
                    FilterChip(
                      key: ValueKey('import-edit-day-$d'),
                      label: Text(_days[d - 1]),
                      selected: _weekdays.contains(d),
                      onSelected: (value) => setState(() {
                        if (value) {
                          _weekdays.add(d);
                        } else {
                          _weekdays.remove(d);
                        }
                      }),
                    ),
                ],
              ),
              if (_dayError)
                Text(
                  'Choose at least one repeat day.',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              const SizedBox(height: 16),
              TextFormField(
                key: const Key('import-edit-start'),
                controller: _start,
                decoration: const InputDecoration(
                  labelText: 'Start time · 24-hour HH:mm',
                  hintText: '09:00',
                ),
                validator: (s) => _minutes(s ?? '') == null
                    ? 'Enter a time such as 09:00 or 14:30.'
                    : null,
              ),
              if (widget.draft.kind == RoutineKind.classSession) ...[
                const SizedBox(height: 14),
                TextFormField(
                  key: const Key('import-edit-end'),
                  controller: _end,
                  decoration: const InputDecoration(
                    labelText: 'End time · 24-hour HH:mm',
                    hintText: '09:50',
                  ),
                  validator: (s) {
                    final end = _minutes(s ?? ''),
                        start = _minutes(_start.text);
                    if (end == null) return 'Enter an end time.';
                    return start != null && end <= start
                        ? 'End time must be later than start time.'
                        : null;
                  },
                ),
              ],
              const SizedBox(height: 14),
              TextFormField(
                controller: _location,
                maxLength: 160,
                decoration: const InputDecoration(
                  labelText: 'Room or location',
                ),
              ),
              if (widget.draft.kind == RoutineKind.classSession)
                TextFormField(
                  controller: _instructor,
                  maxLength: 160,
                  decoration: const InputDecoration(labelText: 'Instructor'),
                ),
              TextFormField(
                controller: _details,
                maxLength: 1200,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: widget.draft.kind == RoutineKind.meal
                      ? 'Menu or notes'
                      : 'Session or notes',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        key: const Key('import-edit-apply'),
        onPressed: _save,
        child: const Text('Apply changes'),
      ),
    ],
  );
}
