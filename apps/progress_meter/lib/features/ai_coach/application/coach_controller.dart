import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../domain/coach_models.dart';
import '../domain/coach_repository.dart';

/// Conversation state is memory-only and separate from the student's records.
class CoachController extends ChangeNotifier {
  CoachController(this.repository);
  final CoachRepository repository;
  List<CoachTurn> _turns = const [];
  List<CoachTurn> get turns => _turns;
  CoachReply? latestReply;
  bool busy = false;
  CoachException? error;
  String? lastQuestion;
  CoachContext? lastContext;
  int _generation = 0;
  bool _disposed = false;

  Future<void> ask(String question, CoachContext context) async {
    if (_disposed || busy) return;
    final trimmed = question.trim();
    if (trimmed.isEmpty || trimmed.runes.length > 2000) {
      error = const CoachException(
        'invalid_request',
        'Enter a question between 1 and 2,000 characters.',
      );
      notifyListeners();
      return;
    }
    if (lastContext != null &&
        (lastContext!.track != context.track ||
            lastContext!.includesNotes != context.includesNotes)) {
      clear();
    }
    lastQuestion = trimmed;
    lastContext = context;
    busy = true;
    error = null;
    final generation = ++_generation;
    notifyListeners();
    try {
      final reply = await repository.ask(
        question: trimmed,
        context: context,
        conversation: _recentConversation(),
      );
      if (_disposed || generation != _generation) return;
      _turns = List.unmodifiable([
        ..._turns,
        CoachTurn(role: 'user', text: trimmed),
        CoachTurn(role: 'assistant', text: reply.reply),
      ]);
      latestReply = reply;
    } on CoachException catch (failure) {
      if (_disposed || generation != _generation) return;
      error = failure;
    } catch (_) {
      if (_disposed || generation != _generation) return;
      error = const CoachException(
        'unavailable',
        'The coach could not complete this request. Please try again.',
      );
    } finally {
      if (!_disposed && generation == _generation) {
        busy = false;
        notifyListeners();
      }
    }
  }

  List<CoachTurn> _recentConversation() {
    final recent = _turns
        .skip(_turns.length > 8 ? _turns.length - 8 : 0)
        .toList();
    var bytes = recent.fold<int>(
      0,
      (count, turn) => count + utf8.encode(turn.text).length,
    );
    while (recent.isNotEmpty && bytes > 24000) {
      bytes -= utf8.encode(recent.removeAt(0).text).length;
    }
    return List.unmodifiable(recent);
  }

  Future<void> retry() async {
    final question = lastQuestion;
    final context = lastContext;
    if (question != null && context != null) await ask(question, context);
  }

  Future<CoachHealth> checkHealth() => repository.health();

  void clear() {
    if (_disposed) return;
    _generation++;
    _turns = const [];
    latestReply = null;
    lastQuestion = null;
    lastContext = null;
    error = null;
    busy = false;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _generation++;
    repository.close();
    super.dispose();
  }
}
