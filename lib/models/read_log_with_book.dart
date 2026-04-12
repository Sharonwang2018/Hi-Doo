import 'dart:convert';

import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/models/read_log.dart';

/// 用于“我的阅读记录列表”：同一条阅读记录附带对应书籍信息（由后端 join 返回）。
class ReadLogWithBook {
  const ReadLogWithBook({required this.readLog, required this.book});

  final ReadLog readLog;
  final Book book;

  factory ReadLogWithBook.fromJson(Map<String, dynamic> json) {
    final readLog = ReadLog.fromJson(json);
    final rawBook = json['book'];
    Map<String, dynamic> bookJson;
    if (rawBook == null) {
      bookJson = const {};
    } else if (rawBook is Map<String, dynamic>) {
      bookJson = rawBook;
    } else if (rawBook is String && rawBook.isNotEmpty) {
      // PG 可能把 json 字段作为字符串返回，这里兜底解析一次。
      try {
        bookJson = (rawBook.trim().isEmpty
            ? <String, dynamic>{}
            : (jsonDecode(rawBook) as Map<String, dynamic>));
      } catch (_) {
        bookJson = const {};
      }
    } else {
      bookJson = const {};
    }

    // 兼容：如果后端未返回 book，给出占位，保证 UI 可工作。
    final book = bookJson.isNotEmpty
        ? Book.fromJson(bookJson)
        : Book(
            id: readLog.bookId,
            isbn: '',
            title: 'Unknown title',
            author: 'Unknown Author',
            coverUrl: null,
            summary: null,
          );
    return ReadLogWithBook(readLog: readLog, book: book);
  }
}
