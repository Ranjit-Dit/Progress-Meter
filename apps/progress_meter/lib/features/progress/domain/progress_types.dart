enum ProgressTrack {
  academic('Academic'),
  career('Career');

  const ProgressTrack(this.label);
  final String label;
}

enum MetricKind {
  knowledge('Knowledge'),
  practice('Practice'),
  consistency('Consistency'),
  impact('Impact');

  const MetricKind(this.label);
  final String label;
}

String metricLabel(MetricKind kind, ProgressTrack track) =>
    switch ((track, kind)) {
      (ProgressTrack.academic, MetricKind.knowledge) => 'Understanding',
      (ProgressTrack.academic, MetricKind.practice) => 'Practice',
      (ProgressTrack.academic, MetricKind.consistency) => 'Consistency',
      (ProgressTrack.academic, MetricKind.impact) => 'Outcomes',
      (ProgressTrack.career, MetricKind.knowledge) => 'Technical skills',
      (ProgressTrack.career, MetricKind.practice) => 'Projects',
      (ProgressTrack.career, MetricKind.consistency) => 'Consistency',
      (ProgressTrack.career, MetricKind.impact) => 'Experience',
    };
