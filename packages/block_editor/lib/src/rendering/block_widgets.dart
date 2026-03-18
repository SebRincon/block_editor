library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:block_editor/block_editor.dart';

int _resolveOffset(GlobalKey key, Offset localPosition) {
  final renderObject = key.currentContext?.findRenderObject();
  if (renderObject == null) return 0;
  RenderParagraph? paragraph;
  void visitor(RenderObject child) {
    if (paragraph != null) return;
    if (child is RenderParagraph) {
      paragraph = child;
      return;
    }
    child.visitChildren(visitor);
  }

  if (renderObject is RenderParagraph) {
    paragraph = renderObject;
  } else {
    renderObject.visitChildren(visitor);
  }
  if (paragraph == null) return 0;
  return paragraph!.getPositionForOffset(localPosition).offset;
}

/// A paragraph block widget.
class ParagraphBlock extends StatefulWidget {
  /// Creates a [ParagraphBlock] for the block identified by [blockId].
  const ParagraphBlock({
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
  State<ParagraphBlock> createState() => _ParagraphBlockState();
}

class _ParagraphBlockState extends State<ParagraphBlock> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final offset = _resolveOffset(_textKey, details.localPosition);
        widget.onEvent(TapEvent(blockId: widget.blockId, offset: offset));
      },
      child: RichTextRenderer(
        key: _textKey,
        delta: widget.delta,
        blockId: widget.blockId,
        selection: widget.selection,
        baseStyle: const TextStyle(fontSize: 16),
      ),
    );
  }
}

/// A heading level 1 block widget.
class H1Block extends StatefulWidget {
  /// Creates an [H1Block] for the block identified by [blockId].
  const H1Block({
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
  State<H1Block> createState() => _H1BlockState();
}

class _H1BlockState extends State<H1Block> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final offset = _resolveOffset(_textKey, details.localPosition);
        widget.onEvent(TapEvent(blockId: widget.blockId, offset: offset));
      },
      child: RichTextRenderer(
        key: _textKey,
        delta: widget.delta,
        blockId: widget.blockId,
        selection: widget.selection,
        baseStyle: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// A heading level 2 block widget.
class H2Block extends StatefulWidget {
  /// Creates an [H2Block] for the block identified by [blockId].
  const H2Block({
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
  State<H2Block> createState() => _H2BlockState();
}

class _H2BlockState extends State<H2Block> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final offset = _resolveOffset(_textKey, details.localPosition);
        widget.onEvent(TapEvent(blockId: widget.blockId, offset: offset));
      },
      child: RichTextRenderer(
        key: _textKey,
        delta: widget.delta,
        blockId: widget.blockId,
        selection: widget.selection,
        baseStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// A heading level 3 block widget.
class H3Block extends StatefulWidget {
  /// Creates an [H3Block] for the block identified by [blockId].
  const H3Block({
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
  State<H3Block> createState() => _H3BlockState();
}

class _H3BlockState extends State<H3Block> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final offset = _resolveOffset(_textKey, details.localPosition);
        widget.onEvent(TapEvent(blockId: widget.blockId, offset: offset));
      },
      child: RichTextRenderer(
        key: _textKey,
        delta: widget.delta,
        blockId: widget.blockId,
        selection: widget.selection,
        baseStyle: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
      ),
    );
  }
}

/// A bullet list item block widget.
class BulletListBlock extends StatefulWidget {
  /// Creates a [BulletListBlock] for the block identified by [blockId].
  const BulletListBlock({
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
  State<BulletListBlock> createState() => _BulletListBlockState();
}

class _BulletListBlockState extends State<BulletListBlock> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final indent = (widget.attributes['indent'] as int? ?? 0).clamp(0, 10);
    return Padding(
      padding: EdgeInsets.only(left: indent * 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 24,
            child: Text('•', style: TextStyle(fontSize: 16)),
          ),
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                final offset = _resolveOffset(_textKey, details.localPosition);
                widget.onEvent(
                  TapEvent(blockId: widget.blockId, offset: offset),
                );
              },
              child: RichTextRenderer(
                key: _textKey,
                delta: widget.delta,
                blockId: widget.blockId,
                selection: widget.selection,
                baseStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A numbered list item block widget.
class NumberedListBlock extends StatefulWidget {
  /// Creates a [NumberedListBlock] for the block identified by [blockId].
  const NumberedListBlock({
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
  State<NumberedListBlock> createState() => _NumberedListBlockState();
}

class _NumberedListBlockState extends State<NumberedListBlock> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final indent = (widget.attributes['indent'] as int? ?? 0).clamp(0, 10);
    return Padding(
      padding: EdgeInsets.only(left: indent * 24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '${widget.number}.',
              style: const TextStyle(fontSize: 16),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTapDown: (details) {
                final offset = _resolveOffset(_textKey, details.localPosition);
                widget.onEvent(
                  TapEvent(blockId: widget.blockId, offset: offset),
                );
              },
              child: RichTextRenderer(
                key: _textKey,
                delta: widget.delta,
                blockId: widget.blockId,
                selection: widget.selection,
                baseStyle: const TextStyle(fontSize: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A todo (checkbox) block widget.
class TodoBlock extends StatefulWidget {
  /// Creates a [TodoBlock] for the block identified by [blockId].
  const TodoBlock({
    super.key,
    required this.blockId,
    required this.delta,
    required this.checked,
    required this.onEvent,
    this.selection = EditorSelection.none,
  });

  /// The id of the block this widget represents.
  final String blockId;

  /// The inline content to render.
  final TextDelta delta;

  /// Whether the todo item is currently checked.
  final bool checked;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  /// The current editor selection.
  final EditorSelection selection;

  @override
  State<TodoBlock> createState() => _TodoBlockState();
}

class _TodoBlockState extends State<TodoBlock> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GestureDetector(
          onTap: () => widget.onEvent(
            CheckboxToggledEvent(
              blockId: widget.blockId,
              checked: !widget.checked,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(right: 8, top: 2),
            child: _Checkbox(checked: widget.checked),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTapDown: (details) {
              final offset = _resolveOffset(_textKey, details.localPosition);
              widget.onEvent(TapEvent(blockId: widget.blockId, offset: offset));
            },
            child: RichTextRenderer(
              key: _textKey,
              delta: widget.delta,
              blockId: widget.blockId,
              selection: widget.selection,
              baseStyle: TextStyle(
                fontSize: 16,
                decoration: widget.checked ? TextDecoration.lineThrough : null,
                color: widget.checked ? const Color(0xFF999999) : null,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _Checkbox extends StatelessWidget {
  const _Checkbox({required this.checked});

  final bool checked;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFF999999), width: 1.5),
        borderRadius: BorderRadius.circular(3),
        color: checked ? const Color(0xFF2196F3) : null,
      ),
      child: checked
          ? const Icon(
              IconData(0xe156, fontFamily: 'MaterialIcons'),
              size: 14,
              color: Color(0xFFFFFFFF),
            )
          : null,
    );
  }
}

/// A block quote widget.
class QuoteBlock extends StatefulWidget {
  /// Creates a [QuoteBlock] for the block identified by [blockId].
  const QuoteBlock({
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
  State<QuoteBlock> createState() => _QuoteBlockState();
}

class _QuoteBlockState extends State<QuoteBlock> {
  final _textKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (details) {
        final offset = _resolveOffset(_textKey, details.localPosition);
        widget.onEvent(TapEvent(blockId: widget.blockId, offset: offset));
      },
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFFCCCCCC), width: 4)),
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: RichTextRenderer(
            key: _textKey,
            delta: widget.delta,
            blockId: widget.blockId,
            selection: widget.selection,
            baseStyle: const TextStyle(fontSize: 16, color: Color(0xFF666666)),
          ),
        ),
      ),
    );
  }
}

/// A horizontal divider block widget.
class DividerBlock extends StatelessWidget {
  /// Creates a [DividerBlock] for the block identified by [blockId].
  const DividerBlock({super.key, required this.blockId, required this.onEvent});

  /// The id of the block this widget represents.
  final String blockId;

  /// Called when the user interacts with this block.
  final void Function(BlockEvent) onEvent;

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, thickness: 1, color: Color(0xFFE0E0E0));
  }
}
