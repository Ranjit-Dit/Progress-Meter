import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../progress/domain/progress_types.dart';
import '../../ai_coach/domain/coach_models.dart' show CoachHealth;
import '../domain/benchmark_models.dart';
import '../domain/benchmark_analytics.dart';
import '../domain/benchmark_repository.dart';

String _requestId() =>
    'benchmark-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';

class BenchmarkResearchController extends ChangeNotifier {
  BenchmarkResearchController(this.repository);
  final BenchmarkResearchRepository repository;
  ResearchPlan? preview;
  BenchmarkReview? review;
  BenchmarkException? error;
  bool busy = false, researching = false, reviewing = false;
  bool _closed = false;
  int _epoch = 0;
  Map<String, dynamic>? _lastResearch;
  String? _researchId, _reviewId, _reviewKey;
  BenchmarkProgressSnapshot? _lastSnapshot;
  bool _lastWasReview = false;
  bool get lastWasReview => _lastWasReview;
  Future<CoachHealth> checkHealth() => repository.health();
  Future<void> research({
    required BenchmarkKind kind,
    required String query,
    String context = '',
    String postText = '',
    required ProgressTrack track,
  }) async {
    if (_closed || busy) return;
    final request = {
      'kind': kind.name,
      'query': query.trim(),
      'context': context.trim(),
      'postText': postText.trim(),
      'track': track.name,
    };
    if (query.trim().isEmpty ||
        query.runes.length > 300 ||
        context.runes.length > 3000 ||
        postText.runes.length > 10000) {
      error = const BenchmarkException(
        'invalid_request',
        'Enter a specific name or public post within the field limits.',
      );
      notifyListeners();
      return;
    }
    final same =
        preview == null && jsonEncode(request) == jsonEncode(_lastResearch);
    if (!same) _researchId = _requestId();
    _lastResearch = request;
    preview = null;
    clearReview(notify: false);
    _lastWasReview = false;
    error = null;
    busy = true;
    researching = true;
    final epoch = ++_epoch;
    notifyListeners();
    try {
      final value = await repository.research(
        requestId: _researchId!,
        kind: kind,
        query: query.trim(),
        context: context.trim(),
        postText: postText.trim(),
        track: track,
      );
      if (_active(epoch)) preview = value;
    } on BenchmarkException catch (e) {
      if (_active(epoch)) error = e;
    } catch (_) {
      if (_active(epoch)) {
        error = const BenchmarkException(
          'unavailable',
          'Research could not finish. Please retry.',
        );
      }
    } finally {
      if (_active(epoch)) {
        busy = false;
        researching = false;
        notifyListeners();
      }
    }
  }

  Future<void> reviewProgress(BenchmarkProgressSnapshot snapshot) async {
    if (_closed || busy) return;
    if (_reviewKey != snapshot.evidenceKey) {
      _reviewId = _requestId();
      review = null;
    }
    _reviewKey = snapshot.evidenceKey;
    _lastSnapshot = snapshot;
    _lastWasReview = true;
    error = null;
    busy = true;
    reviewing = true;
    final epoch = ++_epoch;
    notifyListeners();
    try {
      final value = await repository.review(
        snapshot,
        requestId: _reviewId ??= _requestId(),
      );
      if (_active(epoch)) review = value;
    } on BenchmarkException catch (e) {
      if (_active(epoch)) error = e;
    } catch (_) {
      if (_active(epoch)) {
        error = const BenchmarkException(
          'unavailable',
          'The progress review could not finish. Please retry.',
        );
      }
    } finally {
      if (_active(epoch)) {
        busy = false;
        reviewing = false;
        notifyListeners();
      }
    }
  }

  bool reviewMatches(BenchmarkProgressSnapshot snapshot) =>
      review?.planId == snapshot.plan.id && _reviewKey == snapshot.evidenceKey;
  Future<void> retry() async {
    if (busy || _closed) return;
    if (_lastWasReview && _lastSnapshot != null) {
      await reviewProgress(_lastSnapshot!);
      return;
    }
    final r = _lastResearch;
    if (r != null) {
      await research(
        kind: BenchmarkKind.values.byName(r['kind'] as String),
        query: r['query'] as String,
        context: r['context'] as String,
        postText: r['postText'] as String,
        track: ProgressTrack.values.byName(r['track'] as String),
      );
    }
  }

  bool _active(int e) => !_closed && e == _epoch;
  void clearReview({bool notify = true}) {
    review = null;
    _reviewKey = null;
    _reviewId = null;
    _lastSnapshot = null;
    if (notify && !_closed) notifyListeners();
  }

  void clear() {
    if (_closed) return;
    _epoch++;
    preview = null;
    clearReview(notify: false);
    error = null;
    busy = false;
    researching = false;
    reviewing = false;
    _lastResearch = null;
    _researchId = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _epoch++;
    repository.close();
    super.dispose();
  }
}
