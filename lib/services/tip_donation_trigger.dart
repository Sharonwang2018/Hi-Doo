import 'package:shared_preferences/shared_preferences.dart';

/// Counts **successful Story Challenge retellings** (saved log + non-empty transcript).
/// Every [interval]-th success (6, 12, 18, …) sets [RetellingCompleteScreen.showDonationTip] so the
/// mission sheet auto-opens. Quiz-only / quick-log paths do not increment this counter.
class TipDonationTrigger {
  TipDonationTrigger._();

  static const String _kRetelling = 'tip_donation_retelling_success_total';

  /// 每累计 [interval] 次成功复述弹出一次赞助说明（第 6、12、18… 次）。
  static const int interval = 6;

  static Future<bool> recordRetellingSuccess() async {
    final prefs = await SharedPreferences.getInstance();
    final n = (prefs.getInt(_kRetelling) ?? 0) + 1;
    await prefs.setInt(_kRetelling, n);
    return n >= interval && n % interval == 0;
  }
}
