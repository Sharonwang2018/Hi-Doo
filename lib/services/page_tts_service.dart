import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/services/tts_fetch.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode, kIsWeb;
import 'package:flutter_tts/flutter_tts.dart';

import 'page_tts_audio_impl_stub.dart'
    if (dart.library.html) 'page_tts_audio_impl_web.dart' as tts_audio;

/// TTS：已配置 [EnvConfig.apiBaseUrl] 时走 `POST /api/tts`（服务端优先 **OpenAI**，失败则火山）；再失败则用本机/浏览器朗读。
class PageTtsService {
  final AudioPlayer _player = AudioPlayer();
  FlutterTts? _flutterTts;

  FlutterTts get _tts => _flutterTts ??= FlutterTts();

  static bool get _useServerTts => EnvConfig.isConfigured;

  static const Duration _speakTimeout = Duration(seconds: 240);

  Future<void> _withSpeakTimeout(Future<void> Function() fn) async {
    await fn().timeout(_speakTimeout);
  }

  void _logTts(String msg) {
    if (kDebugMode) debugPrint('[EchoReading TTS] $msg');
  }

  /// Web: fetch + decode + play after user gesture; always [onComplete] so UI spinners clear.
  Future<void> _webSpeakFromUserGesture(
    String t,
    String? languageHint,
    void Function()? onComplete,
    void Function(Object error)? onError,
  ) async {
    try {
      final bytes = await fetchTtsMp3Bytes(EnvConfig.apiBaseUrl, t)
          .timeout(const Duration(seconds: 75));
      if (bytes.isEmpty) throw Exception('TTS returned an empty response');
      tts_audio.unlockAudioContextSync();
      _logTts('decode+play… body=${bytes.length}b');
      await tts_audio
          .playTtsMp3(bytes, _player)
          .timeout(const Duration(seconds: 100));
      _logTts('play finished');
    } catch (e) {
      _logTts('gesture TTS fail $e');
      try {
        await _withSpeakTimeout(() => _fallbackSpeak(t, languageHint: languageHint));
      } catch (e2) {
        onError?.call(e2);
      }
    } finally {
      onComplete?.call();
    }
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

  /// 引导语等：Web 上须在用户手势里 **同步** 进入本方法（勿用 `async () async {}` 再包一层），否则部分浏览器在 await 网络后拒绝播 MP3。
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
    if (!_useServerTts) {
      _logTts('API not configured: device/browser TTS');
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
      unawaited(_webSpeakFromUserGesture(t, languageHint, onComplete, onError));
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

  Future<void> speakWithDoubao(String text, {String? languageHint}) async {
    await speak(text, languageHint: languageHint);
  }

  Future<void> speak(String text, {String? languageHint}) async {
    final t = text.trim();
    if (t.isEmpty) return;
    tts_audio.unlockAudioContextSync();
    await _withSpeakTimeout(() async {
      try {
        if (_useServerTts) {
          await _playFromApi(t);
        } else {
          await _fallbackSpeak(t, languageHint: languageHint);
        }
      } catch (_) {
        await _fallbackSpeak(t, languageHint: languageHint);
      }
    });
  }

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
