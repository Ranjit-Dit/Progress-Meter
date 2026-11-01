import 'dart:async';

import '../../assessment/domain/ai_judgment.dart';
import '../../assessment/application/ai_judgment_controller.dart';
import '../../assessment/data/api_judgment_repository.dart';
import '../../assessment/presentation/assessment_overview.dart';
import '../../assessment/presentation/assessed_goals_screen.dart';
import '../../ai_connection/domain/ai_provider.dart';
import '../../ai_connection/presentation/ai_provider_settings.dart';
import '../../ai_connection/data/personal_coach_repository.dart';
import '../../ai_connection/data/personal_lab_repository.dart';
import '../../ai_connection/data/personal_judgment_repository.dart';
import '../../ai_connection/data/personal_benchmark_repository.dart';
import '../../notifications/application/notification_controller.dart';
import '../../notifications/presentation/notification_settings_card.dart';

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/progress_controller.dart';
import '../../../common/app_theme.dart';
import '../../../common/widgets/progress_charts.dart';
import '../domain/models.dart';
import 'progress_dialogs.dart';
import '../../ai_coach/application/coach_controller.dart';
import '../../ai_coach/data/api_coach_repository.dart';
import '../../ai_coach/presentation/coach_screen.dart';
import '../../routines/presentation/routines_screen.dart';
import '../../routines/domain/routine_analytics.dart';
import '../../testing_lab/application/lab_controller.dart';
import '../../testing_lab/data/api_lab_repository.dart';
import '../../testing_lab/presentation/testing_lab_screen.dart';
import '../../benchmark_research/application/benchmark_controller.dart';
import '../../benchmark_research/data/api_benchmark_repository.dart';
import '../../benchmark_research/domain/benchmark_models.dart';
import '../../benchmark_research/domain/benchmark_analytics.dart';
import '../../benchmark_research/presentation/benchmark_research_screen.dart';

String shortDate(DateTime date) {
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
  return '${date.day} ${months[date.month - 1]}';
}

String fullDate(DateTime date) => '${shortDate(date)} ${date.year}';
String signed(double value) =>
    '${value >= 0 ? '+' : ''}${value.toStringAsFixed(1)}';

class ProgressWorkspace extends StatefulWidget {
  const ProgressWorkspace({
    super.key,
    required this.controller,
    this.coachController,
    this.labController,
    this.benchmarkController,
    this.judgmentController,
    this.notificationController,
  });
  final ProgressController controller;
  final CoachController? coachController;
  final LabController? labController;
  final BenchmarkResearchController? benchmarkController;
  final AiJudgmentController? judgmentController;
  final NotificationController? notificationController;
  @override
  State<ProgressWorkspace> createState() => _ProgressWorkspaceState();
}

class _ProgressWorkspaceState extends State<ProgressWorkspace>
    with WidgetsBindingObserver {
  ProgressController get c => widget.controller;
  late CoachController _coach;
  late bool _ownsCoach;
  late LabController _lab;
  late bool _ownsLab;
  late BenchmarkResearchController _benchmarks;
  late bool _ownsBenchmarks;
  late AiJudgmentController _judgments;
  late bool _ownsJudgments;
  late NotificationController _notifications;
  late bool _ownsNotifications;
  late int _labContextRevision;
  late Uri _coachUrl;
  String _backendToken = '';
  AiProviderConfig? _personalAi;
  String? get _personalAiLabel => _personalAi?.auditModel;
  late int _contextRevision;

  void _invalidatePrivateContext() {
    if (_contextRevision != c.contextRevision) {
      _contextRevision = c.contextRevision;
      _coach.clear();
      _benchmarks.clearReview();
    }
    if (_labContextRevision != c.labContextRevision) {
      _labContextRevision = c.labContextRevision;
      if (_personalAi != null) {
        // Forget cached questions, answers, and reviews when private data resets.
        _replaceAiControllers(_personalAi);
      } else {
        _lab.clear();
        _benchmarks.clear();
        _judgments.clear();
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _contextRevision = c.contextRevision;
    _labContextRevision = c.labContextRevision;
    c.addListener(_invalidatePrivateContext);
    _ownsCoach = widget.coachController == null;
    if (_ownsCoach) {
      final repository = ApiCoachRepository();
      _coachUrl = repository.baseUrl;
      _coach = CoachController(repository);
    } else {
      _coach = widget.coachController!;
      _coachUrl = Uri.parse('http://127.0.0.1:8787');
    }
    _ownsLab = widget.labController == null;
    _lab =
        widget.labController ??
        LabController(
          ApiLabRepository(baseUrl: _coachUrl),
          saveResult: c.recordLabResult,
        );
    _ownsBenchmarks = widget.benchmarkController == null;
    _benchmarks =
        widget.benchmarkController ??
        BenchmarkResearchController(
          ApiBenchmarkResearchRepository(baseUrl: _coachUrl),
        );
    _ownsJudgments = widget.judgmentController == null;
    _judgments =
        widget.judgmentController ??
        AiJudgmentController(
          progress: c,
          repository: ApiJudgmentRepository(baseUrl: _coachUrl),
        );
    _ownsNotifications = widget.notificationController == null;
    _notifications =
        widget.notificationController ?? NotificationController(progress: c);
    unawaited(_notifications.initialize());
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.removeListener(_invalidatePrivateContext);
    if (_ownsJudgments) _judgments.dispose();
    if (_ownsNotifications) _notifications.dispose();
    if (_ownsCoach) _coach.dispose();
    if (_ownsLab) _lab.dispose();
    if (_ownsBenchmarks) _benchmarks.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_notifications.refresh());
  }

  Future<bool> _canChangeAiConnection() async {
    if (_lab.busy || _coach.busy || _benchmarks.busy || _judgments.busy) {
      toast('Wait for the current AI request to finish.');
      return false;
    }
    if (_lab.result != null && !_lab.saved) {
      toast('Save your graded result before changing the connection.');
      return false;
    }
    if (_lab.session != null && _lab.result == null) {
      final discard = await confirm(
        'Change the test server?',
        'Your current questions and unsaved answers will be discarded. Completed results are kept.',
        'Change connection',
      );
      if (!discard || !mounted) return false;
    }
    return mounted;
  }

  void _connectCoach(CoachConnection connection) async {
    if (!await _canChangeAiConnection()) return;
    setState(() {
      _coachUrl = connection.url;
      _backendToken = connection.accessToken;
      _replaceAiControllers(null);
    });
  }

  Future<void> _showPersonalAiSettings() async {
    final selection = await showAiProviderSettings(
      context,
      current: _personalAi,
    );
    if (selection == null || !mounted) return;
    if (!await _canChangeAiConnection()) return;
    setState(() => _replaceAiControllers(selection.config));
    toast(
      selection.config == null
          ? 'Using the app backend. Your personal key has been forgotten.'
          : 'Your personal AI provider is active for this app session.',
    );
  }

  Future<void> _showBackendSettings() async {
    final connection = await showCoachConnectionDialog(
      context,
      current: _coachUrl,
    );
    if (connection != null && mounted) _connectCoach(connection);
  }

  void _replaceAiControllers(AiProviderConfig? personal) {
    if (_ownsJudgments) _judgments.dispose();
    _judgments = AiJudgmentController(
      progress: c,
      repository: personal == null
          ? ApiJudgmentRepository(
              baseUrl: _coachUrl,
              accessToken: _backendToken,
            )
          : PersonalJudgmentRepository(config: personal),
    );
    _ownsJudgments = true;
    if (_ownsBenchmarks) _benchmarks.dispose();
    _benchmarks = BenchmarkResearchController(
      personal == null
          ? ApiBenchmarkResearchRepository(
              baseUrl: _coachUrl,
              accessToken: _backendToken,
            )
          : PersonalBenchmarkResearchRepository(config: personal),
    );
    _ownsBenchmarks = true;
    if (_ownsLab) _lab.dispose();
    _lab = LabController(
      personal == null
          ? ApiLabRepository(baseUrl: _coachUrl, accessToken: _backendToken)
          : PersonalLabRepository(config: personal),
      saveResult: c.recordLabResult,
    );
    _ownsLab = true;
    if (_ownsCoach) _coach.dispose();
    _coach = CoachController(
      personal == null
          ? ApiCoachRepository(baseUrl: _coachUrl, accessToken: _backendToken)
          : PersonalCoachRepository(config: personal),
    );
    _ownsCoach = true;
    _personalAi = personal;
  }

  final scaffoldKey = GlobalKey<ScaffoldState>();
  int page = 0;
  int range = 13;
  int goalFilter = 0;
  String search = '';
  String? beforeId;
  String? afterId;
  static const titles = [
    'Overview',
    'My journey',
    'Benchmarks',
    'Goals',
    'Routines',
    'AI Coach',
    'Testing Lab',
    'Settings',
  ];
  static const icons = [
    Icons.space_dashboard_outlined,
    Icons.timeline_rounded,
    Icons.people_outline_rounded,
    Icons.flag_outlined,
    Icons.calendar_month_outlined,
    Icons.auto_awesome_outlined,
    Icons.science_outlined,
    Icons.tune_rounded,
  ];

  void go(int value) {
    setState(() => page = value);
    scaffoldKey.currentState?.closeDrawer();
  }

  void toast(String message, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? const Color(0xFF9F4039) : AppColors.ink,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> save(Future<void> Function() action, String message) async {
    try {
      await action();
      toast(message);
    } catch (error) {
      toast('Could not save. Your previous data is safe. $error', error: true);
    }
  }

  Future<void> checkIn() async => go(6);

  Future<void> addGoal({MetricKind? metric, double? target}) async {
    final result = await showGoalDialog(
      context,
      c.track,
      initialMetric: metric,
      initialTarget: target,
    );
    if (result != null) {
      await save(() => c.addGoal(result), 'Your next milestone is set.');
    }
  }

  Future<bool> confirm(String title, String message, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: SizedBox(width: 360, child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: c,
    builder: (context, _) => LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 1000;
        return Scaffold(
          key: scaffoldKey,
          drawer: desktop ? null : Drawer(child: sidebar()),
          body: SafeArea(
            key: const Key('workspace-safe-area'),
            child: Row(
              children: [
                if (desktop) SizedBox(width: 220, child: sidebar()),
                Expanded(
                  child: Column(
                    children: [
                      topBar(desktop),
                      Expanded(
                        child: SingleChildScrollView(
                          key: const Key('workspace-scroll'),
                          padding: EdgeInsets.all(
                            constraints.maxWidth < 650 ? 16 : 32,
                          ),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1250),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (c.data.entries.any(
                                    (e) => e.id.startsWith('demo-'),
                                  ))
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 22,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.fromLTRB(
                                          14,
                                          7,
                                          7,
                                          7,
                                        ),
                                        decoration: BoxDecoration(
                                          color: AppColors.pale,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.explore_outlined,
                                              size: 17,
                                              color: AppColors.green,
                                            ),
                                            const SizedBox(width: 10),
                                            const Expanded(
                                              child: Text(
                                                'Legacy sample journal · Current AI scores require assessed evidence.',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.green,
                                                ),
                                              ),
                                            ),
                                            TextButton(
                                              onPressed: () => go(7),
                                              child: const Text(
                                                'Make it yours →',
                                                style: TextStyle(fontSize: 10),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  switch (page) {
                                    0 => overview(),
                                    1 => journey(),
                                    2 => benchmarks(),
                                    3 => goals(),
                                    4 => RoutinesScreen(controller: c),
                                    5 => CoachScreen(
                                      key: ValueKey((
                                        _coach,
                                        c.track,
                                        c.contextRevision,
                                      )),
                                      progress: c,
                                      controller: _coach,
                                      baseUrl: _coachUrl,
                                      onConnectionChanged: _connectCoach,
                                      onPersonalAiSettings:
                                          _showPersonalAiSettings,
                                      personalAiLabel: _personalAiLabel,
                                    ),
                                    6 => TestingLabScreen(
                                      key: ValueKey((
                                        _lab,
                                        c.track,
                                        c.labContextRevision,
                                      )),
                                      progress: c,
                                      controller: _lab,
                                      baseUrl: _coachUrl,
                                      onConnectionChanged: _connectCoach,
                                      onPersonalAiSettings:
                                          _showPersonalAiSettings,
                                      personalAiLabel: _personalAiLabel,
                                    ),
                                    _ => settings(),
                                  },
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );

  Widget sidebar() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: AppColors.line)),
    ),
    child: SafeArea(
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          key: const Key('workspace-navigation-scroll'),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: IntrinsicHeight(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 24, 18, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 9),
                      child: Row(
                        children: [
                          Container(
                            width: 35,
                            height: 35,
                            decoration: BoxDecoration(
                              color: AppColors.green,
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: const Icon(
                              Icons.stacked_line_chart_rounded,
                              color: Colors.white,
                              size: 23,
                            ),
                          ),
                          const SizedBox(width: 10),
                          const Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                'progress /',
                                style: TextStyle(
                                  fontSize: 23,
                                  letterSpacing: -.8,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.ink,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.fromLTRB(10, 42, 0, 15),
                      child: Text(
                        'YOUR WORKSPACE',
                        style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.7,
                          fontWeight: FontWeight.w600,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    for (int i = 0; i < 7; i++) navItem(i),
                    const Spacer(),
                    if (box.maxHeight >= 900)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.pale,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.spa_outlined,
                              size: 25,
                              color: AppColors.green,
                            ),
                            SizedBox(height: 11),
                            Text(
                              'Grow at your own pace.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(height: 5),
                            Text(
                              'Every small step is a step\nforward.',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.muted,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 18),
                    navItem(7),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        avatar(
                          initials(c.data.studentName),
                          color: const Color(0xFFF1E9DD),
                          size: 34,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                c.data.studentName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              const Text(
                                'Student workspace',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.expand_more,
                          size: 16,
                          color: AppColors.muted,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  Widget navItem(int i) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Material(
      color: page == i ? AppColors.pale : Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        key: ValueKey('workspace-nav-$i'),
        borderRadius: BorderRadius.circular(9),
        onTap: () => go(i),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Row(
              children: [
                Icon(
                  icons[i],
                  size: 19,
                  color: page == i ? AppColors.green : AppColors.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    titles[i],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: page == i ? FontWeight.w600 : FontWeight.w400,
                      color: page == i ? AppColors.green : AppColors.muted,
                    ),
                  ),
                ),
                if (page == i) ...[
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    ),
  );
  Widget topBar(bool desktop) => Container(
    key: const Key('workspace-top-bar'),
    padding: EdgeInsets.symmetric(horizontal: desktop ? 32 : 12, vertical: 8),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: AppColors.line)),
    ),
    child: LayoutBuilder(
      builder: (context, box) {
        final compact =
            box.maxWidth < 650 ||
            MediaQuery.textScalerOf(context).scale(11) > 16;
        final title = Row(
          children: [
            if (!desktop)
              IconButton(
                key: const Key('workspace-menu'),
                tooltip: 'Open navigation',
                onPressed: () => scaffoldKey.currentState?.openDrawer(),
                icon: const Icon(Icons.menu_rounded),
              ),
            if (desktop) ...[
              const Icon(Icons.home_outlined, size: 17, color: AppColors.muted),
              const SizedBox(width: 12),
              const Text('/', style: TextStyle(color: AppColors.line)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                titles[page],
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        );
        final scope = page == 4
            ? const Text(
                'Personal routines',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              )
            : trackSwitcher(stretch: compact);
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: title,
              ),
              const SizedBox(height: 4),
              if (page == 4)
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                  child: scope,
                )
              else
                scope,
            ],
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 60),
          child: Row(
            children: [
              Expanded(child: title),
              const SizedBox(width: 12),
              scope,
              if (desktop) ...[
                const SizedBox(width: 22),
                const Icon(
                  Icons.check_circle_outline_rounded,
                  size: 17,
                  color: AppColors.green,
                ),
                const SizedBox(width: 7),
                Text(
                  c.saving ? 'Saving…' : 'Saved on device',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ],
            ],
          ),
        );
      },
    ),
  );

  Widget trackSwitcher({required bool stretch}) => Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.line),
    ),
    child: Row(
      mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
      children: [
        for (final track in ProgressTrack.values)
          if (stretch)
            Expanded(child: trackOption(track, stretch: true))
          else
            trackOption(track, stretch: false),
      ],
    ),
  );

  Widget trackOption(ProgressTrack track, {required bool stretch}) => Semantics(
    selected: c.track == track,
    child: InkWell(
      key: ValueKey('track-${track.name}'),
      borderRadius: BorderRadius.circular(7),
      onTap: () => _changeTrack(track),
      child: Container(
        constraints: const BoxConstraints(minHeight: 44),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.track == track ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: c.track == track
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: .04),
                    blurRadius: 3,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: stretch ? MainAxisSize.max : MainAxisSize.min,
          children: [
            Icon(
              track == ProgressTrack.academic
                  ? Icons.school_outlined
                  : Icons.work_outline_rounded,
              size: 15,
              color: c.track == track ? AppColors.green : AppColors.muted,
            ),
            const SizedBox(width: 7),
            if (stretch)
              Expanded(child: trackLabel(track))
            else
              trackLabel(track),
          ],
        ),
      ),
    ),
  );

  Widget trackLabel(ProgressTrack track) => Text(
    track.label,
    textAlign: TextAlign.center,
    style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: c.track == track ? AppColors.ink : AppColors.muted,
    ),
  );

  Widget heading(
    String eyebrow,
    String title,
    String subtitle, {
    Widget? action,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 26),
    child: LayoutBuilder(
      builder: (context, box) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 16,
        children: [
          SizedBox(
            width: math.min(box.maxWidth, 650),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow,
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.7,
                    fontWeight: FontWeight.w600,
                    color: AppColors.green,
                  ),
                ),
                const SizedBox(height: 9),
                Text(title, style: Theme.of(context).textTheme.headlineLarge),
                const SizedBox(height: 7),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 12,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          ?action,
        ],
      ),
    ),
  );
  Widget primary(String label, IconData icon, VoidCallback action) =>
      FilledButton.icon(
        onPressed: c.saving ? null : action,
        icon: Icon(icon, size: 17),
        label: Text(label),
      );
  Widget card(
    Widget child, {
    Color color = Colors.white,
    EdgeInsets? padding,
  }) => Container(
    padding:
        padding ??
        EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 23),
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(
        color: AppColors.line.withValues(alpha: color == Colors.white ? 1 : .3),
      ),
    ),
    child: child,
  );
  Widget sectionTitle(String title, {Widget? trailing, String? subtitle}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: LayoutBuilder(
          builder: (context, box) {
            final description = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                if (subtitle != null) ...[
                  const SizedBox(height: 5),
                  Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
                ],
              ],
            );
            if (trailing != null && box.maxWidth < 480) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [description, const SizedBox(height: 12), trailing],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: description),
                if (trailing != null) ...[const SizedBox(width: 12), trailing],
              ],
            );
          },
        ),
      );
  Widget twoColumns(
    Widget left,
    Widget right, {
    int leftFlex = 3,
    int rightFlex = 2,
  }) => LayoutBuilder(
    builder: (context, box) => box.maxWidth >= 780
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: leftFlex, child: left),
              const SizedBox(width: 22),
              Expanded(flex: rightFlex, child: right),
            ],
          )
        : Column(children: [left, const SizedBox(height: 20), right]),
  );
  Widget badge(
    String text, {
    Color color = AppColors.green,
    Color? background,
  }) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: background ?? color.withValues(alpha: .09),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
    ),
  );
  Widget avatar(
    String text, {
    double size = 44,
    Color color = AppColors.pale,
  }) => Container(
    width: size,
    height: size,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(size * .32),
    ),
    child: Text(
      text,
      style: TextStyle(
        color: AppColors.ink,
        fontSize: size * .28,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
  String initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  Future<void> _changeTrack(ProgressTrack value) async {
    if (c.track == value) return;
    if (_lab.busy) {
      toast('Wait for the current test action to finish.');
      return;
    }
    if (_lab.result != null && !_lab.saved) {
      toast('Save your graded result before switching tracks.');
      return;
    }
    if (_lab.session != null && _lab.result == null) {
      final discard = await confirm(
        'Switch tracks?',
        'Your current test and unsaved answers will be discarded. Completed results are kept.',
        'Switch track',
      );
      if (!discard || !mounted) return;
    }
    _coach.clear();
    _lab.clear();
    _benchmarks.clear();
    c.selectTrack(value);
    setState(() {
      beforeId = null;
      afterId = null;
    });
  }

  Widget overview() => ListenableBuilder(
    listenable: _judgments,
    builder: (context, _) => AssessmentOverview(
      controller: c,
      reviewing: _judgments.busy,
      onReview: _judgments.review,
      onTest: () => go(6),
      onGoals: () => go(3),
      onRoutines: () => go(4),
      onBenchmarks: () => go(2),
      reviewError: _judgments.error,
    ),
  );

  Widget routineSummary() => card(
    LayoutBuilder(
      builder: (context, box) => Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 20,
        runSpacing: 12,
        children: [
          SizedBox(
            width: math.min(box.maxWidth, 470),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_month_outlined,
                  color: AppColors.green,
                  size: 23,
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Make room for a good day.',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        _todayScheduleSummary(),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            key: const Key('overview-open-routines'),
            onPressed: () => go(4),
            child: const Text(
              'Open routines →',
              style: TextStyle(fontSize: 11),
            ),
          ),
        ],
      ),
    ),
  );

  String _todayScheduleSummary() {
    final now = DateTime.now();
    final tasks = c.tasksOn(now);
    final completed =
        RoutineAnalytics.completedCount(
          c.data.routines,
          c.data.routineCompletions,
          now,
        ) +
        tasks.where((task) => task.completed).length;
    return '${c.routinesOn(now).length} routines · ${tasks.length} tasks planned today · $completed checked off';
  }

  Widget stat(
    String label,
    String value,
    String footnote,
    IconData icon,
  ) => card(
    Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w600,
                  color: AppColors.ink,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                footnote,
                style: const TextStyle(fontSize: 10, color: AppColors.muted),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.pale,
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, color: AppColors.green, size: 17),
        ),
      ],
    ),
    padding: const EdgeInsets.all(20),
  );
  Widget trendCard() {
    final history = c.history;
    final visible = history.skip(math.max(0, history.length - range)).toList();
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'Your progress over time',
            subtitle: 'Small improvements make a big difference.',
            trailing: LayoutBuilder(
              builder: (context, box) => SizedBox(
                width: math.min(box.maxWidth, 240),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    value: range,
                    isDense: true,
                    isExpanded: true,
                    style: const TextStyle(fontSize: 11, color: AppColors.ink),
                    selectedItemBuilder: (context) => const [
                      Text(
                        'Last 4',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Last 8',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Last 13',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'All check-ins',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    items: const [
                      DropdownMenuItem(
                        value: 4,
                        child: Text('Last 4 check-ins'),
                      ),
                      DropdownMenuItem(
                        value: 8,
                        child: Text('Last 8 check-ins'),
                      ),
                      DropdownMenuItem(
                        value: 13,
                        child: Text('Last 13 check-ins'),
                      ),
                      DropdownMenuItem(
                        value: 9999,
                        child: Text('All check-ins'),
                      ),
                    ],
                    onChanged: (v) => setState(() => range = v!),
                  ),
                ),
              ),
            ),
          ),
          ProgressLineChart(
            values: visible.map((e) => e.score).toList(),
            labels: visible.map((e) => shortDate(e.date)).toList(),
            height: 205,
          ),
          const SizedBox(height: 9),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 14,
            runSpacing: 6,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.green,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      '${c.track.label} score',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => go(1),
                child: const Text(
                  'Explore journey →',
                  style: TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget targetCard() {
    final research = c.researchTarget;
    if (research != null) {
      final snapshot = BenchmarkAnalytics.evaluate(
        research,
        c.data.labResults,
        c.data.projectEvidence,
      );
      return card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(
              'Your researched target',
              subtitle: research.subjectName,
            ),
            Text(
              '${snapshot.progressPercent.toStringAsFixed(1)}%',
              style: const TextStyle(
                fontSize: 35,
                fontWeight: FontWeight.w600,
                color: AppColors.green,
              ),
            ),
            const Text(
              'Roadmap readiness',
              style: TextStyle(color: AppColors.muted, fontSize: 12),
            ),
            const SizedBox(height: 14),
            LinearProgressIndicator(
              value: snapshot.progressPercent / 100,
              minHeight: 7,
              borderRadius: BorderRadius.circular(7),
            ),
            const SizedBox(height: 12),
            Text(
              '${snapshot.completeCount} of 5 milestones reached',
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 7),
            const Text(
              'Updates from matching assessments and your project evidence.',
              style: TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () => go(2),
              child: const Text('Open path and review progress →'),
            ),
          ],
        ),
      );
    }
    final target = c.target;
    final gap = target == null || c.latest == null
        ? null
        : target.score - c.latest!.score;
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'A little inspiration',
            trailing: const Icon(
              Icons.north_east,
              size: 17,
              color: AppColors.green,
            ),
          ),
          if (target == null)
            empty(
              'Choose your benchmark',
              'Learn from a profile and turn the gap into a plan.',
              Icons.people_outline,
              action: TextButton(
                onPressed: () => go(2),
                child: const Text('Explore benchmarks →'),
              ),
            )
          else ...[
            Row(
              children: [
                avatar(
                  target.initials,
                  color: const Color(0xFFECE7DD),
                  size: 48,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        target.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        target.role,
                        style: const TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            badge(
              target.isExample ? 'EXAMPLE PROFILE' : 'MANUAL BENCHMARK',
              color: AppColors.gold,
            ),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${target.score.round()}',
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -1,
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 5, left: 5),
                  child: Text(
                    '/100 benchmark',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              gap == null
                  ? 'Log a check-in to see your gap.'
                  : gap <= 0
                  ? 'You’ve reached this benchmark. Keep growing.'
                  : '${gap.toStringAsFixed(1)} points to your benchmark. You’ve got this.',
              style: const TextStyle(fontSize: 11, color: AppColors.muted),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => go(2),
                child: const Text(
                  'See the path forward →',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget exampleNotice() {
    final demo = c.data.entries.any((e) => e.id.startsWith('demo-'));
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          color: AppColors.muted,
          size: 14,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            demo
                ? 'You’re exploring sample check-ins. Start fresh in Settings whenever you’re ready. Scores are self-assessments, equally weighted across four dimensions.'
                : 'Your progress is saved on this device. Scores are self-assessments, equally weighted across four dimensions.',
            style: const TextStyle(
              fontSize: 10,
              height: 1.6,
              color: AppColors.muted,
            ),
          ),
        ),
      ],
    );
  }

  Widget journey() {
    final history = c.history;
    final filtered = history.reversed
        .where(
          (e) => '${e.title} ${e.note}'.toLowerCase().contains(
            search.toLowerCase(),
          ),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          'LOOK BACK. MOVE FORWARD.',
          'Your journey, in perspective.',
          'Earlier self-ratings are archived here. Current ratings and goal attainment come only from AI judgments.',
          action: primary('Open Testing Lab', Icons.science_outlined, checkIn),
        ),
        trendCard(),
        const SizedBox(height: 22),
        if (history.length >= 2) ...[
          comparisonCard(history),
          const SizedBox(height: 22),
        ],
        card(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              sectionTitle(
                'Legacy check-in journal',
                subtitle: '${history.length} dated snapshots · newest first',
              ),
              TextField(
                key: const ValueKey('history-search'),
                decoration: const InputDecoration(
                  hintText: 'Search your check-ins…',
                  prefixIcon: Icon(Icons.search, size: 19),
                ),
                onChanged: (v) => setState(() => search = v),
              ),
              const SizedBox(height: 18),
              if (filtered.isEmpty)
                empty(
                  history.isEmpty
                      ? 'Begin with where you are.'
                      : 'No matching check-ins',
                  history.isEmpty
                      ? 'Complete Testing Lab assessments to build your AI-assessed history.'
                      : 'Try another title or keyword.',
                  Icons.event_note_outlined,
                ),
              for (final entry in filtered)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Container(
                    padding: const EdgeInsets.all(17),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.line),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: AppColors.pale,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Text(
                            '${entry.score.round()}',
                            style: const TextStyle(
                              color: AppColors.green,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 10,
                                runSpacing: 5,
                                children: [
                                  Text(
                                    entry.title,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                  if (entry.id.startsWith('demo-'))
                                    badge('SAMPLE', color: AppColors.gold),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fullDate(entry.date),
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: AppColors.muted,
                                ),
                              ),
                              if (entry.note.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    entry.note,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 16,
                                runSpacing: 5,
                                children: [
                                  for (final m in MetricKind.values)
                                    Text(
                                      '${metricLabel(m, c.track)} ${entry.metrics[m]!.round()}',
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Delete check-in',
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 17,
                            color: AppColors.muted,
                          ),
                          onPressed: () async {
                            if (await confirm(
                              'Delete this check-in?',
                              'This snapshot will be removed from your history. Other check-ins will be kept.',
                              'Delete',
                            )) {
                              await save(
                                () => c.deleteEntry(entry.id),
                                'Check-in deleted.',
                              );
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget comparisonCard(List<ProgressEntry> history) {
    final before =
        history.where((e) => e.id == beforeId).firstOrNull ?? history.first;
    final after =
        history.where((e) => e.id == afterId).firstOrNull ?? history.last;
    Widget picker(
      String label,
      ProgressEntry value,
      ValueChanged<String?> change,
    ) => DropdownButtonFormField<String>(
      key: ValueKey('$label-${c.track.name}-${value.id}'),
      initialValue: value.id,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      style: const TextStyle(fontSize: 12, color: AppColors.ink),
      items: history
          .map(
            (e) => DropdownMenuItem(
              value: e.id,
              child: Text(
                '${fullDate(e.date)} · ${e.title}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          )
          .toList(),
      onChanged: change,
    );
    return card(
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          sectionTitle(
            'You, compared with you',
            subtitle: 'Choose any two snapshots and see what changed.',
            trailing: badge('${signed(after.score - before.score)} pts'),
          ),
          twoColumns(
            picker(
              'Baseline check-in',
              before,
              (v) => setState(() => beforeId = v),
            ),
            picker('Compare with', after, (v) => setState(() => afterId = v)),
            leftFlex: 1,
            rightFlex: 1,
          ),
          const SizedBox(height: 23),
          for (final m in MetricKind.values)
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: LayoutBuilder(
                builder: (context, box) {
                  final label = Text(
                    metricLabel(m, c.track),
                    style: const TextStyle(fontSize: 12),
                  );
                  final scores = Text(
                    '${before.metrics[m]!.round()}  →  ${after.metrics[m]!.round()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                    ),
                  );
                  final change = badge(
                    signed(after.metrics[m]! - before.metrics[m]!),
                    color: after.metrics[m]! >= before.metrics[m]!
                        ? AppColors.green
                        : AppColors.gold,
                  );
                  if (box.maxWidth < 480) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        label,
                        const SizedBox(height: 7),
                        Wrap(
                          spacing: 14,
                          runSpacing: 7,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [scores, change],
                        ),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: label),
                      scores,
                      const SizedBox(width: 20),
                      change,
                    ],
                  );
                },
              ),
            ),
          const Text(
            'Changes are percentage points on the same 0–100 scale.',
            style: TextStyle(fontSize: 10, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _testRoadmapMilestone(
    ResearchPlan plan,
    RoadmapMilestone milestone,
  ) async {
    if (_lab.busy) {
      toast('Wait for the current test action to finish.');
      return;
    }
    if (_lab.result != null && !_lab.saved) {
      toast('Save your current grade before starting a new test.');
      return;
    }
    if (_lab.session != null && _lab.result == null) {
      final discard = await confirm(
        'Start the roadmap test?',
        'Your unfinished test will be discarded. Completed assessments are kept.',
        'Start roadmap test',
      );
      if (!discard || !mounted) return;
    }
    _lab.clear();
    if (c.track != plan.track) c.selectTrack(plan.track);
    go(6);
    await _lab.generate(
      topic: milestone.topic,
      learningNotes:
          'Assessment target: ${milestone.title}. Success criteria: ${milestone.description}',
      track: plan.track,
      level: milestone.level,
    );
  }

  Widget benchmarks() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'INSPIRED BY OTHERS. DRIVEN BY YOU.',
        'Find your next horizon.',
        'Choose a benchmark and turn the distance into achievable goals.',
        action: primary(
          'Add benchmark',
          Icons.person_add_alt_1_outlined,
          () async {
            final result = await showProfileDialog(context, c.track);
            if (result != null) {
              await save(
                () => c.addProfile(result),
                'Benchmark added and selected.',
              );
            }
          },
        ),
      ),
      BenchmarkResearchScreen(
        key: ValueKey((_benchmarks, c.track)),
        progress: c,
        controller: _benchmarks,
        baseUrl: _coachUrl,
        onConnectionChanged: _connectCoach,
        onPersonalAiSettings: _showPersonalAiSettings,
        personalAiLabel: _personalAiLabel,
        onTestMilestone: _testRoadmapMilestone,
      ),
      const Text(
        'MANUAL AND EXAMPLE BENCHMARKS',
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.2,
          color: AppColors.muted,
        ),
      ),
      const SizedBox(height: 12),
      card(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.lightbulb_outline,
              size: 20,
              color: AppColors.gold,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Example profiles are fictional. Add a manual benchmark using someone’s shared scores and the same assessment rubric. Researched targets above use sourced milestones and assessment evidence.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
        color: const Color(0xFFFAF7F0),
      ),
      const SizedBox(height: 22),
      LayoutBuilder(
        builder: (context, box) {
          final width = box.maxWidth >= 950
              ? (box.maxWidth - 36) / 3
              : box.maxWidth >= 600
              ? (box.maxWidth - 18) / 2
              : box.maxWidth;
          return Wrap(
            spacing: 18,
            runSpacing: 18,
            children: [
              for (final profile in c.profiles)
                SizedBox(
                  width: width,
                  child: card(
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            avatar(
                              profile.initials,
                              color: profile.id == c.target?.id
                                  ? const Color(0xFFDCEBDA)
                                  : const Color(0xFFF0EBE3),
                            ),
                            const Spacer(),
                            if (profile.id == c.target?.id)
                              const Icon(
                                Icons.check_circle,
                                size: 20,
                                color: AppColors.green,
                              ),
                          ],
                        ),
                        const SizedBox(height: 17),
                        Text(
                          profile.name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile.role,
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        badge(
                          profile.isExample ? 'EXAMPLE' : 'MANUAL',
                          color: AppColors.gold,
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${profile.score.round()}',
                              style: const TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 5, left: 5),
                              child: Text(
                                '/100',
                                style: TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton(
                            onPressed: () => save(
                              () => c.setTarget(
                                profile.id == c.target?.id ? null : profile.id,
                              ),
                              profile.id == c.target?.id
                                  ? 'Benchmark deselected.'
                                  : '${profile.name} is now your benchmark.',
                            ),
                            child: Text(
                              profile.id == c.target?.id
                                  ? 'Selected · remove'
                                  : 'Set as benchmark',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      if (c.profiles.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: empty(
            'Who inspires your next step?',
            'Add a manual benchmark to begin comparing.',
            Icons.people_outline,
          ),
        ),
      if (c.target != null) ...[
        const SizedBox(height: 25),
        benchmarkComparison(c.target!),
      ],
    ],
  );
  Widget benchmarkComparison(TargetProfile target) => card(
    Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        sectionTitle(
          'Your AI-assessed gap',
          subtitle: 'The benchmark is a reference target. Only AI judges your current score.',
        ),
        for (final metric in MetricKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${aiMetricLabel(metric)} · Target ${target.metrics[metric]!.round()}/100',
                ),
                const SizedBox(height: 6),
                Text(
                  c.judgedScore(metric) == null
                      ? 'Not assessed. Request an AI judgment from Overview.'
                      : 'AI judgment: ${c.judgedScore(metric)!.toStringAsFixed(1)}/100',
                ),
                TextButton(
                  onPressed: () =>
                      addGoal(metric: metric, target: target.metrics[metric]),
                  child: const Text('Create goal →'),
                ),
              ],
            ),
          ),
      ],
    ),
  );

  Widget goals() => ListenableBuilder(
    listenable: _judgments,
    builder: (context, _) => AssessedGoalsScreen(
      controller: c,
      reviewing: _judgments.busy,
      onReview: _judgments.review,
      onTest: () => go(6),
      onAdd: addGoal,
      reviewError: _judgments.error,
      onDelete: (goal) async {
        if (await confirm(
          'Delete this goal?',
          'Your assessed history is kept.',
          'Delete',
        )) {
          await save(() => c.deleteGoal(goal.id), 'Goal deleted.');
        }
      },
    ),
  );

  Widget empty(String title, String text, IconData icon, {Widget? action}) =>
      SizedBox(
        width: double.infinity,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18),
          child: Column(
            children: [
              Icon(icon, size: 30, color: AppColors.green),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              if (action != null)
                Padding(padding: const EdgeInsets.only(top: 12), child: action),
            ],
          ),
        ),
      );

  Widget settings() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        'MAKE IT YOURS',
        'Your space to grow.',
        'Manage your profile, understand your score, and keep a copy of your journey.',
      ),
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Your profile'),
            LayoutBuilder(
              builder: (context, box) {
                final profile = Row(
                  children: [
                    avatar(initials(c.data.studentName), size: 52),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        c.data.studentName,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                );
                final edit = OutlinedButton(
                  onPressed: rename,
                  child: const Text('Edit name'),
                );
                if (box.maxWidth < 420) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [profile, const SizedBox(height: 14), edit],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: profile),
                    const SizedBox(width: 14),
                    edit,
                  ],
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(
              'Only AI judges your progress',
              subtitle: 'Understanding · Practice · Consistency · Outcomes',
            ),
            const Text(
              'Complete Testing Lab assessments, then request an AI judgment from Overview or Goals. AI reviews assessed marks, feedback, and dates. Consistency needs at least three assessment dates in fourteen days; outcomes need comparable assessments on different days. Missing evidence is shown as Not assessed. You can set target scores, but cannot enter your own ratings or mark a metric goal achieved. Older self-ratings remain in the legacy journal only.',
              style: TextStyle(
                fontSize: 12,
                height: 1.8,
                color: AppColors.muted,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      AiProviderSettingsCard(
        current: _personalAi,
        onConfigure: _showPersonalAiSettings,
      ),
      TextButton(
        key: const Key('ai-backend-settings'),
        onPressed: _showBackendSettings,
        child: const Text('App backend connection settings'),
      ),
      const SizedBox(height: 22),
      NotificationSettingsCard(controller: _notifications),
      const SizedBox(height: 22),
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle(
              'Your data stays with you',
              subtitle:
                  '${c.data.entries.length} check-ins · ${c.data.goals.length} goals · ${c.data.profiles.length} benchmarks · ${c.data.routines.length} routines · ${c.data.dailyTasks.length} daily tasks · ${c.data.labResults.length} lab results · ${c.data.aiJudgments.length} AI judgments · ${c.data.researchPlans.length} research paths',
            ),
            const Text(
              'Saved automatically on this device. JSON backups include Testing Lab questions, written answers, and feedback. Export a backup before switching devices. Restoring replaces your current workspace after you confirm.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                OutlinedButton.icon(
                  onPressed: exportData,
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('Export backup'),
                ),
                OutlinedButton.icon(
                  onPressed: importData,
                  icon: const Icon(Icons.restore_outlined, size: 16),
                  label: const Text('Restore backup'),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(height: 22),
      card(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Ready for your own journey?'),
            const Text(
              'Start with an empty workspace. This removes all check-ins, goals, benchmarks, routines, daily tasks, routine check-offs, and Testing Lab results and answers, researched paths, project evidence, AI judgments, and reminder settings from this device. Export a backup first if you want to keep them.',
              style: TextStyle(
                fontSize: 12,
                height: 1.7,
                color: AppColors.muted,
              ),
            ),
            const SizedBox(height: 15),
            OutlinedButton(
              onPressed: () async {
                if (await confirm(
                  'Start with a clean workspace?',
                  'All check-ins, goals, benchmark profiles, routines, daily tasks, routine check-offs, and Testing Lab results and answers, researched paths, project evidence, AI judgments, and reminder settings will be removed, including your own additions. Your name will be kept. Export a backup first to keep a copy.',
                  'Start fresh',
                )) {
                  await save(
                    c.clearDemo,
                    'A fresh start. Your next chapter is yours.',
                  );
                }
              },
              child: const Text(
                'Start fresh',
                style: TextStyle(color: Color(0xFF9F4039)),
              ),
            ),
          ],
        ),
      ),
    ],
  );
  Future<void> rename() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => _TextDialog(
        title: 'What should we call you?',
        initial: c.data.studentName,
        label: 'Your name',
        action: 'Save name',
      ),
    );
    if (value != null && value.trim().isNotEmpty) {
      await save(() => c.rename(value.trim()), 'Profile updated.');
    }
  }

  Future<void> exportData() async {
    final json = const JsonEncoder.withIndent('  ').convert(c.data.toJson());
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Your journey, backed up'),
        content: SizedBox(
          width: 600,
          height: math.min(330, MediaQuery.sizeOf(context).height * .4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Copy this JSON and save it in a text file. Use Restore backup to bring it back.',
                style: TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: SelectableText(
                    json,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: json));
              if (context.mounted) Navigator.pop(context);
              toast('Backup copied. Save it to a .json file.');
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy backup'),
          ),
        ],
      ),
    );
  }

  Future<void> importData() async {
    final value = await showDialog<String>(
      context: context,
      builder: (context) => const _TextDialog(
        title: 'Restore your journey',
        label: 'Paste your Progress Meter JSON backup',
        action: 'Review backup',
        multiline: true,
      ),
    );
    if (value == null) return;
    try {
      final parsed = ProgressData.fromJson(
        Map<String, dynamic>.from(jsonDecode(value) as Map),
      );
      if (await confirm(
        'Replace this workspace?',
        'Restore ${parsed.entries.length} check-ins, ${parsed.goals.length} goals, ${parsed.profiles.length} benchmarks, ${parsed.routines.length} routines, ${parsed.dailyTasks.length} daily tasks, and ${parsed.routineCompletions.length} routine check-offs, and ${parsed.labResults.length} lab results, ${parsed.researchPlans.length} research paths, and ${parsed.projectEvidence.length} project evidence records, and ${parsed.aiJudgments.length} AI judgments with reminder preferences for ${parsed.studentName}? This replaces your current data.',
        'Restore',
      )) {
        await save(() => c.restore(parsed), 'Your backup has been restored.');
      }
    } catch (_) {
      toast(
        'This backup is invalid or uses an unsupported version. Your data was kept.',
        error: true,
      );
    }
  }
}

class _TextDialog extends StatefulWidget {
  const _TextDialog({
    required this.title,
    required this.label,
    required this.action,
    this.initial = '',
    this.multiline = false,
  });
  final String title, label, action, initial;
  final bool multiline;
  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final text = TextEditingController(text: widget.initial);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(widget.title),
    content: SizedBox(
      width: 500,
      child: Form(
        key: form,
        child: TextFormField(
          controller: text,
          autofocus: true,
          maxLength: widget.multiline ? null : 50,
          minLines: widget.multiline ? 8 : 1,
          maxLines: widget.multiline ? 12 : 1,
          decoration: InputDecoration(labelText: widget.label),
          validator: (v) =>
              v == null || v.trim().isEmpty ? 'Please enter a value.' : null,
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
          if (form.currentState!.validate()) Navigator.pop(context, text.text);
        },
        child: Text(widget.action),
      ),
    ],
  );
}
