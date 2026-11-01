import 'coach_models.dart';

abstract interface class CoachRepository {
  Future<CoachReply> ask({
    required String question,
    required CoachContext context,
    List<CoachTurn> conversation = const [],
  });
  Future<CoachHealth> health();
  void close();
}
