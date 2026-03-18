library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

/// Maps a [BlockNode] to its corresponding block widget.
///
/// [BlockRenderer] is the internal registry for all built-in block types.
/// It is stateless and has no knowledge of document structure beyond the
/// single [node] it receives. In Phase 3 the registry is promoted to a
/// public [BlockRegistry] that plugin authors can extend.
///
/// Unknown block types render as [UnknownBlock] rather than throwing, so
/// documents containing unregistered types degrade visibly without crashing.
class BlockRenderer extends StatelessWidget {
  /// Creates a [BlockRenderer] for [node].
  ///
  /// [onEvent] is forwarded to the rendered block widget and must not be null.
  ///
  /// [number] is the visible ordinal for numbered list items. It is ignored
  /// for all other block types. The caller is responsible for computing the
  /// correct value — [BlockRenderer] never derives position from context.
  ///
  /// [selection] is forwarded to the rendered block widget for highlight
  /// painting. Defaults to [EditorSelection.none].
  const BlockRenderer({
    super.key,
    required this.node,
    required this.onEvent,
    this.number = 1,
    this.selection = EditorSelection.none,
  });

  /// The block node to render.
  final BlockNode node;

  /// Called when the user interacts with the rendered block.
  final void Function(BlockEvent) onEvent;

  /// The visible ordinal for numbered list items.
  final int number;

  /// The current editor selection, forwarded to the rendered block widget.
  final EditorSelection selection;

  @override
  Widget build(BuildContext context) {
    final delta = node.delta ?? TextDelta.empty();
    final attrs = node.attributes;

    return switch (node.type) {
      BlockTypes.paragraph => ParagraphBlock(
        blockId: node.id,
        delta: delta,
        selection: selection,
        onEvent: onEvent,
      ),
      BlockTypes.heading1 => H1Block(
        blockId: node.id,
        delta: delta,
        selection: selection,
        onEvent: onEvent,
      ),
      BlockTypes.heading2 => H2Block(
        blockId: node.id,
        delta: delta,
        selection: selection,
        onEvent: onEvent,
      ),
      BlockTypes.heading3 => H3Block(
        blockId: node.id,
        delta: delta,
        selection: selection,
        onEvent: onEvent,
      ),
      BlockTypes.bulletList => BulletListBlock(
        blockId: node.id,
        delta: delta,
        attributes: attrs,
        selection: selection,
        onEvent: onEvent,
      ),
      BlockTypes.numberedList => NumberedListBlock(
        blockId: node.id,
        delta: delta,
        attributes: attrs,
        number: number,
        selection: selection,
        onEvent: onEvent,
      ),
      BlockTypes.todo => TodoBlock(
        blockId: node.id,
        delta: delta,
        checked: attrs['checked'] as bool? ?? false,
        selection: selection,
        onEvent: onEvent,
      ),
      BlockTypes.quote => QuoteBlock(
        blockId: node.id,
        delta: delta,
        selection: selection,
        onEvent: onEvent,
      ),
      BlockTypes.divider => DividerBlock(blockId: node.id, onEvent: onEvent),
      _ => UnknownBlock(blockId: node.id, type: node.type),
    };
  }
}

/// Rendered in place of any block whose type is not registered.
///
/// Displays the unrecognised type string so documents containing unknown
/// block types degrade visibly rather than crashing.
class UnknownBlock extends StatelessWidget {
  /// Creates an [UnknownBlock] for the unrecognised [type].
  const UnknownBlock({super.key, required this.blockId, required this.type});

  /// The id of the block this widget represents.
  final String blockId;

  /// The unrecognised block type string.
  final String type;

  @override
  Widget build(BuildContext context) {
    return Text(
      '[unknown block: $type]',
      style: const TextStyle(color: Color(0xFFFF0000), fontFamily: 'monospace'),
    );
  }
}
