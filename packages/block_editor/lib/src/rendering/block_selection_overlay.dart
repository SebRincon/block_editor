library;

import 'package:block_editor/block_editor.dart';
import 'package:flutter/material.dart';

/// Paints a stable highlight rectangle behind a block.
///
/// Used by [BlockSelectionOverlay] when isCovered is true. Blocks that
/// are only partially covered — the start and end blocks of an
/// [ExpandedSelection] — are highlighted inline by [RichTextRenderer] and
/// do not use this painter.
class SelectionHighlightPainter extends CustomPainter {
  /// Creates a [SelectionHighlightPainter] with the given [color].
  const SelectionHighlightPainter({
    required this.color,
    required this.isCovered,
  });

  /// The color of the highlight rectangle.
  final Color color;

  /// Whether the highlight should be painted.
  final bool isCovered;

  @override
  void paint(Canvas canvas, Size size) {
    if (!isCovered || size.isEmpty) return;
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(SelectionHighlightPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.isCovered != isCovered;
  }
}

/// Wraps a block widget and paints a full-width selection highlight behind
/// it when the block is fully covered by the current selection.
///
/// [isCovered] must be computed by the parent from the current
/// [EditorSelection] and the flattened document order. [BlockSelectionOverlay]
/// is a pure presentation widget — it has no knowledge of document structure.
///
/// Blocks that are partially covered (the anchor or focus block of an
/// [ExpandedSelection]) are highlighted inline by [RichTextRenderer]. This
/// widget handles only fully-covered intermediate blocks.
///
/// The paint layer is kept in the tree even when [isCovered] is false so
/// toggling bulk selection does not swap render object types or perturb the
/// measured size of component blocks.
class BlockSelectionOverlay extends StatelessWidget {
  /// Creates a [BlockSelectionOverlay] for [child].
  ///
  /// [isCovered] is true when this block falls strictly between the start
  /// and end blocks of an [ExpandedSelection] in document order.
  ///
  /// [highlightColor] defaults to a semi-transparent blue consistent with
  /// the inline highlight color used by [RichTextRenderer].
  const BlockSelectionOverlay({
    super.key,
    required this.child,
    required this.isCovered,
    this.highlightColor = const Color(0x663B82F6),
  });

  /// The block widget to wrap.
  final Widget child;

  /// Whether this block is fully covered by the current selection.
  final bool isCovered;

  /// The color of the full-width highlight rectangle.
  final Color highlightColor;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: SelectionHighlightPainter(
        color: highlightColor,
        isCovered: isCovered,
      ),
      child: child,
    );
  }
}
