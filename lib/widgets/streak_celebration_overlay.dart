import 'package:confetti/confetti.dart';
import 'package:echo_reading/services/reading_streak_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Full-screen confetti when the daily streak increases (first activity of the day).
Future<void> maybeShowStreakCelebration(
  BuildContext context,
  ReadingStreakApplyResult streak,
) async {
  if (!streak.didIncrement || !context.mounted) return;
  await showStreakCelebration(
    context,
    streakCount: streak.streakCount,
    usedWeekendRepair: streak.usedWeekendRepair,
  );
}

Future<void> showStreakCelebration(
  BuildContext context, {
  required int streakCount,
  bool usedWeekendRepair = false,
}) {
  return showDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierColor: Colors.black.withValues(alpha: 0.58),
    builder: (ctx) => _StreakCelebrationBody(
      streakCount: streakCount,
      usedWeekendRepair: usedWeekendRepair,
    ),
  );
}

class _StreakCelebrationBody extends StatefulWidget {
  const _StreakCelebrationBody({
    required this.streakCount,
    required this.usedWeekendRepair,
  });

  final int streakCount;
  final bool usedWeekendRepair;

  @override
  State<_StreakCelebrationBody> createState() => _StreakCelebrationBodyState();
}

class _StreakCelebrationBodyState extends State<_StreakCelebrationBody> {
  late final ConfettiController _confetti;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 4));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _confetti.play();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    const colors = <Color>[
      Color(0xFFFF8C42),
      Color(0xFF6FB1FC),
      Color(0xFFFFD54F),
      Color(0xFF81C784),
      Color(0xFFE91E63),
      Color(0xFFB39DDB),
    ];

    return Dialog(
      insetPadding: EdgeInsets.zero,
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          behavior: HitTestBehavior.opaque,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(
                child: ConfettiWidget(
                  confettiController: _confetti,
                  emissionFrequency: 0.045,
                  numberOfParticles: 14,
                  blastDirectionality: BlastDirectionality.explosive,
                  shouldLoop: false,
                  maxBlastForce: 28,
                  minBlastForce: 10,
                  gravity: 0.14,
                  colors: colors,
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.streakCount >= 30 ? '👑🔥' : '🔥',
                        style: const TextStyle(fontSize: 72),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 18),
                      Text(
                        "You've read for ${widget.streakCount} days in a row!\nKeep going, Storyteller!",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          height: 1.35,
                          shadows: const [
                            Shadow(
                              blurRadius: 12,
                              color: Colors.black45,
                              offset: Offset(0, 2),
                            ),
                          ],
                        ),
                      ),
                      if (widget.usedWeekendRepair) ...[
                        const SizedBox(height: 16),
                        Text(
                          'Weekend reading saved your streak. Nice work!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.montserrat(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            height: 1.3,
                            shadows: const [
                              Shadow(
                                blurRadius: 10,
                                color: Colors.black38,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                      const SizedBox(height: 28),
                      Text(
                        'Tap anywhere to continue',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
