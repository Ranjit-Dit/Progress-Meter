import 'package:progress_meter/features/benchmark_research/domain/benchmark_models.dart';
import 'package:progress_meter/features/progress/domain/models.dart';
import 'package:progress_meter/features/testing_lab/domain/lab_models.dart';

Map<String, dynamic> benchmarkJson({
  String id = 'path-one',
  String status = 'ready',
}) => {
  'id': id,
  'kind': 'person',
  'query': 'Sample professional',
  'track': 'academic',
  'researchedAt': '2026-10-30T08:00:00Z',
  'model': 'test-model',
  'source': 'openai',
  'status': status,
  'subjectName': 'Sample professional',
  'headline': 'Public teaching and projects',
  'summary': 'Professional evidence informs this proposed learning path.',
  'warnings': ['Targets are inferred.'],
  'sources': [
    {
      'id': 's1',
      'title': 'Official biography',
      'url': 'https://example.com/bio',
    },
  ],
  'evidence': [
    {
      'text': 'The public biography describes technical teaching.',
      'sourceIds': ['s1'],
    },
  ],
  'milestones': status != 'ready'
      ? []
      : [
          for (var i = 1; i <= 5; i++)
            {
              'id': 'm$i',
              'title': 'Step $i',
              'description':
                  'Demonstrate the requested skill and explain the work.',
              'kind': i == 3 || i == 5 ? 'project' : 'assessment',
              'topic': 'Topic $i',
              'level': 'beginner',
              'targetScore': i == 3 || i == 5 ? null : 80,
              'sourceIds': ['s1'],
            },
        ],
};
ResearchPlan benchmarkPlan({String id = 'path-one'}) =>
    ResearchPlan.fromJson(benchmarkJson(id: id));
LabResult benchmarkLab({
  String id = 'lab-one',
  String topic = 'Topic 1',
  int marks = 4,
  DateTime? date,
  ProgressTrack track = ProgressTrack.academic,
  LabLevel level = LabLevel.beginner,
}) => LabResult(
  sessionId: id,
  topic: topic,
  track: track,
  level: level,
  completedAt: date ?? DateTime.now().subtract(const Duration(minutes: 1)),
  model: 'test-model',
  feedback: 'Show the missing reasoning.',
  nextSteps: ['Practice.'],
  questions: [
    for (var i = 1; i <= 4; i++)
      LabQuestionGrade(
        question: LabQuestion(
          id: 'q$i',
          prompt: 'Explain question $i.',
          dimension: i <= 2
              ? LabDimension.understanding
              : LabDimension.application,
        ),
        answer: 'Written work.',
        correctness: marks,
        reasoning: 0,
        precision: 0,
        feedback: 'Add justification.',
        missingConcepts: [],
        referenceAnswer: 'A full explanation.',
      ),
  ],
);
