/// Child-facing reading challenge (maps to API `challengeMode`).
enum ReadingChallengeKind {
  quiz,
  storyteller,
  both,
}

extension ReadingChallengeKindApi on ReadingChallengeKind {
  String get apiValue => switch (this) {
        ReadingChallengeKind.quiz => 'quiz',
        ReadingChallengeKind.storyteller => 'storyteller',
        ReadingChallengeKind.both => 'both',
      };
}
