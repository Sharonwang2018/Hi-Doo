import 'package:flutter/material.dart';

/// First → Finally: large tappable rounded cards with soft fills (retelling scaffolding).
class StoryStructureScaffoldRow extends StatelessWidget {
  const StoryStructureScaffoldRow({
    super.key,
    this.labels = const ['First', 'Next', 'Then', 'Finally'],
  });

  final List<String> labels;

  static const List<String> _emojis = ['🟢', '🟡', '🟠', '🔴'];
  static const List<Color> _bg = [
    Color(0xFFE8F5E9),
    Color(0xFFFFF9E6),
    Color(0xFFFFF3E0),
    Color(0xFFFFEBEE),
  ];

  @override
  Widget build(BuildContext context) {
    final safe = labels.length >= 4 ? labels : ['First', 'Next', 'Then', 'Finally'];
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 5.0;
        final innerW = constraints.maxWidth;
        final totalGaps = gap * 3;
        var cardW = (innerW - totalGaps) / 4;
        // Keep a readable minimum; narrow phones scroll horizontally instead of stacking.
        const minCard = 72.0;
        if (cardW < minCard) cardW = minCard;

        final cards = List.generate(4, (i) {
          return _StepCard(
            emoji: _emojis[i],
            label: '${safe[i]}…',
            background: _bg[i],
            borderColor: cs.outline.withValues(alpha: 0.14),
          );
        });

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < 4; i++)
                SizedBox(
                  width: cardW,
                  child: Padding(
                    padding: EdgeInsets.only(right: i < 3 ? gap : 0),
                    child: cards[i],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.emoji,
    required this.label,
    required this.background,
    required this.borderColor,
  });

  final String emoji;
  final String label;
  final Color background;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 76),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(emoji, style: const TextStyle(fontSize: 28, height: 1)),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: 0.2,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
