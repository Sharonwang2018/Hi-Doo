/// Web stub: upload from file path not supported, would need Blob/XFile
Future<String> uploadAudioFile(Object fileOrPath, {String contentType = 'audio/webm'}) async {
  throw UnsupportedError('Audio upload is not supported on web; use mobile or desktop.');
}
