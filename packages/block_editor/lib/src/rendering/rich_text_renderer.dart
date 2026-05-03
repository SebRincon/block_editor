library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';
import 'editor_span_builder.dart';

/// Converts a [TextDelta] into an inline-styled [Text.rich] widget.
///
/// When [CursorColorScope] is present and [selection] is a [CollapsedSelection]
/// for [blockId], a blinking caret is painted. The caret uses the actual
/// rendered width of the [Text.rich] widget — obtained via a [GlobalKey] after
/// layout — so the [TextPainter] measurement wraps identically to the rendered
/// text regardless of how parent widgets constrain the editor.
class RichTextRenderer extends StatelessWidget {
  /// Creates a [RichTextRenderer] for [delta].
  const RichTextRenderer({
    super.key,
    required this.delta,
    required this.blockId,
    this.baseStyle,
    this.selection = EditorSelection.none,
    this.selectionColor,
    this.inlineCodeColor,
    this.textAlign = TextAlign.start,
    this.composingRange,
    this.cursorColor,
    this.cursorWidth = 2.0,
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
  final Color? selectionColor;

  /// Background color applied to inline code runs.
  final Color? inlineCodeColor;

  /// How the text should be aligned horizontally.
  final TextAlign textAlign;

  /// The active IME composing region, or null when no composition is active.
  final TextRange? composingRange;

  /// When non-null and [selection] is a [CollapsedSelection] for [blockId],
  /// a blinking caret is painted at the cursor position with this color.
  final Color? cursorColor;

  /// The width of the caret in logical pixels.
  final double cursorWidth;

  @override
  Widget build(BuildContext context) {
    final variables = BlockEditorScope.maybeOf(context)?.variables ?? const {};
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final effectiveBase = resolveBlockEditorTextStyle(context, baseStyle);
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);
    final spans = _buildSpans(variables, editorTheme);
    final textWidget = Text.rich(
      TextSpan(style: effectiveBase, children: spans),
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
      semanticsLabel: delta.plainText,
      textHeightBehavior: blockEditorTextHeightBehavior,
    );

    final sel = selection;
    final isCursorBlock =
        sel is CollapsedSelection &&
        sel.point.blockId == blockId &&
        sel.point.offset >= 0;

    if (!isCursorBlock) return textWidget;

    final scope = CursorColorScope.maybeOf(context);
    final activeCursorColor = cursorColor ?? scope?.color;
    if (activeCursorColor == null) return textWidget;

    final effectiveCursorWidth = scope?.cursorWidth ?? cursorWidth;
    final cursorOff = (sel).point.offset;

    return LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = constraints.maxWidth;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            textWidget,
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _InlineCursorPainter(
                    delta: delta,
                    baseStyle: effectiveBase,
                    variables: variables,
                    cursorOffset: cursorOff,
                    cursorColor: activeCursorColor,
                    cursorWidth: effectiveCursorWidth,
                    textWidth: textWidth,
                    textAlign: textAlign,
                    textDirection: textDirection,
                    textScaler: textScaler,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  List<TextSpan> _buildSpans(
    Map<String, String> variables,
    BlockEditorThemeData editorTheme,
  ) {
    final spans = <TextSpan>[];
    var offset = 0;

    final selRange = _resolvedSelectionRange();
    final activeSelectionColor = selectionColor ?? editorTheme.selection;

    for (final op in delta.ops) {
      if (op is VariableOp) {
        final resolved = variables[op.variableName] ?? '{{${op.variableName}}}';
        final opStart = offset;
        final opEnd = offset + 1;
        final highlight =
            selRange != null && opStart >= selRange.$1 && opEnd <= selRange.$2
            ? activeSelectionColor
            : null;
        spans.add(
          TextSpan(
            text: resolved,
            style: TextStyle(
              color: editorTheme.variable,
              backgroundColor: highlight,
            ),
          ),
        );
        offset += 1;
        continue;
      }
      if (op is TagOp) {
        final opStart = offset;
        final opEnd = offset + 1;
        final highlight =
            selRange != null && opStart >= selRange.$1 && opEnd <= selRange.$2
            ? activeSelectionColor
            : null;
        spans.add(
          TextSpan(
            text: '#${op.tag}',
            style: TextStyle(
              color: editorTheme.tag,
              backgroundColor: highlight,
            ),
          ),
        );
        offset += 1;
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
        spans.addAll(_buildSpansWithComposing(op, opStart, opEnd, editorTheme));
      } else if (selRange != null &&
          _overlaps(
            opStart,
            opEnd,
            TextRange(start: selRange.$1, end: selRange.$2),
          )) {
        spans.addAll(
          _buildSpansWithSelection(
            op,
            opStart,
            opEnd,
            selRange.$1,
            selRange.$2,
            editorTheme,
          ),
        );
      } else {
        spans.add(_buildSpan(op, opStart, opEnd, editorTheme));
      }
      offset = opEnd;
    }
    return spans;
  }

  (int, int)? _resolvedSelectionRange() {
    final sel = selection;
    if (sel is! ExpandedSelection) return null;
    final anchorId = sel.anchor.blockId;
    final focusId = sel.focus.blockId;
    if (anchorId == focusId) {
      if (blockId != anchorId) return null;
      final s = sel.anchor.offset <= sel.focus.offset
          ? sel.anchor.offset
          : sel.focus.offset;
      final e = sel.anchor.offset <= sel.focus.offset
          ? sel.focus.offset
          : sel.anchor.offset;
      return (s, e);
    }
    if (blockId == anchorId) {
      return (sel.anchor.offset, delta.plainText.length);
    }
    if (blockId == focusId) {
      return (0, sel.focus.offset);
    }
    if (blockId != anchorId && blockId != focusId) {
      return (0, delta.plainText.length);
    }
    return null;
  }

  List<TextSpan> _buildSpansWithSelection(
    TextOp op,
    int opStart,
    int opEnd,
    int selStart,
    int selEnd,
    BlockEditorThemeData editorTheme,
  ) {
    final result = <TextSpan>[];
    final clipStart = selStart.clamp(opStart, opEnd);
    final clipEnd = selEnd.clamp(opStart, opEnd);
    if (clipStart > opStart) {
      result.add(
        _buildSpan(
          TextOp(
            op.text.substring(0, clipStart - opStart),
            attributes: op.attributes,
          ),
          opStart,
          clipStart,
          editorTheme,
        ),
      );
    }
    if (clipEnd > clipStart) {
      final selected = TextOp(
        op.text.substring(clipStart - opStart, clipEnd - opStart),
        attributes: op.attributes,
      );
      var style = _spanStyle(selected, editorTheme);
      style = style.copyWith(
        backgroundColor: selectionColor ?? editorTheme.selection,
      );
      result.add(TextSpan(text: selected.text, style: style));
    }
    if (clipEnd < opEnd) {
      result.add(
        _buildSpan(
          TextOp(
            op.text.substring(clipEnd - opStart),
            attributes: op.attributes,
          ),
          clipEnd,
          opEnd,
          editorTheme,
        ),
      );
    }
    return result;
  }

  TextStyle _spanStyle(TextOp op, BlockEditorThemeData editorTheme) {
    final attrs = op.attributes;
    final isCode = attrs.inlineCode ?? false;
    final isLink = attrs.link != null;
    return TextStyle(
      fontWeight: (attrs.bold ?? false) ? FontWeight.bold : null,
      fontStyle: (attrs.italic ?? false) ? FontStyle.italic : null,
      decoration: _buildDecoration(attrs),
      fontFamily: isCode ? 'monospace' : null,
      backgroundColor: _resolveBackgroundColor(attrs, editorTheme),
      color: _resolveColor(attrs, isLink, editorTheme),
    );
  }

  bool _overlaps(int opStart, int opEnd, TextRange range) =>
      opStart < range.end && opEnd > range.start;

  List<TextSpan> _buildSpansWithComposing(
    TextOp op,
    int opStart,
    int opEnd,
    BlockEditorThemeData editorTheme,
  ) {
    final range = composingRange!;
    final compStart = range.start.clamp(opStart, opEnd);
    final compEnd = range.end.clamp(opStart, opEnd);
    final result = <TextSpan>[];
    if (compStart > opStart) {
      result.add(
        _buildSpan(
          TextOp(
            op.text.substring(0, compStart - opStart),
            attributes: op.attributes,
          ),
          opStart,
          compStart,
          editorTheme,
        ),
      );
    }
    if (compEnd > compStart) {
      result.add(
        _buildSpanWithComposingUnderline(
          TextOp(
            op.text.substring(compStart - opStart, compEnd - opStart),
            attributes: op.attributes,
          ),
          compStart,
          compEnd,
          editorTheme,
        ),
      );
    }
    if (compEnd < opEnd) {
      result.add(
        _buildSpan(
          TextOp(
            op.text.substring(compEnd - opStart),
            attributes: op.attributes,
          ),
          compEnd,
          opEnd,
          editorTheme,
        ),
      );
    }
    return result;
  }

  TextSpan _buildSpanWithComposingUnderline(
    TextOp op,
    int start,
    int end,
    BlockEditorThemeData editorTheme,
  ) {
    final attrs = op.attributes;
    final isCode = attrs.inlineCode ?? false;
    final isLink = attrs.link != null;
    final decorations = <TextDecoration>[TextDecoration.underline];
    if (attrs.underline ?? false) decorations.add(TextDecoration.underline);
    if (attrs.strikethrough ?? false) {
      decorations.add(TextDecoration.lineThrough);
    }
    final style = TextStyle(
      fontWeight: (attrs.bold ?? false) ? FontWeight.bold : null,
      fontStyle: (attrs.italic ?? false) ? FontStyle.italic : null,
      decoration: TextDecoration.combine(decorations),
      fontFamily: isCode ? 'monospace' : null,
      backgroundColor: _resolveBackgroundColor(attrs, editorTheme),
      color: _resolveColor(attrs, isLink, editorTheme),
    );
    return TextSpan(text: op.text, style: style);
  }

  TextSpan _buildSpan(
    TextOp op,
    int start,
    int end,
    BlockEditorThemeData editorTheme,
  ) {
    final attrs = op.attributes;
    final isCode = attrs.inlineCode ?? false;
    final isLink = attrs.link != null;
    final style = TextStyle(
      fontWeight: (attrs.bold ?? false) ? FontWeight.bold : null,
      fontStyle: (attrs.italic ?? false) ? FontStyle.italic : null,
      decoration: _buildDecoration(attrs),
      fontFamily: isCode ? 'monospace' : null,
      backgroundColor: _resolveBackgroundColor(attrs, editorTheme),
      color: _resolveColor(attrs, isLink, editorTheme),
    );
    return TextSpan(text: op.text, style: style);
  }

  TextDecoration? _buildDecoration(InlineAttributes attrs) {
    final d = <TextDecoration>[];
    if (attrs.underline ?? false) d.add(TextDecoration.underline);
    if (attrs.strikethrough ?? false) d.add(TextDecoration.lineThrough);
    if (d.isEmpty) return null;
    return TextDecoration.combine(d);
  }

  Color? _resolveColor(
    InlineAttributes attrs,
    bool isLink,
    BlockEditorThemeData editorTheme,
  ) {
    if (attrs.color != null) {
      return Color(int.parse(attrs.color!.replaceFirst('#', '0xFF')));
    }
    if (isLink) return editorTheme.primary;
    return null;
  }

  Color? _resolveBackgroundColor(
    InlineAttributes attrs,
    BlockEditorThemeData editorTheme,
  ) {
    final isCode = attrs.inlineCode ?? false;
    if (isCode) return inlineCodeColor ?? editorTheme.inlineCodeBackground;
    if (attrs.backgroundColor != null) {
      return Color(int.parse(attrs.backgroundColor!.replaceFirst('#', '0xFF')));
    }
    return null;
  }
}

class _InlineCursorPainter extends CustomPainter {
  _InlineCursorPainter({
    required this.delta,
    required this.baseStyle,
    required this.variables,
    required this.cursorOffset,
    required this.cursorColor,
    required this.cursorWidth,
    required this.textWidth,
    required this.textAlign,
    required this.textDirection,
    required this.textScaler,
  });

  final TextDelta delta;
  final TextStyle baseStyle;
  final Map<String, String> variables;
  final int cursorOffset;
  final Color cursorColor;
  final double cursorWidth;
  final double textWidth;
  final TextAlign textAlign;
  final TextDirection textDirection;
  final TextScaler textScaler;

  @override
  void paint(Canvas canvas, Size size) {
    if (cursorOffset < 0) return;

    final span = buildMeasurementSpan(delta, baseStyle, variables);
    final maxWidth = textWidth.isFinite ? textWidth : size.width;
    final painter = TextPainter(
      text: span,
      textAlign: textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
      textHeightBehavior: blockEditorTextHeightBehavior,
    )..layout(maxWidth: maxWidth);

    final visualOffset = modelToVisualOffset(delta, cursorOffset, variables);
    final plainVisualLength = span.toPlainText().length;
    final clampedOffset = visualOffset.clamp(0, plainVisualLength);

    final position = TextPosition(offset: clampedOffset);
    final caretPrototype = Rect.fromLTWH(
      0,
      0,
      cursorWidth,
      painter.preferredLineHeight,
    );
    final caretOffset = painter.getOffsetForCaret(position, caretPrototype);
    final caretHeight = painter.getFullHeightForCaret(position, caretPrototype);

    final scale = painter.height > 0 ? size.height / painter.height : 1.0;
    final cursorTop = caretOffset.dy * scale;
    final scaledCaretHeight = caretHeight * scale;

    canvas.drawRect(
      Rect.fromLTWH(caretOffset.dx, cursorTop, cursorWidth, scaledCaretHeight),
      Paint()
        ..color = cursorColor
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(_InlineCursorPainter old) =>
      old.cursorOffset != cursorOffset ||
      old.cursorColor != cursorColor ||
      old.delta != delta ||
      old.textWidth != textWidth ||
      old.textAlign != textAlign ||
      old.textDirection != textDirection ||
      old.textScaler != textScaler;
}
