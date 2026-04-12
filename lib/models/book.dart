class Book {
  const Book({
    required this.id,
    required this.isbn,
    required this.title,
    required this.author,
    this.coverUrl,
    this.summary,
  });

  final String id;
  final String isbn;
  final String title;
  final String author;
  final String? coverUrl;
  final String? summary;

  static const String defaultSummary = 'No summary available.';

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      id: json['id'] as String,
      isbn: json['isbn'] as String,
      title: json['title'] as String,
      author: json['author'] as String,
      coverUrl: json['cover_url'] as String?,
      summary: json['summary'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isbn': isbn,
      'title': title,
      'author': author,
      'cover_url': coverUrl,
      'summary': summary,
    };
  }
}

class BookLookupResult {
  const BookLookupResult({
    required this.isbn,
    required this.title,
    required this.author,
    this.coverUrl,
    this.summary,
  });

  final String isbn;
  final String title;
  final String author;
  final String? coverUrl;
  final String? summary;
}

extension BookAsLookup on Book {
  BookLookupResult asLookupResult() => BookLookupResult(
        isbn: isbn,
        title: title,
        author: author,
        coverUrl: coverUrl,
        summary: summary,
      );
}
