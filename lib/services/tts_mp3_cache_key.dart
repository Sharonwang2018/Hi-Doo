import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Bump if you intentionally want to invalidate all cached MP3 (e.g. server voice/model change).
/// `a2`: default OpenAI voice switched to `shimmer` (see api/routes/tts.js).
const _ttsMp3CacheSchema = 'a2';

/// Stable cache key for [text] (trimmed UTF-8 → SHA-256 hex).
String ttsMp3CacheKeyForText(String text) {
  final t = text.trim();
  final digest = sha256.convert(utf8.encode(t));
  return '${_ttsMp3CacheSchema}_${digest.toString()}';
}
