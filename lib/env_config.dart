import 'package:echo_reading/constants.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

/// API、Supabase Auth 与运行配置
///
/// 构建示例（见 `run_all.sh`）：
/// `--dart-define=API_BASE_URL=...`
/// `--dart-define=SUPABASE_URL=https://xxxx.supabase.co`
/// `--dart-define=SUPABASE_ANON_KEY=eyJ...`
///
/// Node API 校验 Supabase 签发的 access token，需在 `api/.env` 配置 `SUPABASE_JWT_SECRET`
///（Dashboard → Settings → API → JWT Secret）。
class EnvConfig {
  static const String _apiBaseUrlDefine =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  static const String _supabaseUrlDefine =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String _supabaseAnonKeyDefine =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  static String get apiBaseUrl {
    final fromDefine = _apiBaseUrlDefine.trim();
    if (fromDefine.isNotEmpty) {
      return fromDefine.endsWith('/')
          ? fromDefine.substring(0, fromDefine.length - 1)
          : fromDefine;
    }
    if (!kIsWeb) return 'http://10.0.0.138:3000';
    final b = Uri.base;
    final scheme = b.scheme;
    if (b.port == 3000 || b.port == 443 || b.port == 80) return b.origin;
    return '$scheme://${b.host}:3000';
  }

  /// Supabase 项目 URL，无末尾斜杠
  static String get supabaseUrl {
    var u = _supabaseUrlDefine.trim();
    if (u.endsWith('/')) u = u.substring(0, u.length - 1);
    return u;
  }

  static String get supabaseAnonKey => _supabaseAnonKeyDefine.trim();

  static bool get hasSupabase =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static const int timeout =
      int.fromEnvironment('API_TIMEOUT', defaultValue: 15000);

  /// Sponsor link: `--dart-define=DONATION_URL=...` if set, else [AppConstants.defaultDonationUrl].
  static String get donationUrl {
    const fromEnv = String.fromEnvironment('DONATION_URL', defaultValue: '');
    final t = fromEnv.trim();
    if (t.isNotEmpty) return t;
    return AppConstants.defaultDonationUrl;
  }

  /// 云端能力（扫码存书、挑战、日志）：需要同源/配置的 API **且** Supabase 登录
  static bool get isConfigured => apiBaseUrl.isNotEmpty && hasSupabase;

  static bool get hasDonationUrl {
    final u = Uri.tryParse(donationUrl.trim());
    if (u == null || u.host.isEmpty) return false;
    return u.scheme == 'https' || u.scheme == 'http';
  }
}
