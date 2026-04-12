import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/utils/donation_url_launch.dart';
import 'package:echo_reading/widgets/tip_donation_sheet.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mission, COPPA note, text link to support.
class NgoFooter extends StatelessWidget {
  const NgoFooter({super.key});

  Future<void> _openSupport(BuildContext context) async {
    if (EnvConfig.hasDonationUrl) {
      final uri = Uri.parse(EnvConfig.donationUrl.trim());
      await launchExternalDonationUrl(context, uri);
      return;
    }
    if (context.mounted) {
      await showMissionSupportSheet(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withAlpha(200),
        border: Border(
          top: BorderSide(color: cs.outlineVariant.withAlpha(128)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'A non-profit project dedicated to children\'s literacy.',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.4,
              color: cs.onSurface,
            ),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 18),
            decoration: BoxDecoration(
              color: cs.primaryContainer.withAlpha(80),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: cs.primary.withAlpha(60)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'COPPA Compliant',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Hi-Doo is designed for families and educators. We do not knowingly collect '
                  'personal information from children under 13 for marketing or profiling. '
                  'Reading activity you save is tied only to your own account when you choose to sign in.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.montserrat(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            '© ${DateTime.now().year} Hi-Doo',
            textAlign: TextAlign.center,
            style: GoogleFonts.montserrat(
              fontSize: 11,
              fontWeight: FontWeight.w400,
              color: cs.outline,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: () => _openSupport(context),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text(
                'Support our mission',
                style: GoogleFonts.montserrat(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                  decorationColor: cs.primary.withValues(alpha: 0.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
