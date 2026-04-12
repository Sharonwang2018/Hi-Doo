import 'package:echo_reading/services/reading_streak_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Home app bar: flame tier + "N Days" (local streak from [ReadingStreakService]).
class StreakHomeBadge extends StatelessWidget {
  const StreakHomeBadge({super.key});

  static const Color _blueFlame = Color(0xFF1E88E5);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: ReadingStreakService.streakCountNotifier,
      builder: (context, n, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tierFlame(n),
            const SizedBox(width: 6),
            Text(
              '$n ${n == 1 ? 'Day' : 'Days'}',
              style: GoogleFonts.montserrat(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF1a1a1a),
                letterSpacing: -0.2,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _tierFlame(int n) {
    if (n <= 0) {
      return Icon(
        Icons.local_fire_department_outlined,
        size: 22,
        color: Colors.black.withValues(alpha: 0.35),
      );
    }
    if (n >= 30) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('👑', style: TextStyle(fontSize: 15, height: 1)),
          SizedBox(width: 2),
          Text('🔥', style: TextStyle(fontSize: 22, height: 1)),
        ],
      );
    }
    if (n >= 7) {
      return const Icon(
        Icons.local_fire_department,
        size: 26,
        color: _blueFlame,
      );
    }
    final emojiSize = n <= 3 ? 20.0 : 24.0;
    return Text('🔥', style: TextStyle(fontSize: emojiSize, height: 1));
  }
}
