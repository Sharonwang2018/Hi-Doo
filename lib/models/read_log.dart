class ReadLog {
  const ReadLog({
    required this.id,
    required this.userId,
    required this.bookId,
    this.audioUrl,
    this.transcript,
    this.aiFeedback,
    this.language,
    this.sessionType = 'retelling',
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String bookId;
  final String? audioUrl;
  final String? transcript;
  final String? aiFeedback;
  final String? language;
  final String sessionType;
  final DateTime createdAt;

  bool get isSharedReading => sessionType == 'shared_reading';

  bool get isPhotoReadPage => sessionType == 'photo_read_page';

  factory ReadLog.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? json['_id'] as String? ?? '';
    return ReadLog(
      id: id,
      userId: json['user_id'] as String,
      bookId: json['book_id'] as String,
      audioUrl: json['audio_url'] as String?,
      transcript: json['transcript'] as String?,
      aiFeedback: json['ai_feedback'] as String?,
      language: json['language'] as String?,
      sessionType: json['session_type'] as String? ?? 'retelling',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'audio_url': audioUrl,
      'transcript': transcript,
      'ai_feedback': aiFeedback,
      'language': language,
      'session_type': sessionType,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
