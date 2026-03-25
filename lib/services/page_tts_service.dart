import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/tts_fetch.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

import 'page_tts_audio_impl_stub.dart'
    if (dart.library.html) 'page_tts_audio_impl_web.dart' as tts_audio;

/// TTS：后端 /api/tts（优先豆包语音，其次 OpenAI），失败则设备朗读
class PageTtsService {
  final AudioPlayer _player = AudioPlayer();
  FlutterTts? _flutterTts;

  FlutterTts get _tts => _flutterTts ??= FlutterTts();

  /// 含：HTTP、播 MP3、降级 Web Speech / 本机 TTS；任一步永久挂起时避免 UI 一直转圈（不限于 Web）
  static const Duration _speakTimeout = Duration(seconds: 240);

  Future<void> _withSpeakTimeout(Future<void> Function() fn) async {
    await fn().timeout(_speakTimeout);
  }

  void _logTts(String msg) {
    if (kDebugMode) debugPrint('[EchoReading TTS] $msg');
  }

  Future<void> _playFromApi(String t) async {
    final t0 = DateTime.now();
    _logTts('POST /api/tts chars=${t.length}');
    final bytes = await fetchTtsMp3Bytes(EnvConfig.apiBaseUrl, t);
    final ms = DateTime.now().difference(t0).inMilliseconds;
    _logTts('HTTP ok ${ms}ms body=${bytes.length}b');
    tts_audio.unlockAudioContextSync();
    _logTts('decode+play…');
    await tts_audio.playTtsMp3(bytes, _player);
    _logTts('play finished');
  }

  /// Web 上必须在用户手势回调里 **同步** 调用（不要用 `async () async { await ... }` 再包一层），
  /// 否则 iOS Safari 在 await HTTP 后会拒绝播放豆包 MP3。
  void speakDoubaoFromUserGesture(
    String text, {
    String? languageHint,
    void Function()? onComplete,
    void Function(Object error)? onError,
  }) {
    final t = text.trim();
    if (t.isEmpty) {
      onComplete?.call();
      return;
    }
    tts_audio.unlockAudioContextSync();
    if (!EnvConfig.isConfigured) {
      unawaited(
        _withSpeakTimeout(() => _fallbackSpeak(t, languageHint: languageHint))
            .then((_) => onComplete?.call())
            .catchError((Object e, StackTrace st) {
              onError?.call(e);
            }),
      );
      return;
    }
    if (kIsWeb) {
      fetchTtsMp3Bytes(EnvConfig.apiBaseUrl, t)
          .timeout(const Duration(seconds: 95))
          .then((bytes) async {
        if (bytes.isEmpty) throw Exception('TTS 空响应');
        tts_audio.unlockAudioContextSync();
        _logTts('decode+play… body=${bytes.length}b');
        await tts_audio.playTtsMp3(bytes, _player);
        _logTts('play finished');
      })
          .timeout(_speakTimeout)
          .then((_) => onComplete?.call())
          .catchError((Object e, StackTrace st) async {
        _logTts('gesture TTS fail $e');
        try {
          await _withSpeakTimeout(() => _fallbackSpeak(t, languageHint: languageHint));
          onComplete?.call();
        } catch (e2) {
          onError?.call(e2);
        }
      });
      return;
    }
    unawaited(
      _withSpeakTimeout(() async {
        try {
          await _playFromApi(t);
        } catch (_) {
          await _fallbackSpeak(t, languageHint: languageHint);
        }
      })
          .then((_) => onComplete?.call())
          .catchError((Object e, StackTrace st) {
            onError?.call(e);
          }),
    );
  }

  /// 后端 TTS（豆包/OpenAI）或降级为设备/浏览器语音
  /// [languageHint]：`en` / `zh` 与复述语言一致时优先用于降级 TTS（避免英文点评被当成中文读）
  Future<void> speakWithDoubao(String text, {String? languageHint}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    tts_audio.unlockAudioContextSync();
    await _withSpeakTimeout(() async {
      try {
        if (EnvConfig.isConfigured) {
          await _playFromApi(t);
        } else {
          await _fallbackSpeak(t, languageHint: languageHint);
        }
      } catch (_) {
        await _fallbackSpeak(t, languageHint: languageHint);
      }
    });
  }

  /// 朗读文本（拍照读页等）
  /// [languageHint]：可选 `en` / `zh`，便于降级朗读选对语言（与豆包 API 无关）
  Future<void> speak(String text, {String? languageHint}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    tts_audio.unlockAudioContextSync();

    await _withSpeakTimeout(() async {
      try {
        if (EnvConfig.isConfigured) {
          await _playFromApi(t);
        } else {
          await _fallbackSpeak(t, languageHint: languageHint);
        }
      } catch (_) {
        await _fallbackSpeak(t, languageHint: languageHint);
      }
    });
  }

  /// 仅用设备/浏览器 TTS
  Future<void> speakWithDeviceTts(String text, {String? languageHint}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    await _withSpeakTimeout(() => _fallbackSpeak(t, languageHint: languageHint));
  }

  Future<void> _fallbackSpeak(String text, {String? languageHint}) async {
    final isEn = languageHint == 'en'
        ? true
        : languageHint == 'zh'
            ? false
            : (text.startsWith('Question') ||
                text.startsWith('Hi-Doo is') ||
                text.startsWith('Tell ') ||
                (RegExp(r'^[a-zA-Z]').hasMatch(text.trim()) &&
                    !RegExp(r'[\u4e00-\u9fff]').hasMatch(text)));
    await _tts.setLanguage(isEn ? 'en-US' : 'zh-CN');
    await _tts.setSpeechRate(0.5);
    await _tts.awaitSpeakCompletion(true);
    final utterance = _tts.speak(text);
    // Web：onError 不 complete；原生偶发也不结束，统一加超时
    try {
      await utterance.timeout(const Duration(seconds: 120));
    } on TimeoutException {
      await _tts.stop();
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop().timeout(const Duration(seconds: 2));
    } on TimeoutException {
      // Web 上 AudioPlayer.stop 偶发不返回
    } catch (_) {}
    await _tts.stop();
  }

  void dispose() {
    _player.dispose();
  }
}
