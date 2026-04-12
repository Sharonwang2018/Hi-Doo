import 'dart:typed_data';

/// Mobile/desktop: unused — UI only calls on Web ([kIsWeb]).
Future<void> downloadPosterPng(
  Uint8List bytes, {
  required String filename,
}) async {}

/// No-op off-web.
void openPosterImageInNewTab(Uint8List bytes) {}
