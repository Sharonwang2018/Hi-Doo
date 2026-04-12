import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mission, program copy, and COPPA — shown from scan screen menu (not on camera view).
Future<void> showScanAboutSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.55,
        minChildSize: 0.35,
        maxChildSize: 0.92,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.paddingOf(context).bottom,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'About Hi-Doo',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Beyond reading: Unlock their understanding.',
                  style: GoogleFonts.montserrat(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: cs.onSurface,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "Free for families. Scan any child's book ISBN. Choose a challenge: Detail Detective (Quiz), Master Storyteller (Retell), or do both! Or, simply log your book to keep your reading streak alive.",
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'COPPA Compliant',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Hi-Doo is designed for families and educators. We do not knowingly collect '
                  'personal information from children under 13 for marketing or profiling. '
                  'Reading activity you save is tied only to your own account when you choose to sign in.',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                    height: 1.5,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
