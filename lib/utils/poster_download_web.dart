import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';

/// iPhone / iPod / iPad (including iPadOS “desktop” UA: Mac + Mobile).
bool _isAppleTouchWeb() {
  final ua = html.window.navigator.userAgent;
  final lower = ua.toLowerCase();
  if (lower.contains('iphone') || lower.contains('ipod')) return true;
  if (lower.contains('ipad')) return true;
  if (lower.contains('macintosh') && ua.contains('Mobile')) return true;
  return false;
}

/// True when the Web app should use the iOS “prepare for screenshot” flow.
bool isIosWebPosterScreenshotTarget() => _isAppleTouchWeb();

/// Full-screen screenshot guide: poster + minimal chrome (Done only).
/// [onClosed] runs after the user taps Done (URL revoked).
void openIosWebPosterScreenshotPreview(
  Uint8List bytes, {
  void Function()? onClosed,
}) {
  if (!_isAppleTouchWeb()) return;
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);
  _showIosScreenshotOverlay(url, onClosed: onClosed);
}

void _showIosScreenshotOverlay(
  String objectUrl, {
  void Function()? onClosed,
}) {
  final root = html.document.body;
  if (root == null) return;

  final shell = html.DivElement()
    ..style.position = 'fixed'
    ..style.left = '0'
    ..style.top = '0'
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.backgroundColor = '#000000'
    ..style.zIndex = '2147483647'
    ..style.display = 'flex'
    ..style.flexDirection = 'column'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'flex-start'
    ..style.boxSizing = 'border-box'
    ..style.padding = 'max(44px, env(safe-area-inset-top, 0px) + 28px) 40px max(48px, env(safe-area-inset-bottom, 0px) + 32px) 40px';

  final topBar = html.DivElement()
    ..style.width = '100%'
    ..style.display = 'flex'
    ..style.flexDirection = 'row'
    ..style.justifyContent = 'flex-end'
    ..style.alignItems = 'flex-start'
    ..style.marginBottom = '8px';

  final doneBtn = html.ButtonElement()
    ..text = 'Done'
    ..style.color = '#ffffff'
    ..style.fontSize = '17px'
    ..style.fontWeight = '600'
    ..style.background = 'rgba(255,255,255,0.12)'
    ..style.border = 'none'
    ..style.borderRadius = '10px'
    ..style.padding = '10px 18px'
    ..style.cursor = 'pointer';

  topBar.append(doneBtn);

  final headline = html.DivElement()
    ..text = 'Screenshots are the best way to save on iPhone! 📸'
    ..style.color = '#ffffff'
    ..style.fontSize = '18px'
    ..style.fontWeight = '700'
    ..style.textAlign = 'center'
    ..style.lineHeight = '1.35'
    ..style.marginBottom = '16px'
    ..style.maxWidth = '520px';

  final imgWrap = html.DivElement()
    ..style.flex = '1'
    ..style.display = 'flex'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'center'
    ..style.width = '100%'
    ..style.minHeight = '0';

  final img = html.ImageElement()
    ..src = objectUrl
    ..style.maxWidth = '100%'
    ..style.maxHeight =
        'min(62vh, calc(100dvh - 280px))'
    ..style.width = 'auto'
    ..style.height = 'auto'
    ..style.objectFit = 'contain'
    ..style.borderRadius = '16px'
    ..style.boxShadow = '0 8px 32px rgba(0,0,0,0.45)'
    ..style.touchAction = 'none'
    ..style.userSelect = 'none';

  imgWrap.append(img);

  final hint = html.ParagraphElement()
    ..text =
        'Your poster is ready! Just take a screenshot to share with friends.'
    ..style.color = '#c8c8c8'
    ..style.fontSize = '15px'
    ..style.fontWeight = '500'
    ..style.textAlign = 'center'
    ..style.lineHeight = '1.4'
    ..style.marginTop = '20px'
    ..style.marginBottom = '0'
    ..style.maxWidth = '340px';

  shell.append(topBar);
  shell.append(headline);
  shell.append(imgWrap);
  shell.append(hint);
  root.append(shell);

  void remove() {
    try {
      shell.remove();
    } catch (_) {}
    try {
      html.Url.revokeObjectUrl(objectUrl);
    } catch (_) {}
    onClosed?.call();
  }

  doneBtn.onClick.listen((_) => remove());
}

/// When [window.open] is blocked on non‑iOS Web, still offer a fullscreen [img].
void _showGenericBlobFallbackOverlay(String objectUrl) {
  final root = html.document.body;
  if (root == null) return;

  final shell = html.DivElement()
    ..style.position = 'fixed'
    ..style.left = '0'
    ..style.top = '0'
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.backgroundColor = 'rgba(0,0,0,0.92)'
    ..style.zIndex = '2147483647'
    ..style.display = 'flex'
    ..style.flexDirection = 'column'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'center'
    ..style.padding = '40px'
    ..style.boxSizing = 'border-box';

  final closeBtn = html.ButtonElement()
    ..text = 'Close'
    ..style.alignSelf = 'flex-end'
    ..style.color = '#fff'
    ..style.marginBottom = '12px'
    ..style.background = 'transparent'
    ..style.border = 'none'
    ..style.fontSize = '16px';

  final img = html.ImageElement()
    ..src = objectUrl
    ..style.maxWidth = '100%'
    ..style.maxHeight = '75vh'
    ..style.objectFit = 'contain';

  shell.append(closeBtn);
  shell.append(img);
  root.append(shell);

  void remove() {
    try {
      shell.remove();
    } catch (_) {}
    try {
      html.Url.revokeObjectUrl(objectUrl);
    } catch (_) {}
  }

  closeBtn.onClick.listen((_) => remove());
}

/// Desktop / Android Web: blob or data URL + [download] anchor.
///
/// Returns `null` for default SnackBar, non-empty string for custom hint.
Future<String?> downloadPosterPng(
  Uint8List bytes, {
  required String filename,
}) async {
  final safeName =
      filename.replaceAll(RegExp(r'[^\w.\-]+'), '_').replaceAll('..', '.');
  final name = safeName.isEmpty ? 'poster.png' : safeName;

  final blob = html.Blob([bytes], 'image/png');

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
    objectUrl = html.Url.createObjectUrlFromBlob(blob);
    triggerDownload(objectUrl);
    await Future<void>.delayed(const Duration(milliseconds: 1500));
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
  return null;
}

/// Opens blob in a new tab, or falls back to screenshot overlay if blocked.
String? openPosterImageInNewTab(Uint8List bytes) {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);

  // ignore: avoid_dynamic_calls — browsers may return null when blocked.
  final dynamic opened = html.window.open(url, '_blank');
  if (opened == null) {
    if (_isAppleTouchWeb()) {
      _showIosScreenshotOverlay(url, onClosed: null);
      return 'Popup was blocked — use the fullscreen preview to screenshot.';
    }
    _showGenericBlobFallbackOverlay(url);
    return 'Popup was blocked — use the preview, then save or screenshot the image.';
  }

  Future<void>.delayed(const Duration(minutes: 2), () {
    try {
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  });
  return 'Image opened in a new tab — use your browser menu to save or share.';
}
