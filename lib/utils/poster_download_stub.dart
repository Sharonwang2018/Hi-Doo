import 'dart:typed_data';

/// Mobile / non-Web: always false.
bool isIosWebPosterScreenshotTarget() => false;

/// No-op off-Web.
void openIosWebPosterScreenshotPreview(
  Uint8List bytes, {
  void Function()? onClosed,
}) {}

/// Mobile/desktop: unused — UI only calls on Web ([kIsWeb]).
Future<String?> downloadPosterPng(
  Uint8List bytes, {
  required String filename,
}) async =>
    null;

/// No-op off-web.
String? openPosterImageInNewTab(Uint8List bytes) => null;
