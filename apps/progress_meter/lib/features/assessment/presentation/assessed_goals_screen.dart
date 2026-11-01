import 'package:flutter/material.dart';

import '../../../app/progress_controller.dart';
import '../../../common/app_theme.dart';
import '../../progress/domain/models.dart';
import '../domain/ai_judgment.dart';
import 'assessment_design.dart';

class AssessedGoalsScreen extends StatefulWidget {
  const AssessedGoalsScreen({
    super.key,
    required this.controller,
    required this.reviewing,
    required this.onReview,
    required this.onTest,
    required this.onAdd,
    required this.onDelete,
    this.reviewError,
  });
  final ProgressController controller;
  final bool reviewing;
  final VoidCallback onReview, onTest, onAdd;
  final ValueChanged<ProgressGoal> onDelete;
  final String? reviewError;
  @override
  State<AssessedGoalsScreen> createState() => _AssessedGoalsScreenState();
}

class _AssessedGoalsScreenState extends State<AssessedGoalsScreen> {
  int _filter = 0;
  ProgressController get c => widget.controller;
  bool get _hasEvidence => c.data.labResults.any(
    (r) => r.track == c.track && !r.completedAt.isAfter(DateTime.now()),
  );
  @override
  Widget build(BuildContext context) {
    final all = c.goals;
    final verified = all.where(c.goalAchieved).length;
    final waiting = all.where((g) => c.judgedScore(g.metric) == null).length;
    final goals =
        all
            .where(
              (g) => switch (_filter) {
                1 => !c.goalAchieved(g),
                2 => c.goalAchieved(g),
                3 => c.judgedScore(g.metric) == null,
                _ => true,
              },
            )
            .toList()
          ..sort((a, b) => a.deadline.compareTo(b.deadline));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          spacing: 20,
          runSpacing: 16,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SET YOUR DIRECTION',
                  style: TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.5,
                    color: AppColors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'Ambition, with evidence.',
                  style: TextStyle(
                    fontSize: 33,
                    letterSpacing: -1.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10),
                Text(
                  'You choose the target. AI judges how close you are.',
                  style: TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ],
            ),
            FilledButton.icon(
              key: const Key('goals-add-target'),
              onPressed: c.saving ? null : widget.onAdd,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Set a goal'),
            ),
          ],
        ),
        const SizedBox(height: 27),
        LayoutBuilder(
          builder: (context, box) {
            final stats = [
              _stat(
                'Goals in motion',
                '${all.length - verified}',
                Icons.flag_outlined,
              ),
              _stat('AI verified', '$verified', Icons.verified_outlined),
              _stat('Awaiting evidence', '$waiting', Icons.fact_check_outlined),
            ];
            if (box.maxWidth < 620) {
              return Column(
                children: [
                  for (final item in stats)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: item,
                    ),
                ],
              );
            }
            return Row(
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 14),
                  Expanded(child: stats[i]),
                ],
              ],
            );
          },
        ),
        const SizedBox(height: 20),
        AssessmentPanel(
          color: const Color(0xFFEAF1E7),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 15,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Icon(
                    Icons.auto_awesome_outlined,
                    color: AppColors.green,
                  ),
                  Text(
                    c.judgmentStale
                        ? 'Your evidence changed. Refresh the AI judgment.'
                        : 'Goal progress comes from AI judgments',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  FilledButton.icon(
                    key: const Key('goals-ai-review'),
                    onPressed: widget.reviewing || c.saving || !_hasEvidence
                        ? null
                        : widget.onReview,
                    icon: widget.reviewing
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.insights_outlined, size: 17),
                    label: Text(
                      widget.reviewing ? 'Reviewing…' : 'Review progress',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              const Text(
                'Targets are your intentions, not self-ratings. A goal is AI verified only when a current AI judgment meets its target. Old manual completion marks do not count.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.muted,
                  height: 1.8,
                ),
              ),
              if (!_hasEvidence)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: TextButton.icon(
                    onPressed: widget.onTest,
                    icon: const Icon(Icons.science_outlined, size: 17),
                    label: const Text('Take a test to supply evidence →'),
                  ),
                ),
              if (widget.reviewError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    widget.reviewError!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 26),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (index, label) in [
              (0, 'All goals'),
              (1, 'In progress'),
              (2, 'AI verified'),
              (3, 'Needs evidence'),
            ])
              ChoiceChip(
                key: ValueKey('goals-filter-$index'),
                label: Text(label, style: const TextStyle(fontSize: 12)),
                selected: _filter == index,
                onSelected: (_) => setState(() => _filter = index),
              ),
          ],
        ),
        const SizedBox(height: 18),
        if (goals.isEmpty)
          AssessmentPanel(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 28),
              child: Column(
                children: [
                  const Icon(
                    Icons.outlined_flag,
                    size: 35,
                    color: AppColors.green,
                  ),
                  const SizedBox(height: 15),
                  Text(
                    all.isEmpty
                        ? 'Give your next chapter a target.'
                        : 'No goals in this view yet.',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 9),
                  const Text(
                    'Choose a dimension and a target. Your AI assessment will supply the current score.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.muted,
                      height: 1.8,
                    ),
                  ),
                  const SizedBox(height: 15),
                  TextButton(
                    onPressed: all.isEmpty
                        ? widget.onAdd
                        : () => setState(() => _filter = 0),
                    child: Text(
                      all.isEmpty
                          ? 'Set your first goal →'
                          : 'Show all goals →',
                    ),
                  ),
                ],
              ),
            ),
          ),
        for (final goal in goals)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _goal(goal),
          ),
        const SizedBox(height: 8),
        const Text(
          'Consistency needs evidence across several assessment days. Outcomes need comparable assessed work showing learning progress. AI leaves a dimension unassessed when the evidence is too limited.',
          style: TextStyle(fontSize: 11, color: AppColors.muted, height: 1.8),
        ),
      ],
    );
  }

  Widget _stat(String label, String number, IconData icon) => AssessmentPanel(
    padding: const EdgeInsets.all(21),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.pale,
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: AppColors.green, size: 22),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                number,
                style: const TextStyle(
                  fontSize: 29,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _goal(ProgressGoal goal) {
    final score = c.judgedScore(goal.metric);
    final reached = c.goalAchieved(goal);
    final overdue =
        DateUtils.dateOnly(goal.deadline)
            .isBefore(DateUtils.dateOnly(DateTime.now())) &&
        !reached;
    final progress = score == null
        ? 0.0
        : goal.target == 0
        ? 1.0
        : (score / goal.target).clamp(0.0, 1.0);
    return AssessmentPanel(
      key: ValueKey('assessed-goal-${goal.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(11),
                decoration: BoxDecoration(
                  color: reached ? AppColors.pale : AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  reached
                      ? Icons.verified_outlined
                      : assessmentMetricIcon(goal.metric),
                  size: 23,
                  color: AppColors.green,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.4,
                      ),
                    ),
                    const SizedBox(height: 7),
                    Text(
                      '${aiMetricLabel(goal.metric)} · ${c.track.label}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                key: ValueKey('goal-delete-${goal.id}'),
                tooltip: 'Delete goal',
                onPressed: c.saving ? null : () => widget.onDelete(goal),
                icon: const Icon(
                  Icons.more_horiz,
                  size: 21,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 16,
            runSpacing: 10,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Wrap(
                spacing: 7,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  Text(
                    score == null ? '—' : assessmentScore(score),
                    key: ValueKey('goal-ai-score-${goal.id}'),
                    style: const TextStyle(
                      fontSize: 33,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      '/ ${assessmentScore(goal.target)} target',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                      ),
                    ),
                  ),
                ],
              ),
              AssessmentPill(
                reached
                    ? 'AI verified'
                    : score == null
                    ? 'Needs evidence'
                    : overdue
                    ? 'Past due · keep going'
                    : 'In progress',
                icon: reached
                    ? Icons.verified_outlined
                    : score == null
                    ? Icons.hourglass_empty
                    : Icons.trending_up,
                color: overdue ? AppColors.gold : AppColors.green,
                background: overdue ? const Color(0xFFF8F1E4) : AppColors.pale,
              ),
            ],
          ),
          const SizedBox(height: 13),
          Semantics(
            label: score == null
                ? 'Awaiting AI judgment'
                : '${(progress * 100).toStringAsFixed(0)} percent of goal target',
            child: ExcludeSemantics(
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                borderRadius: BorderRadius.circular(8),
                backgroundColor: AppColors.pale,
                color: AppColors.green,
              ),
            ),
          ),
          const SizedBox(height: 15),
          Wrap(
            spacing: 18,
            runSpacing: 12,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                'Target date · ${assessmentDate(goal.deadline)}',
                style: TextStyle(
                  fontSize: 11,
                  color: overdue ? AppColors.gold : AppColors.muted,
                ),
              ),
              TextButton.icon(
                key: ValueKey('goal-test-${goal.id}'),
                onPressed: widget.onTest,
                icon: const Icon(Icons.science_outlined, size: 16),
                label: Text(
                  reached ? 'Keep practising →' : 'Supply test evidence →',
                ),
              ),
            ],
          ),
          if (score == null)
            const Text(
              'No current AI score is available for this dimension. Complete assessments and request a progress review.',
              style: TextStyle(
                fontSize: 11,
                height: 1.7,
                color: AppColors.muted,
              ),
            ),
        ],
      ),
    );
  }
}
