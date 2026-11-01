import '../../ai_coach/domain/coach_models.dart' show CoachHealth;
import '../../progress/domain/progress_types.dart';
import 'benchmark_models.dart';
import 'benchmark_analytics.dart';

abstract interface class BenchmarkResearchRepository {
  Future<ResearchPlan> research({
    required String requestId,
    required BenchmarkKind kind,
    required String query,
    required String context,
    required String postText,
    required ProgressTrack track,
  });
  Future<BenchmarkReview> review(
    BenchmarkProgressSnapshot snapshot, {
    required String requestId,
  });
  Future<CoachHealth> health();
  void close();
}
