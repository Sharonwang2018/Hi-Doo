import 'dart:html' as html;
import 'dart:typed_data';

/// Triggers a browser download for PNG [bytes].
Future<void> downloadPosterPng(
  Uint8List bytes, {
  required String filename,
}) async {
  final safeName =
      filename.replaceAll(RegExp(r'[^\w.\-]+'), '_').replaceAll('..', '.');
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', safeName.isEmpty ? 'poster.png' : safeName)
    ..style.display = 'none';
  html.document.body?.append(anchor);
  anchor.click();
  anchor.remove();
  html.Url.revokeObjectUrl(url);
}
