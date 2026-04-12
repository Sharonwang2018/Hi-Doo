import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local-only daily streak (SharedPreferences → localStorage on web).
/// Only the **first** saved activity of a local calendar day may change streak (callers pass [isFirstActivityToday]).
/// Weekend repair: last read Thu → miss Fri → **Saturday** first read opens repair → **Sunday** first read completes (+1 streak).
class ReadingStreakApplyResult {
  const ReadingStreakApplyResult({
    required this.streakCount,
    required this.didIncrement,
    required this.usedWeekendRepair,
  });

  final int streakCount;
  final bool didIncrement;
  final bool usedWeekendRepair;
}

class ReadingStreakService {
  ReadingStreakService._();

  static const _kStreak = 'hi_doo_streak_count';
  static const _kLastInc = 'hi_doo_streak_last_increment_yyyy_mm_dd';
  static const _kRepairPending = 'hi_doo_streak_repair_sat_pending';
  static const _kRepairSat = 'hi_doo_streak_repair_saturday_yyyy_mm_dd';

  static final ValueNotifier<int> streakCountNotifier = ValueNotifier<int>(0);

  static String dateKey(DateTime d) {
    final l = d.toLocal();
    final y = l.year.toString().padLeft(4, '0');
    final m = l.month.toString().padLeft(2, '0');
    final day = l.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }

  static DateTime? parseDateKey(String? s) {
    if (s == null || s.isEmpty) return null;
    final p = s.split('-');
    if (p.length != 3) return null;
    try {
      return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
    } catch (_) {
      return null;
    }
  }

  static int calendarDaysBetween(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return db.difference(da).inDays;
  }

  static Future<void> refreshNotifier() async {
    final p = await SharedPreferences.getInstance();
    streakCountNotifier.value = p.getInt(_kStreak) ?? 0;
  }

  /// Call after a successful Reading Log save when [isFirstActivityToday] (from refreshed server logs).
  static Future<ReadingStreakApplyResult> applyIfEligible({
    required bool isFirstActivityToday,
  }) async {
    if (!isFirstActivityToday) {
      await refreshNotifier();
      return ReadingStreakApplyResult(
        streakCount: streakCountNotifier.value,
        didIncrement: false,
        usedWeekendRepair: false,
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    final todayKey = dateKey(now);
    final todayDate = parseDateKey(todayKey)!;

    var streak = prefs.getInt(_kStreak) ?? 0;
    final lastKey = prefs.getString(_kLastInc);
    final lastDate = parseDateKey(lastKey);

    // Drop stale weekend repair (no Sunday completion)
    var repairPending = prefs.getBool(_kRepairPending) ?? false;
    var repairSatDate = parseDateKey(prefs.getString(_kRepairSat));
    if (repairPending && repairSatDate != null) {
      final sunday = repairSatDate.add(const Duration(days: 1));
      if (calendarDaysBetween(sunday, todayDate) >= 1 && todayDate.isAfter(sunday)) {
        await prefs.setBool(_kRepairPending, false);
        await prefs.remove(_kRepairSat);
        repairPending = false;
        repairSatDate = null;
      }
    }

    repairPending = prefs.getBool(_kRepairPending) ?? false;
    repairSatDate = parseDateKey(prefs.getString(_kRepairSat));

    // Finish repair: Sunday immediately after repair Saturday
    if (repairPending &&
        repairSatDate != null &&
        todayDate.weekday == DateTime.sunday &&
        calendarDaysBetween(repairSatDate, todayDate) == 1) {
      streak += 1;
      await prefs.setInt(_kStreak, streak);
      await prefs.setString(_kLastInc, todayKey);
      await prefs.setBool(_kRepairPending, false);
      await prefs.remove(_kRepairSat);
      streakCountNotifier.value = streak;
      return ReadingStreakApplyResult(
        streakCount: streak,
        didIncrement: true,
        usedWeekendRepair: true,
      );
    }

    if (lastDate == null) {
      streak = 1;
      await prefs.setInt(_kStreak, streak);
      await prefs.setString(_kLastInc, todayKey);
      await prefs.setBool(_kRepairPending, false);
      await prefs.remove(_kRepairSat);
      streakCountNotifier.value = streak;
      return ReadingStreakApplyResult(
        streakCount: streak,
        didIncrement: true,
        usedWeekendRepair: false,
      );
    }

    final d = calendarDaysBetween(lastDate, todayDate);
    if (d <= 0) {
      await refreshNotifier();
      return ReadingStreakApplyResult(
        streakCount: streak,
        didIncrement: false,
        usedWeekendRepair: false,
      );
    }

    if (d == 1) {
      streak += 1;
      await prefs.setInt(_kStreak, streak);
      await prefs.setString(_kLastInc, todayKey);
      await prefs.setBool(_kRepairPending, false);
      await prefs.remove(_kRepairSat);
      streakCountNotifier.value = streak;
      return ReadingStreakApplyResult(
        streakCount: streak,
        didIncrement: true,
        usedWeekendRepair: false,
      );
    }

    if (d == 2 && todayDate.weekday == DateTime.saturday) {
      await prefs.setBool(_kRepairPending, true);
      await prefs.setString(_kRepairSat, todayKey);
      await prefs.setInt(_kStreak, streak);
      streakCountNotifier.value = streak;
      return ReadingStreakApplyResult(
        streakCount: streak,
        didIncrement: false,
        usedWeekendRepair: false,
      );
    }

    streak = 1;
    await prefs.setInt(_kStreak, streak);
    await prefs.setString(_kLastInc, todayKey);
    await prefs.setBool(_kRepairPending, false);
    await prefs.remove(_kRepairSat);
    streakCountNotifier.value = streak;
    return ReadingStreakApplyResult(
      streakCount: streak,
      didIncrement: true,
      usedWeekendRepair: false,
    );
  }
}
