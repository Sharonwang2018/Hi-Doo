import 'dart:async';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';

void unlockAudioContextSync() {}

/// 非 Web：audioplayers + onPlayerComplete
Future<void> playTtsMp3(Uint8List bytes, AudioPlayer player) async {
  final dataUrl = Uri.dataFromBytes(bytes, mimeType: 'audio/mpeg').toString();
  final completer = Completer<void>();
  late final StreamSubscription<void> sub;
  sub = player.onPlayerComplete.listen((_) {
    sub.cancel();
    if (!completer.isCompleted) completer.complete();
  });
  await player.play(UrlSource(dataUrl));
  await completer.future.timeout(
    const Duration(seconds: 90),
    onTimeout: () {
      if (!completer.isCompleted) completer.complete();
    },
  );
}
