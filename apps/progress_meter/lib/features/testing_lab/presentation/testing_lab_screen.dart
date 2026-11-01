import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/progress_controller.dart';
import '../../../common/app_theme.dart';
import '../../ai_coach/data/api_coach_repository.dart';
import '../../ai_coach/domain/coach_models.dart';
import '../../ai_coach/presentation/coach_screen.dart';
import '../../progress/domain/models.dart';
import '../application/lab_controller.dart';
import '../domain/lab_models.dart';
import '../domain/lab_analytics.dart';

class TestingLabScreen extends StatefulWidget {
  const TestingLabScreen({
    super.key,
    required this.progress,
    required this.controller,
    required this.baseUrl,
    this.onConnectionChanged,
    this.onPersonalAiSettings,
    this.personalAiLabel,
    this.now,
  });

  final ProgressController progress;
  final LabController controller;
  final Uri baseUrl;
  final ValueChanged<CoachConnection>? onConnectionChanged;
  final VoidCallback? onPersonalAiSettings;
  final String? personalAiLabel;
  final DateTime? now;

  @override
  State<TestingLabScreen> createState() => _TestingLabScreenState();
}

class _TestingLabScreenState extends State<TestingLabScreen> {
  final _form = GlobalKey<FormState>();
  final _formAnchor = GlobalKey();
  final _testAnchor = GlobalKey();
  final _resultAnchor = GlobalKey();
  final _topic = TextEditingController();
  final _notes = TextEditingController();
  final _questionCount = TextEditingController(
    text: '$defaultLabQuestionCount',
  );
  final _answerFields = <String, TextEditingController>{};
  late ProgressTrack _track;
  late ProgressTrack _historyTrack;
  LabLevel _level = LabLevel.intermediate;
  String? _editingSession;
  CoachHealth? _health;
  bool _checking = false;
  bool _offline = false;
  int _historyLimit = 8;

  LabController get lab => widget.controller;
  DateTime get now => widget.now ?? DateTime.now();
  List<LabResult> get history =>
      LabAnalytics.history(widget.progress.data.labResults, _historyTrack);

  @override
  void initState() {
    super.initState();
    final current = lab.session;
    _track = current?.track ?? lab.result?.track ?? widget.progress.track;
    _historyTrack = _track;
    _topic.text = current?.topic ?? lab.result?.topic ?? '';
    _level = current?.level ?? lab.result?.level ?? LabLevel.intermediate;
    _questionCount.text =
        '${current?.questionCount ?? lab.result?.questionCount ?? defaultLabQuestionCount}';
    _checkConnection();
  }

  @override
  void didUpdateWidget(covariant TestingLabScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _editingSession = null;
      for (final field in _answerFields.values) {
        field.dispose();
      }
      _answerFields.clear();
      _health = null;
      _checkConnection();
    }
  }

  @override
  void dispose() {
    _topic.dispose();
    _notes.dispose();
    _questionCount.dispose();
    for (final field in _answerFields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _checkConnection() async {
    setState(() {
      _checking = true;
      _offline = false;
    });
    final checkingController = lab;
    try {
      final response = await checkingController.checkHealth();
      if (mounted && checkingController == lab) {
        setState(() => _health = response);
      }
    } catch (_) {
      if (mounted && checkingController == lab) {
        setState(() {
          _health = null;
          _offline = true;
        });
      }
    } finally {
      if (mounted && checkingController == lab) {
        setState(() => _checking = false);
      }
    }
  }

  Future<void> _connectionSettings() async {
    final result = await showDialog<CoachConnection>(
      context: context,
      builder: (_) => _LabConnectionDialog(current: widget.baseUrl),
    );
    if (result != null && mounted) widget.onConnectionChanged?.call(result);
  }

  void _reveal(GlobalKey anchor) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = anchor.currentContext;
      if (target != null) {
        Scrollable.ensureVisible(
          target,
          duration: const Duration(milliseconds: 250),
          alignment: .05,
        );
      }
    });
  }

  Future<void> _generate() async {
    if (lab.busy || !_form.currentState!.validate()) return;
    await lab.generate(
      topic: _topic.text.trim(),
      learningNotes: _notes.text.trim(),
      track: _track,
      level: _level,
      questionCount: int.parse(_questionCount.text.trim()),
    );
    if (!mounted) return;
    if (lab.session != null) _reveal(_testAnchor);
  }

  void _syncAnswers(LabSession session) {
    if (_editingSession == session.sessionId) return;
    for (final field in _answerFields.values) {
      field.dispose();
    }
    _answerFields.clear();
    for (final question in session.questions) {
      _answerFields[question.id] = TextEditingController(
        text: lab.answers[question.id] ?? '',
      );
    }
    _editingSession = session.sessionId;
  }

  Future<void> _submit() async {
    final session = lab.session;
    if (session == null || lab.busy) return;
    final unanswered = session.questions
        .where((q) => (lab.answers[q.id] ?? '').trim().isEmpty)
        .length;
    if (unanswered > 0 && !lab.answersLocked) {
      final submit = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(
            'Submit $unanswered unanswered ${unanswered == 1 ? 'question' : 'questions'}?',
          ),
          content: const SizedBox(
            width: 420,
            child: Text(
              'Unanswered questions receive zero marks. Once submitted, these answers are locked for this assessment.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep working'),
            ),
            FilledButton(
              key: const Key('lab-confirm-submit'),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit answers'),
            ),
          ],
        ),
      );
      if (submit != true || !mounted) return;
    }
    await lab.submit();
    if (mounted && lab.result != null) _reveal(_resultAnchor);
  }

  Future<void> _startAgain({LabResult? repeat}) async {
    if (lab.busy) return;
    if (lab.result != null && !lab.saved) return;
    if (lab.session != null && lab.result == null) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: const Text('Start another assessment?'),
          content: const SizedBox(
            width: 420,
            child: Text(
              'This unfinished test and its answers will be cleared. Your completed assessment history is kept.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Keep this test'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Start another'),
            ),
          ],
        ),
      );
      if (discard != true || !mounted) return;
    }
    lab.clear();
    setState(() {
      if (repeat != null) {
        _topic.text = repeat.topic;
        _track = repeat.track;
        _historyTrack = repeat.track;
        _level = repeat.level;
        _questionCount.text = '${repeat.questionCount}';
      } else {
        _topic.clear();
        _questionCount.text = '$defaultLabQuestionCount';
      }
      _notes.clear();
    });
    _reveal(_formAnchor);
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([lab, widget.progress]),
    builder: (context, _) {
      final session = lab.session;
      final result = lab.result;
      if (session != null) _syncAnswers(session);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(),
          const SizedBox(height: 22),
          _connection(),
          const SizedBox(height: 22),
          if (lab.error != null) ...[_error(), const SizedBox(height: 20)],
          if (result != null)
            _result(result, key: _resultAnchor)
          else if (session != null)
            _assessment(session)
          else
            _setup(),
          const SizedBox(height: 28),
          _history(),
        ],
      );
    },
  );

  Widget _header() => Wrap(
    alignment: WrapAlignment.spaceBetween,
    crossAxisAlignment: WrapCrossAlignment.center,
    spacing: 20,
    runSpacing: 16,
    children: [
      SizedBox(
        width: math.min(720, MediaQuery.sizeOf(context).width - 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'TURN LEARNING INTO EVIDENCE',
              style: TextStyle(
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
            const SizedBox(height: 9),
            Text(
              'Put your learning to the test.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Choose a topic and how many questions to answer. Get clear marks and a plan to improve.',
              style: TextStyle(
                fontSize: 12,
                height: 1.7,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
      if (widget.onPersonalAiSettings != null)
        OutlinedButton.icon(
          key: const Key('lab-personal-ai'),
          onPressed: lab.busy ? null : widget.onPersonalAiSettings,
          icon: const Icon(Icons.key_outlined, size: 17),
          label: const Text('Your AI model'),
        ),
      if (widget.onConnectionChanged != null)
        OutlinedButton.icon(
          key: const Key('lab-connection'),
          onPressed: lab.busy ? null : _connectionSettings,
          icon: const Icon(Icons.settings_input_component_outlined, size: 17),
          label: const Text('Connection settings'),
        ),
    ],
  );

  Widget _connection() {
    final ready = _health?.configured == true && _health?.mode == 'live';
    final label = widget.personalAiLabel != null
        ? 'Personal AI configured · ${widget.personalAiLabel}'
        : _checking
        ? 'Checking the AI examiner…'
        : ready
        ? 'Live AI examiner connected'
        : _health?.mode == 'demo'
        ? 'Live AI is required for grading'
        : _health?.configured == false
        ? 'OpenAI key is not configured'
        : _offline
        ? 'Testing Lab service is offline'
        : 'Connection not checked';
    return _panel(
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ready ? Icons.check_circle_outline : Icons.cloud_outlined,
            color: ready ? AppColors.green : AppColors.gold,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  key: const Key('lab-health'),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  ready
                      ? widget.personalAiLabel != null
                            ? 'Topics, optional learning notes, and submitted answers go directly to your selected AI provider. Completed assessments save on this device.'
                            : 'Questions and marks use your configured OpenAI model. Completed assessments save on this device.'
                      : _health?.mode == 'demo'
                      ? 'Run the backend in live mode with its OpenAI key. Demo coaching does not produce assessment grades.'
                      : _health?.configured == false
                      ? 'Add OPENAI_API_KEY to backend/.env and restart the service, then refresh this connection.'
                      : 'Start the backend with npm start from its folder, or connect to your hosted service.',
                  style: const TextStyle(
                    fontSize: 11,
                    height: 1.6,
                    color: AppColors.muted,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('lab-refresh-health'),
            tooltip: 'Refresh connection',
            onPressed: _checking || lab.busy ? null : _checkConnection,
            icon: const Icon(Icons.refresh, size: 19),
          ),
        ],
      ),
      padding: 16,
    );
  }

  Widget _error() => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          lab.result != null && !lab.saved
              ? 'Your grade is ready. Saving needs another try.'
              : 'The lab needs attention.',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Text(
          lab.error!.message,
          key: const Key('lab-error'),
          style: const TextStyle(fontSize: 12, height: 1.6),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 8,
          children: [
            if (lab.result != null && !lab.saved)
              FilledButton.icon(
                key: const Key('lab-retry-save'),
                onPressed: lab.busy ? null : lab.retrySave,
                icon: const Icon(Icons.save_outlined, size: 17),
                label: const Text('Retry saving grade'),
              )
            else
              OutlinedButton.icon(
                key: const Key('lab-retry'),
                onPressed: lab.busy
                    ? null
                    : () async {
                        await lab.retry();
                        if (mounted && lab.result != null) {
                          _reveal(_resultAnchor);
                        }
                      },
                icon: const Icon(Icons.refresh, size: 17),
                label: const Text('Try again'),
              ),
            if (lab.result == null && lab.session != null)
              TextButton(
                onPressed: lab.busy ? null : _startAgain,
                child: const Text('Start another test'),
              ),
          ],
        ),
      ],
    ),
    color: const Color(0xFFFBF4E8),
  );

  Widget _setup() => _panel(
    Form(
      key: _form,
      child: Column(
        key: _formAnchor,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'What have you learned?',
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          const Text(
            'Choose a specific topic and the depth you want to demonstrate. The examiner expects correct reasoning, precise answers, and application.',
            style: TextStyle(fontSize: 12, height: 1.7, color: AppColors.muted),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 9,
            runSpacing: 8,
            children: [
              for (final track in ProgressTrack.values)
                ChoiceChip(
                  key: ValueKey('lab-track-${track.name}'),
                  selected: _track == track,
                  label: Text(
                    track == ProgressTrack.academic
                        ? 'Academic topic'
                        : 'Career skill',
                  ),
                  avatar: Icon(
                    track == ProgressTrack.academic
                        ? Icons.school_outlined
                        : Icons.work_outline,
                    size: 16,
                  ),
                  onSelected: lab.busy
                      ? null
                      : (_) => setState(() {
                          _track = track;
                          _historyTrack = track;
                        }),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextFormField(
            key: const Key('lab-topic'),
            controller: _topic,
            enabled: !lab.busy,
            maxLength: 120,
            decoration: const InputDecoration(
              labelText: 'Topic you learned',
              hintText:
                  'For example, SQL joins or the product rule in calculus',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter a specific topic to assess.'
                : null,
          ),
          const SizedBox(height: 14),
          const Text(
            'Choose your level',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in LabLevel.values)
                ChoiceChip(
                  key: ValueKey('lab-level-${level.name}'),
                  label: Text(level.label),
                  selected: _level == level,
                  onSelected: lab.busy
                      ? null
                      : (_) => setState(() => _level = level),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: TextFormField(
                  key: const Key('lab-question-count'),
                  controller: _questionCount,
                  enabled: !lab.busy,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Number of questions',
                    helperText:
                        '$minLabQuestionCount–$maxLabQuestionCount questions · default $defaultLabQuestionCount',
                  ),
                  validator: (value) {
                    final count = int.tryParse(value?.trim() ?? '');
                    if (count == null ||
                        count < minLabQuestionCount ||
                        count > maxLabQuestionCount) {
                      return 'Enter a whole number from $minLabQuestionCount to $maxLabQuestionCount.';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),
              ),
              TextButton(
                key: const Key('lab-default-question-count'),
                onPressed: lab.busy
                    ? null
                    : () => setState(() {
                        _questionCount.text = '$defaultLabQuestionCount';
                      }),
                child: const Text('Use default ($defaultLabQuestionCount)'),
              ),
            ],
          ),
          const SizedBox(height: 20),
          TextFormField(
            key: const Key('lab-learning-notes'),
            controller: _notes,
            enabled: !lab.busy,
            maxLength: 6000,
            minLines: 3,
            maxLines: 7,
            decoration: const InputDecoration(
              labelText: 'What you learned · optional',
              hintText: 'List the concepts, chapter, or skills you covered so the questions stay relevant.',
            ),
          ),
          const SizedBox(height: 17),
          _rubricGuide(),
          const SizedBox(height: 18),
          const Text(
            'Generating sends this topic and optional notes to your AI service. Your written answers are sent when you submit for grading.',
            style: TextStyle(fontSize: 11, height: 1.7, color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const Key('lab-generate'),
            onPressed:
                lab.busy ||
                    _health?.configured == false ||
                    _health?.mode == 'demo'
                ? null
                : _generate,
            icon: lab.generating
                ? _spinner()
                : const Icon(Icons.science_outlined, size: 19),
            label: Text(
              lab.generating ? 'Writing your test…' : 'Generate test',
            ),
          ),
        ],
      ),
    ),
  );

  Widget _rubricGuide() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.pale,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Demanding, with a clear marking scheme.',
          style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.green),
        ),
        const SizedBox(height: 6),
        Text(
          '${_questionMix()} Each is worth 10 marks: correctness 5, reasoning 3, precision 2. Unsupported claims, vague explanations, and missing steps lose marks. Correct alternative methods earn credit.',
          style: const TextStyle(fontSize: 12, height: 1.7),
        ),
      ],
    ),
  );

  String _questionMix() {
    final count = int.tryParse(_questionCount.text.trim());
    if (count == null ||
        count < minLabQuestionCount ||
        count > maxLabQuestionCount) {
      return 'Questions cover understanding and application.';
    }
    final understanding = (count + 1) ~/ 2;
    final application = count ~/ 2;
    return '$understanding understanding ${understanding == 1 ? 'question' : 'questions'} + $application application ${application == 1 ? 'question' : 'questions'}.';
  }

  Widget _assessment(LabSession session) => Column(
    key: _testAnchor,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 9,
              runSpacing: 8,
              children: [
                _badge(session.track.label),
                _badge(session.level.label),
                _badge(
                  '${session.questionCount} QUESTIONS · ${session.questionCount * 10} MARKS',
                ),
              ],
            ),
            const SizedBox(height: 15),
            Text(
              session.topic,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            const Text(
              'Explain your reasoning and show working or code where useful. The examiner marks only what your answers demonstrate.',
              style: TextStyle(
                fontSize: 12,
                height: 1.7,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              lab.answersLocked
                  ? 'Answers submitted and locked. Retry grading to send the same submission.'
                  : 'Answers stay editable until you submit. Blank answers receive zero.',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.green,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Available until ${_dateTime(session.expiresAt)}. Unfinished tests are kept only during this app session.',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
      ),
      const SizedBox(height: 17),
      for (var index = 0; index < session.questions.length; index++) ...[
        _question(session.questions[index], index),
        const SizedBox(height: 14),
      ],
      _panel(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ready for a strict review?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Submitting locks this set of answers. Your grade and detailed feedback will be saved automatically when the review completes.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 17),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  key: const Key('lab-submit'),
                  onPressed: lab.busy
                      ? null
                      : lab.answersLocked
                      ? lab.retry
                      : _submit,
                  icon: lab.grading || lab.saving
                      ? _spinner()
                      : const Icon(Icons.fact_check_outlined, size: 19),
                  label: Text(
                    lab.grading
                        ? 'Examiner is marking…'
                        : lab.saving
                        ? 'Saving your assessment…'
                        : lab.answersLocked
                        ? 'Retry grading'
                        : 'Submit for strict grading',
                  ),
                ),
                OutlinedButton(
                  onPressed: lab.busy ? null : _startAgain,
                  child: const Text('Start another test'),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );

  Widget _question(LabQuestion question, int index) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 9,
          runSpacing: 7,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              'QUESTION ${index + 1}',
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.2,
                color: AppColors.green,
                fontWeight: FontWeight.w600,
              ),
            ),
            _badge(question.dimension.label),
            const Text(
              '10 marks',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
          ],
        ),
        const SizedBox(height: 15),
        SelectableText(
          question.prompt,
          style: const TextStyle(fontSize: 15, height: 1.7),
        ),
        const SizedBox(height: 16),
        TextField(
          key: ValueKey('lab-answer-${question.id}'),
          controller: _answerFields[question.id],
          enabled: !lab.busy && !lab.answersLocked,
          minLines: 4,
          maxLines: 12,
          maxLength: 6000,
          keyboardType: TextInputType.multiline,
          autocorrect: false,
          enableSuggestions: false,
          smartDashesType: SmartDashesType.disabled,
          smartQuotesType: SmartQuotesType.disabled,
          onChanged: (value) => lab.setAnswer(question.id, value),
          decoration: const InputDecoration(
            labelText: 'Your answer and reasoning',
            alignLabelWithHint: true,
            hintText: 'State your answer, then justify it. Show working or code where relevant.',
          ),
        ),
      ],
    ),
  );

  Widget _result(LabResult result, {Key? key, bool historical = false}) {
    final rows = widget.progress.data.labResults;
    final previous = LabAnalytics.previousComparable(rows, result);
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _panel(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _badge('ASSESSMENT COMPLETE'),
                  _badge(result.track.label),
                  _badge(result.level.label),
                  _badge(
                    '${result.questionCount} QUESTIONS · ${result.earnedPoints} / ${result.maxPoints} MARKS',
                  ),
                  _badge(
                    historical || lab.saved
                        ? 'SAVED ON DEVICE'
                        : 'GRADE NOT SAVED YET',
                    color: historical || lab.saved
                        ? AppColors.green
                        : AppColors.gold,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                result.topic,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '${_dateTime(result.completedAt)} · AI practice assessment',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 23),
              LayoutBuilder(
                builder: (context, box) {
                  final score = _score(result.totalScore);
                  final copy = Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _scoreLabel(result.totalScore),
                        style: const TextStyle(
                          fontSize: 21,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        result.feedback,
                        key: const Key('lab-overall-feedback'),
                        style: const TextStyle(fontSize: 13, height: 1.8),
                      ),
                      const SizedBox(height: 12),
                      if (previous != null)
                        Text(
                          '${_signed(result.totalScore - previous.totalScore)} points from your previous ${result.questionCount}-question ${result.level.label.toLowerCase()} assessment on this topic.',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.green,
                            height: 1.7,
                          ),
                        ),
                    ],
                  );
                  if (box.maxWidth < 650) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [score, const SizedBox(height: 20), copy],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      score,
                      const SizedBox(width: 28),
                      Expanded(child: copy),
                    ],
                  );
                },
              ),
              const SizedBox(height: 23),
              LayoutBuilder(
                builder: (context, box) {
                  final width = box.maxWidth < 650
                      ? box.maxWidth
                      : (box.maxWidth - 12) / 2;
                  return Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: width,
                        child: _metric(
                          'Understanding',
                          result.understandingScore,
                          'Concepts and explanations',
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _metric(
                          'Practice / application',
                          result.applicationScore,
                          'Using knowledge to solve problems',
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 13),
              const Text(
                'These are AI rubric marks for this test. Understanding, practice, consistency, and outcomes on Overview and Goals come only from AI judgments of your assessed evidence.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
              if (!historical && !lab.saved) ...[
                const SizedBox(height: 13),
                FilledButton.icon(
                  key: const Key('lab-result-retry-save'),
                  onPressed: lab.busy ? null : lab.retrySave,
                  icon: const Icon(Icons.save_outlined, size: 18),
                  label: Text(lab.saving ? 'Saving…' : 'Retry saving grade'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Your marked paper',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        const Text(
          'Every deduction is tied to the answer you submitted. Use the expected answer and next steps to close the gaps.',
          style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.7),
        ),
        const SizedBox(height: 16),
        for (var index = 0; index < result.questions.length; index++) ...[
          _markedQuestion(result.questions[index], index),
          const SizedBox(height: 14),
        ],
        if (result.nextSteps.isNotEmpty)
          _panel(
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What to work on next',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                for (var index = 0; index < result.nextSteps.length; index++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${index + 1}.',
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.green,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            result.nextSteps[index],
                            style: const TextStyle(fontSize: 13, height: 1.7),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            color: AppColors.pale,
          ),
        if (!historical && lab.saved) ...[
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const Key('lab-retest'),
                onPressed: lab.busy ? null : () => _startAgain(repeat: result),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Test this topic again'),
              ),
              OutlinedButton(
                key: const Key('lab-new-topic'),
                onPressed: lab.busy ? null : _startAgain,
                child: const Text('Test another topic'),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _markedQuestion(LabQuestionGrade grade, int index) => _panel(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Question ${index + 1} · ${grade.dimension.label}',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            _badge(
              '${grade.earnedPoints} / ${grade.maxPoints}',
              color: grade.earnedPoints >= 7 ? AppColors.green : AppColors.gold,
            ),
          ],
        ),
        const SizedBox(height: 12),
        SelectableText(
          grade.prompt,
          style: const TextStyle(fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 12),
        Text(
          grade.feedback,
          key: ValueKey('lab-question-feedback-${grade.id}'),
          style: const TextStyle(fontSize: 13, height: 1.7),
        ),
        const SizedBox(height: 13),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _badge('Correctness ${grade.correctness}/5'),
            _badge('Reasoning ${grade.reasoning}/3'),
            _badge('Precision ${grade.precision}/2'),
          ],
        ),
        if (grade.missingConcepts.isNotEmpty) ...[
          const SizedBox(height: 13),
          const Text(
            'Gaps to address',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 5),
          for (final gap in grade.missingConcepts)
            Text(
              '• $gap',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.7,
              ),
            ),
        ],
        const SizedBox(height: 6),
        ExpansionTile(
          key: ValueKey('lab-marking-details-${grade.id}'),
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 6),
          title: const Text(
            'Your answer & expected answer',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'YOUR ANSWER',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                      color: AppColors.muted,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    grade.answer.trim().isEmpty
                        ? 'No answer submitted.'
                        : grade.answer,
                    style: const TextStyle(fontSize: 12, height: 1.8),
                  ),
                  const SizedBox(height: 17),
                  const Text(
                    'EXPECTED ANSWER',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w600,
                      color: AppColors.green,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    grade.referenceAnswer,
                    style: const TextStyle(fontSize: 12, height: 1.8),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _history() {
    final results = history;
    final shown = results.take(_historyLimit).toList();
    return _panel(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            spacing: 15,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text(
                'Your assessed journey',
                style: TextStyle(fontSize: 21, fontWeight: FontWeight.w600),
              ),
              _badge(
                '${results.length} ${_historyTrack.label.toUpperCase()} ASSESSMENTS',
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Completed tests build a history of what your answers demonstrated. Trend comparisons use the same topic, difficulty, track, and question count. Question sets can still differ in difficulty.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.7),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              for (final track in ProgressTrack.values)
                ChoiceChip(
                  key: ValueKey('lab-history-${track.name}'),
                  label: Text(track.label),
                  selected: _historyTrack == track,
                  onSelected: (_) => setState(() => _historyTrack = track),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (results.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Text(
                'Your first completed assessment will appear here. No manual score entry is needed.',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.muted,
                  height: 1.8,
                ),
              ),
            ),
          for (final result in shown) ...[
            _historyRow(result, results),
            const SizedBox(height: 10),
          ],
          if (results.length > shown.length)
            TextButton(
              onPressed: () => setState(() => _historyLimit += 8),
              child: const Text('Show more assessments'),
            ),
          if (results.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Generated questions can vary between tests. Compare the explanations and gaps alongside the score.',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.muted,
                  height: 1.7,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _historyRow(LabResult result, List<LabResult> results) {
    final previous = LabAnalytics.previousComparable(results, result);
    return Material(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(11),
      child: InkWell(
        key: ValueKey('lab-history-result-${result.id}'),
        borderRadius: BorderRadius.circular(11),
        onTap: () => _showHistoryResult(result),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.pale,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _percent(result.totalScore),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.topic,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${result.level.label} · ${result.questionCount} questions · ${_dateTime(result.completedAt)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                        height: 1.6,
                      ),
                    ),
                    if (previous != null)
                      Text(
                        '${_signed(result.totalScore - previous.totalScore)} pts on this topic',
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.green,
                        ),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, size: 19, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showHistoryResult(LabResult result) => showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: SizedBox(
        width: 900,
        height: math.min(850, MediaQuery.sizeOf(context).height - 40),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Assessment details',
                      style: TextStyle(
                        fontSize: 21,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close assessment details',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Expanded(
                child: SingleChildScrollView(
                  child: _result(result, historical: true),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _panel(
    Widget child, {
    Color color = Colors.white,
    double padding = 22,
  }) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(padding),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.line),
    ),
    child: Material(type: MaterialType.transparency, child: child),
  );

  Widget _metric(String title, double value, String detail) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(11),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const SizedBox(height: 7),
        Text(
          '${_percent(value)} / 100',
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        LinearProgressIndicator(
          value: value / 100,
          backgroundColor: AppColors.line,
          color: AppColors.green,
          borderRadius: BorderRadius.circular(3),
          minHeight: 4,
        ),
        const SizedBox(height: 8),
        Text(
          detail,
          style: const TextStyle(
            fontSize: 10,
            height: 1.6,
            color: AppColors.muted,
          ),
        ),
      ],
    ),
  );
  String _percent(double value) => value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toStringAsFixed(1);

  Widget _score(double score) => Container(
    width: 150,
    height: 150,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: AppColors.pale,
      border: Border.all(
        color: AppColors.green.withValues(alpha: .25),
        width: 7,
      ),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'TEST SCORE',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1,
            color: AppColors.green,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          _percent(score),
          key: const Key('lab-total-score'),
          style: const TextStyle(
            fontSize: 43,
            fontWeight: FontWeight.w600,
            color: AppColors.ink,
            height: 1.2,
          ),
        ),
        const Text(
          '/ 100',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    ),
  );
  Widget _badge(String label, {Color color = AppColors.green}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w600),
    ),
  );
  Widget _spinner() => const SizedBox(
    width: 16,
    height: 16,
    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
  );
  String _scoreLabel(double score) => score >= 90
      ? 'Precise, well-supported work.'
      : score >= 75
      ? 'A solid base. Some gaps remain.'
      : score >= 60
      ? 'Developing understanding. Review the deductions.'
      : 'This topic needs more work.';
  String _signed(double value) =>
      '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';
  String _dateTime(DateTime value) {
    final local = value.toLocal();
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
    return '${local.day} ${months[local.month - 1]} ${local.year}, ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  }
}

class _LabConnectionDialog extends StatefulWidget {
  const _LabConnectionDialog({required this.current});
  final Uri current;
  @override
  State<_LabConnectionDialog> createState() => _LabConnectionDialogState();
}

class _LabConnectionDialogState extends State<_LabConnectionDialog> {
  final _form = GlobalKey<FormState>();
  late final _url = TextEditingController(text: widget.current.toString());
  final _token = TextEditingController();
  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: const Text('Connect Testing Lab'),
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
                'Use the same backend as AI Coach. It receives the topic, optional learning notes, and answers you submit.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.7,
                  color: AppColors.muted,
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                key: const Key('lab-url'),
                controller: _url,
                maxLength: 2048,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Backend service URL',
                  hintText: 'http://127.0.0.1:8787',
                ),
                validator: (value) {
                  try {
                    ApiCoachRepository.validateBaseUrl(
                      Uri.parse(value?.trim() ?? ''),
                    );
                    return null;
                  } catch (_) {
                    return 'Use HTTPS, or HTTP for a local development service.';
                  }
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                key: const Key('lab-access-token'),
                controller: _token,
                obscureText: true,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'Backend access token · if required',
                  helperText: 'Keep your OpenAI key in the backend .env file.',
                ),
                validator: (value) =>
                    value != null &&
                        (value.length > 1024 ||
                            value.contains('\r') ||
                            value.contains('\n'))
                    ? 'Enter a valid backend access token.'
                    : null,
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
        key: const Key('lab-connect-save'),
        onPressed: () {
          if (!_form.currentState!.validate()) return;
          Navigator.pop(
            context,
            CoachConnection(
              ApiCoachRepository.validateBaseUrl(Uri.parse(_url.text.trim())),
              _token.text.trim(),
            ),
          );
        },
        child: const Text('Connect'),
      ),
    ],
  );
}
