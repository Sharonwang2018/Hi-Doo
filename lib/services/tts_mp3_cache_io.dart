import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Directory? _ttsMp3CacheDir;

Future<Directory> _dir() async {
  if (_ttsMp3CacheDir != null) return _ttsMp3CacheDir!;
  final root = await getApplicationSupportDirectory();
  final d = Directory('${root.path}/tts_mp3_cache');
  if (!await d.exists()) {
    await d.create(recursive: true);
  }
  _ttsMp3CacheDir = d;
  return d;
}

/// Read cached MP3 bytes, or `null` if missing.
Future<Uint8List?> ttsMp3CacheGet(String key) async {
  try {
    final f = File('${(await _dir()).path}/$key.mp3');
    if (!await f.exists()) return null;
    final bytes = await f.readAsBytes();
    return bytes.isEmpty ? null : bytes;
  } catch (_) {
    return null;
  }
}

/// Persist MP3 under [key] (fire-and-forget safe; overwrites same key).
Future<void> ttsMp3CachePut(String key, Uint8List bytes) async {
  try {
    final f = File('${(await _dir()).path}/$key.mp3');
    await f.writeAsBytes(bytes, flush: true);
  } catch (_) {
    // ignore disk full / permission
  }
}
