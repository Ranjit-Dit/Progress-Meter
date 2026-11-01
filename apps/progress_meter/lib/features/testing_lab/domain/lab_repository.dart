import '../../ai_coach/domain/coach_models.dart' show CoachHealth;
import '../../progress/domain/progress_types.dart' show ProgressTrack;
import 'lab_models.dart';

abstract interface class LabRepository {
  Future<LabSession> generate({
    required String requestId,
    required String topic,
    required String learningNotes,
    required ProgressTrack track,
    required LabLevel level,
    int questionCount = defaultLabQuestionCount,
  });
  Future<LabResult> grade(LabSession session, Map<String, String> answers);
  Future<CoachHealth> health();
  void close();
}
