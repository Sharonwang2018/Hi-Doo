import 'package:echo_reading/models/mcq_item.dart';
import 'package:echo_reading/services/api_service.dart';

/// API returned [quiz_unavailable] (unknown book / insufficient context for MCQ).
class QuizUnavailableException implements Exception {
  QuizUnavailableException(this.message);

  final String message;

  @override
  String toString() => message;
}

enum BookChallengeMode {
  quiz,
  storyteller,
  both,
}

extension BookChallengeModeApi on BookChallengeMode {
  String get apiValue => switch (this) {
        BookChallengeMode.quiz => 'quiz',
        BookChallengeMode.storyteller => 'storyteller',
        BookChallengeMode.both => 'both',
      };
}

/// AI plan from `/api/assessment` `book_comprehension` (Groq).
class BookComprehensionPlan {
  const BookComprehensionPlan({
    required this.coachIntro,
    required this.mcqQuestions,
    required this.retellingHints,
    this.retellingCentralPrompt,
    this.retellingStructureLabels = const ['First', 'Next', 'Then', 'Finally'],
  });

  final String coachIntro;
  final List<McqItem> mcqQuestions;
  /// Legacy / empty for new API; kept for older payloads.
  final List<String> retellingHints;
  /// Single main storytelling question (Master Storyteller).
  final String? retellingCentralPrompt;
  /// Four scaffold labels shown as icon row (default First → Finally).
  final List<String> retellingStructureLabels;

  Map<String, dynamic> quizSnapshotForLog() => {
        'mcq_questions': mcqQuestions.map((q) => q.toJson()).toList(),
        if (retellingCentralPrompt != null && retellingCentralPrompt!.trim().isNotEmpty)
          'retelling_prompt': retellingCentralPrompt!.trim(),
        'retelling_keywords': retellingStructureLabels,
        if (retellingHints.isNotEmpty) 'retelling_hints': retellingHints,
      };

  static List<McqItem> _parseMcqList(dynamic raw) {
    if (raw is! List) return [];
    return raw.map(McqItem.tryParse).whereType<McqItem>().toList();
  }

  static List<String> _parseKeywords(dynamic raw) {
    if (raw is! List) return [];
    return raw.map((e) => e == null ? '' : e.toString().trim()).where((s) => s.isNotEmpty).toList();
  }

  static BookComprehensionPlan? tryParse(Map<String, dynamic> json, BookChallengeMode mode) {
    final central = (json['retelling_prompt'] as String?)?.trim();
    var structureLabels = _parseKeywords(json['retelling_keywords']);
    if (structureLabels.length != 4) {
      structureLabels = ['First', 'Next', 'Then', 'Finally'];
    }

    var intro = (json['coach_intro'] as String?)?.trim();
    if ((intro == null || intro.isEmpty) && mode != BookChallengeMode.quiz) {
      final c = (json['retelling_prompt'] as String?)?.trim();
      if (c != null && c.isNotEmpty) intro = c;
    }

    var mcq = _parseMcqList(json['mcq_questions']);
    final hintsRaw = json['retelling_hints'];
    var hList = hintsRaw is List
        ? hintsRaw.map((e) => e == null ? '' : e.toString().trim()).where((s) => s.isNotEmpty).toList()
        : <String>[];

    String? retellingCentral = (central != null && central.isNotEmpty) ? central : null;

    switch (mode) {
      case BookChallengeMode.quiz:
        if (mcq.length < 3) return null;
        hList = [];
        retellingCentral = null;
      case BookChallengeMode.storyteller:
        mcq = [];
        if (retellingCentral == null) return null;
        hList = [];
      case BookChallengeMode.both:
        if (mcq.length < 3 || retellingCentral == null) return null;
        hList = [];
    }

    if (intro == null || intro.isEmpty) {
      if (mode == BookChallengeMode.quiz) {
        intro = '';
      } else {
        return null;
      }
    }

    return BookComprehensionPlan(
      coachIntro: intro,
      mcqQuestions: mcq,
      retellingHints: hList,
      retellingCentralPrompt: retellingCentral,
      retellingStructureLabels: structureLabels,
    );
  }
}

class BookComprehensionService {
  BookComprehensionService._();

  static Future<BookComprehensionPlan> fetch({
    required String title,
    required String author,
    String? summary,
    required BookChallengeMode mode,
  }) async {
    final json = await ApiService.postAssessment(
      kind: 'book_comprehension',
      summary: summary,
      bookTitle: title,
      bookAuthor: author,
      challengeMode: mode.apiValue,
      temperature: 0.55,
    );
    if (json['quiz_unavailable'] == true) {
      final raw = (json['fallback_message'] as String?)?.trim();
      throw QuizUnavailableException(
        (raw != null && raw.isNotEmpty)
            ? raw
            : "I'm still learning about this story, let's try a Retell challenge instead!",
      );
    }
    final plan = BookComprehensionPlan.tryParse(json, mode);
    if (plan == null) {
      throw Exception('Could not load challenge plan. Try again.');
    }
    return plan;
  }
}
