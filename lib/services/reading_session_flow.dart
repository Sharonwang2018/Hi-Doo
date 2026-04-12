import 'dart:convert';

import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/models/reading_challenge_kind.dart';
import 'package:echo_reading/screens/comprehension_questions_screen.dart';
import 'package:echo_reading/screens/login_screen.dart';
import 'package:echo_reading/screens/recording_screen.dart';
import 'package:echo_reading/screens/retelling_complete_screen.dart';
import 'package:echo_reading/services/api_auth_service.dart';
import 'package:echo_reading/services/api_service.dart';
import 'package:echo_reading/services/book_comprehension_service.dart';
import 'package:echo_reading/services/books_service.dart';
import 'package:echo_reading/services/post_save_rewards.dart';
import 'package:echo_reading/widgets/streak_celebration_overlay.dart';
import 'package:flutter/material.dart';

/// Sign-in, save book, load Groq plan, and push the right screen.
class ReadingSessionFlow {
  ReadingSessionFlow._();

  static final _books = BooksService();

  static const _kAiCoachMissBody =
      'Oops! Our AI Coach is still learning about this brand new book. Would you like to just log it for now and earn your reading point?';

  static Future<bool> ensureSignedIn(BuildContext outerContext) async {
    if (!EnvConfig.isConfigured) return true;
    if (await ApiAuthService.isRealUser) return true;
    if (!outerContext.mounted) return false;
    final ok = await showDialog<bool>(
      context: outerContext,
      builder: (c) => AlertDialog(
        title: const Text('Account required'),
        content: const Text(
          'Log in with Google or email to save your reading journey and Story Challenge progress. '
          'You can look around the app first, but saving needs an account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (ok == true && outerContext.mounted) {
      await Navigator.push<bool>(
        outerContext,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
    return false;
  }

  static BookChallengeMode _mode(ReadingChallengeKind k) => switch (k) {
        ReadingChallengeKind.quiz => BookChallengeMode.quiz,
        ReadingChallengeKind.storyteller => BookChallengeMode.storyteller,
        ReadingChallengeKind.both => BookChallengeMode.both,
      };

  static const _retellFallbackHints = <String>[
    'First, say who the story is mostly about.',
    'Next, tell one big thing that happens.',
    'Then, share something you wondered or noticed.',
    'Finally, say how the book made you feel.',
  ];

  static Future<void> _pushRetellFallback(BuildContext context, Book book) async {
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecordingScreen(
          bookId: book.id,
          summary: book.summary ?? Book.defaultSummary,
          bookTitle: book.title,
          bookCoverUrl: book.coverUrl,
          language: 'en',
          comprehensionCentralPrompt:
              'Can you tell me what happened in the story from beginning to end?',
          comprehensionStructureLabels: const ['First', 'Next', 'Then', 'Finally'],
          comprehensionRetellingHints: _retellFallbackHints,
          sessionTypeForLog: 'storyteller_challenge',
          showCoachIntroCard: false,
        ),
      ),
    );
  }

  /// Persists a log-only row: `session_type` = log_only; JSON includes `type` for analytics.
  static Future<void> _persistLogOnly(Book book, String logSource) async {
    final transcript = logSource == 'picker_button'
        ? 'Quick reading log (no Story Challenge).'
        : 'Quick log — AI Coach did not have a quiz for this book yet.';
    await ApiService.createReadLog(
      bookId: book.id,
      transcript: transcript,
      aiFeedback: jsonEncode({
        'type': 'log_only',
        'challenge_type': 'log_only',
        'source': logSource,
      }),
      sessionType: 'log_only',
      language: 'en',
    );
  }

  /// From challenge sheet — saves book if needed, no Groq.
  static Future<void> startLogOnly(
    BuildContext context,
    BookLookupResult lookup, {
    Book? savedBook,
  }) async {
    if (!await ensureSignedIn(context) || !context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      final book = savedBook ?? await _books.upsertBook(lookup);
      await _persistLogOnly(book, 'picker_button');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;
      final rewards = await PostSaveRewards.resolve(entryIsLogOnly: true);
      if (!context.mounted) return;
      await maybeShowStreakCelebration(context, rewards.streak);
      if (!context.mounted) return;
      final stars = rewards.starsEarned;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RetellingCompleteScreen(
            bookTitle: book.title,
            bookCoverUrl: book.coverUrl,
            quickLogOnly: true,
            showDonationTip: false,
            starsEarned: stars > 0 ? stars : null,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save log: $e')),
        );
      }
    }
  }

  /// Book already saved — e.g. after AI miss dialog.
  static Future<void> startLogOnlyFromBook(
    BuildContext context,
    Book book, {
    required String logSource,
  }) async {
    if (!await ensureSignedIn(context) || !context.mounted) return;
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    try {
      await _persistLogOnly(book, logSource);
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;
      final rewards = await PostSaveRewards.resolve(entryIsLogOnly: true);
      if (!context.mounted) return;
      await maybeShowStreakCelebration(context, rewards.streak);
      if (!context.mounted) return;
      final stars = rewards.starsEarned;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RetellingCompleteScreen(
            bookTitle: book.title,
            bookCoverUrl: book.coverUrl,
            quickLogOnly: true,
            showDonationTip: false,
            starsEarned: stars > 0 ? stars : null,
          ),
        ),
      );
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save log: $e')),
        );
      }
    }
  }

  static Future<void> _showAiCoachMissDialog(BuildContext context, Book book) async {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (c) => AlertDialog(
        title: const Text('Story Challenge'),
        content: const Text(_kAiCoachMissBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: const Text('Not now'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(c);
              if (context.mounted) {
                _pushRetellFallback(context, book);
              }
            },
            child: const Text('Try Retell'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(c);
              if (!context.mounted) return;
              await startLogOnlyFromBook(context, book, logSource: 'ai_fallback');
            },
            child: const Text('Just log it'),
          ),
        ],
      ),
    );
  }

  /// [savedBook] if already upserted; otherwise [lookup] is saved first.
  static Future<void> startChallenge(
    BuildContext context,
    BookLookupResult lookup, {
    Book? savedBook,
    required ReadingChallengeKind kind,
  }) async {
    if (!await ensureSignedIn(context) || !context.mounted) return;
    if (!context.mounted) return;
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (_) => const PopScope(
        canPop: false,
        child: Center(child: CircularProgressIndicator()),
      ),
    );
    Book? book = savedBook;
    try {
      final sessionBook = book ?? await _books.upsertBook(lookup);
      book = sessionBook;
      final plan = await BookComprehensionService.fetch(
        title: sessionBook.title,
        author: sessionBook.author,
        summary: sessionBook.summary,
        isbn: sessionBook.isbn,
        mode: _mode(kind),
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;
      switch (kind) {
        case ReadingChallengeKind.quiz:
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ComprehensionQuestionsScreen(
                book: sessionBook,
                plan: plan,
                continueToRetell: false,
              ),
            ),
          );
        case ReadingChallengeKind.storyteller:
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => RecordingScreen(
                bookId: sessionBook.id,
                summary: sessionBook.summary ?? Book.defaultSummary,
                bookTitle: sessionBook.title,
                bookCoverUrl: sessionBook.coverUrl,
                language: 'en',
                comprehensionCoachIntro: plan.coachIntro,
                comprehensionCentralPrompt: plan.retellingCentralPrompt,
                comprehensionStructureLabels: plan.retellingStructureLabels,
                comprehensionRetellingHints: plan.retellingHints,
                sessionTypeForLog: 'storyteller_challenge',
              ),
            ),
          );
        case ReadingChallengeKind.both:
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ComprehensionQuestionsScreen(
                book: sessionBook,
                plan: plan,
                continueToRetell: true,
              ),
            ),
          );
      }
    } on QuizUnavailableException catch (_) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;
      final b = book;
      if (b != null &&
          (kind == ReadingChallengeKind.quiz || kind == ReadingChallengeKind.both)) {
        await _showAiCoachMissDialog(context, b);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not load quiz for this book.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (!context.mounted) return;
      final b = book;
      if (b != null) {
        await _showAiCoachMissDialog(context, b);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not start challenge: $e')),
        );
      }
    }
  }
}
