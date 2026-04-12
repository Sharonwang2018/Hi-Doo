import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/models/read_log_with_book.dart';
import 'package:echo_reading/services/api_service.dart';

/// NGO habit nudge: first quick-log of the local calendar day → 1 star;
/// each challenge completion (quiz / retell / combined) → 3 stars.
class ReadingStarRewards {
  ReadingStarRewards._();

  static bool _sameLocalCalendarDay(DateTime a, DateTime b) {
    final la = a.toLocal();
    final lb = b.toLocal();
    return la.year == lb.year && la.month == lb.month && la.day == lb.day;
  }

  /// True when [logs] contains exactly one entry for today's local calendar date.
  static bool isFirstActivityTodayFromLogs(
    List<ReadLogWithBook> logs, [
    DateTime? referenceNow,
  ]) {
    final now = referenceNow ?? DateTime.now();
    final todayLogs =
        logs.where((e) => _sameLocalCalendarDay(e.readLog.createdAt, now)).toList();
    return todayLogs.length == 1;
  }

  /// [logs] must include the row just created. [referenceNow] is usually [DateTime.now()].
  static int computeFromLogs({
    required bool entryIsLogOnly,
    required List<ReadLogWithBook> logs,
    DateTime? referenceNow,
  }) {
    final now = referenceNow ?? DateTime.now();
    final isFirstActivityToday = isFirstActivityTodayFromLogs(logs, now);

    if (entryIsLogOnly) {
      return isFirstActivityToday ? 1 : 0;
    }
    return 3;
  }

  /// Call after the new log is persisted. Refetches journey list from API.
  static Future<int> fetchAndCompute({
    required bool entryIsLogOnly,
  }) async {
    if (!EnvConfig.isConfigured) {
      return entryIsLogOnly ? 0 : 3;
    }
    try {
      final logs = await ApiService.fetchReadLogs();
      return computeFromLogs(
        entryIsLogOnly: entryIsLogOnly,
        logs: logs,
      );
    } catch (_) {
      return entryIsLogOnly ? 0 : 3;
    }
  }
}
