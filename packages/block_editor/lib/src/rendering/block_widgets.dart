library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';
import 'editor_span_builder.dart';

const double _listIndentWidth = 28;
const double _listMarkerWidth = 28;

String _bulletMarkerForIndent(int indent) {
  return switch (indent % 3) {
    1 => '◦',
    2 => '▪',
    _ => '•',
  };
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
      padding: EdgeInsetsDirectional.only(start: indent * _listIndentWidth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _listMarkerWidth,
            child: Text(
              _bulletMarkerForIndent(indent.toInt()),
              textAlign: TextAlign.center,
              style: markdownTheme.listMarkerStyle,
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
      padding: EdgeInsetsDirectional.only(start: indent * _listIndentWidth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _listMarkerWidth + 4,
            child: Text(
              '${widget.number}.',
              textAlign: TextAlign.end,
              style: markdownTheme.listMarkerStyle,
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
      padding: EdgeInsetsDirectional.only(start: indent * _listIndentWidth),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _listMarkerWidth,
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
                    padding: const EdgeInsets.only(top: 2),
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
      minLines: 2,
      emptyText: 'Empty math block',
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
    required this.onChanged,
    required this.previewBuilder,
  });

  final String blockId;
  final TextDelta delta;
  final String label;
  final int minLines;
  final String emptyText;
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

  String get _source => _controller.text;

  int get _lineCount {
    if (_source.isEmpty) return widget.minLines;
    final lines = '\n'.allMatches(_source).length + 1;
    return lines < widget.minLines ? widget.minLines : lines;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.delta.plainText);
    _focusNode = FocusNode();
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
    final textStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: const ['MesloLGS NF', 'monospace'],
      fontSize: 13,
      color: markdownTheme.codeBlockForeground,
      height: 1.5,
      letterSpacing: 0,
    );
    final hiddenStyle = textStyle.copyWith(
      color: Colors.transparent,
      decorationColor: Colors.transparent,
    );
    final showPreview = readOnly || !_focusNode.hasFocus;
    final source = _source.trim().isEmpty ? widget.emptyText : _source;

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
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: const ['MesloLGS NF', 'monospace'],
                      fontSize: 12,
                      color: markdownTheme.codeBlockMutedForeground,
                      height: 1,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Stack(
              alignment: Alignment.topLeft,
              children: [
                if (!readOnly)
                  IgnorePointer(
                    ignoring: showPreview,
                    child: Opacity(
                      opacity: showPreview ? 0 : 1,
                      child: Material(
                        color: Colors.transparent,
                        child: TextField(
                          controller: _controller,
                          focusNode: _focusNode,
                          minLines: _lineCount,
                          maxLines: null,
                          showCursor: !showPreview,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          style: showPreview ? hiddenStyle : textStyle,
                          cursorColor: editorTheme.cursor,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                          ),
                          onChanged: _handleChanged,
                        ),
                      ),
                    ),
                  ),
                if (showPreview)
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: readOnly ? null : _focusSource,
                    child: widget.previewBuilder(context, source, textStyle),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MathPreview extends StatelessWidget {
  const _MathPreview({required this.source, required this.style});

  final String source;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    return Center(
      child: Text(
        source,
        textAlign: TextAlign.center,
        style: style.copyWith(
          fontSize: 18,
          fontStyle: FontStyle.italic,
          color: markdownTheme.codeBlockForeground,
          height: 1.45,
        ),
      ),
    );
  }
}

class _MermaidPreview extends StatelessWidget {
  const _MermaidPreview({required this.source, required this.style});

  final String source;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final lines = source
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final title = lines.isEmpty ? 'diagram' : lines.first;
    final edges = lines.skip(1).take(4).toList();
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
        child: Column(
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
        ),
      ),
    );
  }
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
    _controller = TextEditingController(text: widget.delta.plainText);
    _focusNode = FocusNode();
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
    final textStyle = TextStyle(
      fontFamily: 'JetBrainsMono',
      fontFamilyFallback: const ['MesloLGS NF', 'monospace'],
      fontSize: 13,
      color: markdownTheme.codeBlockForeground,
      height: 1.5,
      letterSpacing: 0,
    );

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
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        minLines: _lineCount,
                        maxLines: null,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        style: textStyle,
                        cursorColor: editorTheme.cursor,
                        decoration: const InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.zero,
                        ),
                        onChanged: _handleChanged,
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
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontFamilyFallback: const ['MesloLGS NF', 'monospace'],
                      fontSize: 12,
                      color: markdownTheme.codeBlockMutedForeground,
                      height: 1,
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
            minRowHeight: header
                ? _defaultRowMinHeight
                : _rowMinHeights[rowIndex] ?? _defaultRowMinHeight,
            showColumnResizeHandle: !readOnly && header,
            showRowResizeHandle:
                !readOnly && !header && column == columnCount - 1,
            onColumnResizeDelta: (delta) => _resizeColumn(column, delta),
            onRowResizeDelta: !header && column == columnCount - 1
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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.text);
    _focusNode = FocusNode();
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
    if (_reportedFocus == focused) return;
    _reportedFocus = focused;
    if (mounted) setState(() {});
    _embeddedInputFocusChanged?.call(focused);
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

  bool _cellNeedsRenderedPreview(String text) {
    return text.contains('\n') ||
        RegExp(r'<br\s*/?>', caseSensitive: false).hasMatch(text) ||
        text.contains('**') ||
        text.contains('~~') ||
        text.contains('`') ||
        RegExp(r'\[[^\]]+\]\([^)]+\)').hasMatch(text) ||
        RegExp(r'\*[^*\s][^*]*\*').hasMatch(text);
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
    final isEditing = !widget.readOnly && _focusNode.hasFocus;
    final hiddenTextStyle = textStyle.copyWith(
      color: Colors.transparent,
      decorationColor: Colors.transparent,
    );
    final showRenderedPreview =
        !isEditing && _cellNeedsRenderedPreview(widget.text);
    final highlightCell = isEditing;

    if (widget.readOnly) {
      return MouseRegion(
        key: widget.cellKey,
        onEnter: (_) => widget.onHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) =>
              widget.onEvent(TapEvent(blockId: widget.tableBlockId, offset: 0)),
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
                    delta: BlockMarkdownCodec.parseInline(
                      _renderableCellText(widget.text),
                    ),
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
      );
    }

    return MouseRegion(
      key: widget.cellKey,
      onEnter: (_) => widget.onHover(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: highlightCell
              ? markdownTheme.tableActiveCellBackground
              : Colors.transparent,
        ),
        child: ConstrainedBox(
          constraints: cellConstraints,
          child: Padding(
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
                  TextField(
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
                    style: showRenderedPreview ? hiddenTextStyle : textStyle,
                    cursorColor: isEditing
                        ? editorTheme.cursor
                        : Colors.transparent,
                    onTap: widget.onActivate,
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
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
                  if (showRenderedPreview)
                    Positioned.fill(
                      child: IgnorePointer(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: RichTextRenderer(
                            delta: BlockMarkdownCodec.parseInline(
                              _renderableCellText(widget.text),
                            ),
                            blockId: widget.blockId,
                            baseStyle: textStyle,
                            textAlign: widget.textAlign,
                          ),
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

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final visible = widget.active || _hovered;
    final color = editorTheme.primary.withValues(alpha: visible ? 0.48 : 0.0);
    if (widget.axis == Axis.horizontal) {
      return PositionedDirectional(
        top: 0,
        bottom: 0,
        end: -3,
        width: 7,
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (details) =>
                widget.onDragDelta(details.delta.dx),
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 90),
                width: 2,
                color: color,
              ),
            ),
          ),
        ),
      );
    }

    return PositionedDirectional(
      start: 0,
      end: 0,
      bottom: -3,
      height: 7,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeRow,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragUpdate: (details) =>
              widget.onDragDelta(details.delta.dy),
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 90),
              height: 2,
              color: color,
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
