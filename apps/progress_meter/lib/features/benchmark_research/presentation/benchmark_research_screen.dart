import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/progress_controller.dart';
import '../../../common/app_theme.dart';
import '../../ai_coach/domain/coach_models.dart';
import '../../ai_coach/presentation/coach_screen.dart';
import '../../ai_coach/data/api_coach_repository.dart';
import '../application/benchmark_controller.dart';
import '../domain/benchmark_models.dart';
import '../domain/benchmark_analytics.dart';

class BenchmarkResearchScreen extends StatefulWidget {
  const BenchmarkResearchScreen({
    super.key,
    required this.progress,
    required this.controller,
    required this.baseUrl,
    this.onConnectionChanged,
    this.onPersonalAiSettings,
    this.personalAiLabel,
    required this.onTestMilestone,
    this.onOpenSource,
  });
  final ProgressController progress;
  final BenchmarkResearchController controller;
  final Uri baseUrl;
  final ValueChanged<CoachConnection>? onConnectionChanged;
  final VoidCallback? onPersonalAiSettings;
  final String? personalAiLabel;
  final void Function(ResearchPlan, RoadmapMilestone) onTestMilestone;
  final Future<bool> Function(Uri)? onOpenSource;
  @override
  State<BenchmarkResearchScreen> createState() =>
      _BenchmarkResearchScreenState();
}

class _BenchmarkResearchScreenState extends State<BenchmarkResearchScreen> {
  final _form = GlobalKey<FormState>();
  final _query = TextEditingController(),
      _context = TextEditingController(),
      _post = TextEditingController();
  BenchmarkKind _kind = BenchmarkKind.person;
  CoachHealth? _health;
  bool _checking = false, _saving = false;
  String? _saveError;
  BenchmarkResearchController get r => widget.controller;
  ProgressController get p => widget.progress;
  bool get locked => r.busy || p.saving || _saving;
  @override
  void initState() {
    super.initState();
    _check();
  }

  @override
  void dispose() {
    _query.dispose();
    _context.dispose();
    _post.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    try {
      final h = await r.checkHealth();
      if (mounted) setState(() => _health = h);
    } catch (_) {
      if (mounted) setState(() => _health = null);
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _research() async {
    if (locked || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await r.research(
      kind: _kind,
      query: _query.text,
      context: _context.text,
      postText: _kind == BenchmarkKind.post ? _post.text : '',
      track: p.track,
    );
  }

  Future<void> _save(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      await action();
    } catch (_) {
      if (mounted) {
        setState(
          () => _saveError = 'Could not save. Your existing target and evidence are unchanged. Please try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(String? url) async {
    if (url == null) return;
    try {
      final uri = publicBenchmarkUrl(url)!;
      final ok =
          await (widget.onOpenSource?.call(uri) ??
              launchUrl(uri, mode: LaunchMode.externalApplication));
      if (!ok) throw StateError('unavailable');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This source link could not be opened.'),
          ),
        );
      }
    }
  }

  Widget _panel(Widget child, {Color color = Colors.white}) => Material(
    color: color,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: AppColors.line),
      borderRadius: BorderRadius.circular(14),
    ),
    child: SizedBox(
      width: double.infinity,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  );
  Widget _label(String s) => Text(
    s,
    style: const TextStyle(fontSize: 11, color: AppColors.muted, height: 1.6),
  );
  Widget _citations(ResearchPlan plan, List<String> ids) => Wrap(
    spacing: 8,
    runSpacing: 2,
    children: [
      for (final source in plan.sources.where((s) => ids.contains(s.id)))
        TextButton.icon(
          key: ValueKey('source-${plan.id}-${source.id}'),
          onPressed: source.url == null ? null : () => _open(source.url),
          icon: Icon(
            source.url == null ? Icons.notes : Icons.open_in_new,
            size: 13,
          ),
          label: Text(
            '[${source.id}] ${source.title}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11),
          ),
        ),
    ],
  );
  Future<void> _connection() async {
    final url = TextEditingController(text: widget.baseUrl.toString()),
        token = TextEditingController();
    final form = GlobalKey<FormState>();
    final result = await showDialog<CoachConnection>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('AI service connection'),
        content: SizedBox(
          width: 450,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: url,
                  decoration: const InputDecoration(labelText: 'Backend URL'),
                  validator: (v) {
                    try {
                      ApiCoachRepository.validateBaseUrl(Uri.parse(v ?? ''));
                      return null;
                    } catch (_) {
                      return 'Use HTTPS or a localhost URL.';
                    }
                  },
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: token,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Backend access token (optional)',
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Use the app backend here. Your OpenAI key stays on that server.',
                  style: TextStyle(fontSize: 12),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(
                  context,
                  CoachConnection(
                    Uri.parse(url.text.trim()),
                    token.text.trim(),
                  ),
                );
              }
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    // The dialog route finishes its closing animation before controllers are disposed.
    if (result != null && mounted) widget.onConnectionChanged?.call(result);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    url.dispose();
    token.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([p, r]),
    builder: (context, _) {
      final saved = p.data.researchPlans
          .where((plan) => plan.track == p.track)
          .toList();
      final selected = p.researchTarget;
      final preview = r.preview;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Icon(Icons.travel_explore, color: AppColors.green),
                    const Text(
                      'Research a person or post',
                      style: TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (widget.onPersonalAiSettings != null)
                      OutlinedButton.icon(
                        key: const Key('benchmark-personal-ai'),
                        onPressed: locked ? null : widget.onPersonalAiSettings,
                        icon: const Icon(Icons.key_outlined, size: 17),
                        label: const Text('Your AI model'),
                      ),
                    if (widget.onConnectionChanged != null)
                      TextButton(
                        onPressed: locked ? null : _connection,
                        child: const Text('Connection settings'),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _label(
                  'Find public professional evidence, then build a learning path with clear targets. Add a field or organization to identify the right person.',
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _health?.configured == true && _health?.mode == 'live'
                          ? Icons.check_circle_outline
                          : Icons.cloud_outlined,
                      size: 17,
                      color: AppColors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _label(
                        _checking
                            ? 'Checking AI service…'
                            : _health?.mode == 'demo'
                            ? 'Live mode is required for research.'
                            : _health?.configured == true
                            ? 'Live AI backend connected'
                            : 'Start the updated AI backend to research public sources.',
                      ),
                    ),
                    IconButton(
                      onPressed: _checking ? null : _check,
                      tooltip: 'Refresh connection',
                      icon: const Icon(Icons.refresh, size: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final kind in BenchmarkKind.values)
                            ChoiceChip(
                              key: ValueKey('research-kind-${kind.name}'),
                              label: Text(
                                kind == BenchmarkKind.person
                                    ? 'Person'
                                    : 'Post / role',
                              ),
                              selected: _kind == kind,
                              onSelected: locked
                                  ? null
                                  : (_) => setState(() => _kind = kind),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        key: const Key('research-query'),
                        controller: _query,
                        maxLength: 300,
                        enabled: !locked,
                        decoration: InputDecoration(
                          labelText: _kind == BenchmarkKind.person
                              ? 'Name, field, or public profile URL'
                              : 'Public post URL, job role, or post title',
                          hintText: _kind == BenchmarkKind.person
                              ? 'Name + organization or specialty'
                              : 'Public link or a specific role',
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Enter a name, public URL, or post title.'
                            : null,
                      ),
                      TextFormField(
                        key: const Key('research-context'),
                        controller: _context,
                        maxLength: 3000,
                        enabled: !locked,
                        minLines: 1,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Context or the level you want to reach (optional)',
                        ),
                      ),
                      if (_kind == BenchmarkKind.post)
                        TextFormField(
                          key: const Key('research-post-text'),
                          controller: _post,
                          maxLength: 10000,
                          enabled: !locked,
                          minLines: 3,
                          maxLines: 7,
                          decoration: const InputDecoration(
                            labelText:
                                'Paste the post or job description (optional)',
                            helperText: 'Helpful for pages that require a login. Provided text is unverified.',
                          ),
                        ),
                      const SizedBox(height: 10),
                      _label(
                        widget.personalAiLabel == null
                            ? 'Research sends this query, context, and any pasted post to OpenAI. Public pages provide evidence; path milestones and score thresholds are inferred learning targets.'
                            : 'Requests go directly to ${widget.personalAiLabel}. Public web search requires a supported OpenAI model. Pasted posts can be analyzed with other providers as unverified context; no linked page is claimed to have been read.',
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        key: const Key('research-search'),
                        onPressed: locked ? null : _research,
                        icon: r.researching
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.search, size: 19),
                        label: Text(
                          r.researching
                              ? 'Researching public sources…'
                              : 'Research and build path',
                        ),
                      ),
                      if (r.researching)
                        const Padding(
                          padding: EdgeInsets.only(top: 10),
                          child: Text(
                            'Public research may take a couple of minutes. Your saved targets are kept.',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (r.error != null) ...[
            const SizedBox(height: 15),
            _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    r.error!.message,
                    key: const Key('research-error'),
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                  TextButton(
                    onPressed: locked
                        ? null
                        : () {
                            if (r.lastWasReview && selected != null) {
                              r.reviewProgress(
                                BenchmarkAnalytics.evaluate(
                                  selected,
                                  p.data.labResults,
                                  p.data.projectEvidence,
                                ),
                              );
                            } else {
                              r.retry();
                            }
                          },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ],
          if (_saveError != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                _saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (preview != null &&
              !saved.any((plan) => plan.id == preview.id)) ...[
            const SizedBox(height: 20),
            _plan(preview, preview: true),
          ],
          if (saved.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Text(
              'Your researched targets',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: ValueKey(
                'research-saved-${p.data.selectedResearchPlanId}-${saved.length}',
              ),
              initialValue: selected?.id ?? '',
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Selected research target',
              ),
              items: [
                const DropdownMenuItem(
                  value: '',
                  child: Text('Choose a saved path'),
                ),
                for (final plan in saved)
                  DropdownMenuItem(
                    value: plan.id,
                    child: Text(
                      plan.subjectName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: locked
                  ? null
                  : (id) =>
                        _save(() => p.selectResearchPlan(id == '' ? null : id)),
            ),
          ],
          if (selected != null) ...[
            const SizedBox(height: 18),
            _plan(selected, preview: false),
          ],
          const SizedBox(height: 28),
        ],
      );
    },
  );
  Widget _plan(ResearchPlan plan, {required bool preview}) {
    final snapshot = BenchmarkAnalytics.evaluate(
      plan,
      p.data.labResults,
      p.data.projectEvidence,
    );
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(
            preview
                ? 'RESEARCH PREVIEW · ${plan.track.label.toUpperCase()}'
                : 'SELECTED TARGET · ${plan.track.label.toUpperCase()}',
          ),
          const SizedBox(height: 6),
          Text(
            plan.subjectName,
            key: ValueKey('research-subject-${plan.id}'),
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          Text(
            plan.headline,
            style: const TextStyle(
              color: AppColors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Text(plan.summary, style: const TextStyle(height: 1.7)),
          for (final warning in plan.warnings)
            Padding(
              padding: const EdgeInsets.only(top: 7),
              child: Text(
                warning,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 12,
                  height: 1.5,
                ),
              ),
            ),
          const SizedBox(height: 12),
          for (final e in plan.evidence)
            Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.text,
                    style: const TextStyle(fontSize: 12, height: 1.6),
                  ),
                  _citations(plan, e.sourceIds),
                ],
              ),
            ),
          if (!plan.isReady)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: _label(
                plan.status == ResearchStatus.needsContext
                    ? 'Add a field, organization, or profile URL to identify the right person before setting a target.'
                    : 'Add more public evidence or paste the relevant post text, then research again.',
              ),
            ),
          if (plan.isReady) ...[
            const Divider(height: 28),
            if (!preview) ...[
              Wrap(
                spacing: 14,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    '${snapshot.progressPercent.toStringAsFixed(1)}%',
                    key: const Key('roadmap-readiness'),
                    style: const TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                  const Text(
                    'Roadmap readiness',
                    style: TextStyle(fontSize: 18),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: snapshot.progressPercent / 100,
                minHeight: 8,
                borderRadius: BorderRadius.circular(8),
              ),
              const SizedBox(height: 10),
              _label(
                '${snapshot.completeCount} of 5 milestones reached · ${snapshot.assessmentCount} assessed skills · ${snapshot.projectCount} self-reported project completions',
              ),
              const SizedBox(height: 7),
              _label(
                'Assessment steps use the latest test on the exact topic, level, and track. Project completions are self-reported. Readiness describes evidence toward this path.',
              ),
              const SizedBox(height: 16),
            ],
            const Text(
              'Your five-step path',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            for (final item in snapshot.milestones)
              _milestone(plan, item, preview),
            if (preview)
              FilledButton.icon(
                key: const Key('research-adopt'),
                onPressed: locked
                    ? null
                    : () => _save(() => p.adoptResearchPlan(plan)),
                icon: const Icon(Icons.flag_outlined, size: 18),
                label: const Text('Adopt path and set target'),
              ),
            if (!preview) ...[
              Wrap(
                spacing: 10,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    key: const Key('research-review'),
                    onPressed: locked ? null : () => r.reviewProgress(snapshot),
                    icon: r.reviewing
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.auto_awesome, size: 17),
                    label: Text(
                      r.reviewing
                          ? 'Reviewing your evidence…'
                          : 'AI review my progress',
                    ),
                  ),
                  TextButton(
                    onPressed: locked ? null : () => _remove(plan),
                    child: const Text('Remove saved path'),
                  ),
                ],
              ),
              if (r.reviewMatches(snapshot) && r.review != null) ...[
                const SizedBox(height: 14),
                _panel(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI progress review',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 9),
                      Text(
                        r.review!.summary,
                        key: const Key('research-review-summary'),
                        style: const TextStyle(height: 1.7),
                      ),
                      if (r.review!.blockers.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Gaps to close',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        for (final x in r.review!.blockers)
                          Text('• $x', style: const TextStyle(height: 1.6)),
                      ],
                      if (r.review!.nextActions.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        const Text(
                          'Next actions',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        for (final x in r.review!.nextActions)
                          Text('• $x', style: const TextStyle(height: 1.6)),
                      ],
                    ],
                  ),
                  color: AppColors.pale,
                ),
              ] else if (r.review != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: _label(
                    'Your evidence has changed. Request a new AI review for the current progress.',
                  ),
                ),
            ],
          ],
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              'Sources and research details (${plan.sources.length})',
              style: const TextStyle(fontSize: 12),
            ),
            children: [
              for (final s in plan.sources)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '[${s.id}] ${s.title}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  subtitle: Text(
                    s.url ?? 'Post text provided by you · unverified',
                    style: const TextStyle(fontSize: 10),
                  ),
                  onTap: s.url == null ? null : () => _open(s.url),
                ),
              _label(
                'Researched ${plan.researchedAt.toLocal().toString().split('.').first} · ${plan.model}',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _milestone(ResearchPlan plan, MilestoneProgress item, bool preview) {
    final m = item.milestone;
    final assessment = m.kind == RoadmapMilestoneKind.assessment;
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.pale,
                  child: Text(
                    m.id.substring(1),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.green,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    m.title,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (!preview && item.complete)
                  const Icon(
                    Icons.check_circle,
                    color: AppColors.green,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              m.description,
              style: const TextStyle(fontSize: 12, height: 1.7),
            ),
            const SizedBox(height: 8),
            _label(
              assessment
                  ? 'Assessment · ${m.level.label} · Target ${m.targetScore}/100 · Topic: ${m.topic}'
                  : 'Project · Completion is reported by you',
            ),
            _citations(plan, m.sourceIds),
            if (!preview) ...[
              LinearProgressIndicator(
                value: item.fraction,
                minHeight: 5,
                borderRadius: BorderRadius.circular(5),
              ),
              const SizedBox(height: 7),
              _label(
                assessment
                    ? item.assessment == null
                          ? 'No matching assessment yet.'
                          : 'Latest matching test: ${item.score!.toStringAsFixed(1)}/100'
                    : item.projectEvidence?.completed == true
                    ? 'Reported complete. Add or update evidence below.'
                    : 'Add project notes or a public deliverable link.',
              ),
              if (item.projectEvidence?.notes.isNotEmpty == true)
                Text(
                  item.projectEvidence!.notes,
                  style: const TextStyle(fontSize: 12, height: 1.6),
                ),
              if (item.projectEvidence?.url != null)
                TextButton(
                  onPressed: () => _open(item.projectEvidence!.url),
                  child: const Text('Open project evidence'),
                ),
              OutlinedButton.icon(
                key: ValueKey('roadmap-action-${m.id}'),
                onPressed: locked
                    ? null
                    : assessment
                    ? () => widget.onTestMilestone(plan, m)
                    : () => _project(plan, m, item.projectEvidence),
                icon: Icon(
                  assessment ? Icons.science_outlined : Icons.edit_note,
                  size: 17,
                ),
                label: Text(
                  assessment
                      ? 'Test this skill'
                      : 'Add or edit project evidence',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _project(
    ResearchPlan plan,
    RoadmapMilestone m,
    RoadmapProjectEvidence? existing,
  ) async {
    final form = GlobalKey<FormState>();
    final notes = TextEditingController(text: existing?.notes ?? ''),
        url = TextEditingController(text: existing?.url ?? '');
    bool complete = existing?.completed ?? false;
    String? issue;
    final result = await showDialog<RoadmapProjectEvidence>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          scrollable: true,
          title: Text(m.title),
          content: SizedBox(
            width: 500,
            child: SingleChildScrollView(
              child: Form(
                key: form,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.description,
                      style: const TextStyle(fontSize: 12, height: 1.6),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      key: const Key('project-notes'),
                      controller: notes,
                      maxLength: 1200,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'What did you build? Add evidence or a brief reflection.',
                      ),
                    ),
                    TextFormField(
                      key: const Key('project-url'),
                      controller: url,
                      maxLength: 2048,
                      decoration: const InputDecoration(
                        labelText: 'Public project URL (optional)',
                      ),
                      validator: (s) {
                        try {
                          publicBenchmarkUrl(s);
                          return null;
                        } catch (_) {
                          return 'Use a public HTTPS URL.';
                        }
                      },
                    ),
                    SwitchListTile(
                      key: const Key('project-completed'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('I completed this milestone'),
                      subtitle: const Text(
                        'This is self-reported; AI has not verified the project.',
                      ),
                      value: complete,
                      onChanged: (v) => setLocal(() => complete = v),
                    ),
                    if (issue != null)
                      Text(
                        issue!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
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
              key: const Key('project-save'),
              onPressed: () {
                if (!form.currentState!.validate()) return;
                if (complete &&
                    notes.text.trim().isEmpty &&
                    url.text.trim().isEmpty) {
                  setLocal(
                    () => issue = 'Add project notes or a public link before marking it complete.',
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  RoadmapProjectEvidence(
                    planId: plan.id,
                    milestoneId: m.id,
                    completed: complete,
                    notes: notes.text.trim(),
                    url: url.text.trim().isEmpty ? null : url.text.trim(),
                    updatedAt: DateTime.now(),
                  ),
                );
              },
              child: const Text('Save evidence'),
            ),
          ],
        ),
      ),
    );
    if (result != null && mounted) {
      await _save(() => p.upsertProjectEvidence(result));
    }
    await Future<void>.delayed(const Duration(milliseconds: 300));
    notes.dispose();
    url.dispose();
  }

  Future<void> _remove(ResearchPlan plan) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('Remove this saved path?'),
        content: Text(
          '${plan.subjectName} and its project evidence will be removed. Your Testing Lab results and other targets are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove path'),
          ),
        ],
      ),
    );
    if (yes == true && mounted) {
      await _save(() => p.deleteResearchPlan(plan.id));
    }
  }
}
