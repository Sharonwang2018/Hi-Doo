import 'dart:convert';
import 'dart:math' as math;

import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/models/mcq_item.dart';
import 'package:echo_reading/screens/recording_screen.dart';
import 'package:echo_reading/screens/retelling_complete_screen.dart';
import 'package:echo_reading/services/api_service.dart';
import 'package:echo_reading/services/book_comprehension_service.dart';
import 'package:echo_reading/services/post_save_rewards.dart';
import 'package:echo_reading/widgets/streak_celebration_overlay.dart';
import 'package:echo_reading/widgets/responsive_layout.dart';
import 'package:echo_reading/widgets/story_structure_scaffold_row.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Detail Detective (MCQ) and/or storyteller preview before retelling (Both mode).
class ComprehensionQuestionsScreen extends StatefulWidget {
  const ComprehensionQuestionsScreen({
    super.key,
    required this.book,
    required this.plan,
    required this.continueToRetell,
  });

  final Book book;
  final BookComprehensionPlan plan;
  final bool continueToRetell;

  @override
  State<ComprehensionQuestionsScreen> createState() => _ComprehensionQuestionsScreenState();
}

class _ComprehensionQuestionsScreenState extends State<ComprehensionQuestionsScreen>
    with TickerProviderStateMixin {
  /// 0, 1, or 2 — which MCQ is shown.
  int currentQuestionIndex = 0;
  bool _answered = false;
  bool _wasCorrect = false;
  int? _pickedIndex;
  double _shakeDx = 0;
  bool _mcqPhaseComplete = false;
  int _correctAnswers = 0;

  /// One report per question index (1-based slot in this session).
  final Set<int> _reportedQuestionSlots = {};

  late final AnimationController _feedbackRevealController;

  @override
  void initState() {
    super.initState();
    _feedbackRevealController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
  }

  @override
  void dispose() {
    _feedbackRevealController.dispose();
    super.dispose();
  }

  String get _appBarTitle {
    if (widget.continueToRetell) return 'Detective, then Storyteller';
    return '🧩 The Detail Detective';
  }

  List<McqItem> get _mcq => widget.plan.mcqQuestions;

  String _primaryActionLabel() {
    final last = currentQuestionIndex >= _mcq.length - 1;
    if (!last) return 'Next';
    if (widget.continueToRetell) return 'Continue';
    return 'Claim Your Badge';
  }

  Future<void> _runShake() async {
    const pattern = <double>[8, -8, 7, -7, 5, -5, 3, -3, 0];
    for (final dx in pattern) {
      if (!mounted) return;
      setState(() => _shakeDx = dx);
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
  }

  Future<void> _onReportQuizIssue() async {
    final slot = currentQuestionIndex + 1;
    if (_reportedQuestionSlots.contains(slot)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You already reported this question. Thank you!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    try {
      await ApiService.reportQuizContentIssue(
        bookId: widget.book.id,
        questionId: slot,
        badContent: true,
      );
      if (!mounted) return;
      setState(() => _reportedQuestionSlots.add(slot));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            "Thank you! We're teaching the AI to be better. 🌟",
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not send report. ${e.toString()}'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onPickOption(int index) {
    if (_answered) return;
    final item = _mcq[currentQuestionIndex];
    final ok = index == item.correctIndex;
    setState(() {
      _answered = true;
      _wasCorrect = ok;
      _pickedIndex = index;
      if (ok) _correctAnswers++;
    });
    if (!ok) _runShake();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _feedbackRevealController.forward(from: 0);
    });
  }

  Future<void> _showPerfectScoreCelebration() async {
    if (!mounted) return;
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: false,
      barrierLabel: 'Perfect score',
      transitionDuration: const Duration(milliseconds: 560),
      pageBuilder: (ctx, animation, secondaryAnimation) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 340),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFFFFF9E6),
                      Color.lerp(Colors.amber.shade50, Colors.white, 0.35)!,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.amber.withValues(alpha: 0.38),
                      blurRadius: 28,
                      spreadRadius: 0,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      '🌟✨🌟',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 38, height: 1.1),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Perfect Score!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: const Color(0xFF5D4037),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'You got all 3 right — amazing!',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.montserrat(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        color: Colors.brown.shade700,
                      ),
                    ),
                    const SizedBox(height: 22),
                    FilledButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFF8C42),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                        shape: const StadiumBorder(),
                        elevation: 2,
                      ),
                      child: Text(
                        widget.continueToRetell ? 'Awesome!' : 'Claim Your Badge!',
                        style: GoogleFonts.montserrat(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.elasticOut);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
    );
  }

  Future<void> _onMcqNext() async {
    if (!_answered) return;
    final isLast = currentQuestionIndex >= _mcq.length - 1;
    if (!isLast) {
      _feedbackRevealController.reset();
      setState(() {
        currentQuestionIndex++;
        _answered = false;
        _pickedIndex = null;
        _wasCorrect = false;
        _shakeDx = 0;
      });
      return;
    }
    if (_correctAnswers >= 3 && mounted) {
      await _showPerfectScoreCelebration();
    }
    if (!mounted) return;
    if (widget.continueToRetell) {
      setState(() {
        _mcqPhaseComplete = true;
        _shakeDx = 0;
      });
    } else {
      await _saveQuizFinish();
    }
  }

  Future<void> _saveQuizFinish() async {
    final context = this.context;
    final payload = jsonEncode({
      'challenge_type': 'quiz_challenge',
      'claimed_reading_badge': true,
      'mcq_questions': widget.plan.mcqQuestions.map((q) => q.toJson()).toList(),
    });
    try {
      await ApiService.createReadLog(
        bookId: widget.book.id,
        transcript: 'Finished Detail Detective (multiple choice).',
        aiFeedback: payload,
        sessionType: 'quiz_challenge',
        language: 'en',
      );
      if (!context.mounted) return;
      final rewards = await PostSaveRewards.resolve(entryIsLogOnly: false);
      if (!context.mounted) return;
      await maybeShowStreakCelebration(context, rewards.streak);
      if (!context.mounted) return;
      final stars = rewards.starsEarned;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => RetellingCompleteScreen(
            bookTitle: widget.book.title,
            bookCoverUrl: widget.book.coverUrl,
            comment: null,
            showDonationTip: false,
            starsEarned: stars > 0 ? stars : null,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save log: $e')),
      );
    }
  }

  void _goToRetell() {
    final central = widget.plan.retellingCentralPrompt?.trim();
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => RecordingScreen(
          bookId: widget.book.id,
          summary: widget.book.summary ?? Book.defaultSummary,
          bookTitle: widget.book.title,
          bookCoverUrl: widget.book.coverUrl,
          language: 'en',
          comprehensionCoachIntro: null,
          comprehensionCentralPrompt: (central != null && central.isNotEmpty) ? central : null,
          comprehensionStructureLabels: widget.plan.retellingStructureLabels,
          comprehensionRetellingHints: widget.plan.retellingHints,
          sessionTypeForLog: 'combined_challenge',
          combinedQuizSnapshot: widget.plan.quizSnapshotForLog(),
        ),
      ),
    );
  }

  static const _labels = ['A', 'B', 'C'];

  static const Color _progressTrackColor = Color(0xFFFFEDE0);
  static const Color _progressFillTop = Color(0xFFFFB366);
  static const Color _progressFillMain = Color(0xFFFF8C42);
  static const Color _progressFillBottom = Color(0xFFE86F2A);

  static const Color _optGreenBorder = Color(0xFF2E7D32);
  static const Color _optGreenFill = Color(0xFFE8F5E9);
  static const Color _optRedBorder = Color(0xFFE53935);
  static const Color _optRedFill = Color(0xFFFFEBEE);

  static const Color _creamFeedbackBg = Color(0xFFFFFBF7);
  static const Color _nextOrange = Color(0xFFFF8C42);

  /// Literal / Inferential / Emotional chips — distinct, child-friendly hues.
  ({Color background, Color foreground}) _levelChipColors(
    BuildContext context,
    String? level,
  ) {
    final l = (level ?? '').toLowerCase();
    if (l.contains('inferential')) {
      return (
        background: const Color(0xFFF3E5F5),
        foreground: const Color(0xFF6A1B9A),
      );
    }
    if (l.contains('emotional')) {
      return (
        background: const Color(0xFFFFE0E8),
        foreground: const Color(0xFFC2185B),
      );
    }
    if (l.contains('literal')) {
      return (
        background: const Color(0xFFE3F2FD),
        foreground: const Color(0xFF1565C0),
      );
    }
    final cs = Theme.of(context).colorScheme;
    return (
      background: cs.secondaryContainer.withValues(alpha: 0.85),
      foreground: cs.onSecondaryContainer,
    );
  }

  BoxDecoration _optionDecoration(BuildContext context, McqItem item, int i) {
    final cs = Theme.of(context).colorScheme;
    if (!_answered) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outline.withValues(alpha: 0.55),
          width: 1.5,
        ),
        color: cs.surfaceContainerHighest.withValues(alpha: 0.28),
      );
    }
    final isCorrect = i == item.correctIndex;
    final isPicked = i == _pickedIndex;
    if (isCorrect) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _optGreenBorder, width: 2.5),
        color: _optGreenFill,
      );
    }
    if (isPicked) {
      return BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _optRedBorder, width: 2),
        color: _optRedFill,
      );
    }
    return BoxDecoration(
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: cs.outline.withValues(alpha: 0.22), width: 1),
      color: cs.surfaceContainerHighest.withValues(alpha: 0.12),
    );
  }

  Widget _buildMcqPhase(BuildContext context) {
    final total = _mcq.length;
    final item = _mcq[currentQuestionIndex];
    final levelChip = (item.level != null && item.level!.isNotEmpty)
        ? _levelChipColors(context, item.level)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            '${currentQuestionIndex + 1} / $total',
            style: GoogleFonts.montserrat(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: const Color(0xFF5D4037),
              height: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 6),
        _GamifiedQuizProgressBar(
          currentQuestionIndex: currentQuestionIndex,
          totalQuestions: total,
          justAnswered: _answered,
          trackColor: _progressTrackColor,
          fillTop: _progressFillTop,
          fillMain: _progressFillMain,
          fillBottom: _progressFillBottom,
        ),
        const SizedBox(height: 20),
        Text(
          widget.book.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.book.author,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 12),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.09),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 40, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (levelChip != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: levelChip.background,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Text(
                                item.level!,
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                      fontWeight: FontWeight.w800,
                                      color: levelChip.foreground,
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Text(
                      item.question,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            height: 1.32,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              right: 2,
              bottom: 4,
              child: Tooltip(
                message: 'Report an issue',
                child: IconButton(
                  onPressed: _reportedQuestionSlots.contains(currentQuestionIndex + 1)
                      ? null
                      : _onReportQuizIssue,
                  icon: Icon(
                    Icons.flag_outlined,
                    size: 18,
                    color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(
                          alpha: _reportedQuestionSlots.contains(currentQuestionIndex + 1)
                              ? 0.35
                              : 0.55,
                        ),
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.only(bottom: i < 2 ? 8 : 0),
            child: Transform.translate(
              offset: Offset(
                _answered && _pickedIndex == i && !_wasCorrect ? _shakeDx : 0,
                0,
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _answered ? null : () => _onPickOption(i),
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    decoration: _optionDecoration(context, item, i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 26,
                            child: Text(
                              _labels[i],
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              item.options[i],
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.28),
                            ),
                          ),
                          if (_answered &&
                              i == _pickedIndex &&
                              i == item.correctIndex) ...[
                            const SizedBox(width: 8),
                            Icon(
                              Icons.check_circle_rounded,
                              color: _optGreenBorder,
                              size: 26,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        if (_answered)
          SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.14),
              end: Offset.zero,
            ).animate(
              CurvedAnimation(
                parent: _feedbackRevealController,
                curve: Curves.easeOutCubic,
              ),
            ),
            child: FadeTransition(
              opacity: _feedbackRevealController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  if (_wasCorrect)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('🎉', style: TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green.shade600,
                          size: 36,
                        ),
                      ],
                    ),
                  if (item.explanation != null && item.explanation!.isNotEmpty) ...[
                    SizedBox(height: _wasCorrect ? 12 : 8),
                    Container(
                      decoration: BoxDecoration(
                        color: _creamFeedbackBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFFE5DDD4).withValues(alpha: 0.95),
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.04),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: Text(
                          item.explanation!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                height: 1.42,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF4E342E),
                              ),
                        ),
                      ),
                    ),
                  ],
                  if (_wasCorrect &&
                      (item.explanation == null || item.explanation!.isEmpty)) ...[
                    const SizedBox(height: 10),
                    Text(
                      'Wonderful — you got it!',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.green.shade800,
                          ),
                    ),
                  ] else if (!_wasCorrect)
                    Padding(
                      padding: EdgeInsets.only(
                        top: item.explanation != null && item.explanation!.isNotEmpty
                            ? 10
                            : 8,
                        bottom: 4,
                      ),
                      child: Text(
                        "Nice try! The green answer fits best. You're still doing great.",
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              height: 1.38,
                            ),
                      ),
                    ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: () => _onMcqNext(),
                    style: FilledButton.styleFrom(
                      backgroundColor: _nextOrange,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: _nextOrange.withValues(alpha: 0.5),
                      minimumSize: const Size(double.infinity, 54),
                      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
                      elevation: 4,
                      shadowColor: _nextOrange.withValues(alpha: 0.45),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(
                      _primaryActionLabel(),
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 24 + 12 + MediaQuery.viewPaddingOf(context).bottom,
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  EdgeInsets _mcqScrollPadding(BuildContext context) {
    final h = ResponsiveLayout.isTablet(context) ? 12.0 : 8.0;
    final side = ResponsiveLayout.isTablet(context) ? 24.0 : 16.0;
    final bottom = 24 + 12 + MediaQuery.viewPaddingOf(context).bottom;
    return EdgeInsets.fromLTRB(side, h, side, bottom);
  }

  Widget _buildStorytellerTail(BuildContext context) {
    final prompt = widget.plan.retellingCentralPrompt?.trim() ?? '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          "Let's tell the story of ${widget.book.title} together!",
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        Text(
          widget.book.author,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (prompt.isNotEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Text(
                prompt,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontSize: 17,
                      height: 1.45,
                    ),
              ),
            ),
          ),
        const SizedBox(height: 22),
        Text(
          'Tell your story in order',
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        StoryStructureScaffoldRow(labels: widget.plan.retellingStructureLabels),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: _goToRetell,
          icon: const Icon(Icons.mic_rounded),
          label: const Text('Continue as Storyteller'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_appBarTitle)),
      body: SafeArea(
        child: ResponsiveLayout.constrainToMaxWidth(
          context,
          SingleChildScrollView(
            padding: _mcqPhaseComplete
                ? ResponsiveLayout.padding(context)
                : _mcqScrollPadding(context),
            child: _mcqPhaseComplete
                ? _buildStorytellerTail(context)
                : _buildMcqPhase(context),
          ),
        ),
      ),
    );
  }
}

/// Capsule progress with milestone dividers, 3D-style fill, and smooth index transitions.
class _GamifiedQuizProgressBar extends StatefulWidget {
  const _GamifiedQuizProgressBar({
    required this.currentQuestionIndex,
    required this.totalQuestions,
    required this.justAnswered,
    required this.trackColor,
    required this.fillTop,
    required this.fillMain,
    required this.fillBottom,
  });

  final int currentQuestionIndex;
  final int totalQuestions;
  final bool justAnswered;
  final Color trackColor;
  final Color fillTop;
  final Color fillMain;
  final Color fillBottom;

  @override
  State<_GamifiedQuizProgressBar> createState() =>
      _GamifiedQuizProgressBarState();
}

class _GamifiedQuizProgressBarState extends State<_GamifiedQuizProgressBar>
    with SingleTickerProviderStateMixin {
  static const double _barHeight = 17;
  static const double _radius = 20;
  static const Duration _animDuration = Duration(milliseconds: 520);

  late final AnimationController _controller;
  late Animation<double> _fillAnimation;

  double _progressFor(int qIndex, int total) {
    if (total <= 0) return 0;
    return ((qIndex + 1) / total).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _animDuration);
    final t = _progressFor(widget.currentQuestionIndex, widget.totalQuestions);
    _fillAnimation = Tween<double>(begin: t, end: t).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.value = 1.0;
  }

  @override
  void didUpdateWidget(covariant _GamifiedQuizProgressBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentQuestionIndex != oldWidget.currentQuestionIndex ||
        widget.totalQuestions != oldWidget.totalQuestions) {
      final from = _fillAnimation.value;
      final to = _progressFor(widget.currentQuestionIndex, widget.totalQuestions);
      _fillAnimation = Tween<double>(begin: from, end: to).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.totalQuestions;
    if (total <= 0) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _fillAnimation,
      builder: (context, child) {
        final fillFrac = _fillAnimation.value.clamp(0.0, 1.0);
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            return SizedBox(
              height: _barHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(_radius),
                  border: widget.justAnswered
                      ? Border.all(
                          color: widget.fillMain.withValues(alpha: 0.5),
                          width: 1.5,
                        )
                      : null,
                  boxShadow: widget.justAnswered
                      ? [
                          BoxShadow(
                            color: widget.fillMain.withValues(alpha: 0.25),
                            blurRadius: 8,
                            spreadRadius: 0,
                          ),
                        ]
                      : null,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(_radius),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ColoredBox(color: widget.trackColor),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: fillFrac,
                          heightFactor: 1,
                          alignment: Alignment.centerLeft,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  widget.fillTop,
                                  widget.fillMain,
                                  widget.fillBottom,
                                ],
                                stops: const [0.0, 0.42, 1.0],
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: widget.fillBottom.withValues(alpha: 0.9),
                                  width: 2,
                                ),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  blurRadius: 0,
                                  offset: const Offset(0, -1),
                                ),
                              ],
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                      ...List<Widget>.generate(
                        math.max(0, total - 1),
                        (i) {
                          final x = w * ((i + 1) / total);
                          return Positioned(
                            left: x - 0.5,
                            top: 2,
                            bottom: 2,
                            width: 1.2,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(1),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.12),
                                    blurRadius: 0,
                                    offset: const Offset(0.5, 0),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
