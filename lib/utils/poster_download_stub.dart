import 'dart:typed_data';

/// Mobile/desktop: unused — UI only calls on Web ([kIsWeb]).
Future<String?> downloadPosterPng(
  Uint8List bytes, {
  required String filename,
}) async =>
    null;

/// No-op off-web.
String? openPosterImageInNewTab(Uint8List bytes) => null;
