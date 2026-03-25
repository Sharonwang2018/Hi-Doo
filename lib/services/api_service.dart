import 'dart:convert';

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/api_upload.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static bool _isUnauthorized(http.Response res) => res.statusCode == 401;

  static void _checkConfigured() {
    if (!EnvConfig.isConfigured) {
      throw Exception(
        'API 未配置。请设置 API_BASE_URL（如 http://localhost:3000）',
      );
    }
  }

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (withAuth) {
      final token = await ApiAuthService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// 根据 ISBN 查询书籍（可选，用于 API 查重）
  static Future<Book?> getBookByIsbn(String isbn) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/books?isbn=$Uri.encodeComponent(isbn)');
    final res = await http.get(uri, headers: await _headers(withAuth: false));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw Exception('查询失败: ${res.body}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return Book(
      id: json['id'] as String,
      isbn: json['isbn'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      coverUrl: json['cover_url'] as String?,
      summary: json['summary'] as String?,
    );
  }

  /// 由服务端请求 Open Library，避免手机浏览器直连外网出现 `ClientException: Load failed`。
  static Future<BookLookupResult?> lookupBookOpenLibrary(String isbn) async {
    _checkConfigured();
    final uri = Uri.parse(
      '${EnvConfig.apiBaseUrl}/api/book-lookup?isbn=${Uri.encodeComponent(isbn)}',
    );
    final res = await http
        .get(uri, headers: await _headers(withAuth: false))
        .timeout(const Duration(seconds: 22));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) {
      var msg = res.body;
      try {
        final j = jsonDecode(res.body) as Map<String, dynamic>?;
        final m = j?['message'] as String?;
        if (m != null && m.isNotEmpty) msg = m;
      } catch (_) {}
      throw Exception(msg);
    }
    final j = jsonDecode(res.body) as Map<String, dynamic>;
    final sum = j['summary'] as String?;
    return BookLookupResult(
      isbn: j['isbn'] as String,
      title: j['title'] as String,
      author: j['author'] as String,
      coverUrl: j['cover_url'] as String?,
      summary: (sum != null && sum.isNotEmpty) ? sum : Book.defaultSummary,
    );
  }

  /// 创建或更新书籍
  static Future<Book> upsertBook(BookLookupResult lookup) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/books');
    final res = await http.post(
      uri,
      headers: await _headers(),
      body: jsonEncode({
        'isbn': lookup.isbn,
        'title': lookup.title,
        'author': lookup.author,
        'cover_url': lookup.coverUrl,
        'summary': lookup.summary ?? Book.defaultSummary,
      }),
    );
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('保存失败: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return Book(
      id: json['id'] as String,
      isbn: json['isbn'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      coverUrl: json['cover_url'] as String?,
      summary: json['summary'] as String?,
    );
  }

  /// 创建阅读记录，返回新建记录的 id
  static Future<String> createReadLog({
    required String bookId,
    String? audioUrl,
    String? transcript,
    String? aiFeedback,
    String? language,
    String sessionType = 'retelling',
  }) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/read-logs');
    final body = jsonEncode({
      'book_id': bookId,
      'audio_url': audioUrl,
      'transcript': transcript,
      'ai_feedback': aiFeedback,
      'language': language,
      'session_type': sessionType,
    });

    Future<http.Response> post() async => http.post(
          uri,
          headers: await _headers(),
          body: body,
        );

    var res = await post();
    if (_isUnauthorized(res)) {
      await ApiAuthService.recoverSessionAfterUnauthorized();
      res = await post();
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('保存失败: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['id'] as String;
  }

  /// 更新阅读记录的 AI 点评
  static Future<void> updateReadLogAiFeedback(String logId, String aiFeedback) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/read-logs/$logId');
    final payload = jsonEncode({'ai_feedback': aiFeedback});

    Future<http.Response> patch() async => http.patch(
          uri,
          headers: await _headers(),
          body: payload,
        );

    var res = await patch();
    if (_isUnauthorized(res)) {
      await ApiAuthService.recoverSessionAfterUnauthorized();
      res = await patch();
    }
    if (res.statusCode != 200) {
      throw Exception('更新失败: ${res.body}');
    }
  }

  /// 上传音频文件，返回 URL（移动端/桌面端）
  static Future<String> uploadAudio(Object fileOrPath, {String contentType = 'audio/webm'}) async {
    return uploadAudioFile(fileOrPath, contentType: contentType);
  }

  /// 通过后端代理调用 OpenRouter Chat（点评等）
  static Future<String> chatCompletion({
    required List<Map<String, String>> messages,
    double temperature = 0.6,
    /// 传给后端 /api/chat，控制 LLM 输出上限；点评等短回复可设 400–512 以略加快收束
    int? maxTokens,
  }) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/api/chat');
    final body = <String, dynamic>{
      'messages': messages,
      'temperature': temperature,
      if (maxTokens case final int v) 'max_tokens': v,
    };
    final res = await http.post(
      uri,
      headers: await _headers(withAuth: false),
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 35));
    if (res.statusCode != 200) throw Exception('Chat 失败: ${res.body}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['content'] as String? ?? '').trim();
  }

  /// 通过后端 OpenRouter 视觉模型识别图片文字（拍照读页）
  static Future<String> visionFromImage(String imageBase64) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/api/vision');
    final res = await http.post(
      uri,
      headers: await _headers(withAuth: false),
      body: jsonEncode({'image': imageBase64}),
    ).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('视觉识别失败: ${res.body}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['text'] as String? ?? '').trim();
  }

  /// 通过后端 OpenAI Whisper 转写音频
  static Future<String> transcribeAudio(List<int> audioBytes, {String contentType = 'audio/webm'}) async {
    _checkConfigured();
    final uri = Uri.parse('${EnvConfig.apiBaseUrl}/api/transcribe');
    final base64 = base64Encode(audioBytes);
    final res = await http.post(
      uri,
      headers: await _headers(withAuth: false),
      body: jsonEncode({'audio_base64': base64, 'content_type': contentType}),
    ).timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) throw Exception('转写失败: ${res.body}');
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['text'] as String? ?? '').trim();
  }
}
