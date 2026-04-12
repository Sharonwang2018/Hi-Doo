/// One multiple-choice item from book comprehension (Detail Detective / Reading Coach).
class McqItem {
  const McqItem({
    required this.question,
    required this.options,
    required this.correctIndex,
    this.level,
    this.explanation,
  }) : assert(options.length == 3);

  final String question;
  final List<String> options;
  final int correctIndex;

  /// e.g. Literal, Inferential, Emotional
  final String? level;

  /// Short encouraging line for the correct answer (from AI).
  final String? explanation;

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        'correct_index': correctIndex,
        if (level != null && level!.isNotEmpty) 'level': level,
        if (explanation != null && explanation!.isNotEmpty) 'explanation': explanation,
      };

  static String _stripOptionPrefix(String s) {
    final t = s.trim();
    final re = RegExp(r'^([ABC])[\).\s]\s*', caseSensitive: false);
    final m = re.firstMatch(t);
    if (m != null) {
      return t.substring(m.end).trim();
    }
    return t;
  }

  static McqItem? tryParse(dynamic e) {
    if (e is! Map) return null;
    final q = (e['question'] ?? e['prompt'])?.toString().trim();
    if (q == null || q.isEmpty) return null;

    List<String> opts;
    final optsRaw = e['options'];
    if (optsRaw is List && optsRaw.length >= 3) {
      opts = optsRaw
          .take(3)
          .map((x) => _stripOptionPrefix(x.toString()))
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      final a = e['a']?.toString().trim();
      final b = e['b']?.toString().trim();
      final c = e['c']?.toString().trim();
      if (a != null &&
          b != null &&
          c != null &&
          a.isNotEmpty &&
          b.isNotEmpty &&
          c.isNotEmpty) {
        opts = [_stripOptionPrefix(a), _stripOptionPrefix(b), _stripOptionPrefix(c)];
      } else {
        return null;
      }
    }
    if (opts.length != 3) return null;

    String? letterFrom(dynamic v) {
      if (v == null) return null;
      final cleaned = v.toString().trim().toUpperCase().replaceAll(RegExp('[^ABC]'), '');
      if (cleaned.isEmpty) return null;
      return cleaned[0];
    }

    int? ci;
    final idx = e['correct_index'];
    if (idx is num) {
      ci = idx.round().clamp(0, 2);
    }
    final letter = ci == null ? (letterFrom(e['correct']) ?? letterFrom(e['answer'])) : null;
    if (ci == null && letter != null) {
      if (letter == 'A') {
        ci = 0;
      } else if (letter == 'B') {
        ci = 1;
      } else if (letter == 'C') {
        ci = 2;
      }
    }
    if (ci == null) return null;

    final explanation = (e['explanation'] as String?)?.trim();
    final level = (e['level'] as String?)?.trim();

    return McqItem(
      question: q,
      options: opts,
      correctIndex: ci,
      level: (level != null && level.isEmpty) ? null : level,
      explanation: (explanation != null && explanation.isEmpty) ? null : explanation,
    );
  }
}
