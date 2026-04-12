import 'dart:async';
import 'dart:convert';

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/services/api_service.dart';
import 'package:http/http.dart' as http;

/// Open Library 公网接口，国内/部分网络易阻塞；必须限时以免扫码后界面永久转圈。
const Duration _openLibraryTimeout = Duration(seconds: 15);
/// 同源 `/books` 正常应在数百 ms 内返回；过长多为网络异常，不必等满再查 Open Library。
const Duration _localBooksWait = Duration(seconds: 3);
const Duration _openLibraryProxyWait = Duration(seconds: 22);

class BookApiService {
  static final RegExp _isbnSanitizer = RegExp(r'[^0-9Xx]');

  String? normalizeIsbn(String raw) {
    final normalized = raw.replaceAll(_isbnSanitizer, '').toUpperCase();
    if (normalized.length == 10 || normalized.length == 13) {
      return normalized;
    }
    return null;
  }

  Future<BookLookupResult?> fetchByIsbn(String isbn) async {
    if (EnvConfig.isConfigured) {
      // 与本地库、Open Library 代理并行：未在库中时总耗时常明显短于「先等本地再等 OL」串行。
      final localF = ApiService.getBookByIsbn(isbn);
      final olF = ApiService.lookupBookOpenLibrary(isbn);

      Book? existing;
      try {
        existing = await localF.timeout(
          _localBooksWait,
          onTimeout: () => null,
        );
      } catch (_) {
        existing = null;
      }

      if (existing != null) {
        return BookLookupResult(
          isbn: existing.isbn,
          title: existing.title,
          author: existing.author,
          coverUrl: existing.coverUrl,
          summary: existing.summary ?? Book.defaultSummary,
        );
      }

      return await olF.timeout(
        _openLibraryProxyWait,
        onTimeout: () => throw TimeoutException(
          'Book lookup timed out. Try entering the title manually.',
          _openLibraryProxyWait,
        ),
      );
    }

    // 未配置 API_BASE_URL 时由客户端直连（仅适合能访问 openlibrary.org 的环境）
    final uri = Uri.parse(
      'https://openlibrary.org/api/books?bibkeys=ISBN:$isbn&format=json&jscmd=data',
    );

    final response = await http.get(uri).timeout(
      _openLibraryTimeout,
      onTimeout: () {
        throw TimeoutException(
          'Book lookup timed out (Open Library may be unreachable). Try manual entry.',
          _openLibraryTimeout,
        );
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Book API request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final key = 'ISBN:$isbn';
    final rawBook = decoded[key];
    if (rawBook is! Map<String, dynamic>) {
      return null;
    }

    final title = (rawBook['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      return null;
    }

    final authors =
        (rawBook['authors'] as List<dynamic>?)
            ?.whereType<Map<String, dynamic>>()
            .map((author) => (author['name'] as String?)?.trim())
            .whereType<String>()
            .where((name) => name.isNotEmpty)
            .toList() ??
        const <String>[];

    final cover = rawBook['cover'] as Map<String, dynamic>?;
    final descriptionRaw = rawBook['notes'] ?? rawBook['description'];

    String? summary;
    if (descriptionRaw is String) {
      summary = descriptionRaw.trim();
    } else if (descriptionRaw is Map<String, dynamic>) {
      summary = (descriptionRaw['value'] as String?)?.trim();
    }

    return BookLookupResult(
      isbn: isbn,
      title: title,
      author: authors.isEmpty ? 'Unknown Author' : authors.join(', '),
      coverUrl:
          (cover?['large'] ?? cover?['medium'] ?? cover?['small']) as String?,
      summary: (summary == null || summary.isEmpty)
          ? Book.defaultSummary
          : summary,
    );
  }
}
