import 'dart:typed_data';

import 'tts_mp3_cache_io.dart' if (dart.library.html) 'tts_mp3_cache_web.dart' as impl;

export 'tts_mp3_cache_key.dart';

Future<Uint8List?> ttsMp3CacheGet(String key) => impl.ttsMp3CacheGet(key);

Future<void> ttsMp3CachePut(String key, Uint8List bytes) => impl.ttsMp3CachePut(key, bytes);
