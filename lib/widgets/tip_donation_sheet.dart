import 'package:echo_reading/env_config.dart';
import 'package:echo_reading/utils/donation_url_launch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

/// Khan Academy–style mission support: optional external donation link (Buy Me a Coffee, Stripe, etc.).
Future<void> showMissionSupportSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: true,
    enableDrag: true,
    showDragHandle: true,
    backgroundColor: cs.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          bottom: MediaQuery.paddingOf(ctx).bottom + 16,
          top: 8,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Support Literacy for All 🌟',
                textAlign: TextAlign.center,
                style: GoogleFonts.quicksand(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: cs.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'Hi-Doo is a non-profit. Your support helps us provide AI reading tools to children who need them most.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                      height: 1.45,
                      color: cs.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Hi-Doo is free for families—always. If you can help, thank you.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      height: 1.35,
                      color: cs.outlineVariant,
                      fontSize: 12,
                    ),
              ),
              const SizedBox(height: 22),
              if (EnvConfig.hasDonationUrl) ...[
                FilledButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(EnvConfig.donationUrl.trim());
                    await launchExternalDonationUrl(ctx, uri);
                  },
                  icon: const Icon(Icons.favorite_rounded),
                  label: const Text('Sponsor a Reader'),
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(EnvConfig.donationUrl.trim());
                    await Clipboard.setData(ClipboardData(text: uri.toString()));
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                        const SnackBar(content: Text('Sponsor link copied.')),
                      );
                    }
                  },
                  icon: const Icon(Icons.link_rounded, size: 18),
                  label: const Text('Copy sponsor link'),
                ),
              ] else ...[
                Text(
                  'No sponsor URL is baked into this build. Developers: set DONATION_URL when running flutter build (see run_all.sh).',
                  textAlign: TextAlign.center,
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                        color: cs.outline,
                        fontStyle: FontStyle.italic,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () {
                    showDialog<void>(
                      context: ctx,
                      builder: (dCtx) => AlertDialog(
                        title: const Text('Enable “Sponsor a Reader”'),
                        content: const Text(
                          'Before building the web app, export a full https URL, for example:\n\n'
                          'export DONATION_URL="https://buymeacoffee.com/yourpage"\n'
                          './run_all.sh\n\n'
                          'DONATION_URL is passed as --dart-define; it is not read from api/.env.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dCtx),
                            child: const Text('OK'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: const Text('How to add a donation link'),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                'If you see a daily usage limit, try again tomorrow—our small servers need a breather too.',
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                      fontSize: 11,
                      height: 1.35,
                      color: cs.outlineVariant,
                    ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: cs.onSurfaceVariant.withValues(alpha: 0.75),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text('Continue'),
              ),
            ],
          ),
        ),
      );
    },
  );
}
