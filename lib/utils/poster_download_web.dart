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

/// Web Share API (files) — iOS Safari can save PNG to Photos from the share sheet.
Future<bool> _tryNavigatorSharePng(html.Blob blob, String filename) async {
  final nav = html.window.navigator;
  final navDyn = nav as dynamic;
  if (navDyn.share == null) return false;

  html.File file;
  try {
    file = html.File([blob], filename, {'type': 'image/png'});
  } catch (_) {
    return false;
  }

  final shareData = <String, Object?>{
    'files': [file],
    'title': 'Hi-Doo reading poster',
  };

  if (navDyn.canShare != null) {
    try {
      final can = navDyn.canShare(shareData) as Object?;
      if (can != true) return false;
    } catch (_) {
      return false;
    }
  }

  try {
    final result = navDyn.share(shareData);
    if (result is Future) {
      await result;
    }
    return true;
  } catch (_) {
    return false;
  }
}

/// Full-screen native [img] so the user can **long-press → Save to Photos** (iOS Safari).
void _showPosterSaveOverlay(String objectUrl) {
  final root = html.document.body;
  if (root == null) return;

  final shell = html.DivElement()
    ..style.position = 'fixed'
    ..style.left = '0'
    ..style.top = '0'
    ..style.width = '100%'
    ..style.height = '100%'
    ..style.backgroundColor = 'rgba(0,0,0,0.94)'
    ..style.zIndex = '2147483647'
    ..style.display = 'flex'
    ..style.flexDirection = 'column'
    ..style.alignItems = 'center'
    ..style.justifyContent = 'center'
    ..style.padding = '12px'
    ..style.boxSizing = 'border-box';

  final topRow = html.DivElement()
    ..style.width = '100%'
    ..style.display = 'flex'
    ..style.justifyContent = 'space-between'
    ..style.alignItems = 'center'
    ..style.marginBottom = '8px'
    ..style.maxWidth = '520px';

  final closeBtn = html.ButtonElement()
    ..text = 'Done'
    ..style.color = '#fff'
    ..style.fontSize = '17px'
    ..style.fontWeight = '600'
    ..style.background = 'transparent'
    ..style.border = 'none'
    ..style.padding = '8px 12px';

  final hintTop = html.DivElement()
    ..text = 'Long-press the image → Save to Photos'
    ..style.color = '#e0e0e0'
    ..style.fontSize = '13px'
    ..style.textAlign = 'center'
    ..style.flex = '1';

  topRow.append(hintTop);
  topRow.append(closeBtn);

  final img = html.ImageElement()
    ..src = objectUrl
    ..style.maxWidth = '100%'
    ..style.maxHeight = '78vh'
    ..style.objectFit = 'contain'
    ..style.touchAction = 'auto'
    ..style.userSelect = 'none';

  final hintBottom = html.ParagraphElement()
    ..text =
        'If “Save to Photos” does not appear, use the Share button in Safari after saving.'
    ..style.color = '#bdbdbd'
    ..style.fontSize = '12px'
    ..style.textAlign = 'center'
    ..style.marginTop = '14px'
    ..style.maxWidth = '320px'
    ..style.lineHeight = '1.35';

  shell.append(topRow);
  shell.append(img);
  shell.append(hintBottom);
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
  shell.onClick.listen((e) {
    if (identical(e.target, shell)) remove();
  });
}

/// Triggers download / share for PNG [bytes].
/// iOS Safari: prefers [navigator.share] (file), then full-screen preview for long-press save.
/// Desktop: blob or data URL + [download] anchor.
///
/// Returns a short user hint for SnackBar when the flow is not a classic “file download”.
Future<String?> downloadPosterPng(
  Uint8List bytes, {
  required String filename,
}) async {
  final safeName =
      filename.replaceAll(RegExp(r'[^\w.\-]+'), '_').replaceAll('..', '.');
  final name = safeName.isEmpty ? 'poster.png' : safeName;

  final blob = html.Blob([bytes], 'image/png');

  if (await _tryNavigatorSharePng(blob, name)) {
    return 'Share sheet opened — choose Save Image to add to Photos (or another app).';
  }

  if (_isAppleTouchWeb()) {
    final url = html.Url.createObjectUrlFromBlob(blob);
    _showPosterSaveOverlay(url);
    return 'Long-press the image, then tap Save to Photos.';
  }

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

/// On iOS Safari, [window.open] on blob URLs is often blocked — use full-screen preview for long-press save.
/// Returns an optional SnackBar hint; desktop usually returns a new-tab message.
String? openPosterImageInNewTab(Uint8List bytes) {
  final blob = html.Blob([bytes], 'image/png');
  final url = html.Url.createObjectUrlFromBlob(blob);

  if (_isAppleTouchWeb()) {
    _showPosterSaveOverlay(url);
    return 'Long-press the image, then tap Save to Photos.';
  }

  // ignore: avoid_dynamic_calls — [Window.open] is typed non-null but browsers may return null when blocked.
  final dynamic opened = html.window.open(url, '_blank');
  if (opened == null) {
    _showPosterSaveOverlay(url);
    return 'Popup was blocked — long-press the image to save.';
  }

  Future<void>.delayed(const Duration(minutes: 2), () {
    try {
      html.Url.revokeObjectUrl(url);
    } catch (_) {}
  });
  return 'Image opened in a new tab — use your browser menu to save or share.';
}
