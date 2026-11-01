import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../app/progress_controller.dart';
import '../domain/ai_judgment.dart';

class AiJudgmentController extends ChangeNotifier {
  AiJudgmentController({required this.progress, required this.repository});
  final ProgressController progress;
  final AiJudgmentRepository repository;
  bool busy = false;
  String? error;
  String? _requestId, _key;
  AiProgressJudgment? _pending;
  bool _closed = false;
  int _epoch = 0;
  Future<void> review() async {
    if (_closed || busy) return;
    final snapshot = AiEvidenceSnapshot.fromResults(
      progress.data.labResults,
      progress.track,
    );
    if (snapshot.assessments.isEmpty) {
      error =
          'Complete a Testing Lab assessment before requesting AI judgments.';
      notifyListeners();
      return;
    }
    if (_key != snapshot.evidenceKey) {
      _requestId =
          'judgment-${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
      _key = snapshot.evidenceKey;
      _pending = null;
    }
    busy = true;
    error = null;
    final epoch = ++_epoch;
    notifyListeners();
    try {
      final judgment =
          _pending ?? await repository.review(snapshot, requestId: _requestId!);
      if (_closed || epoch != _epoch) return;
      _pending = judgment;
      try {
        await progress.recordAiJudgment(judgment);
        _pending = null;
      } catch (_) {
        throw const AiJudgmentException(
          'The AI review could not be saved. Retry to save it without another AI request.',
        );
      }
    } on AiJudgmentException catch (e) {
      if (!_closed && epoch == _epoch) error = e.message;
    } catch (_) {
      if (!_closed && epoch == _epoch) {
        error = 'AI judgment could not finish. Please retry.';
      }
    } finally {
      if (!_closed && epoch == _epoch) {
        busy = false;
        notifyListeners();
      }
    }
  }

  void clear() {
    _epoch++;
    busy = false;
    error = null;
    _key = null;
    _requestId = null;
    _pending = null;
    if (!_closed) notifyListeners();
  }

  @override
  void dispose() {
    _closed = true;
    _epoch++;
    repository.close();
    super.dispose();
  }
}
