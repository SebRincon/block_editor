import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Displays the set of `#tags` currently present in the editor document.
///
/// Rebuilt by the parent whenever the document changes. When [tags] is empty
/// the widget collapses to zero height — it never reserves space when there
/// are no tags to display.
class TagStrip extends StatelessWidget {
  /// Creates a [TagStrip].
  const TagStrip({super.key, required this.tags});

  final Set<String> tags;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Text(
            'Tags',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: tags
                    .map(
                      (tag) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: _TagChip(tag: tag, colors: colors),
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag, required this.colors});

  final String tag;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.accent.withValues(alpha: 0.25)),
      ),
      child: Text(
        '#$tag',
        style: TextStyle(
          color: colors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
