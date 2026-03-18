library;

import 'package:flutter/widgets.dart';
import 'package:block_editor/block_editor.dart';

/// Converts a [TextDelta] into an inline-styled [Text.rich] widget.
///
/// Every text-based block widget delegates inline rendering to this widget.
/// [RichTextRenderer] is stateless and has no dependency on editor focus or
/// controller state beyond the [EditorSelection] it receives for highlight
/// painting.
class RichTextRenderer extends StatelessWidget {
  /// Creates a [RichTextRenderer] for [delta].
  ///
  /// [blockId] identifies which block this renderer belongs to. It is used
  /// to determine whether the current [selection] intersects this block.
  ///
  /// [baseStyle] is inherited by every span. Block widgets supply their own
  /// size, weight, and font through this parameter.
  ///
  /// [selection] drives inline selection highlight painting. Defaults to
  /// [EditorSelection.none].
  ///
  /// [selectionColor] is the background color applied to selected character
  /// ranges. Defaults to a semi-transparent blue.
  ///
  /// [inlineCodeColor] is the background color applied to inline code runs.
  /// Defaults to a light grey.
  const RichTextRenderer({
    super.key,
    required this.delta,
    required this.blockId,
    this.baseStyle,
    this.selection = EditorSelection.none,
    this.selectionColor = const Color(0x443399FF),
    this.inlineCodeColor = const Color(0xFFEEEEEE),
    this.textAlign = TextAlign.start,
  });

  /// The content to render.
  final TextDelta delta;

  /// The id of the block this renderer belongs to.
  final String blockId;

  /// The base [TextStyle] inherited by all spans.
  final TextStyle? baseStyle;

  /// The current editor selection, used to paint inline highlights.
  final EditorSelection selection;

  /// Background color applied to selected character ranges.
  final Color selectionColor;

  /// Background color applied to inline code runs.
  final Color inlineCodeColor;

  /// How the text should be aligned horizontally.
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final spans = _buildSpans();
    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: textAlign,
      semanticsLabel: delta.plainText,
    );
  }

  List<TextSpan> _buildSpans() {
    final spans = <TextSpan>[];
    var offset = 0;

    for (final op in delta.ops) {
      if (op is! TextOp) {
        continue;
      }
      final length = op.text.length;
      spans.add(_buildSpan(op, offset, offset + length));
      offset += length;
    }

    return spans;
  }

  TextSpan _buildSpan(TextOp op, int start, int end) {
    final attrs = op.attributes;
    final isCode = attrs.inlineCode ?? false;
    final isLink = attrs.link != null;

    var style = TextStyle(
      fontWeight: (attrs.bold ?? false) ? FontWeight.bold : null,
      fontStyle: (attrs.italic ?? false) ? FontStyle.italic : null,
      decoration: _buildDecoration(attrs),
      fontFamily: isCode ? 'monospace' : null,
      backgroundColor: isCode ? inlineCodeColor : null,
      color: _resolveColor(attrs, isLink),
    );

    final highlight = _selectionHighlight(start, end);
    if (highlight != null) {
      style = style.copyWith(backgroundColor: highlight);
    }

    return TextSpan(text: op.text, style: style);
  }

  TextDecoration? _buildDecoration(InlineAttributes attrs) {
    final decorations = <TextDecoration>[];
    if (attrs.underline ?? false) decorations.add(TextDecoration.underline);
    if (attrs.strikethrough ?? false) {
      decorations.add(TextDecoration.lineThrough);
    }
    if (decorations.isEmpty) return null;
    return TextDecoration.combine(decorations);
  }

  Color? _resolveColor(InlineAttributes attrs, bool isLink) {
    if (attrs.color != null) {
      return Color(int.parse(attrs.color!.replaceFirst('#', '0xFF')));
    }
    if (isLink) return const Color(0xFF0070F3);
    return null;
  }

  Color? _selectionHighlight(int opStart, int opEnd) {
    final sel = selection;
    switch (sel) {
      case NoSelection():
        return null;
      case CollapsedSelection():
        return null;
      case ExpandedSelection():
        final ids = [blockId];
        final resolved = sel.resolveOrder(ids);
        if (resolved.start.blockId != blockId &&
            resolved.end.blockId != blockId) {
          if (_isBlockFullyCovered(sel)) return selectionColor;
          return null;
        }
        final selStart = resolved.start.blockId == blockId
            ? resolved.start.offset
            : 0;
        final selEnd = resolved.end.blockId == blockId
            ? resolved.end.offset
            : double.maxFinite.toInt();
        if (opStart < selStart || opEnd > selEnd) return null;
        return selectionColor;
    }
  }

  bool _isBlockFullyCovered(ExpandedSelection sel) {
    return sel.anchor.blockId != blockId && sel.focus.blockId != blockId;
  }
}
