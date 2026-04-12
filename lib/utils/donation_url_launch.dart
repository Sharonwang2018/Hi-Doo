import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] in a new tab / external browser; on failure copies URL and shows a [SnackBar].
Future<void> launchExternalDonationUrl(BuildContext context, Uri uri) async {
  try {
    if (await canLaunchUrl(uri)) {
      var ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (ok) return;
      ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
      if (ok) return;
    } else {
      final ok = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_blank',
      );
      if (ok) return;
    }
  } catch (_) {
    // fall through to clipboard
  }

  await Clipboard.setData(ClipboardData(text: uri.toString()));
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Could not open the sponsor page automatically. The link is copied—paste it into your browser.',
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }
}
