import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

/// Shown from Home ⋮ menu, next to About & privacy.
class ContactUsScreen extends StatelessWidget {
  const ContactUsScreen({super.key});

  static const String _contactEmail = 'contact@hidoo.app';

  Future<void> _openEmail(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: const {
        'subject': 'Hi-Doo — question or feedback',
      },
    );
    try {
      if (await canLaunchUrl(uri)) {
        final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (ok) return;
      } else {
        final ok = await launchUrl(uri, mode: LaunchMode.platformDefault);
        if (ok) return;
      }
    } catch (_) {}
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Could not open email. Write to us at $_contactEmail',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Contact us',
          style: GoogleFonts.montserrat(fontWeight: FontWeight.w700),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        children: [
          Text(
            'We’d love to hear from you',
            style: GoogleFonts.montserrat(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              height: 1.3,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Questions about reading challenges, feedback on the app, or partnership ideas — '
            'send us an email and we’ll get back when we can.',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              height: 1.45,
              fontWeight: FontWeight.w400,
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 28),
          FilledButton.icon(
            onPressed: () => _openEmail(context),
            icon: const Icon(Icons.mail_outline_rounded),
            label: Text(
              'Email $_contactEmail',
              style: GoogleFonts.montserrat(fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'If the button doesn’t open your mail app, copy the address above into your email client.',
            style: GoogleFonts.montserrat(
              fontSize: 12,
              height: 1.4,
              fontWeight: FontWeight.w500,
              color: cs.outline,
            ),
          ),
        ],
      ),
    );
  }
}
