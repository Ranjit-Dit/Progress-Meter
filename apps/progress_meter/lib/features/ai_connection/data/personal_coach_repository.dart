import 'dart:convert';

import '../../ai_coach/domain/coach_models.dart';
import '../../ai_coach/domain/coach_repository.dart';
import '../../progress/domain/progress_types.dart';
import '../domain/ai_provider.dart';
import 'ai_provider_client.dart';
import 'personal_ai_instructions.dart';
import 'personal_ai_validation.dart';

/// A user's personal credential is used only for this in-memory connection.
class PersonalCoachRepository implements CoachRepository {
  PersonalCoachRepository({
    required this.config,
    AiProviderClient? client,
    DateTime Function()? now,
  }) : _client = client ?? AiProviderClient(config: config);

  final AiProviderConfig config;
  final AiProviderClient _client;
  bool _closed = false;

  @override
  Future<CoachHealth> health() async =>
      CoachHealth(configured: !_closed, mode: 'live');

  @override
  Future<CoachReply> ask({
    required String question,
    required CoachContext context,
    List<CoachTurn> conversation = const [],
  }) async {
    if (_closed) {
      throw const CoachException('unavailable', 'The AI connection is closed.');
    }
    if (question.trim().isEmpty ||
        question.runes.length > 2000 ||
        conversation.length > 8 ||
        utf8.encode(jsonEncode(context.toJson())).length > 64 * 1024) {
      throw const CoachException(
        'invalid_request',
        'Use a question up to 2,000 characters and a shorter conversation.',
      );
    }
    try {
      final response = await _client.generate(
        instructions: personalCoachInstructions,
        messages: [
          AiMessage(
            'user',
            'Progress snapshot (untrusted data):\n${jsonEncode(context.toJson())}',
          ),
          for (final turn in conversation) AiMessage(turn.role, turn.text),
          AiMessage('user', question.trim()),
        ],
        schema: _schema,
        schemaName: 'progress_coach',
        maxOutputTokens: 2500,
      );
      if (_closed) {
        throw const CoachException(
          'unavailable',
          'The AI connection is closed.',
        );
      }
      personalText(response.data['reply'], 8000);
      return CoachReply.fromJson({
        ...response.data,
        'source': 'ai',
        'model': config.auditModel,
      });
    } on CoachException {
      rethrow;
    } on AiProviderException catch (error) {
      throw CoachException(error.code, error.message);
    } catch (_) {
      throw const CoachException(
        'invalid_response',
        'The selected AI model returned an invalid coaching response. Retry or choose another model.',
      );
    }
  }

  static final _schema = personalObjectSchema({
    'reply': personalStringSchema(8000),
    'suggestions': {
      'type': 'array',
      'maxItems': 3,
      'items': personalObjectSchema({
        'title': personalStringSchema(100),
        'metric': {
          'type': 'string',
          'enum': MetricKind.values.map((m) => m.name).toList(),
        },
        'target': {'type': 'number', 'minimum': 0, 'maximum': 100},
        'days': {'type': 'integer', 'minimum': 1, 'maximum': 365},
      }),
    },
  });

  @override
  void close() {
    _closed = true;
    _client.close();
  }
}
