import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Mission, program copy, COPPA, and research-informed product direction.
Future<void> showScanAboutSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  TextStyle sectionTitle() => GoogleFonts.montserrat(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.3,
        color: cs.primary,
      );
  TextStyle body() => GoogleFonts.montserrat(
        fontSize: 13.5,
        height: 1.5,
        fontWeight: FontWeight.w400,
        color: cs.onSurfaceVariant,
      );

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return DraggableScrollableSheet(
        initialChildSize: 0.62,
        minChildSize: 0.38,
        maxChildSize: 0.94,
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
                  "Free for families. Scan a child's book ISBN, then choose a challenge: "
                  'Detail Detective (quiz questions) and Master Storyteller (retell) map to the classic loop below — '
                  'or simply log a book to keep a reading streak.',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w400,
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 22),
                Text('Read → question → retell', style: sectionTitle()),
                const SizedBox(height: 8),
                Text(
                  'Strong programs emphasize input, then sense-making (questions, clues), then output in the child’s own words. '
                  'Hi-Doo is built around that cycle so comprehension—not just page count—is the point.',
                  style: body(),
                ),
                const SizedBox(height: 22),
                Text('What educators and families often look for', style: sectionTitle()),
                const SizedBox(height: 8),
                Text(
                  '• Age- or level-appropriate reading choices (graded reading mindset)\n'
                  '• Short AI-assisted prompts after reading, plus time to retell\n'
                  '• Check-ins with a parent or teacher—sometimes in role-play—to strengthen expression in English, Chinese, or both\n'
                  '• Clear feedback, badges, or small wins so practice feels motivating\n\n'
                  'We use this landscape as a compass: Hi-Doo today focuses on scan-to-challenge flow, streaks, and respectful AI help where it fits.',
                  style: body(),
                ),
                const SizedBox(height: 22),
                Text('Design for children', style: sectionTitle()),
                const SizedBox(height: 8),
                Text(
                  'Kids need simple paths and quick encouragement. We keep improving clarity, delight, and positive feedback so the app feels approachable—not like homework software.',
                  style: body(),
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
                const SizedBox(height: 16),
                Text(
                  'Have research, school partnership, or product ideas? Use Contact us in the ⋮ menu (hello@hidoo.org).',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    color: cs.onSurfaceVariant.withValues(alpha: 0.9),
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
