/// Web 端 TTS 播放完成检测参数（与 `page_tts_audio_impl_web.dart` 中 `playTtsMp3` 配套）。
/// 集中可调：轮询间隔、末尾容差、安全超时等。
abstract final class WebTtsAudioPlaybackConfig {
  WebTtsAudioPlaybackConfig._();

  /// 判定「已播完」时允许的末尾时间误差（秒），对应 `currentTime >= duration - epsilon`
  /// （略大于 0.1，减少浮点与编解码边界导致的永远差一截）
  static const double endEpsilonSeconds = 0.25;

  /// `timeupdate` 之外额外轮询间隔（部分 WebKit 不触发 `ended`）
  static const Duration pollInterval = Duration(milliseconds: 250);

  /// 设置 `src` 后等待 `loadedmetadata`，避免 `duration` 长期为 NaN
  static const Duration metadataLoadTimeout = Duration(seconds: 15);

  /// 长期无结束信号时强制收尾（应晚于「解码时长 + durationFailSafeExtraMs」）
  static const Duration safetyTimeout = Duration(seconds: 90);

  /// Web Audio 解码得到的时长（秒）×1000 后额外等待，再强制 `complete`（应对 `ended` 不触发）
  static const int durationFailSafeExtraMs = 750;

  /// `decodeAudioData` 大文件可能较慢；超时则放弃「按时长兜底」，仍依赖事件与 [safetyTimeout]
  static const Duration decodeDurationTimeout = Duration(seconds: 12);

  /// `AudioPlayer.stop()` 在 Web 上偶发不返回
  static const Duration playerStopTimeout = Duration(seconds: 2);
}
