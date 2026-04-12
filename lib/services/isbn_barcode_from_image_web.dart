// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:html' as html;
// ignore: uri_does_not_exist
import 'dart:js_util' as js_util;

Future<T?> _windowPromise<T>(String method, List<Object?> args) async {
  try {
    return await js_util.promiseToFuture<T>(
      js_util.callMethod(html.window, method, args),
    );
  } catch (_) {
    return null;
  }
}

Future<Object?> pickWebBarcodeImageFile() =>
    _windowPromise<Object?>('hidooPickImageFile', const []);

Future<String?> decodeWebBarcodeFromFile(Object file) =>
    _windowPromise<String?>('hidooDecodeBarcodeFromImageFile', [file]);
