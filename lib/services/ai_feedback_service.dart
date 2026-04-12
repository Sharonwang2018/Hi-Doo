import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/api_service.dart';

/// AI listener-style feedback after a retelling (Groq via `/api/assessment`).
class AiFeedbackService {
  AiFeedbackService._();

  /// [languageHint] is reserved for future locale variants; US build uses English listener voice on the server.
  static Future<Map<String, dynamic>> generate({
    required String transcript,
    required String summary,
    List<String> questions = const [],
    String? languageHint,
  }) async {
    if (!EnvConfig.isConfigured) {
      throw Exception(
        'API is not configured. Set API_BASE_URL and server GROQ_API_KEY (see api/.env.example).',
      );
    }

    final result = await ApiService.postAssessment(
      kind: 'retelling_feedback',
      transcript: transcript,
      summary: summary,
      temperature: 0.55,
    );

    final comment = (result['comment'] as String?)?.trim();
    final score = (result['logic_score'] as num?)?.toInt();

    if (comment == null || comment.isEmpty) {
      throw Exception('Empty listener response.');
    }
    if (score == null || score < 1 || score > 5) {
      throw Exception('Invalid score from model.');
    }

    return {'comment': comment, 'encouragement': comment, 'logic_score': score};
  }
}
