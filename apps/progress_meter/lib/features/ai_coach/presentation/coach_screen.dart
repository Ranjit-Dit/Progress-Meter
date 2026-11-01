import 'package:flutter/material.dart';

import '../../../app/progress_controller.dart';
import '../../../common/app_theme.dart';
import '../../progress/domain/models.dart';
import '../../progress/presentation/progress_dialogs.dart';
import '../application/coach_controller.dart';
import '../data/api_coach_repository.dart';
import '../domain/coach_models.dart';

class CoachConnection {
  const CoachConnection(this.url, this.accessToken);
  final Uri url;
  final String accessToken;
}

Future<CoachConnection?> showCoachConnectionDialog(
  BuildContext context, {
  required Uri current,
}) => showDialog<CoachConnection>(
  context: context,
  builder: (_) => _ConnectionDialog(current: current),
);

class CoachScreen extends StatefulWidget {
  const CoachScreen({
    super.key,
    required this.progress,
    required this.controller,
    required this.baseUrl,
    required this.onConnectionChanged,
    this.onPersonalAiSettings,
    this.personalAiLabel,
  });
  final ProgressController progress;
  final CoachController controller;
  final Uri baseUrl;
  final ValueChanged<CoachConnection> onConnectionChanged;
  final VoidCallback? onPersonalAiSettings;
  final String? personalAiLabel;
  @override
  State<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends State<CoachScreen> {
  final _question = TextEditingController();
  final _form = GlobalKey<FormState>();
  final _responseAnchor = GlobalKey();
  final _added = <CoachSuggestion>{};
  bool _includeNotes = false;
  bool _checking = false;
  CoachHealth? _health;
  String? _healthError;
  CoachController get coach => widget.controller;
  ProgressController get progress => widget.progress;

  @override
  void initState() {
    super.initState();
    _includeNotes = coach.lastContext?.includesNotes ?? false;
    _checkConnection();
  }

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _checking = true;
      _healthError = null;
    });
    try {
      final result = await coach.checkHealth();
      if (mounted) setState(() => _health = result);
    } catch (_) {
      if (mounted) {
        setState(() {
          _health = null;
          _healthError = 'Coach service is offline';
        });
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _send([String? prompt]) async {
    if (coach.busy) return;
    if (prompt == null && !_form.currentState!.validate()) return;
    final question = (prompt ?? _question.text).trim();
    _question.clear();
    await coach.ask(
      question,
      CoachContext.fromProgressData(
        progress.data,
        progress.track,
        includeNotes: _includeNotes,
      ),
    );
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _responseAnchor.currentContext;
      if (anchor != null && mounted) {
        Scrollable.ensureVisible(
          anchor,
          duration: const Duration(milliseconds: 250),
          alignment: .15,
        );
      }
    });
  }

  Future<void> _connectionSettings() async {
    final result = await showDialog<CoachConnection>(
      context: context,
      builder: (_) => _ConnectionDialog(current: widget.baseUrl),
    );
    if (result != null && mounted) widget.onConnectionChanged(result);
  }

  Future<void> _reviewGoal(CoachSuggestion suggestion) async {
    final track = progress.track;
    final now = DateUtils.dateOnly(DateTime.now());
    final result = await showGoalDialog(
      context,
      track,
      initialMetric: suggestion.metric,
      initialTarget: suggestion.target,
      initialTitle: suggestion.title,
      initialDeadline: now.add(Duration(days: suggestion.days)),
    );
    if (result == null || !mounted) return;
    try {
      await progress.addGoal(result);
      if (!mounted) return;
      setState(() => _added.add(suggestion));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your reviewed goal has been added to Goals.'),
        ),
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this goal. Please try again.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: coach,
    builder: (context, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 20,
          runSpacing: 15,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'A LITTLE GUIDANCE FOR YOUR NEXT STEP',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Meet your progress coach.',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Reflect on your journey. Find a focus. Make a plan.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
            OutlinedButton.icon(
              key: const Key('coach-connection'),
              onPressed: _connectionSettings,
              icon: const Icon(
                Icons.settings_input_component_outlined,
                size: 16,
              ),
              label: const Text('Connection settings'),
            ),
            if (widget.onPersonalAiSettings != null)
              OutlinedButton.icon(
                key: const Key('coach-personal-ai'),
                onPressed: coach.busy ? null : widget.onPersonalAiSettings,
                icon: const Icon(Icons.key_outlined, size: 16),
                label: const Text('Your AI model'),
              ),
          ],
        ),
        const SizedBox(height: 25),
        LayoutBuilder(
          builder: (context, box) {
            final conversation = _conversation();
            final contextPanel = _contextPanel();
            if (box.maxWidth < 850) {
              return Column(
                children: [
                  contextPanel,
                  const SizedBox(height: 20),
                  conversation,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: conversation),
                const SizedBox(width: 22),
                Expanded(flex: 2, child: contextPanel),
              ],
            );
          },
        ),
      ],
    ),
  );

  Widget _panel(Widget child, {Color color = Colors.white}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );

  Widget _conversation() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (coach.turns.isEmpty && !coach.busy) ...[
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.pale,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.green,
                  size: 23,
                ),
              ),
              const SizedBox(height: 17),
              const Text(
                'What would help you move forward?',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Ask about your recent progress, a study or career plan, or the gap to your selected benchmark.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 21),
              for (final (icon, title, prompt) in [
                (
                  Icons.insights_outlined,
                  'Understand my progress',
                  'Explain my recent progress. What improved, and what should I focus on next?',
                ),
                (
                  Icons.calendar_month_outlined,
                  'Build a 7-day plan',
                  'Help me create a realistic 7-day plan based on my current progress and goals.',
                ),
                (
                  Icons.flag_outlined,
                  'Close my benchmark gap',
                  'Help me close the gap to my selected benchmark. Suggest practical next steps without promising a timeline.',
                ),
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 9),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: coach.busy ? null : () => _send(prompt),
                      icon: Icon(icon, size: 17),
                      label: Text(title, style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        alignment: Alignment.centerLeft,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
      ],
      if (coach.turns.isNotEmpty) ...[
        Row(
          children: [
            const Expanded(
              child: Text(
                'YOUR CONVERSATION',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted,
                ),
              ),
            ),
            TextButton.icon(
              key: const Key('coach-clear'),
              onPressed: coach.clear,
              icon: const Icon(Icons.refresh, size: 14),
              label: const Text(
                'New conversation',
                style: TextStyle(fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < coach.turns.length; index++)
          Padding(
            key: index == coach.turns.length - 1 ? _responseAnchor : null,
            padding: const EdgeInsets.only(bottom: 14),
            child: _message(coach.turns[index]),
          ),
      ],
      if (coach.latestReply?.source == 'demo')
        Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: _panel(
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.science_outlined, color: AppColors.gold, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Example response · Your service is in demo mode. This guidance was generated locally to preview the feature; it is not an OpenAI response.',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
            color: const Color(0xFFFAF7F0),
          ),
        ),
      if (coach.busy)
        Padding(
          padding: const EdgeInsets.only(bottom: 15),
          child: _panel(
            const Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Looking at your progress…',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ),
      if (coach.error != null) ...[_errorPanel(), const SizedBox(height: 16)],
      if (!coach.busy &&
          coach.latestReply != null &&
          coach.latestReply!.suggestions.isNotEmpty) ...[
        const SizedBox(height: 8),
        const Text(
          'TURN GUIDANCE INTO A GOAL',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.3,
            color: AppColors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 7),
        const Text(
          'Review the title, target, and deadline before anything is saved.',
          style: TextStyle(fontSize: 11, color: AppColors.muted),
        ),
        const SizedBox(height: 13),
        for (final suggestion in coach.latestReply!.suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _panel(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    suggestion.title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    '${metricLabel(suggestion.metric, progress.track)} · Target ${suggestion.target.round()}/100 · ${suggestion.days} days',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 13),
                  OutlinedButton.icon(
                    key: ValueKey('coach-goal-${suggestion.title}'),
                    onPressed: _added.contains(suggestion) || progress.saving
                        ? null
                        : () => _reviewGoal(suggestion),
                    icon: Icon(
                      _added.contains(suggestion)
                          ? Icons.check_circle_outline
                          : Icons.add_rounded,
                      size: 16,
                    ),
                    label: Text(
                      _added.contains(suggestion)
                          ? 'Added to Goals'
                          : 'Review goal',
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 10),
      ],
      _panel(
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                key: const Key('coach-question'),
                controller: _question,
                minLines: 2,
                maxLines: 5,
                maxLength: 2000,
                decoration: InputDecoration(
                  hintText:
                      'Ask about your ${progress.track.label.toLowerCase()} progress…',
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Write a question or choose a prompt above.'
                    : null,
              ),
              const SizedBox(height: 9),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'AI guidance can be mistaken. Use your own judgment.',
                      style: TextStyle(fontSize: 10, color: AppColors.muted),
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    key: const Key('coach-send'),
                    onPressed: coach.busy ? null : () => _send(),
                    icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                    label: const Text('Send'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 11),
      const Text(
        'Sending shares your question and the progress context shown here with your coach service and, in live mode, OpenAI. Conversations stay in memory for this session.',
        style: TextStyle(fontSize: 10, height: 1.7, color: AppColors.muted),
      ),
    ],
  );

  Widget _message(CoachTurn turn) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              turn.role == 'user'
                  ? Icons.person_outline
                  : Icons.auto_awesome_outlined,
              size: 16,
              color: AppColors.green,
            ),
            const SizedBox(width: 8),
            Text(
              turn.role == 'user' ? 'YOU' : 'PROGRESS COACH',
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 13),
        SelectableText(
          turn.text,
          style: const TextStyle(
            fontSize: 13,
            height: 1.8,
            color: AppColors.ink,
          ),
        ),
      ],
    ),
    color: turn.role == 'user' ? AppColors.pale : Colors.white,
  );

  Widget _errorPanel() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: AppColors.gold),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Your coach needs a moment',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          coach.error!.message,
          style: const TextStyle(
            fontSize: 12,
            height: 1.7,
            color: AppColors.muted,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            OutlinedButton(
              key: const Key('coach-retry'),
              onPressed: coach.busy ? null : () => coach.retry(),
              child: const Text('Try again'),
            ),
            TextButton(
              onPressed: _connectionSettings,
              child: const Text('Connection settings'),
            ),
          ],
        ),
      ],
    ),
    color: const Color(0xFFFAF7F0),
  );

  Widget _contextPanel() {
    final history = progress.history;
    final recent = history.length > 12 ? 12 : history.length;
    final activeGoals = progress.goals
        .where((goal) => !goal.completed)
        .take(12)
        .length;
    final target = progress.target;
    final status = widget.personalAiLabel != null
        ? 'Personal AI configured · ${widget.personalAiLabel}'
        : _checking
        ? 'Checking connection…'
        : _health == null
        ? 'Coach service is offline'
        : _health!.mode == 'demo'
        ? 'Connected · demo mode'
        : !_health!.configured
        ? 'Service connected · key needed'
        : 'Connected to your coach';
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Your coaching context',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                key: const Key('coach-health-refresh'),
                tooltip: 'Check coach connection',
                onPressed: _checking ? null : _checkConnection,
                icon: const Icon(
                  Icons.sync_rounded,
                  size: 18,
                  color: AppColors.green,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _health?.configured == true
                    ? Icons.check_circle_outline
                    : Icons.circle_outlined,
                size: 14,
                color: _health?.configured == true
                    ? AppColors.green
                    : AppColors.gold,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  status,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
          if (_healthError != null || _health?.configured == false) ...[
            const SizedBox(height: 11),
            Text(
              _health?.configured == false
                  ? 'Configure OPENAI_API_KEY in your backend’s .env file, then restart the service.'
                  : 'Start the local coach service or connect to a hosted coach in Connection settings.',
              style: const TextStyle(
                fontSize: 11,
                height: 1.7,
                color: AppColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 15),
          _contextRow(
            Icons.school_outlined,
            'Selected track',
            progress.track.label,
          ),
          _contextRow(
            Icons.timeline_rounded,
            'AI judgments',
            '$recent snapshots',
          ),
          _contextRow(
            Icons.flag_outlined,
            'Active goals',
            '$activeGoals milestones',
          ),
          _contextRow(
            Icons.people_outline,
            'Benchmark',
            target == null
                ? 'None selected'
                : target.isExample
                ? 'Fictional example'
                : 'Manual, unverified',
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 11),
          CheckboxListTile(
            key: const Key('coach-share-notes'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            title: const Text(
              'Include AI review details',
              style: TextStyle(fontSize: 12),
            ),
            subtitle: const Text(
              'Optional. Notes stay private by default.',
              style: TextStyle(fontSize: 10, color: AppColors.muted),
            ),
            value: _includeNotes,
            onChanged: coach.busy
                ? null
                : (value) {
                    coach.clear();
                    setState(() => _includeNotes = value ?? false);
                  },
          ),
          const SizedBox(height: 7),
          const Text(
            'Names are omitted from profile context. Goal titles and anything you type may still contain personal details. Changing tracks or note sharing starts a new conversation.',
            style: TextStyle(fontSize: 10, height: 1.7, color: AppColors.muted),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.pale,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Your progress stays yours.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'The coach offers ideas. Only the dedicated AI review can judge your scores; goal suggestions need your review before saving.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.7,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _contextRow(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      children: [
        Icon(icon, size: 17, color: AppColors.green),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
          ),
        ),
      ],
    ),
  );
}

class _ConnectionDialog extends StatefulWidget {
  const _ConnectionDialog({required this.current});
  final Uri current;
  @override
  State<_ConnectionDialog> createState() => _ConnectionDialogState();
}

class _ConnectionDialogState extends State<_ConnectionDialog> {
  final _form = GlobalKey<FormState>();
  late final _url = TextEditingController(text: widget.current.toString());
  final _token = TextEditingController();
  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  String? _validateUrl(String? value) {
    try {
      ApiCoachRepository.validateBaseUrl(Uri.parse(value?.trim() ?? ''));
      return null;
    } catch (_) {
      return 'Use HTTPS, or HTTP for a local development service.';
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Connect your coach'),
    content: SizedBox(
      width: 520,
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Connect only to a coach service you trust. It receives the progress context you choose to send.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 19),
              TextFormField(
                key: const Key('coach-url'),
                controller: _url,
                maxLength: 2048,
                keyboardType: TextInputType.url,
                autocorrect: false,
                validator: _validateUrl,
                decoration: const InputDecoration(
                  labelText: 'Coach service URL',
                  hintText: 'http://127.0.0.1:8787',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('coach-access-token'),
                controller: _token,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Coach access token (if required)',
                  helperText: 'This is not your OpenAI API key.',
                ),
                validator: (value) =>
                    value != null && value.trim().startsWith('sk-')
                    ? 'Keep your OpenAI API key on the backend only.'
                    : null,
              ),
              const SizedBox(height: 19),
              const Text(
                'LOCAL BACKEND SETUP',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w600,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '1. Add your OpenAI key to backend/.env.\n2. Run this command from the backend folder:',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.8,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 9),
              const SelectableText(
                'node --env-file-if-exists=.env server.mjs',
                style: TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
              const SizedBox(height: 12),
              const Text(
                'Connection changes apply to this session and start a new conversation. Use COACH_API_URL when building to set a permanent default.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.7,
                  color: AppColors.muted,
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
        key: const Key('coach-connect-save'),
        onPressed: () {
          if (_form.currentState!.validate()) {
            Navigator.pop(
              context,
              CoachConnection(Uri.parse(_url.text.trim()), _token.text.trim()),
            );
          }
        },
        child: const Text('Connect'),
      ),
    ],
  );
}
