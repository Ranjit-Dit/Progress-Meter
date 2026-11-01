import '../domain/models.dart';

/// Fictional, reproducible sample records relative to the first launch date.
ProgressData createDemoData(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final entries = <ProgressEntry>[];
  for (var week = 0; week < 13; week++) {
    final date = today.subtract(Duration(days: (12 - week) * 7));
    entries.add(
      ProgressEntry(
        id: 'demo-academic-$week',
        title: week == 12
            ? 'A stronger foundation'
            : 'Week ${week + 1} learning check-in',
        note: week == 12
            ? 'Finished the data structures module and improved my practice scores.'
            : 'Reviewed concepts, practiced problems, and reflected on weekly learning.',
        track: ProgressTrack.academic,
        date: date,
        metrics: {
          MetricKind.knowledge: 44 + week * 3.0,
          MetricKind.practice: 40 + week * 3.0,
          MetricKind.consistency: 48 + week * 3.0,
          MetricKind.impact: 36 + week * 3.0,
        },
      ),
    );
    entries.add(
      ProgressEntry(
        id: 'demo-career-$week',
        title: week == 12
            ? 'Portfolio project shipped'
            : 'Week ${week + 1} career check-in',
        note: week == 12
            ? 'Built a Flutter prototype, documented it, and asked for feedback.'
            : 'Built practical skills through project work and feedback.',
        track: ProgressTrack.career,
        date: date,
        metrics: {
          MetricKind.knowledge: 37 + week * 3.0,
          MetricKind.practice: 30 + week * 3.0,
          MetricKind.consistency: 46 + week * 2.0,
          MetricKind.impact: 22 + week * 3.0,
        },
      ),
    );
  }
  return ProgressData(
    entries: entries,
    studentName: 'Alex',
    targetProfileId: 'demo-maya',
    profiles: [
      TargetProfile(
        id: 'demo-maya',
        name: 'Maya Patel',
        role: 'Computer science · Year 3',
        initials: 'MP',
        track: ProgressTrack.academic,
        metrics: {
          MetricKind.knowledge: 90,
          MetricKind.practice: 88,
          MetricKind.consistency: 92,
          MetricKind.impact: 86,
        },
      ),
      TargetProfile(
        id: 'demo-arjun',
        name: 'Arjun Mehta',
        role: 'Engineering · Year 2',
        initials: 'AM',
        track: ProgressTrack.academic,
        metrics: {
          MetricKind.knowledge: 84,
          MetricKind.practice: 87,
          MetricKind.consistency: 80,
          MetricKind.impact: 85,
        },
      ),
      TargetProfile(
        id: 'demo-sara',
        name: 'Sara Khan',
        role: 'Data science · Year 3',
        initials: 'SK',
        track: ProgressTrack.academic,
        metrics: {
          MetricKind.knowledge: 93,
          MetricKind.practice: 90,
          MetricKind.consistency: 86,
          MetricKind.impact: 91,
        },
      ),
      TargetProfile(
        id: 'demo-daniel',
        name: 'Daniel Kim',
        role: 'Flutter developer · Intern',
        initials: 'DK',
        track: ProgressTrack.career,
        metrics: {
          MetricKind.knowledge: 88,
          MetricKind.practice: 92,
          MetricKind.consistency: 84,
          MetricKind.impact: 86,
        },
      ),
      TargetProfile(
        id: 'demo-priya',
        name: 'Priya Sharma',
        role: 'Product designer · Junior',
        initials: 'PS',
        track: ProgressTrack.career,
        metrics: {
          MetricKind.knowledge: 82,
          MetricKind.practice: 89,
          MetricKind.consistency: 90,
          MetricKind.impact: 84,
        },
      ),
      TargetProfile(
        id: 'demo-omar',
        name: 'Omar Ali',
        role: 'Software engineer · Junior',
        initials: 'OA',
        track: ProgressTrack.career,
        metrics: {
          MetricKind.knowledge: 94,
          MetricKind.practice: 91,
          MetricKind.consistency: 88,
          MetricKind.impact: 90,
        },
      ),
    ],
    goals: [
      ProgressGoal(
        id: 'demo-goal-1',
        title: 'Build a daily problem-solving habit',
        track: ProgressTrack.academic,
        metric: MetricKind.practice,
        target: 85,
        deadline: today.add(const Duration(days: 14)),
      ),
      ProgressGoal(
        id: 'demo-goal-2',
        title: 'Master data structures fundamentals',
        track: ProgressTrack.academic,
        metric: MetricKind.knowledge,
        target: 90,
        deadline: today.add(const Duration(days: 30)),
      ),
      ProgressGoal(
        id: 'demo-goal-3',
        title: 'Ship a portfolio-ready project',
        track: ProgressTrack.career,
        metric: MetricKind.practice,
        target: 85,
        deadline: today.add(const Duration(days: 21)),
      ),
    ],
  );
}
