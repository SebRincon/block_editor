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
  ///
  /// [composingRange] is the active IME composing region. When non-null, the
  /// characters within this range receive an underline decoration at render
  /// time. The range is transient — it is never stored in the document and
  /// never affects serialization.
  ///
  /// Variable resolution for [VariableOp] embeds is read automatically from
  /// the nearest [BlockEditorScope] ancestor via context. No parameter is
  /// needed on this widget.
  const RichTextRenderer({
    super.key,
    required this.delta,
    required this.blockId,
    this.baseStyle,
    this.selection = EditorSelection.none,
    this.selectionColor = const Color(0x443399FF),
    this.inlineCodeColor = const Color(0xFFEEEEEE),
    this.textAlign = TextAlign.start,
    this.composingRange,
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

  /// The active IME composing region, or null when no composition is active.
  ///
  /// When non-null, characters in this range receive a composing underline
  /// that is separate from any [InlineAttributes] formatting. The document
  /// is never modified by this parameter.
  final TextRange? composingRange;

  @override
  Widget build(BuildContext context) {
    final variables = BlockEditorScope.maybeOf(context)?.variables ?? const {};
    final spans = _buildSpans(variables);
    return Text.rich(
      TextSpan(style: baseStyle, children: spans),
      textAlign: textAlign,
      semanticsLabel: delta.plainText,
    );
  }

  List<TextSpan> _buildSpans(Map<String, String> variables) {
    final spans = <TextSpan>[];
    var offset = 0;

    for (final op in delta.ops) {
      if (op is VariableOp) {
        final resolved = variables[op.variableName] ?? '{{${op.variableName}}}';
        spans.add(
          TextSpan(
            text: resolved,
            style: const TextStyle(color: Color(0xFF8B5CF6)),
          ),
        );
        offset += resolved.length;
        continue;
      }

      if (op is TagOp) {
        spans.add(
          TextSpan(
            text: '#${op.tag}',
            style: const TextStyle(color: Color(0xFF0EA5E9)),
          ),
        );
        offset += op.tag.length + 1;
        continue;
      }

      if (op is! TextOp) {
        offset++;
        continue;
      }

      final length = op.text.length;
      final opStart = offset;
      final opEnd = offset + length;

      if (composingRange != null &&
          _overlaps(opStart, opEnd, composingRange!)) {
        spans.addAll(_buildSpansWithComposing(op, opStart, opEnd));
      } else {
        spans.add(_buildSpan(op, opStart, opEnd));
      }

      offset = opEnd;
    }

    return spans;
  }

  bool _overlaps(int opStart, int opEnd, TextRange range) {
    return opStart < range.end && opEnd > range.start;
  }

  List<TextSpan> _buildSpansWithComposing(TextOp op, int opStart, int opEnd) {
    final range = composingRange!;
    final compStart = range.start.clamp(opStart, opEnd);
    final compEnd = range.end.clamp(opStart, opEnd);
    final result = <TextSpan>[];

    if (compStart > opStart) {
      final beforeText = op.text.substring(0, compStart - opStart);
      result.add(
        _buildSpan(
          TextOp(beforeText, attributes: op.attributes),
          opStart,
          compStart,
        ),
      );
    }

    if (compEnd > compStart) {
      final composingText = op.text.substring(
        compStart - opStart,
        compEnd - opStart,
      );
      result.add(
        _buildSpanWithComposingUnderline(
          TextOp(composingText, attributes: op.attributes),
          compStart,
          compEnd,
        ),
      );
    }

    if (compEnd < opEnd) {
      final afterText = op.text.substring(compEnd - opStart);
      result.add(
        _buildSpan(
          TextOp(afterText, attributes: op.attributes),
          compEnd,
          opEnd,
        ),
      );
    }

    return result;
  }

  TextSpan _buildSpanWithComposingUnderline(TextOp op, int start, int end) {
    final attrs = op.attributes;
    final isCode = attrs.inlineCode ?? false;
    final isLink = attrs.link != null;

    final existingDecorations = <TextDecoration>[];
    if (attrs.underline ?? false) {
      existingDecorations.add(TextDecoration.underline);
    }
    if (attrs.strikethrough ?? false) {
      existingDecorations.add(TextDecoration.lineThrough);
    }
    existingDecorations.add(TextDecoration.underline);

    var style = TextStyle(
      fontWeight: (attrs.bold ?? false) ? FontWeight.bold : null,
      fontStyle: (attrs.italic ?? false) ? FontStyle.italic : null,
      decoration: TextDecoration.combine(existingDecorations),
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
