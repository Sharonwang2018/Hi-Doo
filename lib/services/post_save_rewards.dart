import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/api_service.dart';
import 'package:echo_reading/services/reading_star_rewards.dart';
import 'package:echo_reading/services/reading_streak_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One fetch of read logs → stars + streak (first activity of day from logs when API works).
class PostSaveRewards {
  PostSaveRewards._();

  static const _kLastAnyAct = 'hi_doo_last_any_activity_yyyy_mm_dd';

  static Future<({int starsEarned, ReadingStreakApplyResult streak})> resolve({
    required bool entryIsLogOnly,
  }) async {
    if (!EnvConfig.isConfigured) {
      return _offlineStarsAndStreak(entryIsLogOnly);
    }
    try {
      final logs = await ApiService.fetchReadLogs();
      final first = ReadingStarRewards.isFirstActivityTodayFromLogs(logs);
      final stars = ReadingStarRewards.computeFromLogs(
        entryIsLogOnly: entryIsLogOnly,
        logs: logs,
      );
      final streak = await ReadingStreakService.applyIfEligible(
        isFirstActivityToday: first,
      );
      return (starsEarned: stars, streak: streak);
    } catch (_) {
      return _offlineStarsAndStreak(entryIsLogOnly);
    }
  }

  static Future<({int starsEarned, ReadingStreakApplyResult streak})> _offlineStarsAndStreak(
    bool entryIsLogOnly,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final tk = ReadingStreakService.dateKey(DateTime.now());
    final last = prefs.getString(_kLastAnyAct);
    final first = last != tk;
    if (first) {
      await prefs.setString(_kLastAnyAct, tk);
    }
    final streak = await ReadingStreakService.applyIfEligible(
      isFirstActivityToday: first,
    );
    final stars = entryIsLogOnly ? (first ? 1 : 0) : 3;
    return (starsEarned: stars, streak: streak);
  }
}
