import '../../progress/domain/progress_types.dart' show ProgressTrack;

const defaultLabQuestionCount = 4;
const minLabQuestionCount = 2;
const maxLabQuestionCount = 20;
const maxLabSubmissionBytes = 512 * 1024;

bool validLabQuestionCount(int count) =>
    count >= minLabQuestionCount && count <= maxLabQuestionCount;

LabDimension labQuestionDimension(int index, int count) =>
    index < (count + 1) ~/ 2
    ? LabDimension.understanding
    : LabDimension.application;

enum LabLevel {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const LabLevel(this.label);
  final String label;
}

enum LabDimension {
  understanding('Understanding'),
  application('Application');

  const LabDimension(this.label);
  final String label;
}

class LabException implements Exception {
  const LabException(this.code, this.message);
  final String code;
  final String message;
  @override
  String toString() => message;
}

String _text(Object? value, String label, int max, {bool empty = false}) {
  if (value is! String ||
      (!empty && value.trim().isEmpty) ||
      value.runes.length > max) {
    throw FormatException('Invalid $label in testing lab data.');
  }
  return value.trim();
}

String _answer(Object? value) {
  if (value is! String || value.runes.length > 6000) {
    throw const FormatException('Invalid testing lab answer.');
  }
  return value;
}

List<String> _texts(Object? value, String label, int maxItems, int maxLength) {
  if (value is! List || value.length > maxItems) {
    throw FormatException('Invalid $label in testing lab data.');
  }
  return List.unmodifiable(value.map((v) => _text(v, label, maxLength)));
}

T _enum<T extends Enum>(Object? value, List<T> options, String label) {
  final match = options.where((v) => v.name == value).firstOrNull;
  if (match == null) {
    throw FormatException('Invalid $label in testing lab data.');
  }
  return match;
}

DateTime _date(Object? value, String label) {
  if (value is! String || value.length > 40) {
    throw FormatException('Invalid $label.');
  }
  final date = DateTime.tryParse(value);
  if (date == null) throw FormatException('Invalid $label.');
  return date;
}

Map<String, dynamic> _map(Object? value) {
  if (value is! Map) throw const FormatException('Invalid testing lab object.');
  return Map<String, dynamic>.from(value);
}

List<T> _questions<T>(Object? value, T Function(Map<String, dynamic>) parse) {
  if (value is! List || !validLabQuestionCount(value.length)) {
    throw const FormatException('A lab must contain 2–20 questions.');
  }
  return List.unmodifiable(value.map((v) => parse(_map(v))));
}

int _points(Object? value, int maximum) {
  if (value is! int || value < 0 || value > maximum) {
    throw const FormatException('Invalid testing lab rubric marks.');
  }
  return value;
}

void _validateQuestions(List<LabQuestion> questions) {
  if (!validLabQuestionCount(questions.length)) {
    throw const FormatException('A lab must contain 2–20 questions.');
  }
  for (var i = 0; i < questions.length; i++) {
    final expected = labQuestionDimension(i, questions.length);
    if (questions[i].id != 'q${i + 1}' || questions[i].dimension != expected) {
      throw const FormatException(
        'Invalid testing lab question order or dimensions.',
      );
    }
  }
}

class LabQuestion {
  LabQuestion({
    required String id,
    required String prompt,
    required this.dimension,
    this.maxPoints = 10,
  }) : id = _text(id, 'question ID', 10),
       prompt = _text(prompt, 'question prompt', 1800) {
    final number = int.tryParse(id.startsWith('q') ? id.substring(1) : '');
    if (number == null ||
        number < 1 ||
        number > maxLabQuestionCount ||
        id != 'q$number' ||
        maxPoints != 10) {
      throw const FormatException('Invalid testing lab question.');
    }
  }
  final String id;
  final String prompt;
  final LabDimension dimension;
  final int maxPoints;
  factory LabQuestion.fromJson(Map<String, dynamic> json) => LabQuestion(
    id: _text(json['id'], 'question ID', 10),
    prompt: _text(json['prompt'], 'question prompt', 1800),
    dimension: _enum(
      json['dimension'],
      LabDimension.values,
      'question dimension',
    ),
    maxPoints: _points(json['maxPoints'], 10),
  );
  Map<String, dynamic> toJson() => {
    'id': id,
    'prompt': prompt,
    'dimension': dimension.name,
    'maxPoints': maxPoints,
  };
}

/// The bearer token is memory-only. This model intentionally has no toJson.
class LabSession {
  LabSession({
    required String sessionId,
    required String sessionToken,
    required String topic,
    required this.track,
    required this.level,
    required this.createdAt,
    required this.expiresAt,
    required List<LabQuestion> questions,
    this.source = 'openai',
    required String model,
  }) : sessionId = _text(sessionId, 'session ID', 100),
       sessionToken = _text(sessionToken, 'session token', 256),
       topic = _text(topic, 'topic', 120),
       model = _text(model, 'model', 120),
       questions = List.unmodifiable(questions) {
    _validateQuestions(questions);
    if (!['openai', 'ai'].contains(source) ||
        !expiresAt.isAfter(createdAt) ||
        expiresAt.difference(createdAt) > const Duration(hours: 3)) {
      throw const FormatException('Invalid live testing lab session.');
    }
  }
  final String sessionId, sessionToken, topic, source, model;
  final ProgressTrack track;
  final LabLevel level;
  final DateTime createdAt, expiresAt;
  final List<LabQuestion> questions;
  int get questionCount => questions.length;
  int get maxPoints =>
      questions.fold(0, (sum, question) => sum + question.maxPoints);
  bool get expired => !DateTime.now().isBefore(expiresAt);
  factory LabSession.fromJson(Map<String, dynamic> json) => LabSession(
    sessionId: _text(json['sessionId'], 'session ID', 100),
    sessionToken: _text(json['sessionToken'], 'session token', 256),
    topic: _text(json['topic'], 'topic', 120),
    track: _enum(json['track'], ProgressTrack.values, 'track'),
    level: _enum(json['level'], LabLevel.values, 'level'),
    createdAt: _date(json['createdAt'], 'session date'),
    expiresAt: _date(json['expiresAt'], 'session expiry'),
    questions: _questions(json['questions'], LabQuestion.fromJson),
    source: _text(json['source'], 'source', 20),
    model: _text(json['model'], 'model', 120),
  );
}

class LabQuestionGrade {
  LabQuestionGrade({
    required this.question,
    required String answer,
    required this.correctness,
    required this.reasoning,
    required this.precision,
    required String feedback,
    required List<String> missingConcepts,
    required String referenceAnswer,
  }) : answer = _answer(answer),
       feedback = _text(feedback, 'question feedback', 1600),
       missingConcepts = _texts(missingConcepts, 'missing concepts', 5, 300),
       referenceAnswer = _text(referenceAnswer, 'reference answer', 3000) {
    _points(correctness, 5);
    _points(reasoning, 3);
    _points(precision, 2);
    if (this.answer.trim().isEmpty && earnedPoints != 0) {
      throw const FormatException(
        'An unanswered question must receive zero marks.',
      );
    }
  }
  final LabQuestion question;
  final String answer, feedback, referenceAnswer;
  final int correctness, reasoning, precision;
  final List<String> missingConcepts;
  String get id => question.id;
  String get prompt => question.prompt;
  LabDimension get dimension => question.dimension;
  int get maxPoints => question.maxPoints;
  int get earnedPoints => correctness + reasoning + precision;
  factory LabQuestionGrade.fromJson(Map<String, dynamic> json) =>
      LabQuestionGrade(
        question: LabQuestion.fromJson(json),
        answer: _answer(json['answer']),
        correctness: _points(json['correctness'], 5),
        reasoning: _points(json['reasoning'], 3),
        precision: _points(json['precision'], 2),
        feedback: _text(json['feedback'], 'question feedback', 1600),
        missingConcepts: _texts(
          json['missingConcepts'],
          'missing concepts',
          5,
          300,
        ),
        referenceAnswer: _text(
          json['referenceAnswer'],
          'reference answer',
          3000,
        ),
      );
  Map<String, dynamic> toJson() => {
    ...question.toJson(),
    'answer': answer,
    'correctness': correctness,
    'reasoning': reasoning,
    'precision': precision,
    'feedback': feedback,
    'missingConcepts': missingConcepts,
    'referenceAnswer': referenceAnswer,
  };
}

/// Completed assessment evidence; no server bearer token or learning notes.
class LabResult {
  LabResult({
    required String sessionId,
    required String topic,
    required this.track,
    required this.level,
    required this.completedAt,
    this.source = 'openai',
    required String model,
    required String feedback,
    required List<String> nextSteps,
    required List<LabQuestionGrade> questions,
  }) : sessionId = _text(sessionId, 'result ID', 100),
       topic = _text(topic, 'topic', 120),
       model = _text(model, 'model', 120),
       feedback = _text(feedback, 'overall feedback', 2000),
       nextSteps = _texts(nextSteps, 'next steps', 4, 500),
       questions = List.unmodifiable(questions) {
    _validateQuestions(questions.map((q) => q.question).toList());
    if (!['openai', 'ai'].contains(source)) {
      throw const FormatException('Only live assessed results can be saved.');
    }
  }
  final String sessionId, topic, source, model, feedback;
  final ProgressTrack track;
  final LabLevel level;
  final DateTime completedAt;
  final List<LabQuestionGrade> questions;
  final List<String> nextSteps;
  String get id => sessionId;
  int get questionCount => questions.length;
  int get earnedPoints => questions.fold(0, (n, q) => n + q.earnedPoints);
  int get maxPoints =>
      questions.fold(0, (sum, question) => sum + question.maxPoints);
  double get totalScore => earnedPoints * 100 / maxPoints;
  double get understandingScore => _dimensionScore(LabDimension.understanding);
  double get applicationScore => _dimensionScore(LabDimension.application);
  double _dimensionScore(LabDimension dimension) {
    final matching = questions.where((q) => q.dimension == dimension);
    final maximum = matching.fold(0, (sum, q) => sum + q.maxPoints);
    return matching.fold(0, (sum, q) => sum + q.earnedPoints) * 100 / maximum;
  }

  factory LabResult.fromJson(Map<String, dynamic> json) {
    final result = LabResult(
      sessionId: _text(json['sessionId'], 'result ID', 100),
      topic: _text(json['topic'], 'topic', 120),
      track: _enum(json['track'], ProgressTrack.values, 'track'),
      level: _enum(json['level'], LabLevel.values, 'level'),
      completedAt: _date(json['completedAt'], 'completed date'),
      source: _text(json['source'], 'source', 20),
      model: _text(json['model'], 'model', 120),
      feedback: _text(json['feedback'], 'overall feedback', 2000),
      nextSteps: _texts(json['nextSteps'], 'next steps', 4, 500),
      questions: _questions(json['questions'], LabQuestionGrade.fromJson),
    );
    for (final (key, actual) in [
      ('totalScore', result.totalScore),
      ('understandingScore', result.understandingScore),
      ('applicationScore', result.applicationScore),
    ]) {
      final value = json[key];
      if (value is! num || !value.isFinite || (value - actual).abs() > .001) {
        throw const FormatException(
          'Testing lab totals do not match the rubric marks.',
        );
      }
    }
    return result;
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'topic': topic,
    'track': track.name,
    'level': level.name,
    'completedAt': completedAt.toIso8601String(),
    'source': source,
    'model': model,
    'feedback': feedback,
    'nextSteps': nextSteps,
    'totalScore': totalScore,
    'understandingScore': understandingScore,
    'applicationScore': applicationScore,
    'questions': questions.map((q) => q.toJson()).toList(),
  };
}
