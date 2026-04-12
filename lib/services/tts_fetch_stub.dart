import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:echo_reading/services/api_service.dart';
import 'package:echo_reading/services/tts_mp3_cache.dart';
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:http/http.dart' as http;

/// Fetches TTS MP3 from `POST /api/tts`, with **local cache** (file on mobile, IndexedDB on web).
/// Server defaults: OpenAI `tts-1` + `shimmer` (override via `OPENAI_TTS_*` in `api/.env`). Cache invalidates on schema bump in `tts_mp3_cache_key.dart`.
Future<Uint8List> fetchTtsMp3Bytes(String apiBaseUrl, String text) async {
  final cacheKey = ttsMp3CacheKeyForText(text);
  final cached = await ttsMp3CacheGet(cacheKey);
  if (cached != null && cached.isNotEmpty) {
    if (kDebugMode) {
      debugPrint('[EchoReading TTS] cache hit key=${cacheKey.substring(0, 12)}… bytes=${cached.length}');
    }
    return cached;
  }

  final base =
      apiBaseUrl.endsWith('/') ? apiBaseUrl.substring(0, apiBaseUrl.length - 1) : apiBaseUrl;
  final uri = Uri.parse('$base/api/tts');
  final headers = await ApiService.quotaHttpHeaders();
  final res = await http
      .post(
        uri,
        headers: headers,
        body: jsonEncode({'text': text}),
      )
      .timeout(const Duration(seconds: 95));
  if (res.statusCode != 200) {
    throw Exception('TTS failed: ${ApiService.responseErrorMessage(res)}');
  }
  if (res.bodyBytes.isEmpty) {
    throw Exception('TTS returned an empty response');
  }
  final bytes = Uint8List.fromList(res.bodyBytes);
  // Do not block playback on disk/IndexedDB; failures ignored inside impl.
  unawaited(ttsMp3CachePut(cacheKey, bytes));
  return bytes;
}
