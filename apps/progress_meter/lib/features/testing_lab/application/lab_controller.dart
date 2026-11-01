import 'dart:math';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../ai_coach/domain/coach_models.dart' show CoachHealth;
import '../../progress/domain/progress_types.dart' show ProgressTrack;
import '../domain/lab_models.dart';
import '../domain/lab_repository.dart';

class _GenerationRequest {
  _GenerationRequest(
    this.topic,
    this.notes,
    this.track,
    this.level,
    this.questionCount,
  ) : id =
          'lab-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
  final String id, topic, notes;
  final ProgressTrack track;
  final LabLevel level;
  final int questionCount;
  bool matches(
    String value,
    String learningNotes,
    ProgressTrack valueTrack,
    LabLevel valueLevel,
    int valueQuestionCount,
  ) =>
      topic == value &&
      notes == learningNotes &&
      track == valueTrack &&
      level == valueLevel &&
      questionCount == valueQuestionCount;
}

enum _Operation { none, generate, grade, save }

/// Drafts/tokens stay in memory; only completed results reach persistence.
class LabController extends ChangeNotifier {
  LabController(this.repository, {required this._saveResult});
  final LabRepository repository;
  final Future<void> Function(LabResult) _saveResult;
  LabSession? session;
  LabResult? result;
  LabException? error;
  bool saved = false;
  bool get resultSaved => saved;
  final Map<String, String> _answers = {};
  Map<String, String> get answers => Map.unmodifiable(_answers);
  Map<String, String>? _submittedAnswers;
  bool get answersLocked => _submittedAnswers != null;
  _GenerationRequest? _lastRequest;
  _Operation _operation = _Operation.none;
  bool get busy => _operation != _Operation.none;
  bool get generating => _operation == _Operation.generate;
  bool get grading => _operation == _Operation.grade;
  bool get saving => _operation == _Operation.save;
  int _epoch = 0;
  bool _disposed = false;

  Future<void> generate({
    required String topic,
    String learningNotes = '',
    required ProgressTrack track,
    required LabLevel level,
    int questionCount = defaultLabQuestionCount,
  }) async {
    if (_disposed || busy) return;
    final value = topic.trim(), notes = learningNotes.trim();
    if (value.isEmpty ||
        value.runes.length > 120 ||
        notes.runes.length > 6000 ||
        !validLabQuestionCount(questionCount)) {
      error = const LabException(
        'invalid_request',
        'Enter a topic up to 120 characters, notes up to 6,000 characters, and 2–20 questions.',
      );
      notifyListeners();
      return;
    }
    final request =
        session == null &&
            result == null &&
            _lastRequest?.matches(value, notes, track, level, questionCount) ==
                true
        ? _lastRequest!
        : _GenerationRequest(value, notes, track, level, questionCount);
    _lastRequest = request;
    session = null;
    result = null;
    saved = false;
    error = null;
    _answers.clear();
    _submittedAnswers = null;
    _operation = _Operation.generate;
    final epoch = ++_epoch;
    notifyListeners();
    try {
      final generated = await repository.generate(
        requestId: request.id,
        topic: value,
        learningNotes: notes,
        track: track,
        level: level,
        questionCount: questionCount,
      );
      if (!_active(epoch)) return;
      session = generated;
      _answers.addEntries(generated.questions.map((q) => MapEntry(q.id, '')));
    } on LabException catch (failure) {
      if (_active(epoch)) error = failure;
    } catch (_) {
      if (_active(epoch)) {
        error = const LabException(
          'unavailable',
          'The lab could not generate questions. Please retry.',
        );
      }
    } finally {
      if (_active(epoch)) {
        _operation = _Operation.none;
        notifyListeners();
      }
    }
  }

  void setAnswer(String questionId, String text) {
    if (_disposed ||
        busy ||
        answersLocked ||
        result != null ||
        !_answers.containsKey(questionId)) {
      return;
    }
    _answers[questionId] = text;
    error = null;
    // Text fields already rebuild their own value; notify summary/button state.
    notifyListeners();
  }

  Future<void> submit() async {
    if (_disposed || busy || session == null) return;
    if (result != null) {
      if (!saved) await retrySave();
      return;
    }
    if (_answers.values.any((a) => a.runes.length > 6000)) {
      error = const LabException(
        'invalid_request',
        'Use at most 6,000 characters per answer.',
      );
      notifyListeners();
      return;
    }
    final submissionBytes = utf8
        .encode(
          jsonEncode({
            'sessionId': session!.sessionId,
            'sessionToken': session!.sessionToken,
            'answers': [
              for (final question in session!.questions)
                {
                  'questionId': question.id,
                  'answer': _answers[question.id] ?? '',
                },
            ],
          }),
        )
        .length;
    if (submissionBytes > maxLabSubmissionBytes) {
      error = const LabException(
        'request_too_large',
        'These answers contain too much data. Shorten the text before submitting.',
      );
      notifyListeners();
      return;
    }
    _submittedAnswers ??= Map.unmodifiable(_answers);
    _operation = _Operation.grade;
    error = null;
    final epoch = ++_epoch;
    notifyListeners();
    try {
      final graded = await repository.grade(session!, _submittedAnswers!);
      if (!_active(epoch)) return;
      result = graded;
      _operation = _Operation.save;
      notifyListeners();
      await _persist(graded, epoch);
    } on LabException catch (failure) {
      if (_active(epoch)) error = failure;
    } catch (_) {
      if (_active(epoch)) {
        error = const LabException(
          'unavailable',
          'The lab could not grade this test. Retry the same submitted answers.',
        );
      }
    } finally {
      if (_active(epoch)) {
        _operation = _Operation.none;
        notifyListeners();
      }
    }
  }

  Future<void> _persist(LabResult value, int epoch) async {
    try {
      await _saveResult(value);
      if (_active(epoch)) saved = true;
    } catch (_) {
      if (_active(epoch)) {
        saved = false;
        error = const LabException(
          'save_failed',
          'The test was graded, but the result could not be saved. Retry saving; grading will not run again.',
        );
      }
    }
  }

  Future<void> retrySave() async {
    if (_disposed || busy || result == null || saved) return;
    final value = result!;
    final epoch = ++_epoch;
    _operation = _Operation.save;
    error = null;
    notifyListeners();
    try {
      await _persist(value, epoch);
    } finally {
      if (_active(epoch)) {
        _operation = _Operation.none;
        notifyListeners();
      }
    }
  }

  Future<void> retry() async {
    if (_disposed || busy) return;
    if (result != null && !saved) {
      await retrySave();
      return;
    }
    if (session != null && result == null) {
      await submit();
      return;
    }
    final request = _lastRequest;
    if (request != null && session == null) {
      await generate(
        topic: request.topic,
        learningNotes: request.notes,
        track: request.track,
        level: request.level,
        questionCount: request.questionCount,
      );
    }
  }

  Future<CoachHealth> checkHealth() => repository.health();
  bool _active(int epoch) => !_disposed && epoch == _epoch;

  void clear() {
    if (_disposed) return;
    _epoch++;
    session = null;
    result = null;
    error = null;
    saved = false;
    _answers.clear();
    _submittedAnswers = null;
    _lastRequest = null;
    _operation = _Operation.none;
    notifyListeners();
  }

  void reset() => clear();

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _epoch++;
    repository.close();
    super.dispose();
  }
}
