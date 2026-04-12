import 'dart:convert';

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/models/read_log_with_book.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/api_client_id_service.dart';
import 'package:echo_reading/services/api_upload.dart';
import 'package:http/http.dart' as http;

class ApiService {
  ApiService._();

  static bool _isUnauthorized(http.Response res) => res.statusCode == 401;

  static void _checkConfigured() {
    if (!EnvConfig.isConfigured) {
      throw Exception(
        'API is not configured. Set API_BASE_URL (e.g. http://localhost:3000).',
      );
    }
  }

  static Future<void> _attachClientId(Map<String, String> headers) async {
    headers['X-Client-Id'] = await ApiClientIdService.getOrCreate();
  }

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{'Content-Type': 'application/json'};
    await _attachClientId(headers);
    if (withAuth) {
      final token = await ApiAuthService.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  /// 计费类接口：Client-Id + 可选 Bearer（含访客）。
  static Future<Map<String, String>> quotaHttpHeaders() async =>
      _headers(withAuth: true);

  static String responseErrorMessage(http.Response res) {
    try {
      final j = jsonDecode(res.body);
      if (j is Map && j['message'] is String) {
        final m = (j['message'] as String).trim();
        if (m.isNotEmpty) return m;
      }
    } catch (_) {}
    final b = res.body;
    return b.length > 220 ? '${b.substring(0, 220)}…' : b;
  }

  /// 根据 ISBN 查询书籍（可选，用于 API 查重）
  static Future<Book?> getBookByIsbn(String isbn) async {
    _checkConfigured();
    final uri = Uri.parse(EnvConfig.apiUrl('/books')).replace(
      queryParameters: {'isbn': isbn},
    );
    final res = await http.get(uri, headers: await _headers(withAuth: false));
    if (res.statusCode == 404) return null;
    if (res.statusCode != 200) throw Exception('Lookup failed: ${res.body}');
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
    final uri = Uri.parse(EnvConfig.apiUrl('/api/book-lookup')).replace(
      queryParameters: {'isbn': isbn},
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
    final uri = Uri.parse(EnvConfig.apiUrl('/books'));
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
      throw Exception('Save failed: ${res.body}');
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
    final uri = Uri.parse(EnvConfig.apiUrl('/read-logs'));
    final body = jsonEncode({
      'book_id': bookId,
      'audio_url': audioUrl,
      'transcript': transcript,
      'ai_feedback': aiFeedback,
      'language': language,
      'session_type': sessionType,
    });

    Future<http.Response> post() async =>
        http.post(uri, headers: await _headers(), body: body);

    var res = await post();
    if (_isUnauthorized(res)) {
      if (ApiAuthService.isUserSessionStale401(res)) {
        final m = responseErrorMessage(res);
        throw Exception(
          m.isNotEmpty
              ? m
              : 'Could not save: server rejected this user id (check read_logs FK → auth.users or profiles).',
        );
      }
      await ApiAuthService.recoverSessionAfterUnauthorized();
      res = await post();
    }
    if (res.statusCode != 200 && res.statusCode != 201) {
      if (res.statusCode == 401) {
        final detail = responseErrorMessage(res);
        throw Exception(
          detail.isNotEmpty
              ? 'Could not save your reading. $detail'
              : 'Please sign in again to save your reading.',
        );
      }
      if (res.statusCode == 403) {
        final msg = ApiService.responseErrorMessage(res);
        throw Exception(
          msg.isNotEmpty ? msg : 'Sign in with email or Google to save your reading journey.',
        );
      }
      throw Exception('Save failed: ${res.body}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return json['id'] as String;
  }

  /// 更新阅读记录的 AI 点评
  static Future<void> updateReadLogAiFeedback(
    String logId,
    String aiFeedback,
  ) async {
    _checkConfigured();
    final uri = Uri.parse(EnvConfig.apiUrl('/read-logs/$logId'));
    final payload = jsonEncode({'ai_feedback': aiFeedback});

    Future<http.Response> patch() async =>
        http.patch(uri, headers: await _headers(), body: payload);

    var res = await patch();
    if (_isUnauthorized(res)) {
      if (ApiAuthService.isUserSessionStale401(res)) {
        final m = responseErrorMessage(res);
        throw Exception(
          m.isNotEmpty ? m : 'Could not update log: account not linked in database.',
        );
      }
      await ApiAuthService.recoverSessionAfterUnauthorized();
      res = await patch();
    }
    if (res.statusCode != 200) {
      throw Exception('Update failed: ${res.body}');
    }
  }

  /// 上传音频文件，返回 URL（移动端/桌面端）
  static Future<String> uploadAudio(
    Object fileOrPath, {
    String contentType = 'audio/webm',
  }) async {
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
    final uri = Uri.parse(EnvConfig.apiUrl('/api/chat'));
    final body = <String, dynamic>{
      'messages': messages,
      'temperature': temperature,
      if (maxTokens case final int v) 'max_tokens': v,
    };
    final res = await http
        .post(
          uri,
          headers: await _headers(withAuth: true),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 35));
    if (res.statusCode != 200) {
      throw Exception('Chat failed: ${ApiService.responseErrorMessage(res)}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['content'] as String? ?? '').trim();
  }

  /// Groq-backed retelling listener feedback (`/api/assessment`).
  static Future<Map<String, dynamic>> postAssessment({
    required String kind,
    String? transcript,
    String? summary,
    String? bookTitle,
    String? bookAuthor,
    String? challengeMode,
    double temperature = 0.55,
  }) async {
    _checkConfigured();
    final uri = Uri.parse(EnvConfig.apiUrl('/api/assessment'));
    final body = <String, dynamic>{
      'kind': kind,
      'temperature': temperature,
      if (transcript != null && transcript.isNotEmpty) 'transcript': transcript,
      if (summary != null) 'summary': summary,
      if (bookTitle != null && bookTitle.trim().isNotEmpty) 'bookTitle': bookTitle.trim(),
      if (bookAuthor != null && bookAuthor.trim().isNotEmpty) 'bookAuthor': bookAuthor.trim(),
      if (challengeMode != null && challengeMode.trim().isNotEmpty) 'challengeMode': challengeMode.trim(),
    };
    final res = await http
        .post(
          uri,
          headers: await _headers(withAuth: true),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 45));
    if (res.statusCode != 200) {
      throw Exception('Assessment failed: ${ApiService.responseErrorMessage(res)}');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  /// 通过后端 OpenAI Whisper 转写音频
  static Future<String> transcribeAudio(
    List<int> audioBytes, {
    String contentType = 'audio/webm',
  }) async {
    _checkConfigured();
    final uri = Uri.parse(EnvConfig.apiUrl('/api/transcribe'));
    final base64 = base64Encode(audioBytes);
    final res = await http
        .post(
          uri,
          headers: await _headers(withAuth: true),
          body: jsonEncode({
            'audio_base64': base64,
            'content_type': contentType,
          }),
        )
        .timeout(const Duration(seconds: 60));
    if (res.statusCode != 200) {
      throw Exception('Transcription failed: ${ApiService.responseErrorMessage(res)}');
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (json['text'] as String? ?? '').trim();
  }

  /// 获取“我的阅读记录列表”：每条记录附带书籍信息（后端 join）。
  static Future<List<ReadLogWithBook>> fetchReadLogs() async {
    _checkConfigured();
    final uri = Uri.parse(EnvConfig.apiUrl('/read-logs'));

    Future<http.Response> getLogs() async =>
        http.get(uri, headers: await _headers());

    var res = await getLogs();
    if (_isUnauthorized(res)) {
      if (ApiAuthService.isUserSessionStale401(res)) {
        final m = responseErrorMessage(res);
        throw Exception(
          m.isNotEmpty ? m : 'Could not load logs: account not linked in database.',
        );
      }
      await ApiAuthService.recoverSessionAfterUnauthorized();
      res = await getLogs();
    }
    if (res.statusCode != 200) {
      throw Exception('Could not load reading log: ${res.body}');
    }

    final jsonList = jsonDecode(res.body) as List<dynamic>;
    return jsonList
        .map((e) => ReadLogWithBook.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Report bad quiz / MCQ content (`POST /api/quiz-reports`).
  static Future<void> reportQuizContentIssue({
    required String bookId,
    required int questionId,
    bool badContent = true,
  }) async {
    _checkConfigured();
    final uri = Uri.parse(EnvConfig.apiUrl('/api/quiz-reports'));
    final res = await http
        .post(
          uri,
          headers: await _headers(withAuth: true),
          body: jsonEncode({
            'book_id': bookId,
            'question_id': questionId,
            'bad_content': badContent,
          }),
        )
        .timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) {
      throw Exception(
        'Report failed: ${ApiService.responseErrorMessage(res)}',
      );
    }
  }
}
