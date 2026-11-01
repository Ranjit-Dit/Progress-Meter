import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/progress_controller.dart';
import '../../../common/app_theme.dart';
import '../../benchmark_research/domain/benchmark_analytics.dart';
import '../../progress/domain/models.dart';
import '../../routines/presentation/routines_screen.dart' show routineClock;
import '../../testing_lab/domain/lab_models.dart';
import '../domain/ai_judgment.dart';
import 'assessment_design.dart';

class AssessmentOverview extends StatelessWidget {
  const AssessmentOverview({
    super.key,
    required this.controller,
    required this.reviewing,
    required this.onReview,
    required this.onTest,
    required this.onGoals,
    required this.onRoutines,
    required this.onBenchmarks,
    this.reviewError,
  });
  final ProgressController controller;
  final bool reviewing;
  final VoidCallback onReview, onTest, onGoals, onRoutines, onBenchmarks;
  final String? reviewError;

  List<LabResult> get _results =>
      controller.data.labResults
          .where(
            (r) =>
                r.track == controller.track &&
                !r.completedAt.isAfter(DateTime.now()),
          )
          .toList()
        ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

  @override
  Widget build(BuildContext context) {
    final results = _results;
    final judgment = controller.currentJudgment;
    final goals = controller.goals;
    final achieved = goals.where(controller.goalAchieved).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _hero(context, results.length),
        const SizedBox(height: 24),
        Wrap(
          spacing: 9,
          runSpacing: 8,
          children: [
            AssessmentPill(
              '${controller.track.label} workspace',
              icon: Icons.school_outlined,
            ),
            AssessmentPill(
              '${results.length} assessed tests',
              icon: Icons.fact_check_outlined,
            ),
            AssessmentPill(
              '$achieved of ${goals.length} goals AI verified',
              icon: Icons.verified_outlined,
            ),
          ],
        ),
        const SizedBox(height: 30),
        AssessmentSectionTitle(
          'Your AI assessment',
          subtitle: judgment == null
              ? 'Your work supplies the evidence. AI makes the judgment.'
              : 'Reviewed ${assessmentDate(judgment.reviewedAt)} · ${judgment.model}',
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, box) {
            final columns = box.maxWidth < 560
                ? 1
                : box.maxWidth < 1000
                ? 2
                : 4;
            final width = (box.maxWidth - 14 * (columns - 1)) / columns;
            return Wrap(
              spacing: 14,
              runSpacing: 14,
              children: [
                for (final metric in MetricKind.values)
                  SizedBox(width: width, child: _metric(metric)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        _review(context, results.isNotEmpty),
        const SizedBox(height: 26),
        LayoutBuilder(
          builder: (context, box) {
            final history = _history(results);
            final target = _target();
            if (box.maxWidth < 850) {
              return Column(
                children: [history, const SizedBox(height: 18), target],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: history),
                const SizedBox(width: 18),
                Expanded(flex: 2, child: target),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        LayoutBuilder(
          builder: (context, box) {
            final goalPanel = _goals(
              goals.where((g) => !controller.goalAchieved(g)).take(2).toList(),
            );
            final dayPanel = _today();
            if (box.maxWidth < 850) {
              return Column(
                children: [goalPanel, const SizedBox(height: 18), dayPanel],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: goalPanel),
                const SizedBox(width: 18),
                Expanded(child: dayPanel),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Understanding, practice, consistency, and outcomes are judged only by AI from saved assessments. Old self-ratings and routine check-offs do not change these values.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.7,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _hero(BuildContext context, int count) => AssessmentPanel(
    color: const Color(0xFF203F35),
    padding: const EdgeInsets.all(30),
    child: LayoutBuilder(
      builder: (context, box) {
        final copy = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AssessmentPill(
              'EVIDENCE OVER ESTIMATES',
              color: Color(0xFFD8EDD0),
              background: Color(0xFF35564A),
              icon: Icons.auto_awesome,
            ),
            const SizedBox(height: 20),
            Text(
              'Progress you can prove.',
              style: TextStyle(
                fontSize: box.maxWidth < 550 ? 30 : 39,
                height: 1.12,
                letterSpacing: -1.4,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              'Welcome back, ${controller.data.studentName}. Take a test, understand the gaps, and make your next move count.',
              style: const TextStyle(
                fontSize: 13,
                height: 1.8,
                color: Color(0xFFC7D9CF),
              ),
            ),
            const SizedBox(height: 23),
            Wrap(
              spacing: 11,
              runSpacing: 11,
              children: [
                FilledButton.icon(
                  key: const Key('overview-ai-test'),
                  onPressed: onTest,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFD9EBC7),
                    foregroundColor: AppColors.ink,
                  ),
                  icon: const Icon(Icons.science_outlined, size: 18),
                  label: Text(
                    count == 0 ? 'Take your first test' : 'Test what I learned',
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: onGoals,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF5E7B6C)),
                  ),
                  icon: const Icon(Icons.flag_outlined, size: 17),
                  label: const Text('My goals'),
                ),
              ],
            ),
          ],
        );
        if (box.maxWidth < 800) return copy;
        return Row(
          children: [
            Expanded(flex: 3, child: copy),
            const SizedBox(width: 35),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: const Color(0xFF2C4B40),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HeroStep('01', 'Show your work', 'Answer in Testing Lab'),
                    SizedBox(height: 22),
                    _HeroStep(
                      '02',
                      'Get an AI judgment',
                      'Four dimensions, with evidence',
                    ),
                    SizedBox(height: 22),
                    _HeroStep(
                      '03',
                      'Close the gap',
                      'Work toward your next target',
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _metric(MetricKind metric) {
    final value = controller.judgedScore(metric);
    final detail = controller.currentJudgment?.metrics
        .where((m) => m.metric == metric)
        .firstOrNull;
    final hint = switch (metric) {
      MetricKind.knowledge =>
        'How clearly your answers demonstrate understanding.',
      MetricKind.practice => 'How well you apply what you learned.',
      MetricKind.consistency =>
        'AI needs assessment evidence across several days.',
      MetricKind.impact =>
        'AI needs comparable work to judge demonstrated growth.',
    };
    return AssessmentPanel(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppColors.pale,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  assessmentMetricIcon(metric),
                  size: 21,
                  color: AppColors.green,
                ),
              ),
              const Spacer(),
              const Icon(Icons.auto_awesome, size: 15, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            aiMetricLabel(metric),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            value == null ? 'Not assessed' : '${assessmentScore(value)} / 100',
            key: ValueKey('overview-ai-${metric.name}'),
            style: TextStyle(
              fontSize: value == null ? 23 : 28,
              letterSpacing: -.8,
              fontWeight: FontWeight.w600,
              color: value == null ? AppColors.muted : AppColors.ink,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            detail?.feedback ?? hint,
            style: const TextStyle(
              fontSize: 11,
              height: 1.7,
              color: AppColors.muted,
            ),
          ),
          if (detail != null && detail.evidenceIds.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                '${detail.evidenceIds.length} assessed evidence ${detail.evidenceIds.length == 1 ? 'record' : 'records'}',
                style: const TextStyle(fontSize: 10, color: AppColors.green),
              ),
            ),
        ],
      ),
    );
  }

  Widget _review(BuildContext context, bool hasEvidence) => AssessmentPanel(
    color: const Color(0xFFF0F4EC),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 20,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Icon(Icons.auto_awesome_outlined, color: AppColors.green),
            Text(
              controller.judgmentStale
                  ? 'New evidence is ready for AI review'
                  : controller.currentJudgment == null
                  ? 'Turn your tests into a clear picture'
                  : 'What your AI examiner noticed',
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            ),
            FilledButton.icon(
              key: const Key('overview-ai-review'),
              onPressed: reviewing || controller.saving || !hasEvidence
                  ? null
                  : onReview,
              icon: reviewing
                  ? const SizedBox(
                      width: 15,
                      height: 15,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.insights_outlined, size: 17),
              label: Text(
                reviewing ? 'Reviewing evidence…' : 'Ask AI to judge progress',
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          controller.currentJudgment?.summary ??
              (hasEvidence
                  ? 'AI reviews your saved assessment evidence. Missing evidence stays unassessed; you never enter your own scores.'
                  : 'Complete a Testing Lab assessment first. Your four scores will stay unassessed until AI has evidence to judge.'),
          style: const TextStyle(
            fontSize: 12,
            height: 1.8,
            color: AppColors.muted,
          ),
        ),
        if (controller.judgmentStale)
          const Padding(
            padding: EdgeInsets.only(top: 9),
            child: Text(
              'The previous judgment is out of date. Refresh it to use the new evidence.',
              style: TextStyle(fontSize: 11, color: AppColors.gold),
            ),
          ),
        if (reviewError != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              reviewError!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontSize: 12,
              ),
            ),
          ),
      ],
    ),
  );

  Widget _history(List<LabResult> results) => AssessmentPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssessmentSectionTitle(
          'Your assessment trail',
          subtitle: 'AI-marked tests · latest ${math.min(results.length, 7)}',
          action: TextButton(
            onPressed: onTest,
            child: const Text('Open Testing Lab →'),
          ),
        ),
        const SizedBox(height: 20),
        if (results.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Your first test starts the story. There are no assumed scores here.',
              style: TextStyle(color: AppColors.muted, height: 1.7),
            ),
          ),
        if (results.isNotEmpty) ...[
          LayoutBuilder(
            builder: (context, box) {
              final resultsToShow = results.take(7).toList().reversed.toList();
              final textScale = MediaQuery.textScalerOf(context).scale(10) / 10;
              return SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  width: math.max(
                    box.maxWidth,
                    resultsToShow.length * 48 * textScale,
                  ),
                  height: 110 + 30 * textScale,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final result in resultsToShow)
                        Expanded(
                          child: Semantics(
                            label:
                                '${result.topic}, ${assessmentScore(result.totalScore)} out of 100, ${assessmentDate(result.completedAt)}',
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Text(
                                    assessmentScore(result.totalScore),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
                                  ),
                                  const SizedBox(height: 7),
                                  Container(
                                    height: 4 + result.totalScore * .9,
                                    decoration: BoxDecoration(
                                      color: result.id == results.first.id
                                          ? AppColors.green
                                          : const Color(0xFFCBDDC9),
                                      borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(6),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '${result.completedAt.toLocal().day}',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppColors.muted,
                                    ),
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
            },
          ),
          const SizedBox(height: 19),
          Text(
            'Latest: ${results.first.topic}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
          ),
          const SizedBox(height: 5),
          Text(
            '${results.first.level.label} · ${results.first.questionCount} questions · ${assessmentDate(results.first.completedAt)}',
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          const SizedBox(height: 10),
          const Text(
            'Test marks show the submitted work. Different question sets can differ in difficulty.',
            style: TextStyle(fontSize: 10, height: 1.7, color: AppColors.muted),
          ),
        ],
      ],
    ),
  );

  Widget _target() {
    final plan = controller.researchTarget;
    final snapshot = plan == null
        ? null
        : BenchmarkAnalytics.evaluate(
            plan,
            controller.data.labResults,
            controller.data.projectEvidence,
          );
    return AssessmentPanel(
      color: const Color(0xFFF6F1E7),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.explore_outlined, color: AppColors.gold, size: 25),
          const SizedBox(height: 17),
          Text(
            plan == null ? 'Choose your next horizon' : plan.subjectName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              letterSpacing: -.7,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            plan == null
                ? 'Find a person or role that inspires you. Build a sourced path with clear milestones.'
                : plan.headline,
            style: const TextStyle(
              fontSize: 12,
              height: 1.8,
              color: AppColors.muted,
            ),
          ),
          if (snapshot != null) ...[
            const SizedBox(height: 22),
            Text(
              '${snapshot.progressPercent.toStringAsFixed(1)}% path readiness',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 9),
            LinearProgressIndicator(
              value: snapshot.progressPercent / 100,
              minHeight: 6,
              borderRadius: BorderRadius.circular(8),
              backgroundColor: Colors.white,
              color: AppColors.gold,
            ),
            const SizedBox(height: 9),
            const Text(
              'Milestone evidence, including self-reported project completion. Separate from your AI scores.',
              style: TextStyle(
                fontSize: 10,
                height: 1.7,
                color: AppColors.muted,
              ),
            ),
          ],
          const SizedBox(height: 17),
          TextButton(
            onPressed: onBenchmarks,
            child: Text(
              plan == null ? 'Explore benchmarks →' : 'Open your path →',
            ),
          ),
        ],
      ),
    );
  }

  Widget _goals(List<ProgressGoal> goals) => AssessmentPanel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AssessmentSectionTitle(
          'Your next milestones',
          action: TextButton(
            onPressed: onGoals,
            child: const Text('All goals →'),
          ),
        ),
        const SizedBox(height: 17),
        if (goals.isEmpty)
          const Text(
            'Choose an ambitious target. AI assessment evidence will track your progress toward it.',
            style: TextStyle(fontSize: 12, color: AppColors.muted, height: 1.8),
          ),
        for (final goal in goals) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.outlined_flag, size: 18, color: AppColors.green),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${aiMetricLabel(goal.metric)} · target ${assessmentScore(goal.target)} · due ${assessmentDate(goal.deadline)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.muted,
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
        ],
      ],
    ),
  );

  Widget _today() {
    final tasks = controller.tasksOn(DateTime.now());
    final routines = controller.routinesOn(DateTime.now());
    return AssessmentPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssessmentSectionTitle(
            'Make room for today',
            subtitle: '${tasks.length} tasks · ${routines.length} routines',
            action: TextButton(
              onPressed: onRoutines,
              child: const Text('Open planner →'),
            ),
          ),
          const SizedBox(height: 17),
          if (tasks.isEmpty && routines.isEmpty)
            const Text(
              'A clear day to shape. Add a task, plan a meal, or organize your classes.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                height: 1.8,
              ),
            ),
          for (final task in tasks.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  Icon(
                    task.completed
                        ? Icons.check_circle_outline
                        : Icons.radio_button_unchecked,
                    size: 17,
                    color: task.completed ? AppColors.green : AppColors.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 12,
                        decoration: task.completed
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    task.timeMinutes == null
                        ? 'Any time'
                        : routineClock(task.timeMinutes!),
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          for (final routine in routines.take(
            tasks.length >= 3 ? 0 : 3 - tasks.length,
          ))
            Padding(
              padding: const EdgeInsets.only(bottom: 13),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 17, color: AppColors.muted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      routine.title,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    routineClock(routine.startMinutes),
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
    );
  }
}

class _HeroStep extends StatelessWidget {
  const _HeroStep(this.number, this.title, this.subtitle);
  final String number, title, subtitle;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        number,
        style: const TextStyle(
          color: Color(0xFFB3D39B),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(
                color: Color(0xFFB4CABD),
                fontSize: 10,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
