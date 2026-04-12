// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:async';
import 'dart:html' as html;
// 仅 Web 编译/分析目标下存在；本文件由 `dart.library.html` 条件导入，勿在 VM 测试里直接 import。
// ignore: uri_does_not_exist
import 'dart:js_util' as js_util;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

import 'page_tts_audio_web_config.dart';

/// 极短合法 WAV（静音），用于在同步栈内 `AudioElement.play()`，单独解锁 iOS/Safari 的 HTML5 音频（与 Web Audio 不是同一条策略）。
const _silentWavBase64 =
    'UklGRiQAAABXQVZFZm10IBAAAAABAAEAIlYAAESsAAACABAAZGF0YQAAAAA=';

void _unlockHtmlAudioElementSync() {
  try {
    final a = html.AudioElement();
    a.setAttribute('playsinline', 'true');
    a.setAttribute('webkit-playsinline', 'true');
    a.volume = 0.0001;
    a.src = 'data:audio/wav;base64,$_silentWavBase64';
    try {
      a.load();
    } catch (_) {}
    unawaited(a.play().catchError((_) {}));
  } catch (_) {
    // ignore
  }
}

Object? _audioContextConstructor() {
  final w = html.window;
  return js_util.getProperty(w, 'AudioContext') ?? js_util.getProperty(w, 'webkitAudioContext');
}

/// 整页共用一个 [AudioContext]，避免每次播完 close 后下次又 suspended 且「用户激活」已在 await HTTP 后过期。
Object? _sharedTtsAudioContext;

/// 在按钮 [onPressed] 触发的 **同步** 路径里调用（须在首个 `await` 之前）。
/// iOS 微信 / Safari 上仅靠 [resume] 不够；用极短无声振荡器「点亮」音频图更稳。
void unlockAudioContextSync() {
  try {
    final ctor = _audioContextConstructor();
    if (ctor == null) return;
    _sharedTtsAudioContext ??= js_util.callConstructor<Object>(ctor, []);
    final ctx = _sharedTtsAudioContext!;
    final state = js_util.getProperty(ctx, 'state');
    if (state == 'suspended') {
      js_util.callMethod(ctx, 'resume', []);
    }
    final osc = js_util.callMethod(ctx, 'createOscillator', []);
    final gain = js_util.callMethod(ctx, 'createGain', []);
    final g = js_util.getProperty(gain, 'gain');
    if (g != null) {
      js_util.setProperty(g, 'value', 0);
    }
    js_util.callMethod(osc, 'connect', [gain]);
    js_util.callMethod(gain, 'connect', [js_util.getProperty(ctx, 'destination')]);
    js_util.callMethod(osc, 'start', [0]);
    js_util.callMethod(osc, 'stop', [0.001]);
    _unlockHtmlAudioElementSync();
  } catch (_) {
    // ignore
  }
}

/// 优先用 Web Audio API 播放 MP3。失败（如手机端 decode 内存限制）返回 `false`，由 [playTtsMp3] 走 `<audio>`，不抛异常。
Future<bool> _playMp3WithWebAudioApi(Uint8List bytes) async {
  final ctor = _audioContextConstructor();
  if (ctor == null) {
    return false;
  }
  _sharedTtsAudioContext ??= js_util.callConstructor<Object>(ctor, []);
  final Object ctx = _sharedTtsAudioContext!;
  Object? source;
  try {
    final copy = Uint8List.fromList(bytes);
    final audioBuffer = await js_util.promiseToFuture<Object>(
      js_util.callMethod(ctx, 'decodeAudioData', [copy.buffer]),
    );
    final created = js_util.callMethod(ctx, 'createBufferSource', []);
    if (created == null) {
      return false;
    }
    final Object src = created;
    source = src;
    js_util.setProperty(src, 'buffer', audioBuffer);
    final dest = js_util.getProperty(ctx, 'destination');
    js_util.callMethod(src, 'connect', [dest]);

    final completer = Completer<void>();
    var finished = false;

    void completePlayback() {
      if (finished || completer.isCompleted) return;
      finished = true;
      completer.complete();
    }

    js_util.setProperty(src, 'onended', js_util.allowInterop((_) => completePlayback()));

    final state = js_util.getProperty(ctx, 'state');
    if (state == 'suspended') {
      await js_util.promiseToFuture(js_util.callMethod(ctx, 'resume', []));
    }

    js_util.callMethod(src, 'start', [0]);

    final dur = js_util.getProperty(audioBuffer, 'duration');
    final sec = dur is num && dur.isFinite && dur > 0 ? dur.toDouble() : 45.0;
    await completer.future.timeout(
      Duration(milliseconds: (sec * 1000).ceil() + 2500),
      onTimeout: completePlayback,
    );
    return true;
  } catch (_) {
    return false;
  } finally {
    try {
      final s = source;
      if (s != null) {
        js_util.callMethod(s, 'stop', []);
      }
    } catch (_) {}
  }
}

/// 用 Web Audio 解码得到 MP3 时长（秒），供 `<audio>` 兜底路径的定时器。
Future<double?> _decodeMp3DurationSec(Uint8List bytes) async {
  final ctor = _audioContextConstructor();
  if (ctor == null) return null;
  final ctx = js_util.callConstructor<Object>(ctor, []);
  try {
    final copy = Uint8List.fromList(bytes);
    final promise = js_util.callMethod(ctx, 'decodeAudioData', [copy.buffer]);
    final audioBuffer = await js_util.promiseToFuture<Object>(promise);
    final d = js_util.getProperty(audioBuffer, 'duration');
    if (d is num && d.isFinite && d > 0) return d.toDouble();
  } catch (_) {
    return null;
  } finally {
    try {
      final closeResult = js_util.callMethod(ctx, 'close', []);
      if (closeResult != null) {
        await js_util.promiseToFuture<Object>(closeResult);
      }
    } catch (_) {}
  }
  return null;
}

/// 兜底：HTML5 Audio（部分环境 Web Audio 失败时使用）
Future<void> _playMp3WithAudioElement(Uint8List bytes) async {
  final blob = html.Blob([bytes], 'audio/mpeg');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final audio = html.AudioElement();
  audio.preload = 'auto';
  audio.setAttribute('playsinline', 'true');
  audio.setAttribute('webkit-playsinline', 'true');
  try {
    audio.volume = 1.0;
  } catch (_) {}

  final completer = Completer<void>();
  final metadataReady = Completer<void>();
  var isFinished = false;
  final subs = <StreamSubscription<dynamic>>[];
  Timer? safetyTimer;
  Timer? pollTimer;
  Timer? durationFailSafeTimer;

  final decodeDurationFuture = _decodeMp3DurationSec(bytes);

  void cleanup() {
    durationFailSafeTimer?.cancel();
    durationFailSafeTimer = null;
    safetyTimer?.cancel();
    safetyTimer = null;
    pollTimer?.cancel();
    pollTimer = null;
    for (final s in subs) {
      s.cancel();
    }
    subs.clear();
    try {
      audio.pause();
    } catch (_) {}
    try {
      audio.removeAttribute('src');
      audio.load();
    } catch (_) {}
  }

  void completeSuccess() {
    if (isFinished || completer.isCompleted) return;
    isFinished = true;
    cleanup();
    html.Url.revokeObjectUrl(url);
    completer.complete();
  }

  void completeError(Object error) {
    if (isFinished || completer.isCompleted) return;
    isFinished = true;
    cleanup();
    html.Url.revokeObjectUrl(url);
    completer.completeError(error);
  }

  bool isNearOrPastEnd() {
    try {
      if (audio.ended == true) return true;
      final t = audio.currentTime;
      if (!t.isFinite) return false;
      final eps = WebTtsAudioPlaybackConfig.endEpsilonSeconds;

      final d = audio.duration;
      if (d.isFinite && d > 0 && t >= d - eps) return true;

      final b = audio.buffered;
      if (b.length > 0) {
        final end = b.end(b.length - 1);
        if (end.isFinite && t >= end - eps) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  void onPlaybackMaybeComplete() {
    if (isFinished || completer.isCompleted) return;
    if (isNearOrPastEnd()) {
      completeSuccess();
    }
  }

  subs.add(audio.onEnded.listen((_) => completeSuccess()));
  subs.add(audio.onPause.listen((_) {
    if (isFinished || completer.isCompleted) return;
    if (isNearOrPastEnd()) {
      completeSuccess();
    }
  }));
  subs.add(audio.onError.listen((_) {
    completeError(Exception('TTS decode or playback failed'));
  }));
  subs.add(audio.onTimeUpdate.listen((_) => onPlaybackMaybeComplete()));
  subs.add(audio.onLoadedData.listen((_) => onPlaybackMaybeComplete()));
  subs.add(audio.onLoadedMetadata.listen((_) {
    if (!metadataReady.isCompleted) metadataReady.complete();
    onPlaybackMaybeComplete();
  }));
  subs.add(audio.onDurationChange.listen((_) => onPlaybackMaybeComplete()));

  audio.src = url;
  try {
    audio.load();
  } catch (_) {
    // ignore
  }

  try {
    await metadataReady.future.timeout(WebTtsAudioPlaybackConfig.metadataLoadTimeout);
  } on TimeoutException {
    // 部分环境不触发 loadedmetadata，仍尝试 play
  } catch (_) {
    // ignore
  }

  safetyTimer = Timer(WebTtsAudioPlaybackConfig.safetyTimeout, () {
    try {
      audio.pause();
    } catch (_) {}
    if (!isFinished && !completer.isCompleted) {
      completeSuccess();
    }
  });

  pollTimer = Timer.periodic(WebTtsAudioPlaybackConfig.pollInterval, (_) {
    onPlaybackMaybeComplete();
  });

  try {
    await _playHtmlAudioWithRetry(audio);
  } catch (e, st) {
    isFinished = true;
    cleanup();
    html.Url.revokeObjectUrl(url);
    Error.throwWithStackTrace(
      Exception('Web audio play blocked or failed: $e'),
      st,
    );
  }

  final playStartedAt = DateTime.now();
  double? decodedDurationSec;
  try {
    decodedDurationSec = await decodeDurationFuture.timeout(
      WebTtsAudioPlaybackConfig.decodeDurationTimeout,
      onTimeout: () => null,
    );
  } catch (_) {}

  if (decodedDurationSec != null &&
      decodedDurationSec.isFinite &&
      decodedDurationSec > 0) {
    final endMs =
        (decodedDurationSec * 1000).ceil() + WebTtsAudioPlaybackConfig.durationFailSafeExtraMs;
    final elapsedMs = DateTime.now().difference(playStartedAt).inMilliseconds;
    final remainingMs = endMs - elapsedMs;
    durationFailSafeTimer = Timer(Duration(milliseconds: remainingMs > 0 ? remainingMs : 0), () {
      if (!isFinished && !completer.isCompleted) {
        completeSuccess();
      }
    });
  }

  await completer.future;
}

/// 移动端 [NotAllowedError]：再 [unlockAudioContextSync] + [resume] 后重试一次 [play]。
Future<void> _playHtmlAudioWithRetry(html.AudioElement audio) async {
  try {
    await audio.play();
    return;
  } catch (e) {
    final s = e.toString();
    final notAllowed =
        s.contains('NotAllowedError') || s.contains('not allowed') || s.contains('NotAllowed');
    if (!notAllowed) rethrow;
    unlockAudioContextSync();
    try {
      final ctor = _audioContextConstructor();
      if (ctor != null && _sharedTtsAudioContext != null) {
        final ctx = _sharedTtsAudioContext!;
        final state = js_util.getProperty(ctx, 'state');
        if (state == 'suspended') {
          await js_util.promiseToFuture(js_util.callMethod(ctx, 'resume', []));
        }
      }
    } catch (_) {
      // ignore
    }
    await audio.play();
  }
}

/// Web：优先 `<audio>`（MP3 兼容性好），失败再 Web Audio API。
/// 本文件仅 Web；[player] 用于与 Flutter 侧状态对齐，实际播放在 DOM 音频/Web Audio。
Future<void> playTtsMp3(Uint8List bytes, AudioPlayer player) async {
  unlockAudioContextSync();
  try {
    await player.stop().timeout(WebTtsAudioPlaybackConfig.playerStopTimeout);
  } on TimeoutException {
    // ignore
  } catch (_) {
    // ignore
  }

  try {
    await _playMp3WithAudioElement(bytes);
    return;
  } catch (_) {
    // 继续尝试 Web Audio
  }

  if (await _playMp3WithWebAudioApi(bytes)) {
    return;
  }

  await _playMp3WithAudioElement(bytes);
}
