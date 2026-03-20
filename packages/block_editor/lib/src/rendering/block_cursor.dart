library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

/// A blinking text cursor widget that overlays a [RichTextRenderer].
///
/// [BlockCursor] renders the block's [TextDelta] via [RichTextRenderer] and
/// paints a blinking caret at cursorOffset when [selection] is a
/// [CollapsedSelection] that belongs to [blockId].
///
/// The blink animation is part of the public API. Supply a custom
/// [Animation<double>] via [animation] to override the default breathing
/// fade. The animation value must be in the range [0.0, 1.0] where 1.0 is
/// fully opaque.
///
/// When no [animation] is supplied, an internal [AnimationController] drives
/// a smooth [Curves.easeInOut] fade over [blinkDuration].
class BlockCursor extends StatefulWidget {
  /// Creates a [BlockCursor] for the block identified by [blockId].
  ///
  /// cursorOffset is the character offset within [delta] at which the
  /// caret is drawn. A value of -1 suppresses the cursor entirely.
  ///
  /// [blinkDuration] controls the length of one full fade-in-then-fade-out
  /// cycle when no external [animation] is provided. Defaults to 1200ms.
  const BlockCursor({
    super.key,
    required this.blockId,
    required this.delta,
    required this.selection,
    this.baseStyle,
    this.cursorColor = const Color(0xFF000000),
    this.cursorWidth = 2.0,
    this.animation,
    this.blinkDuration = const Duration(milliseconds: 1200),
    this.child,
  });

  /// The id of the block this cursor belongs to.
  final String blockId;

  /// The inline content of the block.
  final TextDelta delta;

  /// The current editor selection. The cursor is only visible when this is
  /// a [CollapsedSelection] pointing at [blockId].
  final EditorSelection selection;

  /// The base text style used for layout measurements.
  final TextStyle? baseStyle;

  /// The color of the cursor line.
  final Color cursorColor;

  /// The width of the cursor line in logical pixels.
  final double cursorWidth;

  /// An optional external animation that drives cursor opacity.
  ///
  /// When supplied, [blinkDuration] is ignored and the internal
  /// [AnimationController] is not created.
  final Animation<double>? animation;

  /// The duration of one full blink cycle when using the default animation.
  final Duration blinkDuration;

  /// An optional child widget to paint the cursor over.
  ///
  /// When supplied this widget is used in place of the internally built
  /// [RichTextRenderer]. Use this when [BlockCursor] wraps a [BlockRenderer]
  /// rather than raw text.
  final Widget? child;

  @override
  State<BlockCursor> createState() => _BlockCursorState();
}

class _BlockCursorState extends State<BlockCursor>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    if (widget.animation == null) {
      _controller = AnimationController(
        vsync: this,
        duration: widget.blinkDuration ~/ 2,
      )..repeat(reverse: true);
      _animation = CurvedAnimation(
        parent: _controller!,
        curve: Curves.easeInOut,
      );
    } else {
      _animation = widget.animation!;
    }
  }

  @override
  void didUpdateWidget(BlockCursor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animation != null) {
      _animation = widget.animation!;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  bool get _shouldShowCursor {
    final sel = widget.selection;
    if (sel is! CollapsedSelection) return false;
    if (sel.point.blockId != widget.blockId) return false;
    if (sel.point.offset == -1) return false;
    return true;
  }

  int get _offset {
    final sel = widget.selection as CollapsedSelection;
    return sel.point.offset;
  }

  Widget get _content =>
      widget.child ??
      RichTextRenderer(
        delta: widget.delta,
        blockId: widget.blockId,
        selection: widget.selection,
        baseStyle: widget.baseStyle,
      );

  @override
  Widget build(BuildContext context) {
    if (!_shouldShowCursor) {
      return _content;
    }

    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          foregroundPainter: CursorPainter(
            delta: widget.delta,
            cursorOffset: _offset,
            baseStyle: widget.baseStyle,
            cursorColor: widget.cursorColor.withValues(alpha: _animation.value),
            cursorWidth: widget.cursorWidth,
          ),
          child: child,
        );
      },
      child: _content,
    );
  }
}

class CursorPainter extends CustomPainter {
  CursorPainter({
    required this.delta,
    required this.cursorOffset,
    required this.baseStyle,
    required this.cursorColor,
    required this.cursorWidth,
  });

  final TextDelta delta;
  final int cursorOffset;
  final TextStyle? baseStyle;
  final Color cursorColor;
  final double cursorWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (cursorOffset < 0) return;

    final effectiveStyle = (baseStyle ?? const TextStyle()).copyWith(
      fontSize: baseStyle?.fontSize ?? 16,
    );

    final painter = TextPainter(
      text: TextSpan(text: delta.plainText, style: effectiveStyle),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width);

    final caretOffset = painter.getOffsetForCaret(
      TextPosition(offset: cursorOffset.clamp(0, delta.plainText.length)),
      Rect.fromLTWH(0, 0, cursorWidth, painter.preferredLineHeight),
    );

    final cursorHeight = painter.preferredLineHeight;
    final paint = Paint()
      ..color = cursorColor
      ..strokeWidth = cursorWidth
      ..style = PaintingStyle.fill;

    canvas.drawRect(
      Rect.fromLTWH(caretOffset.dx, caretOffset.dy, cursorWidth, cursorHeight),
      paint,
    );
  }

  @override
  bool shouldRepaint(CursorPainter oldDelegate) {
    return oldDelegate.cursorOffset != cursorOffset ||
        oldDelegate.cursorColor != cursorColor ||
        oldDelegate.delta != delta ||
        oldDelegate.cursorWidth != cursorWidth;
  }
}
