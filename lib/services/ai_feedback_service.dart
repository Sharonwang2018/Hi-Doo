import 'dart:convert';

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/api_service.dart';

/// 生成儿童复述的 AI 点评（专业老师口吻，语言与复述一致）
/// 通过后端 /api/chat（豆包或 OpenRouter），需配置 api/.env。
class AiFeedbackService {
  AiFeedbackService._();

  /// 根据复述内容和书籍概要生成专业点评。
  /// [languageHint] 复述语言：'zh' 点评用中文，'en' 点评用英文；不传则由模型根据复述内容判断。
  static Future<Map<String, dynamic>> generate({
    required String transcript,
    required String summary,
    List<String> questions = const [],
    String? languageHint,
  }) async {
    final langInstruction = languageHint == 'en'
        ? 'The child retold in English. You must write your entire comment in English.'
        : languageHint == 'zh'
            ? '孩子用中文复述。你必须用中文写整段点评。'
            : 'Write your comment in the SAME language as the child\'s retelling: if they spoke in Chinese, reply in Chinese; if in English, reply in English.';

    final prompt = '''
You are an experienced children's reading teacher. The child has just done a free retelling of a book. Give professional, kind feedback as a teacher would.

Requirements:
1. Base your comment only on what the child actually said. Point out what they remembered or expressed well (e.g. characters, plot, feelings).
2. If something was vague or missing, gently suggest they could add it next time. Do not invent content they did not say.
3. Avoid empty praise like "You did great." Be specific and sincere, as a real teacher would.
4. Tone: warm, encouraging, suitable to read aloud to a child. **Keep it concise**: about 2–4 short paragraphs or 40–70 words (中文约 120–220 字)，便于语音朗读、减少等待。
5. **Language**: $langInstruction

Return strict JSON only:
{
  "comment": "点评正文（与孩子复述同语言）",
  "logic_score": 1-5
}
''';

    final messages = [
      {
        'role': 'system',
        'content': 'You are a professional children\'s reading teacher. Give feedback in the same language as the child\'s retelling. Be specific and kind, not generic praise.',
      },
      {
        'role': 'user',
        'content': '书籍概要 / Book summary:\n$summary\n\n孩子复述 / Child\'s retelling:\n$transcript\n\n$prompt',
      },
    ];
    if (!EnvConfig.isConfigured) {
      throw Exception('请配置后端 API_BASE_URL 与 ARK_* 或 OPENROUTER_API_KEY（见 docs）');
    }
    final content = await ApiService.chatCompletion(
      messages: messages,
      temperature: 0.55,
      maxTokens: 480,
    );

    String raw = content.trim();
    if (raw.startsWith('```')) {
      final end = raw.indexOf('```', 3);
      if (end != -1) raw = raw.substring(3, end).trim();
      if (raw.startsWith('json')) raw = raw.substring(4).trim();
    }
    final result = jsonDecode(raw) as Map<String, dynamic>;
    final comment = (result['comment'] as String?)?.trim();
    final score = (result['logic_score'] as num?)?.toInt();

    if (comment == null || comment.isEmpty) {
      throw Exception('点评内容为空');
    }
    if (score == null || score < 1 || score > 5) {
      throw Exception('评分无效');
    }

    return {'comment': comment, 'encouragement': comment, 'logic_score': score};
  }
}
