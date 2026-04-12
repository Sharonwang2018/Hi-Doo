import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download for PNG [bytes].
/// Uses a blob URL first; delays before [revokeObjectUrl] so the download can start.
/// Falls back to a data URL if the blob path fails (some Safari/WebKit builds).
Future<void> downloadPosterPng(
  Uint8List bytes, {
  required String filename,
}) async {
  final safeName =
      filename.replaceAll(RegExp(r'[^\w.\-]+'), '_').replaceAll('..', '.');
  final name = safeName.isEmpty ? 'poster.png' : safeName;

  void triggerDownload(String href) {
    final anchor = html.AnchorElement(href: href)
      ..setAttribute('download', name)
      ..style.display = 'none';
    html.document.body?.append(anchor);
    anchor.click();
    anchor.remove();
  }

  String? objectUrl;
  try {
    final blob = html.Blob([bytes], 'image/png');
    objectUrl = html.Url.createObjectUrlFromBlob(blob);
    triggerDownload(objectUrl);
    await Future<void>.delayed(const Duration(milliseconds: 800));
  } catch (_) {
    final failed = objectUrl;
    objectUrl = null;
    if (failed != null) {
      try {
        html.Url.revokeObjectUrl(failed);
      } catch (_) {}
    }
    final dataUri = 'data:image/png;base64,${base64Encode(bytes)}';
    triggerDownload(dataUri);
  } finally {
    final u = objectUrl;
    if (u != null) {
      try {
        html.Url.revokeObjectUrl(u);
      } catch (_) {}
    }
  }
}
