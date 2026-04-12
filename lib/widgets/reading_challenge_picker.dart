import 'package:echo_reading/models/book.dart';
import 'package:echo_reading/models/reading_challenge_kind.dart';
import 'package:echo_reading/services/reading_session_flow.dart';
import 'package:flutter/material.dart';

/// Child picks quiz, storyteller, both, or log-only — four equal paths.
class ReadingChallengePicker extends StatelessWidget {
  const ReadingChallengePicker({
    super.key,
    required this.parentContext,
    required this.sheetContext,
    required this.lookup,
    this.savedBook,
  });

  final BuildContext parentContext;
  final BuildContext sheetContext;
  final BookLookupResult lookup;
  final Book? savedBook;

  static const Color _titleColor = Color(0xFF4E342E);

  static const _gridGap = 16.0;

  void _pick(ReadingChallengeKind kind) {
    Navigator.pop(sheetContext);
    ReadingSessionFlow.startChallenge(
      parentContext,
      lookup,
      savedBook: savedBook,
      kind: kind,
    );
  }

  void _pickLogOnly() {
    Navigator.pop(sheetContext);
    ReadingSessionFlow.startLogOnly(
      parentContext,
      lookup,
      savedBook: savedBook,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cover = lookup.coverUrl;
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (cover != null && cover.isNotEmpty) ...[
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      cover,
                      height: 168,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              Text(
                lookup.title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      fontSize: 26,
                      color: _titleColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                lookup.author,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: cs.onSurfaceVariant.withValues(alpha: 0.92),
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              Text(
                'Ready for the Story Challenge?',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: _titleColor,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _pathGrid(context),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pathGrid(BuildContext context) {
    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PathCard(
                  onTap: () => _pick(ReadingChallengeKind.quiz),
                  leading: const Icon(
                    Icons.extension_rounded,
                    size: 38,
                    color: Color(0xFFE65100),
                  ),
                  title: 'Detail Detective',
                  titleSuffix: '(Quiz)',
                  subtitle: 'Test your memory',
                  borderColor: const Color(0xFFFFCC80),
                  gradientColors: const [
                    Color(0xFFFFFDF9),
                    Color(0xFFFFF3E0),
                  ],
                ),
              ),
              SizedBox(width: _gridGap),
              Expanded(
                child: _PathCard(
                  onTap: () => _pick(ReadingChallengeKind.storyteller),
                  leading: const Icon(
                    Icons.record_voice_over_rounded,
                    size: 38,
                    color: Color(0xFF1565C0),
                  ),
                  title: 'Master Storyteller',
                  titleSuffix: '(Retell)',
                  subtitle: 'Tell the story in your own words',
                  borderColor: const Color(0xFFBBDEFB),
                  gradientColors: const [
                    Color(0xFFF8FDFF),
                    Color(0xFFE3F2FD),
                  ],
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: _gridGap),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _PathCard(
                  onTap: () => _pick(ReadingChallengeKind.both),
                  leading: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 40,
                    color: Color(0xFFFF8F00),
                  ),
                  title: 'Detective + Storyteller',
                  titleSuffix: '(Both)',
                  subtitle: 'Quiz first, then retell',
                  borderColor: const Color(0xFFFFE082),
                  gradientColors: const [
                    Color(0xFFFFFDF5),
                    Color(0xFFFFF8E1),
                  ],
                ),
              ),
              SizedBox(width: _gridGap),
              Expanded(
                child: _PathCard(
                  onTap: _pickLogOnly,
                  leading: const Icon(
                    Icons.menu_book_rounded,
                    size: 38,
                    color: Color(0xFF2E7D32),
                  ),
                  title: 'Just log it',
                  titleSuffix: '(Done for now)',
                  subtitle: 'Save your reading, skip the challenge',
                  borderColor: const Color(0xFFC8E6C9),
                  gradientColors: const [
                    Color(0xFFF9FFF9),
                    Color(0xFFE8F5E9),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PathCard extends StatefulWidget {
  const _PathCard({
    required this.onTap,
    required this.leading,
    required this.title,
    required this.titleSuffix,
    required this.subtitle,
    required this.borderColor,
    required this.gradientColors,
  });

  final VoidCallback onTap;
  final Widget leading;
  final String title;
  final String titleSuffix;
  final String subtitle;
  final Color borderColor;
  final List<Color> gradientColors;

  @override
  State<_PathCard> createState() => _PathCardState();
}

class _PathCardState extends State<_PathCard> {
  bool _pressed = false;

  static const double _cardRadius = 20;

  @override
  Widget build(BuildContext context) {
    const titleColor = ReadingChallengePicker._titleColor;
    const subtitleGray = Color(0xFF8D8D8D);

    return AnimatedScale(
      scale: _pressed ? 0.94 : 1.0,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        elevation: 0,
        child: InkWell(
          onTap: widget.onTap,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          borderRadius: BorderRadius.circular(_cardRadius),
          splashColor: widget.borderColor.withValues(alpha: 0.4),
          highlightColor: widget.borderColor.withValues(alpha: 0.14),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(_cardRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.gradientColors,
              ),
              border: Border.all(
                color: widget.borderColor,
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      widget.leading,
                      const SizedBox(height: 12),
                      Text(
                        widget.title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              height: 1.2,
                              color: titleColor,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.titleSuffix,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                              color: titleColor.withValues(alpha: 0.76),
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        widget.subtitle,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: subtitleGray,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
