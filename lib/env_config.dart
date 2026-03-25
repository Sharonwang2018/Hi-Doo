import 'package:flutter/foundation.dart' show kIsWeb;

/// API 与运行配置
///
/// 构建时传 `--dart-define=API_BASE_URL=...`（见 `run_all.sh`）。
/// - 若已设置且非空：Web / 原生均使用该地址（与 `flutter build web` 一致）。
/// - Web 且未设置：用 [Uri.base] 推导同源 API（端口 3000 / 80 / 443）。
/// - 原生且未设置：默认 `http://10.0.0.138:3000`（与脚本一致；本机模拟器可改 localhost）。
///
/// iPhone Safari 对 **局域网自签名 HTTPS** 常导致 `ClientException: Load failed`；
/// 本地调试请用 `HTTP=1 ./run_all.sh` 走 HTTP，或 ngrok 等可信证书。
class EnvConfig {
  static const String _apiBaseUrlDefine =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

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
    // 同源：3000 直连、443/80 经 ngrok 等代理
    if (b.port == 3000 || b.port == 443 || b.port == 80) return b.origin;
    return '$scheme://${b.host}:3000';
  }

  static const int timeout =
      int.fromEnvironment('API_TIMEOUT', defaultValue: 15000);

  static bool get isConfigured => apiBaseUrl.isNotEmpty;
}
