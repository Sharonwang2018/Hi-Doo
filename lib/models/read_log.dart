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
    this.libraryPartnerName,
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
  final String? libraryPartnerName;
  final DateTime createdAt;

  bool get isSharedReading => sessionType == 'shared_reading';

  bool get isComprehensionQuestions => sessionType == 'comprehension_questions';

  bool get isQuizChallenge => sessionType == 'quiz_challenge';

  bool get isStorytellerChallenge => sessionType == 'storyteller_challenge';

  bool get isCombinedChallenge => sessionType == 'combined_challenge';

  /// Quick log only — no Detail Detective / Storyteller (for analytics).
  bool get isLogOnly => sessionType == 'log_only';

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
      libraryPartnerName: json['library_partner_name'] as String?,
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
      if (libraryPartnerName != null) 'library_partner_name': libraryPartnerName,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
