import '../../assessment/domain/ai_judgment.dart';

import 'package:flutter/material.dart';

import '../../../common/app_theme.dart';
import '../domain/models.dart';

Future<ProgressGoal?> showGoalDialog(
  BuildContext context,
  ProgressTrack track, {
  MetricKind? initialMetric,
  double? initialTarget,
  String? initialTitle,
  DateTime? initialDeadline,
}) => showDialog<ProgressGoal>(
  context: context,
  builder: (_) => _GoalDialog(
    track: track,
    initialMetric: initialMetric,
    initialTarget: initialTarget,
    initialTitle: initialTitle,
    initialDeadline: initialDeadline,
  ),
);

Future<TargetProfile?> showProfileDialog(
  BuildContext context,
  ProgressTrack track,
) => showDialog<TargetProfile>(
  context: context,
  builder: (_) => _ProfileDialog(track: track),
);

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

String _dateLabel(DateTime date) {
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

String? _required(String? value) =>
    value == null || value.trim().isEmpty ? 'Please fill in this field.' : null;

Map<MetricKind, double> _initialMetrics() => {
  for (final metric in MetricKind.values) metric: 50,
};

class _GoalDialog extends StatefulWidget {
  const _GoalDialog({
    required this.track,
    this.initialMetric,
    this.initialTarget,
    this.initialTitle,
    this.initialDeadline,
  });
  final ProgressTrack track;
  final MetricKind? initialMetric;
  final double? initialTarget;
  final String? initialTitle;
  final DateTime? initialDeadline;

  @override
  State<_GoalDialog> createState() => _GoalDialogState();
}

class _GoalDialogState extends State<_GoalDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  late MetricKind _metric;
  late double _target;
  DateTime _deadline = _today().add(const Duration(days: 14));

  @override
  void initState() {
    super.initState();
    _title.text = widget.initialTitle ?? '';
    if (widget.initialDeadline != null) {
      _deadline = DateUtils.dateOnly(widget.initialDeadline!);
      if (_deadline.isBefore(_today())) _deadline = _today();
    }
    _metric = widget.initialMetric ?? MetricKind.knowledge;
    _target = (widget.initialTarget ?? 85).clamp(0, 100).toDouble();
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final result = await showDatePicker(
      context: context,
      initialDate: _deadline,
      firstDate: _today(),
      lastDate: _today().add(const Duration(days: 365 * 5)),
      helpText: 'Choose your target date',
    );
    if (result != null && mounted) setState(() => _deadline = result);
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(context).pop(
      ProgressGoal(
        id: 'goal-${DateTime.now().microsecondsSinceEpoch}',
        title: _title.text.trim(),
        track: widget.track,
        metric: _metric,
        target: _target,
        deadline: _deadline,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _DialogFrame(
    title: 'Give your ambition a plan',
    subtitle: '${widget.track.label} · Set a clear, achievable next step',
    saveLabel: 'Create goal',
    saveKey: const Key('goal-save'),
    onSave: _save,
    child: Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextFormField(
            key: const Key('goal-title'),
            controller: _title,
            autofocus: true,
            validator: _required,
            maxLength: 100,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Your goal',
              hintText: 'e.g. Build a daily problem-solving habit',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<MetricKind>(
            initialValue: _metric,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Focus area'),
            items: MetricKind.values
                .map(
                  (metric) => DropdownMenuItem(
                    value: metric,
                    child: Text(aiMetricLabel(metric)),
                  ),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => _metric = value);
            },
          ),
          const SizedBox(height: 24),
          _SliderRow(
            label: 'Target AI score',
            value: _target,
            onChanged: (value) => setState(() => _target = value),
          ),
          const SizedBox(height: 12),
          const _HelpNote(
            text: 'Choose the score you want to reach. Your current rating and goal attainment come only from AI judgments of assessed evidence.',
          ),
          const SizedBox(height: 22),
          _DateButton(
            label: 'Target date',
            date: _deadline,
            onPressed: _pickDate,
          ),
        ],
      ),
    ),
  );
}

class _ProfileDialog extends StatefulWidget {
  const _ProfileDialog({required this.track});
  final ProgressTrack track;

  @override
  State<_ProfileDialog> createState() => _ProfileDialogState();
}

class _ProfileDialogState extends State<_ProfileDialog> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _role = TextEditingController();
  final _metrics = _initialMetrics();

  @override
  void dispose() {
    _name.dispose();
    _role.dispose();
    super.dispose();
  }

  void _save() {
    if (!_form.currentState!.validate()) return;
    final parts = _name.text.trim().split(RegExp(r'\s+'));
    final initials = parts.take(2).map((part) => part[0]).join().toUpperCase();
    Navigator.of(context).pop(
      TargetProfile(
        id: 'profile-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        role: _role.text.trim(),
        initials: initials,
        track: widget.track,
        metrics: _metrics,
        isExample: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => _DialogFrame(
    title: 'Add a benchmark',
    subtitle: '${widget.track.label} · Someone who inspires your next step',
    saveLabel: 'Add benchmark',
    saveKey: const Key('profile-save'),
    onSave: _save,
    child: Form(
      key: _form,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _HelpNote(
            text: 'Manual benchmark: enter the scores you want to work toward. These are your estimates, not a verified student profile.',
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('profile-name'),
            controller: _name,
            autofocus: true,
            validator: _required,
            maxLength: 60,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Name',
              hintText: 'e.g. My future self',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            key: const Key('profile-role'),
            controller: _role,
            validator: _required,
            maxLength: 100,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Role or description',
              hintText: 'e.g. Flutter developer · Internship ready',
            ),
          ),
          const SizedBox(height: 22),
          _MetricSliders(
            track: widget.track,
            metrics: _metrics,
            onChanged: (metric, value) =>
                setState(() => _metrics[metric] = value),
          ),
        ],
      ),
    ),
  );
}

class _DialogFrame extends StatelessWidget {
  const _DialogFrame({
    required this.title,
    required this.subtitle,
    required this.child,
    required this.saveLabel,
    required this.saveKey,
    required this.onSave,
  });
  final String title;
  final String subtitle;
  final Widget child;
  final String saveLabel;
  final Key saveKey;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) => Dialog(
    insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // With a keyboard or in landscape, let the heading and actions
          // scroll too so they cannot consume the entire form viewport.
          final scrollWholeForm = constraints.maxHeight < 500;
          final form = Padding(padding: const EdgeInsets.all(26), child: child);
          final content = Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 24, 16, 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              if (scrollWholeForm)
                form
              else
                Flexible(child: SingleChildScrollView(child: form)),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 16, 26, 20),
                child: Wrap(
                  alignment: WrapAlignment.end,
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      key: saveKey,
                      onPressed: onSave,
                      child: Text(saveLabel),
                    ),
                  ],
                ),
              ),
            ],
          );
          return scrollWholeForm
              ? SingleChildScrollView(child: content)
              : content;
        },
      ),
    ),
  );
}

class _DateButton extends StatelessWidget {
  const _DateButton({
    required this.label,
    required this.date,
    required this.onPressed,
  });
  final String label;
  final DateTime date;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onPressed,
    child: Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 8,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_today_outlined, size: 17),
            const SizedBox(width: 12),
            Flexible(child: Text(label)),
          ],
        ),
        Text(
          _dateLabel(date),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class _MetricSliders extends StatelessWidget {
  const _MetricSliders({
    required this.track,
    required this.metrics,
    required this.onChanged,
  });
  final ProgressTrack track;
  final Map<MetricKind, double> metrics;
  final void Function(MetricKind, double) onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 12,
        runSpacing: 8,
        children: [
          Text(
            'Rate your progress',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          Text(
            '${(metrics.values.reduce((a, b) => a + b) / 4).toStringAsFixed(1)} / 100',
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      const _HelpNote(
        text: 'Self-reported scores: 0 = just starting, 50 = developing, 100 = your goal achieved. Your overall score is the equal average of these four areas. Keep your standards consistent over time.',
      ),
      const SizedBox(height: 20),
      for (final metric in MetricKind.values) ...[
        _SliderRow(
          label: metricLabel(metric, track),
          value: metrics[metric]!,
          onChanged: (value) => onChanged(metric, value),
        ),
        if (metric != MetricKind.values.last) const SizedBox(height: 12),
      ],
    ],
  );
}

class _SliderRow extends StatelessWidget {
  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(width: 12),
          Container(
            decoration: BoxDecoration(
              color: AppColors.pale,
              borderRadius: BorderRadius.circular(6),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            child: Text(
              '${value.round()}',
              style: const TextStyle(
                color: AppColors.green,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
      Semantics(
        label: label,
        child: Slider(
          value: value,
          min: 0,
          max: 100,
          divisions: 100,
          label: '${value.round()}',
          onChanged: onChanged,
        ),
      ),
    ],
  );
}

class _HelpNote extends StatelessWidget {
  const _HelpNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.pale,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      text,
      style: const TextStyle(fontSize: 12, height: 1.6, color: AppColors.ink),
    ),
  );
}
