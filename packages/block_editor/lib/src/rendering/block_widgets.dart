library;

import 'dart:math' as math;

import 'package:flutter/gestures.dart' show GestureBinding, PointerScrollEvent;
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:block_editor/block_editor.dart';
import 'embedded_text_editing_shortcuts.dart';
import 'editor_span_builder.dart';
import 'source_syntax_highlighter.dart';

InputDecoration _embeddedTextFieldDecoration({
  EdgeInsetsGeometry contentPadding = EdgeInsets.zero,
  String? hintText,
  TextStyle? hintStyle,
}) {
  return InputDecoration(
    isDense: true,
    filled: false,
    fillColor: Colors.transparent,
    hoverColor: Colors.transparent,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: contentPadding,
    hintText: hintText,
    hintStyle: hintStyle,
  );
}

double _textLineHeight(TextStyle style) {
  final fontSize = style.fontSize ?? 16;
  return fontSize * (style.height ?? 1.0);
}

TextStyle _sourceEditorTextStyle(
  BuildContext context,
  MarkdownDocumentThemeData markdownTheme,
) {
  final configuredStyle = BlockEditorScope.maybeOf(
    context,
  )?.sourceEditingConfig?.textStyle;
  final base =
      configuredStyle ??
      const TextStyle(
        fontFamily: 'Cascadia Mono',
        fontFamilyFallback: [
          'JetBrains Mono',
          'Fira Code',
          'MesloLGS NF',
          'Monaco',
          'monospace',
        ],
        fontSize: 13,
        height: 1.45,
        letterSpacing: 0,
      );
  return base.copyWith(
    color: base.color ?? markdownTheme.codeBlockForeground,
    fontSize: base.fontSize ?? 13,
    height: base.height ?? 1.45,
    letterSpacing: 0,
  );
}

TextStyle _sourceLabelTextStyle(TextStyle sourceStyle, Color color) {
  return TextStyle(
    fontFamily: sourceStyle.fontFamily,
    fontFamilyFallback: sourceStyle.fontFamilyFallback,
    fontSize: 12,
    color: color,
    height: 1,
    letterSpacing: 0,
  );
}

Color _effectiveCursorColor(
  BuildContext context,
  BlockEditorThemeData editorTheme,
) {
  return BlockEditorScope.maybeOf(context)?.cursorColor ?? editorTheme.cursor;
}

Color _effectiveSelectionColor(
  BuildContext context,
  BlockEditorThemeData editorTheme,
) {
  return BlockEditorScope.maybeOf(context)?.selectionColor ??
      editorTheme.selection;
}

TextSelectionThemeData _embeddedTextSelectionTheme(
  BuildContext context,
  BlockEditorThemeData editorTheme,
) {
  final cursor = _effectiveCursorColor(context, editorTheme);
  final selection = _effectiveSelectionColor(context, editorTheme);
  return TextSelectionThemeData(
    cursorColor: cursor,
    selectionColor: selection,
    selectionHandleColor: cursor,
  );
}

TextSpan _highlightEmbeddedSource(
  BuildContext context, {
  required String blockId,
  required String source,
  required String language,
  required TextStyle baseStyle,
}) {
  final editorTheme = BlockEditorThemeData.fromContext(context);
  final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
  final highlighter = BlockEditorScope.maybeOf(
    context,
  )?.sourceEditingConfig?.highlighter;
  if (highlighter != null) {
    try {
      return highlighter(
        BlockSourceHighlightRequest(
          blockId: blockId,
          source: source,
          language: language,
          baseStyle: baseStyle,
          editorTheme: editorTheme,
          markdownTheme: markdownTheme,
        ),
      );
    } catch (_) {
      // Embedded source highlighting is decorative. Keep editing available if a
      // host highlighter rejects a language or is not warmed up yet.
    }
  }
  return buildHighlightedSourceSpan(
    source,
    language: language,
    baseStyle: baseStyle,
    editorTheme: editorTheme,
    markdownTheme: markdownTheme,
  );
}

Widget _offsetMarker(double dy, Widget child) {
  if (dy == 0) return child;
  return Transform.translate(offset: Offset(0, dy), child: child);
}

({int offset, TextAffinity affinity}) _resolveOffset(
  GlobalKey key,
  Offset globalPosition,
  TextDelta delta,
  TextStyle baseStyle,
  Map<String, String> variables,
) {
  final renderBox = key.currentContext?.findRenderObject() as RenderBox?;
  if (renderBox == null) {
    return (offset: 0, affinity: TextAffinity.downstream);
  }

  final context = key.currentContext!;
  final localPosition = renderBox.globalToLocal(globalPosition);
  final constrainedWidth = renderBox.size.width;
  final renderedHeight = renderBox.size.height;
  final effectiveBase = resolveBlockEditorTextStyle(context, baseStyle);
  final markdownTheme = MarkdownDocumentThemeData.fromContext(context);

  final span = buildMeasurementSpan(
    delta,
    effectiveBase,
    variables,
    markdownTheme,
  );
  final painter = TextPainter(
    text: span,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    textHeightBehavior: blockEditorTextHeightBehavior,
  )..layout(maxWidth: constrainedWidth);

  final scale = renderedHeight > 0 && painter.height > 0
      ? painter.height / renderedHeight
      : 1.0;
  final scaledPosition = Offset(localPosition.dx, localPosition.dy * scale);

  final visualPosition = painter.getPositionForOffset(scaledPosition);
  return (
    offset: visualToModelOffset(delta, visualPosition.offset, variables),
    affinity: visualPosition.affinity,
  );
}

/// A paragraph block widget.
class ParagraphWidget extends StatefulWidget {
  /// Creates a [ParagraphWidget] for the block identified by [blockId].
  const ParagraphWidget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<ParagraphWidget> createState() => _ParagraphWidgetState();
}

class _ParagraphWidgetState extends State<ParagraphWidget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = markdownTheme.paragraphStyle;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        onTapDown: (details) {
          final position = _resolveOffset(
            _textKey,
            details.globalPosition,
            widget.delta,
            baseStyle,
            BlockEditorScope.maybeOf(context)?.variables ?? const {},
          );
          widget.onEvent(
            TapEvent(
              blockId: widget.blockId,
              offset: position.offset,
              affinity: position.affinity,
            ),
          );
        },
        child: RichTextRenderer(
          key: _textKey,
          delta: widget.delta,
          blockId: widget.blockId,
          selection: widget.selection,
          baseStyle: baseStyle,
        ),
      ),
    );
  }
}

/// A heading level 1 block widget.
class H1Widget extends StatefulWidget {
  /// Creates an [H1Widget] for the block identified by [blockId].
  const H1Widget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<H1Widget> createState() => _H1WidgetState();
}

class _H1WidgetState extends State<H1Widget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = markdownTheme.heading1Style;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        onTapDown: (details) {
          final position = _resolveOffset(
            _textKey,
            details.globalPosition,
            widget.delta,
            baseStyle,
            BlockEditorScope.maybeOf(context)?.variables ?? const {},
          );
          widget.onEvent(
            TapEvent(
              blockId: widget.blockId,
              offset: position.offset,
              affinity: position.affinity,
            ),
          );
        },
        child: RichTextRenderer(
          key: _textKey,
          delta: widget.delta,
          blockId: widget.blockId,
          selection: widget.selection,
          baseStyle: baseStyle,
        ),
      ),
    );
  }
}

/// A heading level 2 block widget.
class H2Widget extends StatefulWidget {
  /// Creates an [H2Widget] for the block identified by [blockId].
  const H2Widget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<H2Widget> createState() => _H2WidgetState();
}

class _H2WidgetState extends State<H2Widget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = markdownTheme.heading2Style;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        onTapDown: (details) {
          final position = _resolveOffset(
            _textKey,
            details.globalPosition,
            widget.delta,
            baseStyle,
            BlockEditorScope.maybeOf(context)?.variables ?? const {},
          );
          widget.onEvent(
            TapEvent(
              blockId: widget.blockId,
              offset: position.offset,
              affinity: position.affinity,
            ),
          );
        },
        child: RichTextRenderer(
          key: _textKey,
          delta: widget.delta,
          blockId: widget.blockId,
          selection: widget.selection,
          baseStyle: baseStyle,
        ),
      ),
    );
  }
}

/// A heading level 3 block widget.
class H3Widget extends StatefulWidget {
  /// Creates an [H3Widget] for the block identified by [blockId].
  const H3Widget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<H3Widget> createState() => _H3WidgetState();
}

class _H3WidgetState extends State<H3Widget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = markdownTheme.heading3Style;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        onTapDown: (details) {
          final position = _resolveOffset(
            _textKey,
            details.globalPosition,
            widget.delta,
            baseStyle,
            BlockEditorScope.maybeOf(context)?.variables ?? const {},
          );
          widget.onEvent(
            TapEvent(
              blockId: widget.blockId,
              offset: position.offset,
              affinity: position.affinity,
            ),
          );
        },
        child: RichTextRenderer(
          key: _textKey,
          delta: widget.delta,
          blockId: widget.blockId,
          selection: widget.selection,
          baseStyle: baseStyle,
        ),
      ),
    );
  }
}

/// A heading level 4 block widget.
class H4Widget extends StatefulWidget {
  /// Creates an [H4Widget] for the block identified by [blockId].
  const H4Widget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<H4Widget> createState() => _H4WidgetState();
}

class _H4WidgetState extends State<H4Widget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = markdownTheme.heading4Style;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        onTapDown: (details) {
          final position = _resolveOffset(
            _textKey,
            details.globalPosition,
            widget.delta,
            baseStyle,
            BlockEditorScope.maybeOf(context)?.variables ?? const {},
          );
          widget.onEvent(
            TapEvent(
              blockId: widget.blockId,
              offset: position.offset,
              affinity: position.affinity,
            ),
          );
        },
        child: RichTextRenderer(
          key: _textKey,
          delta: widget.delta,
          blockId: widget.blockId,
          selection: widget.selection,
          baseStyle: baseStyle,
        ),
      ),
    );
  }
}

/// A heading level 5 block widget.
class H5Widget extends StatefulWidget {
  /// Creates an [H5Widget] for the block identified by [blockId].
  const H5Widget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<H5Widget> createState() => _H5WidgetState();
}

class _H5WidgetState extends State<H5Widget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = markdownTheme.heading5Style;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        onTapDown: (details) {
          final position = _resolveOffset(
            _textKey,
            details.globalPosition,
            widget.delta,
            baseStyle,
            BlockEditorScope.maybeOf(context)?.variables ?? const {},
          );
          widget.onEvent(
            TapEvent(
              blockId: widget.blockId,
              offset: position.offset,
              affinity: position.affinity,
            ),
          );
        },
        child: RichTextRenderer(
          key: _textKey,
          delta: widget.delta,
          blockId: widget.blockId,
          selection: widget.selection,
          baseStyle: baseStyle,
        ),
      ),
    );
  }
}

/// A heading level 6 block widget.
class H6Widget extends StatefulWidget {
  /// Creates an [H6Widget] for the block identified by [blockId].
  const H6Widget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<H6Widget> createState() => _H6WidgetState();
}

class _H6WidgetState extends State<H6Widget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = markdownTheme.heading6Style;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        onTapDown: (details) {
          final position = _resolveOffset(
            _textKey,
            details.globalPosition,
            widget.delta,
            baseStyle,
            BlockEditorScope.maybeOf(context)?.variables ?? const {},
          );
          widget.onEvent(
            TapEvent(
              blockId: widget.blockId,
              offset: position.offset,
              affinity: position.affinity,
            ),
          );
        },
        child: RichTextRenderer(
          key: _textKey,
          delta: widget.delta,
          blockId: widget.blockId,
          selection: widget.selection,
          baseStyle: baseStyle,
        ),
      ),
    );
  }
}

/// A bullet list item block widget.
class BulletListWidget extends StatefulWidget {
  /// Creates a [BulletListWidget] for the block identified by [blockId].
  const BulletListWidget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.attributes,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// The block attributes. Used to read the indent level.
  final Map<String, dynamic> attributes;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<BulletListWidget> createState() => _BulletListWidgetState();
}

class _BulletListWidgetState extends State<BulletListWidget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final indent = (widget.attributes['indent'] as int? ?? 0).clamp(0, 10);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = markdownTheme.paragraphStyle;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: indent * markdownTheme.listIndentWidth,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: markdownTheme.listMarkerWidth,
            child: _offsetMarker(
              markdownTheme.bulletListMarkerVerticalOffset,
              SizedBox(
                height: _textLineHeight(baseStyle),
                child: Center(
                  child: _BulletMarker(
                    indent: indent.toInt(),
                    style: markdownTheme.listMarkerStyle,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: GestureDetector(
                onTapDown: (details) {
                  final position = _resolveOffset(
                    _textKey,
                    details.globalPosition,
                    widget.delta,
                    baseStyle,
                    BlockEditorScope.maybeOf(context)?.variables ?? const {},
                  );
                  widget.onEvent(
                    TapEvent(
                      blockId: widget.blockId,
                      offset: position.offset,
                      affinity: position.affinity,
                    ),
                  );
                },
                child: RichTextRenderer(
                  key: _textKey,
                  delta: widget.delta,
                  blockId: widget.blockId,
                  selection: widget.selection,
                  baseStyle: baseStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _BulletMarkerVariant { filledCircle, invertedCircle, invertedSquare }

class _BulletMarker extends StatelessWidget {
  const _BulletMarker({required this.indent, required this.style});

  final int indent;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final color = style.color ?? editorTheme.mutedForeground;
    final variant = switch (indent % 3) {
      1 => _BulletMarkerVariant.invertedCircle,
      2 => _BulletMarkerVariant.invertedSquare,
      _ => _BulletMarkerVariant.filledCircle,
    };
    final size = switch (variant) {
      _BulletMarkerVariant.filledCircle => 5.5,
      _BulletMarkerVariant.invertedCircle => 7.0,
      _BulletMarkerVariant.invertedSquare => 6.0,
    };

    return Semantics(
      label: 'Bullet marker',
      child: CustomPaint(
        key: ValueKey<String>('block-editor-bullet-marker-${variant.name}'),
        size: Size.square(size),
        painter: _BulletMarkerPainter(
          variant: variant,
          color: color,
          surface: editorTheme.background,
        ),
      ),
    );
  }
}

class _BulletMarkerPainter extends CustomPainter {
  const _BulletMarkerPainter({
    required this.variant,
    required this.color,
    required this.surface,
  });

  final _BulletMarkerVariant variant;
  final Color color;
  final Color surface;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paint = Paint()..isAntiAlias = true;

    switch (variant) {
      case _BulletMarkerVariant.filledCircle:
        canvas.drawCircle(
          center,
          size.shortestSide / 2,
          paint..color = color.withValues(alpha: 0.86),
        );
      case _BulletMarkerVariant.invertedCircle:
        canvas.drawCircle(
          center,
          size.shortestSide / 2 - 0.6,
          paint..color = surface,
        );
        canvas.drawCircle(
          center,
          size.shortestSide / 2 - 0.8,
          Paint()
            ..isAntiAlias = true
            ..color = color.withValues(alpha: 0.82)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.25,
        );
      case _BulletMarkerVariant.invertedSquare:
        final rect = Rect.fromCenter(
          center: center,
          width: size.width,
          height: size.height,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(1.6));
        canvas.drawRRect(rrect, paint..color = surface);
        canvas.drawRRect(
          rrect.deflate(0.6),
          Paint()
            ..isAntiAlias = true
            ..color = color.withValues(alpha: 0.82)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.15,
        );
    }
  }

  @override
  bool shouldRepaint(covariant _BulletMarkerPainter oldDelegate) {
    return oldDelegate.variant != variant ||
        oldDelegate.color != color ||
        oldDelegate.surface != surface;
  }
}

/// A numbered list item block widget.
class NumberedListWidget extends StatefulWidget {
  /// Creates a [NumberedListWidget] for the block identified by [blockId].
  const NumberedListWidget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.attributes,
    required this.number,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// The block attributes. Used to read the indent level.
  final Map<String, dynamic> attributes;

  /// The visible ordinal number shown to the left of the content.
  final int number;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<NumberedListWidget> createState() => _NumberedListWidgetState();
}

class _NumberedListWidgetState extends State<NumberedListWidget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final indent = (widget.attributes['indent'] as int? ?? 0).clamp(0, 10);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = markdownTheme.paragraphStyle;
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: indent * markdownTheme.listIndentWidth,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: markdownTheme.listMarkerWidth + 4,
            child: _offsetMarker(
              markdownTheme.numberedListMarkerVerticalOffset,
              SizedBox(
                width: markdownTheme.listMarkerWidth + 4,
                height: _textLineHeight(baseStyle),
                child: Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: Text(
                    '${widget.number}.',
                    textAlign: TextAlign.end,
                    style: markdownTheme.listMarkerStyle.copyWith(height: 1),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: GestureDetector(
                onTapDown: (details) {
                  final position = _resolveOffset(
                    _textKey,
                    details.globalPosition,
                    widget.delta,
                    baseStyle,
                    BlockEditorScope.maybeOf(context)?.variables ?? const {},
                  );
                  widget.onEvent(
                    TapEvent(
                      blockId: widget.blockId,
                      offset: position.offset,
                      affinity: position.affinity,
                    ),
                  );
                },
                child: RichTextRenderer(
                  key: _textKey,
                  delta: widget.delta,
                  blockId: widget.blockId,
                  selection: widget.selection,
                  baseStyle: baseStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A todo (checkbox) block widget.
class TodoWidget extends StatefulWidget {
  /// Creates a [TodoWidget] for the block identified by [blockId].
  const TodoWidget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.checked,
    required this.attributes,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// Whether the todo item is currently checked.
  final bool checked;

  /// The block attributes. Used to read the indent level.
  final Map<String, dynamic> attributes;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final indent = (widget.attributes['indent'] as int? ?? 0).clamp(0, 10);
    final baseStyle = markdownTheme.paragraphStyle.copyWith(
      decoration: widget.checked ? TextDecoration.lineThrough : null,
      color: widget.checked ? editorTheme.mutedForeground : null,
    );
    return Padding(
      padding: EdgeInsetsDirectional.only(
        start: indent * markdownTheme.listIndentWidth,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: markdownTheme.listMarkerWidth,
            child: Align(
              alignment: AlignmentDirectional.topCenter,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: GestureDetector(
                  onTap: () => widget.onEvent(
                    CheckboxToggledEvent(
                      blockId: widget.blockId,
                      checked: !widget.checked,
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.only(
                      top: markdownTheme.todoMarkerVerticalOffset,
                    ),
                    child: _Checkbox(checked: widget.checked),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: GestureDetector(
                onTapDown: (details) {
                  final position = _resolveOffset(
                    _textKey,
                    details.globalPosition,
                    widget.delta,
                    baseStyle,
                    BlockEditorScope.maybeOf(context)?.variables ?? const {},
                  );
                  widget.onEvent(
                    TapEvent(
                      blockId: widget.blockId,
                      offset: position.offset,
                      affinity: position.affinity,
                    ),
                  );
                },
                child: RichTextRenderer(
                  key: _textKey,
                  delta: widget.delta,
                  blockId: widget.blockId,
                  selection: widget.selection,
                  baseStyle: baseStyle,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        border: Border.all(color: editorTheme.border, width: 1.5),
        borderRadius: BorderRadius.circular(editorTheme.radiusXs),
        color: checked ? editorTheme.primary : null,
      ),
      child: checked
          ? Icon(
              const IconData(0xe156, fontFamily: 'MaterialIcons'),
              size: 14,
              color: editorTheme.primaryForeground,
            )
          : null,
    );
  }
}

/// A block quote widget.
class QuoteWidget extends StatefulWidget {
  /// Creates a [QuoteWidget] for the block identified by [blockId].
  const QuoteWidget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<QuoteWidget> createState() => _QuoteWidgetState();
}

class _QuoteWidgetState extends State<QuoteWidget> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = markdownTheme.quoteStyle;
    return MouseRegion(
      cursor: SystemMouseCursors.text,
      child: GestureDetector(
        onTapDown: (details) {
          final position = _resolveOffset(
            _textKey,
            details.globalPosition,
            widget.delta,
            baseStyle,
            BlockEditorScope.maybeOf(context)?.variables ?? const {},
          );
          widget.onEvent(
            TapEvent(
              blockId: widget.blockId,
              offset: position.offset,
              affinity: position.affinity,
            ),
          );
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: markdownTheme.quoteBorder, width: 3),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(left: 12),
            child: RichTextRenderer(
              key: _textKey,
              delta: widget.delta,
              blockId: widget.blockId,
              selection: widget.selection,
              baseStyle: baseStyle,
            ),
          ),
        ),
      ),
    );
  }
}

/// A horizontal divider block widget.
class DividerWidget extends StatelessWidget {
  /// Creates a [DividerWidget] for the block identified by [blockId].
  const DividerWidget({
    super.key,
    required this.blockId,
    required this.onEvent,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    return Divider(height: 1, thickness: 1, color: editorTheme.border);
  }
}

/// A display math block with a readable preview and editable source.
class MathBlockWidget extends StatelessWidget {
  /// Creates a [MathBlockWidget] for the block identified by [blockId].
  const MathBlockWidget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The raw display math source.
  final TextDelta delta;

  /// Called when the user edits this block.
  final void Function(BlockEvent) onEvent;

  @override
  Widget build(BuildContext context) {
    return _PreviewSourceBlock(
      blockId: blockId,
      delta: delta,
      label: 'math',
      minLines: 1,
      emptyText: 'Empty math block',
      splitPreviewWhileEditing: true,
      onChanged: (text) =>
          onEvent(MathBlockChangedEvent(blockId: blockId, text: text)),
      previewBuilder: (context, source, style) =>
          _MathPreview(source: source, style: style),
    );
  }
}

/// A Mermaid diagram block with a source-backed preview.
class MermaidBlockWidget extends StatelessWidget {
  /// Creates a [MermaidBlockWidget] for the block identified by [blockId].
  const MermaidBlockWidget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The raw Mermaid source.
  final TextDelta delta;

  /// Called when the user edits this block.
  final void Function(BlockEvent) onEvent;

  @override
  Widget build(BuildContext context) {
    return _PreviewSourceBlock(
      blockId: blockId,
      delta: delta,
      label: 'mermaid',
      minLines: 3,
      emptyText: 'Empty Mermaid diagram',
      splitPreviewWhileEditing: true,
      splitPreviewHeightBuilder: _MermaidPreview.preferredHeight,
      onChanged: (text) =>
          onEvent(MermaidBlockChangedEvent(blockId: blockId, text: text)),
      previewBuilder: (context, source, style) =>
          _MermaidPreview(source: source, style: style),
    );
  }
}

class _PreviewSourceBlock extends StatefulWidget {
  const _PreviewSourceBlock({
    required this.blockId,
    required this.delta,
    required this.label,
    required this.minLines,
    required this.emptyText,
    this.splitPreviewWhileEditing = false,
    this.splitPreviewHeightBuilder,
    required this.onChanged,
    required this.previewBuilder,
  });

  final String blockId;
  final TextDelta delta;
  final String label;
  final int minLines;
  final String emptyText;
  final bool splitPreviewWhileEditing;
  final double Function(String source)? splitPreviewHeightBuilder;
  final ValueChanged<String> onChanged;
  final Widget Function(BuildContext context, String source, TextStyle style)
  previewBuilder;

  @override
  State<_PreviewSourceBlock> createState() => _PreviewSourceBlockState();
}

class _PreviewSourceBlockState extends State<_PreviewSourceBlock> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  ValueChanged<bool>? _embeddedInputFocusChanged;
  bool _reportedFocus = false;
  bool _splitPreviewActive = false;

  String get _source => _controller.text;

  int get _lineCount {
    if (_source.isEmpty) return widget.minLines;
    final lines = '\n'.allMatches(_source).length + 1;
    return lines < widget.minLines ? widget.minLines : lines;
  }

  @override
  void initState() {
    super.initState();
    _controller = _createSourceController(
      text: widget.delta.plainText,
      blockId: widget.blockId,
      label: widget.label,
    );
    _focusNode = FocusNode(
      onKeyEvent: (_, event) =>
          handleEmbeddedTextEditingShortcut(_controller, event),
    );
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _embeddedInputFocusChanged = BlockEditorScope.maybeOf(
      context,
    )?.onEmbeddedInputFocusChanged;
  }

  @override
  void didUpdateWidget(covariant _PreviewSourceBlock oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSource = widget.delta.plainText;
    if (!_focusNode.hasFocus && nextSource != _controller.text) {
      _controller.text = nextSource;
    }
  }

  @override
  void dispose() {
    if (_reportedFocus) {
      _embeddedInputFocusChanged?.call(false);
    }
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (focused &&
        widget.splitPreviewWhileEditing &&
        !_splitPreviewActive &&
        mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_focusNode.hasFocus) return;
        setState(() => _splitPreviewActive = true);
      });
    } else if (!focused && _splitPreviewActive && mounted) {
      setState(() => _splitPreviewActive = false);
    }
    if (_reportedFocus == focused) return;
    _reportedFocus = focused;
    _embeddedInputFocusChanged?.call(focused);
    if (mounted) setState(() {});
  }

  void _handleChanged(String value) {
    setState(() {});
    widget.onChanged(value);
  }

  void _focusSource() {
    if (_focusNode.hasFocus) return;
    _focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final scope = BlockEditorScope.maybeOf(context);
    final readOnly = scope?.readOnly ?? false;
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final textStyle = _sourceEditorTextStyle(context, markdownTheme);
    final hiddenStyle = textStyle.copyWith(
      color: Colors.transparent,
      decorationColor: Colors.transparent,
    );
    final splitPreview =
        !readOnly && _splitPreviewActive && widget.splitPreviewWhileEditing;
    final showPreview = readOnly || !_focusNode.hasFocus;
    final source = _source.trim().isEmpty ? widget.emptyText : _source;
    final splitMinHeight = math.max(
      widget.label == 'mermaid' ? 260.0 : 164.0,
      _lineCount * _textLineHeight(textStyle) + 22.0,
    );
    final splitPreviewHeight = widget.splitPreviewHeightBuilder?.call(source);
    final splitPanelHeight = math.max(splitMinHeight, splitPreviewHeight ?? 0);
    Widget sourceEditor({required TextStyle style, required bool showCursor}) {
      return Material(
        color: Colors.transparent,
        child: TextSelectionTheme(
          data: _embeddedTextSelectionTheme(context, editorTheme),
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            minLines: _lineCount,
            maxLines: null,
            showCursor: showCursor,
            keyboardType: TextInputType.multiline,
            textInputAction: TextInputAction.newline,
            style: style,
            cursorColor: _effectiveCursorColor(context, editorTheme),
            decoration: _embeddedTextFieldDecoration(),
            onChanged: _handleChanged,
          ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: markdownTheme.codeBlockBackground,
        borderRadius: BorderRadius.all(Radius.circular(editorTheme.radiusMd)),
        border: Border.all(color: markdownTheme.codeBlockBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: editorTheme.background.withValues(alpha: 0.66),
                  border: Border.all(
                    color: markdownTheme.codeBlockBorder.withValues(
                      alpha: 0.72,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(editorTheme.radiusSm),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: Text(
                    widget.label,
                    style: _sourceLabelTextStyle(
                      textStyle,
                      markdownTheme.codeBlockMutedForeground,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              child: splitPreview
                  ? LayoutBuilder(
                      builder: (context, constraints) {
                        final preview = widget.previewBuilder(
                          context,
                          source,
                          textStyle,
                        );
                        final editor = SizedBox(
                          key: ValueKey(
                            'block-editor-source-editor-${widget.blockId}',
                          ),
                          height: splitPanelHeight,
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: editorTheme.background.withValues(
                                alpha: 0.48,
                              ),
                              border: Border.all(
                                color: markdownTheme.codeBlockBorder.withValues(
                                  alpha: 0.62,
                                ),
                              ),
                              borderRadius: BorderRadius.circular(
                                editorTheme.radiusSm,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: sourceEditor(
                                style: textStyle,
                                showCursor: true,
                              ),
                            ),
                          ),
                        );
                        final boundedPreview = SizedBox(
                          key: ValueKey(
                            'block-editor-source-preview-${widget.blockId}',
                          ),
                          height: splitPanelHeight,
                          child: preview,
                        );
                        if (constraints.maxWidth < 720) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              editor,
                              const SizedBox(height: 10),
                              boundedPreview,
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: editor),
                            const SizedBox(width: 10),
                            Expanded(child: boundedPreview),
                          ],
                        );
                      },
                    )
                  : Stack(
                      alignment: Alignment.topLeft,
                      children: [
                        if (!readOnly)
                          sourceEditor(
                            style: showPreview ? hiddenStyle : textStyle,
                            showCursor: !showPreview,
                          ),
                        if (showPreview)
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: readOnly ? null : _focusSource,
                            child: widget.previewBuilder(
                              context,
                              source,
                              textStyle,
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

TextEditingController _createSourceController({
  required String text,
  required String blockId,
  required String label,
}) {
  return _HighlightedSourceController(
    text: text,
    blockId: blockId,
    language: _sourceLanguageForLabel(label),
  );
}

class _HighlightedSourceController extends TextEditingController {
  _HighlightedSourceController({
    required String text,
    required this.blockId,
    required this.language,
  }) : super(text: text);

  final String blockId;
  final String language;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    if (baseStyle.color == Colors.transparent) {
      return TextSpan(style: baseStyle, text: text);
    }
    return _highlightEmbeddedSource(
      context,
      blockId: blockId,
      source: text,
      language: language,
      baseStyle: baseStyle,
    );
  }
}

class _MarkdownInlineEditingController extends TextEditingController {
  _MarkdownInlineEditingController({required String text}) : super(text: text);

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    if (baseStyle.color == Colors.transparent) {
      return TextSpan(style: baseStyle, text: text);
    }
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    return TextSpan(
      style: baseStyle,
      children: _buildMarkdownInlineEditingSpans(
        text,
        baseStyle,
        editorTheme,
        markdownTheme,
      ),
    );
  }
}

List<TextSpan> _buildMarkdownInlineEditingSpans(
  String input,
  TextStyle baseStyle,
  BlockEditorThemeData editorTheme,
  MarkdownDocumentThemeData markdownTheme,
) {
  final spans = <TextSpan>[];
  var index = 0;
  while (index < input.length) {
    final token = _tryMarkdownInlineEditingToken(
      input,
      index,
      baseStyle,
      editorTheme,
      markdownTheme,
    );
    if (token != null) {
      spans.addAll(token.spans);
      index = token.end;
      continue;
    }

    final next = _nextMarkdownInlineEditingMarker(input, index + 1);
    spans.add(TextSpan(text: input.substring(index, next), style: baseStyle));
    index = next;
  }
  return spans;
}

({List<TextSpan> spans, int end})? _tryMarkdownInlineEditingToken(
  String input,
  int index,
  TextStyle baseStyle,
  BlockEditorThemeData editorTheme,
  MarkdownDocumentThemeData markdownTheme,
) {
  final variableEnd = input.startsWith('{{', index)
      ? input.indexOf('}}', index + 2)
      : -1;
  if (variableEnd > index + 2) {
    return (
      spans: [
        TextSpan(
          text: input.substring(index, variableEnd + 2),
          style: baseStyle.copyWith(color: editorTheme.variable),
        ),
      ],
      end: variableEnd + 2,
    );
  }

  final embed = _tryMarkdownWikiEditingToken(
    input,
    index,
    baseStyle,
    markdownTheme,
    embed: true,
  );
  if (embed != null) return embed;

  final wiki = _tryMarkdownWikiEditingToken(
    input,
    index,
    baseStyle,
    markdownTheme,
    embed: false,
  );
  if (wiki != null) return wiki;

  if (input.startsWith('[^', index)) {
    final close = input.indexOf(']', index + 2);
    if (close > index + 2) {
      return (
        spans: [
          TextSpan(
            text: input.substring(index, close + 1),
            style: buildFootnoteMarkerStyle(baseStyle, markdownTheme),
          ),
        ],
        end: close + 1,
      );
    }
  }

  final link = _tryMarkdownLinkEditingToken(
    input,
    index,
    baseStyle,
    markdownTheme,
  );
  if (link != null) return link;

  final tag = _tryMarkdownTagEditingToken(input, index, baseStyle, editorTheme);
  if (tag != null) return tag;

  for (final candidate in [
    (
      delimiter: '***',
      attributes: const InlineAttributes(bold: true, italic: true),
    ),
    (delimiter: '**', attributes: const InlineAttributes(bold: true)),
    (delimiter: '~~', attributes: const InlineAttributes(strikethrough: true)),
    (delimiter: '==', attributes: const InlineAttributes(highlight: true)),
    (delimiter: '`', attributes: const InlineAttributes(inlineCode: true)),
    (delimiter: '*', attributes: const InlineAttributes(italic: true)),
  ]) {
    final token = _tryMarkdownDelimitedEditingToken(
      input,
      index,
      baseStyle,
      markdownTheme,
      delimiter: candidate.delimiter,
      attributes: candidate.attributes,
    );
    if (token != null) return token;
  }

  return null;
}

({List<TextSpan> spans, int end})? _tryMarkdownDelimitedEditingToken(
  String input,
  int index,
  TextStyle baseStyle,
  MarkdownDocumentThemeData markdownTheme, {
  required String delimiter,
  required InlineAttributes attributes,
}) {
  if (!input.startsWith(delimiter, index)) return null;
  final close = input.indexOf(delimiter, index + delimiter.length);
  if (close <= index + delimiter.length) return null;
  final syntaxStyle = _markdownInlineSyntaxStyle(baseStyle, markdownTheme);
  final contentStyle = _markdownInlineContentStyle(
    attributes,
    baseStyle,
    markdownTheme,
  );
  return (
    spans: [
      TextSpan(text: delimiter, style: syntaxStyle),
      TextSpan(
        text: input.substring(index + delimiter.length, close),
        style: contentStyle,
      ),
      TextSpan(text: delimiter, style: syntaxStyle),
    ],
    end: close + delimiter.length,
  );
}

({List<TextSpan> spans, int end})? _tryMarkdownLinkEditingToken(
  String input,
  int index,
  TextStyle baseStyle,
  MarkdownDocumentThemeData markdownTheme,
) {
  if (!input.startsWith('[', index)) return null;
  final closeLabel = input.indexOf('](', index + 1);
  if (closeLabel < 0) return null;
  final closeUrl = input.indexOf(')', closeLabel + 2);
  if (closeUrl < 0) return null;
  final syntaxStyle = _markdownInlineSyntaxStyle(baseStyle, markdownTheme);
  final linkStyle = baseStyle.copyWith(color: markdownTheme.linkColor);
  return (
    spans: [
      TextSpan(text: '[', style: syntaxStyle),
      TextSpan(text: input.substring(index + 1, closeLabel), style: linkStyle),
      TextSpan(
        text: input.substring(closeLabel, closeUrl + 1),
        style: syntaxStyle,
      ),
    ],
    end: closeUrl + 1,
  );
}

({List<TextSpan> spans, int end})? _tryMarkdownWikiEditingToken(
  String input,
  int index,
  TextStyle baseStyle,
  MarkdownDocumentThemeData markdownTheme, {
  required bool embed,
}) {
  final prefix = embed ? '![[' : '[[';
  if (!input.startsWith(prefix, index)) return null;
  final close = input.indexOf(']]', index + prefix.length);
  if (close < 0) return null;
  final raw = input.substring(index + prefix.length, close);
  if (raw.trim().isEmpty) return null;
  final separator = raw.indexOf('|');
  final syntaxStyle = _markdownInlineSyntaxStyle(baseStyle, markdownTheme);
  final wikiStyle = baseStyle.copyWith(
    color: markdownTheme.wikiLinkColor,
    backgroundColor: embed
        ? markdownTheme.embedBackground
        : markdownTheme.wikiLinkBackground,
  );
  final spans = <TextSpan>[TextSpan(text: prefix, style: syntaxStyle)];
  if (separator >= 0) {
    spans
      ..add(TextSpan(text: raw.substring(0, separator + 1), style: syntaxStyle))
      ..add(TextSpan(text: raw.substring(separator + 1), style: wikiStyle));
  } else {
    spans.add(TextSpan(text: raw, style: wikiStyle));
  }
  spans.add(TextSpan(text: ']]', style: syntaxStyle));
  return (spans: spans, end: close + 2);
}

({List<TextSpan> spans, int end})? _tryMarkdownTagEditingToken(
  String input,
  int index,
  TextStyle baseStyle,
  BlockEditorThemeData editorTheme,
) {
  if (!input.startsWith('#', index)) return null;
  if (index > 0 && _isMarkdownTagBodyRune(input.codeUnitAt(index - 1))) {
    return null;
  }
  final start = index + 1;
  if (start >= input.length ||
      !_isMarkdownTagBodyRune(input.codeUnitAt(start))) {
    return null;
  }
  var end = start;
  while (end < input.length && _isMarkdownTagBodyRune(input.codeUnitAt(end))) {
    end++;
  }
  final tag = input.substring(start, end);
  if (!tag.contains(RegExp(r'[A-Za-z_]'))) return null;
  return (
    spans: [
      TextSpan(
        text: input.substring(index, end),
        style: baseStyle.copyWith(color: editorTheme.tag),
      ),
    ],
    end: end,
  );
}

bool _isMarkdownTagBodyRune(int codeUnit) {
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x2D ||
      codeUnit == 0x2F ||
      codeUnit == 0x5F;
}

TextStyle _markdownInlineSyntaxStyle(
  TextStyle baseStyle,
  MarkdownDocumentThemeData markdownTheme,
) {
  return baseStyle.copyWith(
    color: markdownTheme.codeBlockMutedForeground.withValues(alpha: 0.74),
    backgroundColor: null,
    fontWeight: FontWeight.normal,
    fontStyle: FontStyle.normal,
    decoration: TextDecoration.none,
  );
}

TextStyle _markdownInlineContentStyle(
  InlineAttributes attributes,
  TextStyle baseStyle,
  MarkdownDocumentThemeData markdownTheme,
) {
  final isCode = attributes.inlineCode ?? false;
  final isLink = attributes.link != null && attributes.link!.isNotEmpty;
  final isWikiLink =
      attributes.wikiLink != null && attributes.wikiLink!.isNotEmpty;
  final isFootnote =
      attributes.footnote != null && attributes.footnote!.isNotEmpty;
  final base = isCode
      ? baseStyle.copyWith(
          fontFamily: markdownTheme.inlineCodeStyle.fontFamily,
          fontFamilyFallback: markdownTheme.inlineCodeStyle.fontFamilyFallback,
          color: markdownTheme.inlineCodeForeground,
          backgroundColor: markdownTheme.inlineCodeBackground,
        )
      : baseStyle;
  return base.copyWith(
    fontWeight: attributes.bold == true
        ? FontWeight.bold
        : attributes.bold == false
        ? FontWeight.normal
        : null,
    fontStyle: attributes.italic == true
        ? FontStyle.italic
        : attributes.italic == false
        ? FontStyle.normal
        : null,
    decoration: TextDecoration.combine([
      if (attributes.underline ?? false) TextDecoration.underline,
      if (attributes.strikethrough ?? false) TextDecoration.lineThrough,
    ]),
    color: isLink
        ? markdownTheme.linkColor
        : isWikiLink
        ? markdownTheme.wikiLinkColor
        : isFootnote
        ? markdownTheme.footnoteColor
        : attributes.highlight == true
        ? markdownTheme.highlightForeground
        : isCode
        ? markdownTheme.inlineCodeForeground
        : null,
    backgroundColor: isCode
        ? markdownTheme.inlineCodeBackground
        : attributes.highlight == true
        ? markdownTheme.highlightBackground
        : isWikiLink
        ? markdownTheme.wikiLinkBackground
        : isFootnote
        ? markdownTheme.footnoteBackground
        : null,
  );
}

int _nextMarkdownInlineEditingMarker(String input, int start) {
  var next = input.length;
  for (final marker in const [
    '{{',
    '![[',
    '[[',
    '[^',
    '[',
    '#',
    '***',
    '**',
    '~~',
    '==',
    '`',
    '*',
  ]) {
    final found = input.indexOf(marker, start);
    if (found >= 0 && found < next) next = found;
  }
  return next;
}

String _sourceLanguageForLabel(String label) {
  return switch (label.trim().toLowerCase()) {
    'math' => 'latex',
    'md' => 'markdown',
    _ => label,
  };
}

class _MathPreview extends StatelessWidget {
  const _MathPreview({required this.source, required this.style});

  final String source;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final mathSource = _normalizedMathSource(source);
    if (mathSource.isEmpty || source == 'Empty math block') {
      return Center(
        child: Text(
          source,
          textAlign: TextAlign.center,
          style: style.copyWith(
            color: markdownTheme.codeBlockMutedForeground,
            height: 1.35,
          ),
        ),
      );
    }
    return Center(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Math.tex(
          mathSource,
          mathStyle: MathStyle.display,
          textStyle: style.copyWith(
            fontFamily: null,
            fontFamilyFallback: null,
            fontSize: 20,
            color: markdownTheme.codeBlockForeground,
          ),
          onErrorFallback: (error) => _MathErrorPreview(
            source: mathSource,
            message: error.messageWithType,
            style: style,
          ),
        ),
      ),
    );
  }
}

String _normalizedMathSource(String source) {
  var trimmed = source.trim();
  if (trimmed.startsWith(r'$$') && trimmed.endsWith(r'$$')) {
    trimmed = trimmed.substring(2, trimmed.length - 2).trim();
  }
  if (trimmed.startsWith(r'$') &&
      trimmed.endsWith(r'$') &&
      trimmed.length > 1) {
    trimmed = trimmed.substring(1, trimmed.length - 1).trim();
  }
  return trimmed;
}

class _MathErrorPreview extends StatelessWidget {
  const _MathErrorPreview({
    required this.source,
    required this.message,
    required this.style,
  });

  final String source;
  final String message;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Invalid math',
          style: style.copyWith(
            color: markdownTheme.codeBlockForeground,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          message,
          style: style.copyWith(
            color: markdownTheme.codeBlockMutedForeground,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(source, style: style),
      ],
    );
  }
}

class _MermaidPreview extends StatelessWidget {
  const _MermaidPreview({required this.source, required this.style});

  final String source;
  final TextStyle style;

  static double preferredHeight(String source) {
    final diagram = _MermaidDiagramParser.parse(source);
    if (diagram != null) return diagram.height + 24.0;
    final visibleLineCount = source
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .length;
    return 48.0 + math.min(4, math.max(1, visibleLineCount - 1)) * 27.0;
  }

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final diagram = _MermaidDiagramParser.parse(source);
    final paintSpec = _MermaidPaintSpec(
      surface: editorTheme.background,
      border: markdownTheme.codeBlockBorder,
      primary: editorTheme.primary,
      foreground: markdownTheme.codeBlockForeground,
      radius: editorTheme.radiusSm,
      labelStyle: style.copyWith(
        fontFamily: null,
        fontFamilyFallback: null,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: markdownTheme.codeBlockForeground,
      ),
      mutedStyle: style.copyWith(
        fontFamily: null,
        fontFamilyFallback: null,
        fontSize: 11.5,
        height: 1.2,
        color: markdownTheme.codeBlockMutedForeground,
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: editorTheme.background.withValues(alpha: 0.58),
        border: Border.all(
          color: markdownTheme.codeBlockBorder.withValues(alpha: 0.72),
        ),
        borderRadius: BorderRadius.circular(editorTheme.radiusSm),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: diagram == null
            ? _MermaidSourceFallback(source: source, style: style)
            : LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.hasBoundedWidth
                      ? constraints.maxWidth
                      : 640.0;
                  return SizedBox(
                    width: width,
                    height: diagram.height,
                    child: CustomPaint(
                      painter: _MermaidDiagramPainter(
                        diagram: diagram,
                        spec: paintSpec,
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class _MermaidSourceFallback extends StatelessWidget {
  const _MermaidSourceFallback({required this.source, required this.style});

  final String source;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final lines = source
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final title = lines.isEmpty ? 'diagram' : lines.first;
    final edges = lines.skip(1).take(4).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: style.copyWith(
            color: markdownTheme.codeBlockMutedForeground,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        if (edges.isEmpty)
          Text(source, style: style)
        else
          for (final edge in edges)
            Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.account_tree_outlined,
                    size: 14,
                    color: markdownTheme.codeBlockMutedForeground,
                  ),
                  const SizedBox(width: 8),
                  Flexible(child: Text(edge, style: style)),
                ],
              ),
            ),
      ],
    );
  }
}

class _MermaidDiagramParser {
  const _MermaidDiagramParser._();

  static _MermaidDiagram? parse(String source) {
    final lines = source
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty && !line.startsWith('%%'))
        .toList();
    if (lines.isEmpty) return null;

    final header = lines.first.toLowerCase();
    if (header.startsWith('graph ') || header.startsWith('flowchart ')) {
      return _parseFlow(source, lines);
    }
    if (header.startsWith('sequencediagram')) {
      return _parseSequence(source, lines);
    }
    return null;
  }

  static _MermaidFlowDiagram? _parseFlow(String source, List<String> lines) {
    final horizontal = RegExp(
      r'\b(?:lr|rl)\b',
      caseSensitive: false,
    ).hasMatch(lines.first);
    final nodesById = <String, _MermaidFlowNode>{};
    final nodeOrder = <String>[];
    final edges = <_MermaidFlowEdge>[];

    void addNode(_MermaidFlowNode node) {
      final existing = nodesById[node.id];
      if (existing == null) {
        nodesById[node.id] = node;
        nodeOrder.add(node.id);
      } else if (existing.label == existing.id && node.label != node.id) {
        nodesById[node.id] = node;
      }
    }

    for (final line in lines.skip(1)) {
      final edge = _parseFlowEdge(line);
      if (edge != null) {
        addNode(edge.from);
        addNode(edge.to);
        edges.add(edge);
        continue;
      }

      final node = _parseFlowNode(line.replaceAll(';', ''));
      if (node != null) addNode(node);
    }

    if (nodesById.isEmpty || edges.isEmpty) return null;
    return _MermaidFlowDiagram(
      source: source,
      direction: horizontal ? Axis.horizontal : Axis.vertical,
      nodes: [for (final id in nodeOrder) nodesById[id]!],
      edges: edges,
    );
  }

  static _MermaidFlowEdge? _parseFlowEdge(String line) {
    final trimmed = line.replaceAll(';', '').trim();
    final match = RegExp(
      r'^(.+?)\s*(?:-->|---|==>|-.->|--x|--o)\s*(?:\|([^|]+)\|\s*)?(.+?)$',
    ).firstMatch(trimmed);
    if (match == null) return null;

    final from = _parseFlowNode(match.group(1) ?? '');
    final to = _parseFlowNode(match.group(3) ?? '');
    if (from == null || to == null) return null;
    return _MermaidFlowEdge(
      from: from,
      to: to,
      label: _cleanMermaidLabel(match.group(2) ?? ''),
    );
  }

  static _MermaidFlowNode? _parseFlowNode(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return null;
    final match = RegExp(
      r'^([A-Za-z0-9_]+)\s*[\[\(\{]([^\]\)\}]+)[\]\)\}]$',
    ).firstMatch(trimmed);
    if (match != null) {
      final id = match.group(1)!;
      return _MermaidFlowNode(
        id: id,
        label: _cleanMermaidLabel(match.group(2) ?? id),
      );
    }

    final id = trimmed.split(RegExp(r'\s+')).first;
    if (id.isEmpty) return null;
    return _MermaidFlowNode(id: id, label: _cleanMermaidLabel(id));
  }

  static _MermaidSequenceDiagram? _parseSequence(
    String source,
    List<String> lines,
  ) {
    final participantsById = <String, String>{};
    final participantOrder = <String>[];
    final messages = <_MermaidSequenceMessage>[];

    void addParticipant(String id, [String? label]) {
      if (id.isEmpty) return;
      if (!participantsById.containsKey(id)) participantOrder.add(id);
      participantsById[id] = _cleanMermaidLabel(
        label ?? participantsById[id] ?? id,
      );
    }

    for (final line in lines.skip(1)) {
      final participant = _parseSequenceParticipant(line);
      if (participant != null) {
        addParticipant(participant.id, participant.label);
        continue;
      }

      final message = _parseSequenceMessage(line);
      if (message != null) {
        addParticipant(message.from);
        addParticipant(message.to);
        messages.add(message);
      }
    }

    if (participantOrder.length < 2 && messages.isEmpty) return null;
    return _MermaidSequenceDiagram(
      source: source,
      participants: [
        for (final id in participantOrder)
          _MermaidParticipant(id: id, label: participantsById[id] ?? id),
      ],
      messages: messages,
    );
  }

  static _MermaidParticipant? _parseSequenceParticipant(String line) {
    final match = RegExp(
      r'^participant\s+([A-Za-z0-9_]+)(?:\s+as\s+(.+))?$',
      caseSensitive: false,
    ).firstMatch(line.trim());
    if (match == null) return null;
    final id = match.group(1)!;
    return _MermaidParticipant(
      id: id,
      label: _cleanMermaidLabel(match.group(2) ?? id),
    );
  }

  static _MermaidSequenceMessage? _parseSequenceMessage(String line) {
    final match = RegExp(
      r'^([A-Za-z0-9_]+)\s*[-=]+[)>x-]*\s*([A-Za-z0-9_]+)\s*:\s*(.+)$',
    ).firstMatch(line.trim());
    if (match == null) return null;
    return _MermaidSequenceMessage(
      from: match.group(1)!,
      to: match.group(2)!,
      label: _cleanMermaidLabel(match.group(3) ?? ''),
    );
  }

  static String _cleanMermaidLabel(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'''^["']|["']$'''), '')
        .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
        .replaceAll(r'\n', '\n');
  }
}

abstract class _MermaidDiagram {
  String get source;
  double get height;
  void paint(Canvas canvas, Size size, _MermaidPaintSpec spec);
}

class _MermaidPaintSpec {
  const _MermaidPaintSpec({
    required this.surface,
    required this.border,
    required this.primary,
    required this.foreground,
    required this.radius,
    required this.labelStyle,
    required this.mutedStyle,
  });

  final Color surface;
  final Color border;
  final Color primary;
  final Color foreground;
  final double radius;
  final TextStyle labelStyle;
  final TextStyle mutedStyle;
}

class _MermaidDiagramPainter extends CustomPainter {
  const _MermaidDiagramPainter({required this.diagram, required this.spec});

  final _MermaidDiagram diagram;
  final _MermaidPaintSpec spec;

  @override
  void paint(Canvas canvas, Size size) {
    diagram.paint(canvas, size, spec);
  }

  @override
  bool shouldRepaint(covariant _MermaidDiagramPainter oldDelegate) {
    return oldDelegate.diagram.source != diagram.source ||
        oldDelegate.spec.surface != spec.surface ||
        oldDelegate.spec.primary != spec.primary;
  }
}

class _MermaidFlowDiagram implements _MermaidDiagram {
  const _MermaidFlowDiagram({
    required this.source,
    required this.direction,
    required this.nodes,
    required this.edges,
  });

  @override
  final String source;
  final Axis direction;
  final List<_MermaidFlowNode> nodes;
  final List<_MermaidFlowEdge> edges;

  @override
  double get height {
    final levelCount = _levels().values.fold<int>(
      1,
      (maxLevel, level) => math.max(maxLevel, level + 1),
    );
    final base = direction == Axis.vertical ? 72.0 : 62.0;
    return math.max(158.0, base + levelCount * 72.0);
  }

  @override
  void paint(Canvas canvas, Size size, _MermaidPaintSpec spec) {
    final rects = _layout(size);
    final edgePaint = Paint()
      ..color = spec.border.withValues(alpha: 0.9)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    for (final edge in edges) {
      final from = rects[edge.from.id];
      final to = rects[edge.to.id];
      if (from == null || to == null) continue;
      final start = direction == Axis.vertical
          ? Offset(from.center.dx, from.bottom)
          : Offset(from.right, from.center.dy);
      final end = direction == Axis.vertical
          ? Offset(to.center.dx, to.top)
          : Offset(to.left, to.center.dy);
      _paintConnector(canvas, start, end, direction, edgePaint);
      if (edge.label.isNotEmpty) {
        _paintEdgeLabel(canvas, edge.label, start, end, spec);
      }
    }

    final incoming = <String>{for (final edge in edges) edge.to.id};
    for (final node in nodes) {
      final rect = rects[node.id];
      if (rect == null) continue;
      _paintFlowNode(
        canvas,
        rect,
        node,
        spec,
        root: !incoming.contains(node.id),
      );
    }
  }

  Map<String, int> _levels() {
    final ids = {for (final node in nodes) node.id};
    final incoming = <String, int>{for (final id in ids) id: 0};
    for (final edge in edges) {
      incoming[edge.to.id] = (incoming[edge.to.id] ?? 0) + 1;
    }
    final levels = <String, int>{
      for (final id in ids)
        if ((incoming[id] ?? 0) == 0) id: 0,
    };
    if (levels.isEmpty && nodes.isNotEmpty) levels[nodes.first.id] = 0;

    for (var pass = 0; pass < nodes.length; pass++) {
      var changed = false;
      for (final edge in edges) {
        final fromLevel = levels[edge.from.id];
        if (fromLevel == null) continue;
        final nextLevel = math.max(levels[edge.to.id] ?? 0, fromLevel + 1);
        if (levels[edge.to.id] != nextLevel) {
          levels[edge.to.id] = nextLevel;
          changed = true;
        }
      }
      if (!changed) break;
    }
    for (final node in nodes) {
      levels.putIfAbsent(node.id, () => 0);
    }
    return levels;
  }

  Map<String, Rect> _layout(Size size) {
    final levels = _levels();
    final groups = <int, List<_MermaidFlowNode>>{};
    for (final node in nodes) {
      groups.putIfAbsent(levels[node.id] ?? 0, () => []).add(node);
    }
    final orderedLevels = groups.keys.toList()..sort();
    final rects = <String, Rect>{};
    const hPadding = 18.0;
    const vPadding = 18.0;
    const nodeGap = 16.0;
    final maxNodeWidth = direction == Axis.vertical ? 172.0 : 150.0;

    if (direction == Axis.vertical) {
      final yStep = orderedLevels.length <= 1
          ? 0.0
          : (size.height - vPadding * 2 - 42) / (orderedLevels.length - 1);
      for (
        var levelIndex = 0;
        levelIndex < orderedLevels.length;
        levelIndex++
      ) {
        final group = groups[orderedLevels[levelIndex]]!;
        final widths = [
          for (final node in group) _nodeWidth(node.label, maxNodeWidth),
        ];
        final totalWidth =
            widths.fold<double>(0, (total, width) => total + width) +
            nodeGap * (group.length - 1);
        var left = math.max(hPadding, (size.width - totalWidth) / 2);
        final top = vPadding + yStep * levelIndex;
        for (var i = 0; i < group.length; i++) {
          final width = widths[i];
          rects[group[i].id] = Rect.fromLTWH(left, top, width, 42);
          left += width + nodeGap;
        }
      }
    } else {
      final xStep = orderedLevels.length <= 1
          ? 0.0
          : (size.width - hPadding * 2 - maxNodeWidth) /
                (orderedLevels.length - 1);
      for (
        var levelIndex = 0;
        levelIndex < orderedLevels.length;
        levelIndex++
      ) {
        final group = groups[orderedLevels[levelIndex]]!;
        final totalHeight = group.length * 42 + nodeGap * (group.length - 1);
        var top = math.max(vPadding, (size.height - totalHeight) / 2);
        final left = hPadding + xStep * levelIndex;
        for (final node in group) {
          final width = _nodeWidth(node.label, maxNodeWidth);
          rects[node.id] = Rect.fromLTWH(left, top, width, 42);
          top += 42 + nodeGap;
        }
      }
    }
    return rects;
  }

  static double _nodeWidth(String label, double maxWidth) {
    return (label.length * 7.2 + 34).clamp(84.0, maxWidth).toDouble();
  }
}

class _MermaidFlowNode {
  const _MermaidFlowNode({required this.id, required this.label});

  final String id;
  final String label;
}

class _MermaidFlowEdge {
  const _MermaidFlowEdge({
    required this.from,
    required this.to,
    required this.label,
  });

  final _MermaidFlowNode from;
  final _MermaidFlowNode to;
  final String label;
}

class _MermaidSequenceDiagram implements _MermaidDiagram {
  const _MermaidSequenceDiagram({
    required this.source,
    required this.participants,
    required this.messages,
  });

  @override
  final String source;
  final List<_MermaidParticipant> participants;
  final List<_MermaidSequenceMessage> messages;

  @override
  double get height => math.max(150.0, 104.0 + messages.length * 42.0);

  @override
  void paint(Canvas canvas, Size size, _MermaidPaintSpec spec) {
    if (participants.isEmpty) return;
    final xs = _participantPositions(size.width);
    final participantById = {for (final p in participants) p.id: p};
    final linePaint = Paint()
      ..color = spec.border.withValues(alpha: 0.82)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final lifelinePaint = Paint()
      ..color = spec.border.withValues(alpha: 0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < participants.length; i++) {
      final participant = participants[i];
      final x = xs[participant.id]!;
      final rect = Rect.fromCenter(
        center: Offset(x, 28),
        width: 108,
        height: 34,
      );
      _paintParticipant(canvas, rect, participant.label, spec);
      canvas.drawLine(
        Offset(x, rect.bottom + 10),
        Offset(x, size.height - 12),
        lifelinePaint,
      );
    }

    for (var index = 0; index < messages.length; index++) {
      final message = messages[index];
      final fromX = xs[message.from];
      final toX = xs[message.to];
      if (fromX == null || toX == null) continue;
      final y = 84 + index * 42.0;
      final from = participantById[message.from]?.label ?? message.from;
      final to = participantById[message.to]?.label ?? message.to;
      if (fromX == toX) {
        _paintSelfMessage(
          canvas,
          Offset(fromX, y),
          message.label,
          spec,
          linePaint,
        );
      } else {
        _paintStraightArrow(
          canvas,
          Offset(fromX, y),
          Offset(toX, y),
          linePaint,
        );
        _paintSequenceLabel(
          canvas,
          message.label,
          Offset((fromX + toX) / 2, y - 18),
          spec,
        );
      }
      _paintSequenceEndpointLabels(canvas, from, to, fromX, toX, y, spec);
    }
  }

  Map<String, double> _participantPositions(double width) {
    final positions = <String, double>{};
    if (participants.length == 1) {
      positions[participants.first.id] = width / 2;
      return positions;
    }
    const padding = 62.0;
    final step = (width - padding * 2) / (participants.length - 1);
    for (var i = 0; i < participants.length; i++) {
      positions[participants[i].id] = padding + step * i;
    }
    return positions;
  }
}

class _MermaidParticipant {
  const _MermaidParticipant({required this.id, required this.label});

  final String id;
  final String label;
}

class _MermaidSequenceMessage {
  const _MermaidSequenceMessage({
    required this.from,
    required this.to,
    required this.label,
  });

  final String from;
  final String to;
  final String label;
}

void _paintConnector(
  Canvas canvas,
  Offset start,
  Offset end,
  Axis direction,
  Paint paint,
) {
  final path = Path()..moveTo(start.dx, start.dy);
  if (direction == Axis.vertical) {
    final midY = (start.dy + end.dy) / 2;
    path.cubicTo(start.dx, midY, end.dx, midY, end.dx, end.dy);
  } else {
    final midX = (start.dx + end.dx) / 2;
    path.cubicTo(midX, start.dy, midX, end.dy, end.dx, end.dy);
  }
  canvas.drawPath(path, paint);
  _drawArrowHead(canvas, start, end, paint);
}

void _paintStraightArrow(Canvas canvas, Offset start, Offset end, Paint paint) {
  canvas.drawLine(start, end, paint);
  _drawArrowHead(canvas, start, end, paint);
}

void _drawArrowHead(Canvas canvas, Offset start, Offset end, Paint paint) {
  final angle = math.atan2(end.dy - start.dy, end.dx - start.dx);
  const arrowLength = 8.0;
  const arrowSpread = math.pi / 7;
  final path = Path()
    ..moveTo(end.dx, end.dy)
    ..lineTo(
      end.dx - arrowLength * math.cos(angle - arrowSpread),
      end.dy - arrowLength * math.sin(angle - arrowSpread),
    )
    ..moveTo(end.dx, end.dy)
    ..lineTo(
      end.dx - arrowLength * math.cos(angle + arrowSpread),
      end.dy - arrowLength * math.sin(angle + arrowSpread),
    );
  canvas.drawPath(path, paint);
}

void _paintFlowNode(
  Canvas canvas,
  Rect rect,
  _MermaidFlowNode node,
  _MermaidPaintSpec spec, {
  required bool root,
}) {
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(spec.radius + 2));
  final fill = root
      ? Color.alphaBlend(spec.primary.withValues(alpha: 0.10), spec.surface)
      : Color.alphaBlend(
          spec.foreground.withValues(alpha: 0.025),
          spec.surface,
        );
  final fillPaint = Paint()..color = fill;
  final borderPaint = Paint()
    ..color = root
        ? spec.primary.withValues(alpha: 0.5)
        : spec.border.withValues(alpha: 0.86)
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1;
  canvas.drawRRect(rrect, fillPaint);
  canvas.drawRRect(rrect, borderPaint);
  _paintCenteredText(canvas, node.label, rect.deflate(10), spec.labelStyle);
}

void _paintParticipant(
  Canvas canvas,
  Rect rect,
  String label,
  _MermaidPaintSpec spec,
) {
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(spec.radius + 2));
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = Color.alphaBlend(
        spec.primary.withValues(alpha: 0.08),
        spec.surface,
      ),
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = spec.primary.withValues(alpha: 0.42)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1,
  );
  _paintCenteredText(canvas, label, rect.deflate(8), spec.labelStyle);
}

void _paintEdgeLabel(
  Canvas canvas,
  String label,
  Offset start,
  Offset end,
  _MermaidPaintSpec spec,
) {
  final center = Offset((start.dx + end.dx) / 2, (start.dy + end.dy) / 2);
  _paintLabelPill(canvas, label, center, spec, maxWidth: 96);
}

void _paintSequenceLabel(
  Canvas canvas,
  String label,
  Offset center,
  _MermaidPaintSpec spec,
) {
  if (label.isEmpty) return;
  _paintLabelPill(canvas, label, center, spec, maxWidth: 150);
}

void _paintSequenceEndpointLabels(
  Canvas canvas,
  String from,
  String to,
  double fromX,
  double toX,
  double y,
  _MermaidPaintSpec spec,
) {
  if ((toX - fromX).abs() < 150) return;
  _paintSmallText(
    canvas,
    from,
    Offset(fromX, y + 10),
    spec.mutedStyle,
    maxWidth: 80,
  );
  _paintSmallText(
    canvas,
    to,
    Offset(toX, y + 10),
    spec.mutedStyle,
    maxWidth: 80,
  );
}

void _paintSelfMessage(
  Canvas canvas,
  Offset origin,
  String label,
  _MermaidPaintSpec spec,
  Paint paint,
) {
  final path = Path()
    ..moveTo(origin.dx, origin.dy)
    ..relativeLineTo(42, 0)
    ..relativeLineTo(0, 24)
    ..relativeLineTo(-42, 0);
  canvas.drawPath(path, paint);
  _drawArrowHead(
    canvas,
    origin + const Offset(42, 24),
    origin + const Offset(0, 24),
    paint,
  );
  _paintSequenceLabel(canvas, label, origin + const Offset(42, -18), spec);
}

void _paintLabelPill(
  Canvas canvas,
  String text,
  Offset center,
  _MermaidPaintSpec spec, {
  required double maxWidth,
}) {
  if (text.isEmpty) return;
  final painter = TextPainter(
    text: TextSpan(text: text, style: spec.mutedStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  final rect = Rect.fromCenter(
    center: center,
    width: painter.width + 12,
    height: painter.height + 7,
  );
  final rrect = RRect.fromRectAndRadius(rect, Radius.circular(spec.radius));
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = Color.alphaBlend(
        spec.foreground.withValues(alpha: 0.045),
        spec.surface,
      ),
  );
  canvas.drawRRect(
    rrect,
    Paint()
      ..color = spec.border.withValues(alpha: 0.64)
      ..style = PaintingStyle.stroke,
  );
  painter.paint(
    canvas,
    Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
  );
}

void _paintCenteredText(
  Canvas canvas,
  String text,
  Rect rect,
  TextStyle style,
) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 2,
    ellipsis: '...',
  )..layout(maxWidth: rect.width);
  painter.paint(
    canvas,
    Offset(
      rect.left + (rect.width - painter.width) / 2,
      rect.top + (rect.height - painter.height) / 2,
    ),
  );
}

void _paintSmallText(
  Canvas canvas,
  String text,
  Offset center,
  TextStyle style, {
  required double maxWidth,
}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: TextAlign.center,
    maxLines: 1,
    ellipsis: '...',
  )..layout(maxWidth: maxWidth);
  painter.paint(
    canvas,
    Offset(center.dx - painter.width / 2, center.dy - painter.height / 2),
  );
}

/// A source-preserving block for Markdown constructs without rich block UI.
class RawMarkdownWidget extends StatefulWidget {
  /// Creates a [RawMarkdownWidget] for the block identified by [blockId].
  const RawMarkdownWidget({
    super.key,
    required this.blockId,
    required this.delta,
    required this.onEvent,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The raw Markdown source to preserve.
  final TextDelta delta;

  /// Called when the user edits this block.
  final void Function(BlockEvent) onEvent;

  @override
  State<RawMarkdownWidget> createState() => _RawMarkdownWidgetState();
}

class _RawMarkdownWidgetState extends State<RawMarkdownWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  ValueChanged<bool>? _embeddedInputFocusChanged;
  bool _reportedFocus = false;

  String get _source => _controller.text;

  int get _lineCount {
    if (_source.isEmpty) return 3;
    final lines = '\n'.allMatches(_source).length + 1;
    return lines < 3 ? 3 : lines;
  }

  @override
  void initState() {
    super.initState();
    _controller = _HighlightedSourceController(
      text: widget.delta.plainText,
      blockId: widget.blockId,
      language: 'markdown',
    );
    _focusNode = FocusNode(
      onKeyEvent: (_, event) =>
          handleEmbeddedTextEditingShortcut(_controller, event),
    );
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _embeddedInputFocusChanged = BlockEditorScope.maybeOf(
      context,
    )?.onEmbeddedInputFocusChanged;
  }

  @override
  void didUpdateWidget(covariant RawMarkdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextSource = widget.delta.plainText;
    if (!_focusNode.hasFocus && nextSource != _controller.text) {
      _controller.text = nextSource;
    }
  }

  @override
  void dispose() {
    if (_reportedFocus) {
      _embeddedInputFocusChanged?.call(false);
    }
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (_reportedFocus == focused) return;
    _reportedFocus = focused;
    _embeddedInputFocusChanged?.call(focused);
  }

  void _handleChanged(String value) {
    setState(() {});
    widget.onEvent(
      RawMarkdownChangedEvent(blockId: widget.blockId, text: value),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scope = BlockEditorScope.maybeOf(context);
    final readOnly = scope?.readOnly ?? false;
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final textStyle = _sourceEditorTextStyle(context, markdownTheme);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: markdownTheme.codeBlockBackground,
        borderRadius: BorderRadius.all(Radius.circular(editorTheme.radiusMd)),
        border: Border.all(color: markdownTheme.codeBlockBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 24),
              child: readOnly
                  ? SelectableText(_source, style: textStyle)
                  : Material(
                      color: Colors.transparent,
                      child: TextSelectionTheme(
                        data: _embeddedTextSelectionTheme(context, editorTheme),
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: _lineCount,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: textStyle,
                          cursorColor: _effectiveCursorColor(
                            context,
                            editorTheme,
                          ),
                          decoration: _embeddedTextFieldDecoration(),
                          onChanged: _handleChanged,
                        ),
                      ),
                    ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: editorTheme.background.withValues(alpha: 0.66),
                  border: Border.all(
                    color: markdownTheme.codeBlockBorder.withValues(
                      alpha: 0.72,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(editorTheme.radiusSm),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  child: Text(
                    'markdown',
                    style: _sourceLabelTextStyle(
                      textStyle,
                      markdownTheme.codeBlockMutedForeground,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A GitHub-style Markdown table block.
class TableWidget extends StatefulWidget {
  /// Creates a [TableWidget] for the block identified by [blockId].
  const TableWidget({
    super.key,
    required this.blockId,
    required this.headers,
    required this.rows,
    required this.alignments,
    required this.onEvent,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// Header cell Markdown text.
  final List<String> headers;

  /// Body row cell Markdown text.
  final List<List<String>> rows;

  /// Optional per-column alignment values: left, center, or right.
  final List<String> alignments;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  @override
  State<TableWidget> createState() => _TableWidgetState();
}

class _TableWidgetState extends State<TableWidget> {
  static const double _columnControlGutter = 28;
  static const double _rowControlGutter = 48;
  static const double _columnControlWidth = 124;
  static const double _rowControlWidth = 40;
  static const double _controlHeight = 22;
  static const double _controlGap = 4;
  static const double _defaultColumnWidth = 180;
  static const double _minColumnWidth = 96;
  static const double _maxColumnWidth = 560;
  static const double _defaultRowMinHeight = 36;
  static const double _minRowHeight = 32;
  static const double _maxRowHeight = 360;

  final GlobalKey _tableShellKey = GlobalKey();
  final Map<int, GlobalKey> _headerCellKeys = {};
  final Map<int, GlobalKey> _rowCellKeys = {};
  final Map<int, double> _columnWidths = {};
  final Map<int, double> _rowMinHeights = {};
  int? _activeRowIndex;
  int? _activeColumnIndex;
  bool _showRowControls = false;
  bool _hoveringTable = false;
  bool _anchorUpdateScheduled = false;
  Rect? _activeColumnRect;
  Rect? _activeRowRect;
  int _structureVersion = 0;
  List<String>? _optimisticHeaders;
  List<List<String>>? _optimisticRows;
  List<String>? _optimisticAlignments;

  @override
  void didUpdateWidget(covariant TableWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_hasOptimisticTable) return;
    final widgetChanged =
        !_sameStringList(widget.headers, oldWidget.headers) ||
        !_sameRows(widget.rows, oldWidget.rows) ||
        !_sameStringList(widget.alignments, oldWidget.alignments);
    if (widgetChanged || _optimisticTableMatchesWidget()) {
      _optimisticHeaders = null;
      _optimisticRows = null;
      _optimisticAlignments = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final readOnly = BlockEditorScope.maybeOf(context)?.readOnly ?? false;
    final sourceHeaders = _optimisticHeaders ?? widget.headers;
    final sourceRows = _optimisticRows ?? widget.rows;
    final sourceAlignments = _optimisticAlignments ?? widget.alignments;
    final effectiveHeaders = sourceHeaders.isEmpty
        ? const ['Column 1', 'Column 2']
        : sourceHeaders;
    final columnCount = effectiveHeaders.length;
    final effectiveRows = sourceRows.isEmpty
        ? [List.filled(columnCount, ''), List.filled(columnCount, '')]
        : sourceRows.map((row) => _normalizeRow(row, columnCount)).toList();
    final activeRowIndex = _activeRow(effectiveRows.length);
    final activeColumnIndex = _activeColumn(columnCount);
    final reserveControlGutters = !readOnly;
    final showControls = reserveControlGutters && _hoveringTable;
    if (reserveControlGutters) {
      _scheduleControlAnchorUpdate(activeRowIndex, activeColumnIndex);
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MouseRegion(
            cursor: readOnly
                ? SystemMouseCursors.basic
                : SystemMouseCursors.text,
            onEnter: readOnly
                ? null
                : (_) {
                    if (!_hoveringTable) {
                      setState(() => _hoveringTable = true);
                    }
                  },
            onExit: readOnly ? null : (_) => _clearHoverControls(),
            child: _wrapReadonlyTap(
              readOnly: readOnly,
              child: Stack(
                key: _tableShellKey,
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: EdgeInsets.only(
                      top: reserveControlGutters ? _columnControlGutter : 0,
                      right: reserveControlGutters ? _rowControlGutter : 0,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(editorTheme.radiusSm),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: editorTheme.background,
                          border: Border.all(color: markdownTheme.tableBorder),
                          borderRadius: BorderRadius.circular(
                            editorTheme.radiusSm,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.025),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Table(
                            defaultColumnWidth: const IntrinsicColumnWidth(),
                            columnWidths: {
                              for (
                                var column = 0;
                                column < columnCount;
                                column++
                              )
                                if (_columnWidths[column] != null)
                                  column: FixedColumnWidth(
                                    _columnWidths[column]!,
                                  ),
                            },
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: markdownTheme.tableBorder,
                              ),
                              verticalInside: BorderSide(
                                color: markdownTheme.tableBorder,
                              ),
                            ),
                            children: [
                              _buildRow(
                                context,
                                cells: effectiveHeaders,
                                columnCount: columnCount,
                                rowIndex: -1,
                                header: true,
                                readOnly: readOnly,
                                rowCount: effectiveRows.length,
                                activeRowIndex: activeRowIndex,
                                activeColumnIndex: activeColumnIndex,
                                alignments: sourceAlignments,
                              ),
                              for (
                                var index = 0;
                                index < effectiveRows.length;
                                index++
                              )
                                _buildRow(
                                  context,
                                  cells: effectiveRows[index],
                                  columnCount: columnCount,
                                  rowIndex: index,
                                  readOnly: readOnly,
                                  rowCount: effectiveRows.length,
                                  activeRowIndex: activeRowIndex,
                                  activeColumnIndex: activeColumnIndex,
                                  alignments: sourceAlignments,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (showControls)
                    ..._buildControlOverlays(
                      rowCount: effectiveRows.length,
                      columnCount: columnCount,
                      alignments: sourceAlignments,
                      activeRowIndex: activeRowIndex,
                      activeColumnIndex: activeColumnIndex,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _wrapReadonlyTap({required bool readOnly, required Widget child}) {
    if (!readOnly) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) =>
          widget.onEvent(TapEvent(blockId: widget.blockId, offset: 0)),
      child: child,
    );
  }

  int? _activeRow(int rowCount) {
    if (_activeRowIndex == null || rowCount <= 0) return null;
    return _activeRowIndex!.clamp(0, rowCount - 1).toInt();
  }

  int? _activeColumn(int columnCount) {
    if (_activeColumnIndex == null || columnCount <= 0) return null;
    return _activeColumnIndex!.clamp(0, columnCount - 1).toInt();
  }

  void _activateCell({
    required int rowIndex,
    required int columnIndex,
    required int rowCount,
    required int columnCount,
    required bool fromHover,
  }) {
    final fallbackRow = rowCount <= 0 ? 0 : rowCount - 1;
    final nextRow = rowIndex < 0
        ? _activeRow(rowCount) ?? fallbackRow
        : rowIndex.clamp(0, rowCount - 1).toInt();
    final nextColumn = columnIndex.clamp(0, columnCount - 1).toInt();
    final nextShowRowControls = rowIndex >= 0;
    final nextHoveringTable = _hoveringTable || fromHover;
    if (_activeRowIndex == nextRow &&
        _activeColumnIndex == nextColumn &&
        _showRowControls == nextShowRowControls &&
        _hoveringTable == nextHoveringTable) {
      return;
    }
    setState(() {
      _activeRowIndex = nextRow;
      _activeColumnIndex = nextColumn;
      _showRowControls = nextShowRowControls;
      _hoveringTable = nextHoveringTable;
    });
    _scheduleControlAnchorUpdate(nextRow, nextColumn);
  }

  void _clearHoverControls() {
    if (!_hoveringTable &&
        _activeRowIndex == null &&
        _activeColumnIndex == null &&
        !_showRowControls &&
        _activeColumnRect == null &&
        _activeRowRect == null) {
      return;
    }
    setState(() {
      _hoveringTable = false;
      _activeRowIndex = null;
      _activeColumnIndex = null;
      _showRowControls = false;
      _activeColumnRect = null;
      _activeRowRect = null;
    });
  }

  void _resizeColumn(int column, double delta) {
    if (delta == 0) return;
    final current = _columnWidths[column] ?? _measuredColumnWidth(column);
    setState(() {
      _columnWidths[column] = (current + delta)
          .clamp(_minColumnWidth, _maxColumnWidth)
          .toDouble();
    });
    _scheduleControlAnchorUpdate(_activeRowIndex, _activeColumnIndex);
  }

  void _resizeRow(int row, double delta) {
    if (delta == 0) return;
    final current = _rowMinHeights[row] ?? _measuredRowHeight(row);
    setState(() {
      _rowMinHeights[row] = (current + delta)
          .clamp(_minRowHeight, _maxRowHeight)
          .toDouble();
    });
    _scheduleControlAnchorUpdate(_activeRowIndex, _activeColumnIndex);
  }

  double _measuredColumnWidth(int column) {
    final key = _headerCellKeys[column];
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.size.width.clamp(_minColumnWidth, _maxColumnWidth).toDouble();
    }
    return _defaultColumnWidth;
  }

  double _measuredRowHeight(int row) {
    final key = _rowCellKeys[row];
    final box = key?.currentContext?.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) {
      return box.size.height.clamp(_minRowHeight, _maxRowHeight).toDouble();
    }
    return _defaultRowMinHeight;
  }

  TableRow _buildRow(
    BuildContext context, {
    required List<String> cells,
    required int columnCount,
    required int rowIndex,
    required bool readOnly,
    required int rowCount,
    required int? activeRowIndex,
    required int? activeColumnIndex,
    required List<String> alignments,
    bool header = false,
  }) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final baseStyle = header
        ? markdownTheme.tableHeaderStyle
        : markdownTheme.tableCellStyle;
    final rowMinHeight = header
        ? _defaultRowMinHeight
        : math.max(
            _rowMinHeights[rowIndex] ?? _defaultRowMinHeight,
            _estimatedRowHeight(cells, baseStyle),
          );
    return TableRow(
      decoration: BoxDecoration(
        color: header ? markdownTheme.tableHeaderBackground : null,
      ),
      children: [
        for (var column = 0; column < columnCount; column++)
          _TableCellContent(
            key: ValueKey(
              '${widget.blockId}:table:$_structureVersion:${header ? 'h' : 'r'}:$rowIndex:$column',
            ),
            cellKey: header
                ? _headerCellKey(column)
                : column == columnCount - 1
                ? _rowCellKey(rowIndex)
                : null,
            blockId: '${widget.blockId}_table_${rowIndex}_$column',
            tableBlockId: widget.blockId,
            text: column < cells.length ? cells[column] : '',
            baseStyle: baseStyle,
            textAlign: _alignmentFor(column, alignments),
            header: header,
            rowIndex: rowIndex,
            columnIndex: column,
            active: header
                ? activeColumnIndex == column && !_showRowControls
                : activeRowIndex == rowIndex && activeColumnIndex == column,
            readOnly: readOnly,
            minRowHeight: rowMinHeight,
            showColumnResizeHandle: !readOnly,
            showRowResizeHandle: !readOnly && !header,
            onColumnResizeDelta: (delta) => _resizeColumn(column, delta),
            onRowResizeDelta: !header
                ? (delta) => _resizeRow(rowIndex, delta)
                : null,
            onActivate: () => _activateCell(
              rowIndex: rowIndex,
              columnIndex: column,
              rowCount: rowCount,
              columnCount: columnCount,
              fromHover: false,
            ),
            onHover: () => _activateCell(
              rowIndex: rowIndex,
              columnIndex: column,
              rowCount: rowCount,
              columnCount: columnCount,
              fromHover: true,
            ),
            onEvent: widget.onEvent,
          ),
      ],
    );
  }

  double _estimatedRowHeight(List<String> cells, TextStyle style) {
    final lineHeight = _textLineHeight(style);
    var maxLines = 1;
    for (final cell in cells) {
      final normalized = cell.replaceAll(
        RegExp(r'<br\s*/?>', caseSensitive: false),
        '\n',
      );
      maxLines = math.max(maxLines, '\n'.allMatches(normalized).length + 1);
    }
    return lineHeight * maxLines + 18;
  }

  List<Widget> _buildControlOverlays({
    required int rowCount,
    required int columnCount,
    required List<String> alignments,
    required int? activeRowIndex,
    required int? activeColumnIndex,
  }) {
    final overlays = <Widget>[];
    final shellBox =
        _tableShellKey.currentContext?.findRenderObject() as RenderBox?;
    final shellSize = shellBox?.size ?? Size.zero;
    final maxTop = shellSize.height > _controlHeight
        ? shellSize.height - _controlHeight
        : 0.0;

    if (activeColumnIndex != null && _activeColumnRect != null) {
      final column = activeColumnIndex;
      final rect = _activeColumnRect!;
      final maxLeft = shellSize.width > _columnControlWidth
          ? shellSize.width - _columnControlWidth
          : 0.0;
      overlays.add(
        Positioned(
          left: (rect.center.dx - _columnControlWidth / 2).clamp(0.0, maxLeft),
          top: (rect.top - _controlHeight - _controlGap).clamp(0.0, maxTop),
          child: _TableInlineControls(
            addTooltip: 'Add column right',
            deleteTooltip: 'Delete column ${column + 1}',
            activeAlignment: column < alignments.length
                ? alignments[column]
                : null,
            onAlign: (alignment) => _emitTableAction(
              TableColumnAlignmentChangedEvent(
                blockId: widget.blockId,
                columnIndex: column,
                alignment: alignment,
              ),
              nextRowIndex: activeRowIndex,
              nextColumnIndex: column,
            ),
            onAdd: () => _emitTableAction(
              TableColumnInsertedEvent(
                blockId: widget.blockId,
                index: column + 1,
              ),
              nextRowIndex: activeRowIndex,
              nextColumnIndex: column + 1,
            ),
            onDelete: columnCount > 1
                ? () => _emitTableAction(
                    TableColumnDeletedEvent(
                      blockId: widget.blockId,
                      index: column,
                    ),
                    nextRowIndex: activeRowIndex,
                    nextColumnIndex: column.clamp(0, columnCount - 2).toInt(),
                  )
                : null,
          ),
        ),
      );
    }

    if (_showRowControls && activeRowIndex != null && _activeRowRect != null) {
      final row = activeRowIndex;
      final column = activeColumnIndex ?? 0;
      final rect = _activeRowRect!;
      final maxLeft = shellSize.width > _rowControlWidth
          ? shellSize.width - _rowControlWidth
          : 0.0;
      overlays.add(
        Positioned(
          left: (rect.right + _controlGap).clamp(0.0, maxLeft),
          top: (rect.center.dy - _controlHeight / 2).clamp(0.0, maxTop),
          child: _TableInlineControls(
            addTooltip: 'Add row below',
            deleteTooltip: 'Delete row ${row + 1}',
            onAdd: () => _emitTableAction(
              TableRowInsertedEvent(blockId: widget.blockId, index: row + 1),
              nextRowIndex: row + 1,
              nextColumnIndex: column,
            ),
            onDelete: rowCount > 1
                ? () => _emitTableAction(
                    TableRowDeletedEvent(blockId: widget.blockId, index: row),
                    nextRowIndex: row.clamp(0, rowCount - 2).toInt(),
                    nextColumnIndex: column,
                  )
                : null,
          ),
        ),
      );
    }
    return overlays;
  }

  void _emitTableAction(
    BlockEvent event, {
    required int? nextRowIndex,
    required int? nextColumnIndex,
  }) {
    final optimisticTable = _optimisticTableAfter(event);
    setState(() {
      if (optimisticTable != null) {
        _optimisticHeaders = optimisticTable.headers;
        _optimisticRows = optimisticTable.rows;
        _optimisticAlignments = optimisticTable.alignments;
        _structureVersion++;
      }
      _activeRowIndex = nextRowIndex;
      _activeColumnIndex = nextColumnIndex;
      _showRowControls = _showRowControls && nextRowIndex != null;
    });
    _scheduleControlAnchorUpdate(nextRowIndex, nextColumnIndex);
    widget.onEvent(event);
  }

  ({List<String> headers, List<List<String>> rows, List<String> alignments})?
  _optimisticTableAfter(BlockEvent event) {
    final headers = _currentHeaders();
    final rows = _currentRows(headers.length);
    final alignments = List<String>.of(
      _optimisticAlignments ?? widget.alignments,
    );

    switch (event) {
      case TableRowInsertedEvent():
        final index = event.index.clamp(0, rows.length).toInt();
        rows.insert(index, List.filled(headers.length, ''));
      case TableRowDeletedEvent():
        if (rows.length <= 1) return null;
        final index = event.index.clamp(0, rows.length - 1).toInt();
        rows.removeAt(index);
      case TableColumnInsertedEvent():
        final index = event.index.clamp(0, headers.length).toInt();
        headers.insert(index, 'Column ${headers.length + 1}');
        for (final row in rows) {
          row.insert(index, '');
        }
        if (alignments.isNotEmpty) {
          while (alignments.length < headers.length - 1) {
            alignments.add('');
          }
          alignments.insert(index, '');
        }
      case TableColumnDeletedEvent():
        if (headers.length <= 1) return null;
        final index = event.index.clamp(0, headers.length - 1).toInt();
        headers.removeAt(index);
        for (final row in rows) {
          if (index < row.length) row.removeAt(index);
        }
        if (alignments.isNotEmpty) {
          while (alignments.length < headers.length + 1) {
            alignments.add('');
          }
          alignments.removeAt(index);
        }
      case TableColumnAlignmentChangedEvent():
        final index = event.columnIndex.clamp(0, headers.length - 1).toInt();
        while (alignments.length < headers.length) {
          alignments.add('');
        }
        alignments[index] = event.alignment == null ? '' : event.alignment!;
      default:
        return null;
    }

    return (headers: headers, rows: rows, alignments: alignments);
  }

  GlobalKey _headerCellKey(int column) =>
      _headerCellKeys.putIfAbsent(column, GlobalKey.new);

  GlobalKey _rowCellKey(int row) =>
      _rowCellKeys.putIfAbsent(row, GlobalKey.new);

  bool get _hasOptimisticTable =>
      _optimisticHeaders != null ||
      _optimisticRows != null ||
      _optimisticAlignments != null;

  bool _optimisticTableMatchesWidget() {
    final headers = _optimisticHeaders ?? widget.headers;
    final rows = _optimisticRows ?? widget.rows;
    final alignments = _optimisticAlignments ?? widget.alignments;
    return _sameStringList(headers, widget.headers) &&
        _sameRows(rows, widget.rows) &&
        _sameStringList(alignments, widget.alignments);
  }

  List<String> _currentHeaders() {
    final headers = _optimisticHeaders ?? widget.headers;
    return headers.isEmpty
        ? <String>['Column 1', 'Column 2']
        : List<String>.of(headers);
  }

  List<List<String>> _currentRows(int columnCount) {
    final rows = _optimisticRows ?? widget.rows;
    if (rows.isEmpty) {
      return [List.filled(columnCount, ''), List.filled(columnCount, '')];
    }
    return rows
        .map((row) => List<String>.of(_normalizeRow(row, columnCount)))
        .toList();
  }

  void _scheduleControlAnchorUpdate(int? rowIndex, int? columnIndex) {
    if (_anchorUpdateScheduled) return;
    _anchorUpdateScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _anchorUpdateScheduled = false;
      if (!mounted) return;
      final shellBox =
          _tableShellKey.currentContext?.findRenderObject() as RenderBox?;
      if (shellBox == null || !shellBox.hasSize) return;

      Rect? resolve(GlobalKey key) {
        final box = key.currentContext?.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return null;
        final offset = box.localToGlobal(Offset.zero, ancestor: shellBox);
        return offset & box.size;
      }

      final nextColumnRect = columnIndex == null
          ? null
          : resolve(_headerCellKey(columnIndex));
      final nextRowRect = rowIndex == null || !_showRowControls
          ? null
          : resolve(_rowCellKey(rowIndex));
      if (_activeColumnRect == nextColumnRect &&
          _activeRowRect == nextRowRect) {
        return;
      }
      setState(() {
        _activeColumnRect = nextColumnRect;
        _activeRowRect = nextRowRect;
      });
    });
  }

  TextAlign _alignmentFor(int column, List<String> alignments) {
    final value = column < alignments.length ? alignments[column] : null;
    return switch (value) {
      'center' => TextAlign.center,
      'right' => TextAlign.right,
      _ => TextAlign.left,
    };
  }

  bool _sameStringList(List<String> a, List<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  bool _sameRows(List<List<String>> a, List<List<String>> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var row = 0; row < a.length; row++) {
      if (!_sameStringList(a[row], b[row])) return false;
    }
    return true;
  }

  List<String> _normalizeRow(List<String> row, int columnCount) {
    if (row.length == columnCount) return row;
    if (row.length > columnCount) return row.sublist(0, columnCount);
    return [...row, ...List.filled(columnCount - row.length, '')];
  }
}

class _TableCellContent extends StatefulWidget {
  const _TableCellContent({
    super.key,
    required this.cellKey,
    required this.blockId,
    required this.tableBlockId,
    required this.text,
    required this.baseStyle,
    required this.textAlign,
    required this.header,
    required this.rowIndex,
    required this.columnIndex,
    required this.active,
    required this.readOnly,
    required this.minRowHeight,
    required this.showColumnResizeHandle,
    required this.showRowResizeHandle,
    required this.onColumnResizeDelta,
    required this.onRowResizeDelta,
    required this.onActivate,
    required this.onHover,
    required this.onEvent,
  });

  final Key? cellKey;
  final String blockId;
  final String tableBlockId;
  final String text;
  final TextStyle baseStyle;
  final TextAlign textAlign;
  final bool header;
  final int rowIndex;
  final int columnIndex;
  final bool active;
  final bool readOnly;
  final double minRowHeight;
  final bool showColumnResizeHandle;
  final bool showRowResizeHandle;
  final ValueChanged<double> onColumnResizeDelta;
  final ValueChanged<double>? onRowResizeDelta;
  final VoidCallback onActivate;
  final VoidCallback onHover;
  final void Function(BlockEvent) onEvent;

  @override
  State<_TableCellContent> createState() => _TableCellContentState();
}

class _TableCellContentState extends State<_TableCellContent> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  ValueChanged<bool>? _embeddedInputFocusChanged;
  bool _reportedFocus = false;
  bool _editing = false;

  Key get _cellSurfaceKey => ValueKey<String>(
    'block-editor-table-cell-${widget.tableBlockId}-'
    '${widget.header ? 'header' : 'row'}-${widget.rowIndex}-${widget.columnIndex}',
  );

  @override
  void initState() {
    super.initState();
    _controller = _MarkdownInlineEditingController(text: widget.text);
    _focusNode = FocusNode(
      onKeyEvent: (_, event) =>
          handleEmbeddedTextEditingShortcut(_controller, event),
    );
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _embeddedInputFocusChanged = BlockEditorScope.maybeOf(
      context,
    )?.onEmbeddedInputFocusChanged;
  }

  void _handleFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (focused) widget.onActivate();
    if (!focused && _editing && mounted) {
      setState(() => _editing = false);
    }
    if (_reportedFocus == focused) return;
    _reportedFocus = focused;
    if (mounted) setState(() {});
    _embeddedInputFocusChanged?.call(focused);
  }

  void _activateEditorShell() {
    widget.onActivate();
    if (widget.readOnly) return;
    final shouldMoveCaretToEnd = !_editing && !_focusNode.hasFocus;
    if (!_editing) {
      setState(() => _editing = true);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (!_focusNode.hasFocus) {
        _focusNode.requestFocus();
      }
      if (shouldMoveCaretToEnd) {
        _controller.selection = TextSelection.collapsed(
          offset: _controller.text.length,
        );
      }
    });
  }

  @override
  void didUpdateWidget(_TableCellContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != _controller.text && !_focusNode.hasFocus) {
      _controller.text = widget.text;
    }
  }

  @override
  void dispose() {
    if (_reportedFocus) {
      _embeddedInputFocusChanged?.call(false);
    }
    _focusNode.removeListener(_handleFocusChanged);
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _renderableCellText(String text) {
    return text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  }

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final textStyle = widget.baseStyle;
    final cellConstraints = BoxConstraints(
      minWidth: 96,
      maxWidth: 560,
      minHeight: widget.minRowHeight,
    );
    final isEditing = !widget.readOnly && _editing;
    final renderableText = _renderableCellText(widget.text);
    final showRenderedPreview = !isEditing;
    final highlightCell = widget.active || isEditing;
    final textSelectionTheme = _embeddedTextSelectionTheme(
      context,
      editorTheme,
    );
    final activeCellBackground = markdownTheme.tableActiveCellBackground;
    final cursorColor = _effectiveCursorColor(context, editorTheme);

    if (widget.readOnly) {
      return MouseRegion(
        key: widget.cellKey,
        onEnter: (_) => widget.onHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) =>
              widget.onEvent(TapEvent(blockId: widget.tableBlockId, offset: 0)),
          child: DecoratedBox(
            key: _cellSurfaceKey,
            decoration: BoxDecoration(
              color: highlightCell ? activeCellBackground : Colors.transparent,
            ),
            child: ConstrainedBox(
              constraints: cellConstraints,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: RichTextRenderer(
                      delta: BlockMarkdownCodec.parseInline(renderableText),
                      blockId: widget.blockId,
                      baseStyle: textStyle,
                      textAlign: widget.textAlign,
                    ),
                  ),
                  if (widget.showColumnResizeHandle)
                    _TableCellResizeHandle(
                      axis: Axis.horizontal,
                      active: widget.active,
                      onDragDelta: widget.onColumnResizeDelta,
                    ),
                  if (widget.showRowResizeHandle &&
                      widget.onRowResizeDelta != null)
                    _TableCellResizeHandle(
                      axis: Axis.vertical,
                      active: widget.active,
                      onDragDelta: widget.onRowResizeDelta!,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (showRenderedPreview) {
      return MouseRegion(
        key: widget.cellKey,
        onEnter: (_) => widget.onHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _activateEditorShell(),
          child: DecoratedBox(
            key: _cellSurfaceKey,
            decoration: BoxDecoration(
              color: highlightCell ? activeCellBackground : Colors.transparent,
            ),
            child: ConstrainedBox(
              constraints: cellConstraints,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                    child: RichTextRenderer(
                      delta: BlockMarkdownCodec.parseInline(renderableText),
                      blockId: widget.blockId,
                      baseStyle: textStyle,
                      textAlign: widget.textAlign,
                    ),
                  ),
                  if (widget.showColumnResizeHandle)
                    _TableCellResizeHandle(
                      axis: Axis.horizontal,
                      active: widget.active,
                      onDragDelta: widget.onColumnResizeDelta,
                    ),
                  if (widget.showRowResizeHandle &&
                      widget.onRowResizeDelta != null)
                    _TableCellResizeHandle(
                      axis: Axis.vertical,
                      active: widget.active,
                      onDragDelta: widget.onRowResizeDelta!,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return MouseRegion(
      key: widget.cellKey,
      onEnter: (_) => widget.onHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _activateEditorShell(),
        child: DecoratedBox(
          key: _cellSurfaceKey,
          decoration: BoxDecoration(
            color: highlightCell ? activeCellBackground : Colors.transparent,
          ),
          child: ConstrainedBox(
            constraints: cellConstraints,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(
                    left: 12,
                    right: 12,
                    top: 3,
                    bottom: 3,
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: Stack(
                      clipBehavior: Clip.none,
                      alignment: AlignmentDirectional.centerStart,
                      children: [
                        TextSelectionTheme(
                          data: textSelectionTheme,
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: null,
                            readOnly: widget.readOnly,
                            canRequestFocus: !widget.readOnly,
                            showCursor: isEditing,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            textAlign: widget.textAlign,
                            style: textStyle,
                            cursorColor: isEditing
                                ? cursorColor
                                : Colors.transparent,
                            onTap: widget.onActivate,
                            decoration: _embeddedTextFieldDecoration(
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 6,
                              ),
                              hintText: widget.header
                                  ? 'Column ${widget.columnIndex + 1}'
                                  : '',
                              hintStyle: isEditing
                                  ? editorTheme.mutedStyle
                                  : editorTheme.mutedStyle.copyWith(
                                      color: Colors.transparent,
                                    ),
                            ),
                            onChanged: (value) => widget.onEvent(
                              TableCellChangedEvent(
                                blockId: widget.tableBlockId,
                                header: widget.header,
                                rowIndex: widget.rowIndex,
                                columnIndex: widget.columnIndex,
                                text: value,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (widget.showColumnResizeHandle)
                  _TableCellResizeHandle(
                    axis: Axis.horizontal,
                    active: widget.active,
                    onDragDelta: widget.onColumnResizeDelta,
                  ),
                if (widget.showRowResizeHandle &&
                    widget.onRowResizeDelta != null)
                  _TableCellResizeHandle(
                    axis: Axis.vertical,
                    active: widget.active,
                    onDragDelta: widget.onRowResizeDelta!,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TableCellResizeHandle extends StatefulWidget {
  const _TableCellResizeHandle({
    required this.axis,
    required this.active,
    required this.onDragDelta,
  });

  final Axis axis;
  final bool active;
  final ValueChanged<double> onDragDelta;

  @override
  State<_TableCellResizeHandle> createState() => _TableCellResizeHandleState();
}

class _TableCellResizeHandleState extends State<_TableCellResizeHandle> {
  bool _hovered = false;

  Widget _preventParentScrollWhileHovering(Widget child) {
    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent) {
          GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
        }
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final visible = widget.active || _hovered;
    final trackColor = editorTheme.foreground.withValues(
      alpha: visible ? 0.045 : 0.0,
    );
    final barColor = editorTheme.foreground.withValues(
      alpha: visible ? 0.30 : 0.0,
    );
    if (widget.axis == Axis.horizontal) {
      return PositionedDirectional(
        top: 0,
        bottom: 0,
        end: 0,
        width: 7,
        child: _preventParentScrollWhileHovering(
          MouseRegion(
            cursor: SystemMouseCursors.resizeColumn,
            onEnter: (_) => setState(() => _hovered = true),
            onExit: (_) => setState(() => _hovered = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragUpdate: (details) =>
                  widget.onDragDelta(details.delta.dx),
              child: Stack(
                children: [
                  Positioned.fill(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      color: trackColor,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    bottom: 0,
                    right: 0,
                    width: 2,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 90),
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return PositionedDirectional(
      start: 0,
      end: 0,
      bottom: 0,
      height: 7,
      child: _preventParentScrollWhileHovering(
        MouseRegion(
          cursor: SystemMouseCursors.resizeRow,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (details) =>
                widget.onDragDelta(details.delta.dy),
            child: Stack(
              children: [
                Positioned.fill(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    color: trackColor,
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 2,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 90),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TableInlineControls extends StatelessWidget {
  const _TableInlineControls({
    required this.addTooltip,
    required this.deleteTooltip,
    required this.onAdd,
    required this.onDelete,
    this.activeAlignment,
    this.onAlign,
  });

  final String addTooltip;
  final String deleteTooltip;
  final VoidCallback? onAdd;
  final VoidCallback? onDelete;
  final String? activeAlignment;
  final ValueChanged<String?>? onAlign;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: editorTheme.background,
        border: Border.all(color: editorTheme.border.withValues(alpha: 0.82)),
        borderRadius: BorderRadius.circular(editorTheme.radiusSm),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 5,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(1),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onAlign != null) ...[
              _TableAlignmentButton(
                tooltip: 'Align left',
                icon: Icons.format_align_left,
                selected: activeAlignment == 'left',
                onPressed: () =>
                    onAlign!(activeAlignment == 'left' ? null : 'left'),
              ),
              const SizedBox(width: 1),
              _TableAlignmentButton(
                tooltip: 'Align center',
                icon: Icons.format_align_center,
                selected: activeAlignment == 'center',
                onPressed: () =>
                    onAlign!(activeAlignment == 'center' ? null : 'center'),
              ),
              const SizedBox(width: 1),
              _TableAlignmentButton(
                tooltip: 'Align right',
                icon: Icons.format_align_right,
                selected: activeAlignment == 'right',
                onPressed: () =>
                    onAlign!(activeAlignment == 'right' ? null : 'right'),
              ),
              const SizedBox(width: 3),
            ],
            _TableActionButton(
              tooltip: addTooltip,
              icon: Icons.add_rounded,
              onPressed: onAdd,
            ),
            const SizedBox(width: 1),
            _TableActionButton(
              tooltip: deleteTooltip,
              icon: Icons.remove_rounded,
              tone: _TableActionTone.destructive,
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _TableAlignmentButton extends StatelessWidget {
  const _TableAlignmentButton({
    required this.tooltip,
    required this.icon,
    required this.selected,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final foreground = selected
        ? editorTheme.primary
        : editorTheme.mutedForeground;
    final background = selected
        ? editorTheme.primary.withValues(alpha: 0.12)
        : Colors.transparent;
    return Tooltip(
      message: tooltip,
      waitDuration: const Duration(milliseconds: 650),
      showDuration: const Duration(milliseconds: 900),
      preferBelow: false,
      verticalOffset: 8,
      decoration: BoxDecoration(
        color: editorTheme.foreground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(editorTheme.radiusXs),
      ),
      textStyle: editorTheme.smallStyle.copyWith(color: editorTheme.background),
      child: Semantics(
        button: true,
        selected: selected,
        label: tooltip,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (_) => onPressed(),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(editorTheme.radiusSm),
                color: background,
              ),
              child: SizedBox.square(
                dimension: 18,
                child: Icon(icon, size: 12, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _TableActionTone { neutral, destructive }

class _TableActionButton extends StatelessWidget {
  const _TableActionButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.tone = _TableActionTone.neutral,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final _TableActionTone tone;

  @override
  Widget build(BuildContext context) {
    return _TableActionButtonInner(
      tooltip: tooltip,
      icon: icon,
      onPressed: onPressed,
      tone: tone,
    );
  }
}

class _TableActionButtonInner extends StatefulWidget {
  const _TableActionButtonInner({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    required this.tone,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final _TableActionTone tone;

  @override
  State<_TableActionButtonInner> createState() =>
      _TableActionButtonInnerState();
}

class _TableActionButtonInnerState extends State<_TableActionButtonInner> {
  bool _hovered = false;
  bool _pressed = false;

  void _setHoverState({required bool hovered, bool pressed = false}) {
    if (!mounted) return;
    setState(() {
      _hovered = hovered;
      _pressed = pressed;
    });
  }

  void _setPressed(bool pressed) {
    if (!mounted) return;
    setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final enabled = widget.onPressed != null;
    final destructive = widget.tone == _TableActionTone.destructive;
    final accent = destructive
        ? const Color(0xFFDC2626)
        : editorTheme.mutedForeground;
    final foreground = enabled
        ? accent
        : editorTheme.mutedForeground.withValues(alpha: 0.32);
    final fillAlpha = !enabled
        ? 0.18
        : _pressed
        ? 0.18
        : _hovered
        ? 0.12
        : destructive
        ? 0.08
        : 0.0;
    return Tooltip(
      message: widget.tooltip,
      waitDuration: const Duration(milliseconds: 650),
      showDuration: const Duration(milliseconds: 900),
      preferBelow: false,
      verticalOffset: 8,
      decoration: BoxDecoration(
        color: editorTheme.foreground.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(editorTheme.radiusXs),
      ),
      textStyle: editorTheme.smallStyle.copyWith(color: editorTheme.background),
      child: Semantics(
        button: true,
        enabled: enabled,
        label: widget.tooltip,
        child: MouseRegion(
          cursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.forbidden,
          onEnter: enabled ? (_) => _setHoverState(hovered: true) : null,
          onExit: enabled ? (_) => _setHoverState(hovered: false) : null,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: enabled
                ? (_) {
                    _setPressed(true);
                    widget.onPressed?.call();
                  }
                : null,
            onPointerUp: enabled ? (_) => _setPressed(false) : null,
            onPointerCancel: enabled ? (_) => _setPressed(false) : null,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(
                  color: destructive && enabled
                      ? accent.withValues(alpha: 0.22)
                      : Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(editorTheme.radiusSm),
                color: destructive
                    ? accent.withValues(alpha: fillAlpha)
                    : editorTheme.muted.withValues(alpha: fillAlpha),
              ),
              child: SizedBox.square(
                dimension: 18,
                child: Icon(widget.icon, size: 12, color: foreground),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
