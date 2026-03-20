library;

import 'package:block_editor/block_editor.dart';

/// Performs all character-level editing operations on a [BlockController].
///
/// [EditorEditingOperations] is a pure-Dart helper with no Flutter dependency.
/// [BlockEditorWidget] holds one instance and delegates all keyboard editing
/// events to it. Every method is independently testable without a widget tree.
///
/// All operations manipulate [TextDelta.ops] directly, preserving inline
/// formatting across every insertion, deletion, and block split.
class EditorEditingOperations {
  /// Creates an [EditorEditingOperations] bound to [controller].
  const EditorEditingOperations(this.controller);

  /// The controller whose document and selection are mutated.
  final BlockController controller;

  /// Inserts [character] at the current cursor position.
  ///
  /// The inserted character inherits the [InlineAttributes] of the character
  /// immediately to its left. Does nothing when the current selection is not
  /// a [CollapsedSelection] or when [character] is empty.
  void insertCharacter(String character) {
    if (character.isEmpty) return;
    final sel = controller.selection;
    if (sel is! CollapsedSelection) return;
    final blockId = sel.point.blockId;
    final offset = sel.point.offset;
    final node = controller.document.findById(blockId);
    if (node == null) return;
    final delta = node.delta ?? TextDelta.empty();
    final newOps = _insertIntoOps(delta.ops, offset, character);
    controller.updateDelta(blockId, TextDelta(newOps));
    controller.collapseSelection(blockId, offset + character.length);
  }

  /// Deletes the character before the cursor or the selected range.
  ///
  /// When the cursor is at offset 0 and there is a previous block, merges
  /// this block's content into the end of the previous block, preserving
  /// inline formatting on both sides.
  void backspace() {
    final sel = controller.selection;
    if (sel is ExpandedSelection) {
      _deleteSelectedRange(sel);
      return;
    }
    if (sel is! CollapsedSelection) return;
    final blockId = sel.point.blockId;
    final offset = sel.point.offset;
    final node = controller.document.findById(blockId);
    if (node == null) return;

    if (offset > 0) {
      final delta = node.delta ?? TextDelta.empty();
      final newOps = _deleteRangeFromOps(delta.ops, offset - 1, offset);
      controller.updateDelta(blockId, TextDelta(newOps));
      controller.collapseSelection(blockId, offset - 1);
      return;
    }

    final blocks = controller.document.blocks;
    final index = blocks.indexWhere((b) => b.id == blockId);
    if (index == 0) return;
    final prevNode = blocks[index - 1];
    if (prevNode.delta == null) return;
    final prevDelta = prevNode.delta!;
    final joinOffset = prevDelta.plainText.length;
    final thisDelta = node.delta ?? TextDelta.empty();
    controller.updateDelta(prevNode.id, prevDelta.concat(thisDelta));
    controller.delete(blockId);
    controller.collapseSelection(prevNode.id, joinOffset);
  }

  /// Deletes the character at the cursor or the selected range.
  ///
  /// When the cursor is at the last offset of the block and there is a next
  /// block, merges the next block's content into this block, preserving
  /// inline formatting on both sides.
  void delete() {
    final sel = controller.selection;
    if (sel is ExpandedSelection) {
      _deleteSelectedRange(sel);
      return;
    }
    if (sel is! CollapsedSelection) return;
    final blockId = sel.point.blockId;
    final offset = sel.point.offset;
    final node = controller.document.findById(blockId);
    if (node == null) return;
    final delta = node.delta ?? TextDelta.empty();

    if (offset < delta.plainText.length) {
      final newOps = _deleteRangeFromOps(delta.ops, offset, offset + 1);
      controller.updateDelta(blockId, TextDelta(newOps));
      controller.collapseSelection(blockId, offset);
      return;
    }

    final blocks = controller.document.blocks;
    final index = blocks.indexWhere((b) => b.id == blockId);
    if (index == blocks.length - 1) return;
    final nextNode = blocks[index + 1];
    final nextDelta = nextNode.delta ?? TextDelta.empty();
    controller.updateDelta(blockId, delta.concat(nextDelta));
    controller.delete(nextNode.id);
    controller.collapseSelection(blockId, offset);
  }

  /// Splits the current block at the cursor offset or transforms an empty
  /// list block to a paragraph.
  ///
  /// The before half retains its inline formatting via [TextDelta.slice].
  /// The after half retains its inline formatting via [TextDelta.slice].
  /// For list block types with an empty delta, transforms the block to a
  /// [BlockTypes.paragraph] in place instead of splitting.
  void insertNewline() {
    final sel = controller.selection;
    if (sel is! CollapsedSelection) return;
    final blockId = sel.point.blockId;
    final offset = sel.point.offset;
    final node = controller.document.findById(blockId);
    if (node == null) return;
    final delta = node.delta ?? TextDelta.empty();
    final isListType = _isListType(node.type);

    if (isListType && delta.isEmpty) {
      controller.transformType(blockId, BlockTypes.paragraph);
      controller.collapseSelection(blockId, 0);
      return;
    }

    final length = delta.plainText.length;
    final before = delta.slice(0, offset);
    final after = delta.slice(offset, length);
    controller.updateDelta(blockId, before);
    final newNode = BlockNode(
      type: node.type,
      attributes: Map.of(node.attributes)..remove('checked'),
      delta: after,
    );
    final blocks = controller.document.blocks;
    final index = blocks.indexWhere((b) => b.id == blockId);
    controller.insertAt(index + 1, newNode);
    controller.collapseSelection(newNode.id, 0);
  }

  /// Increments the indent level of the current list block by 1.
  ///
  /// Does nothing for non-list block types. Indent is clamped at 8.
  void indent() {
    final sel = controller.selection;
    if (sel is! CollapsedSelection) return;
    final node = controller.document.findById(sel.point.blockId);
    if (node == null || !_isListType(node.type)) return;
    final current = node.attributes['indent'] as int? ?? 0;
    controller.updateAttributes(node.id, {'indent': (current + 1).clamp(0, 8)});
  }

  /// Decrements the indent level of the current list block by 1.
  ///
  /// Does nothing for non-list block types. Indent is clamped at 0.
  void dedent() {
    final sel = controller.selection;
    if (sel is! CollapsedSelection) return;
    final node = controller.document.findById(sel.point.blockId);
    if (node == null || !_isListType(node.type)) return;
    final current = node.attributes['indent'] as int? ?? 0;
    controller.updateAttributes(node.id, {'indent': (current - 1).clamp(0, 8)});
  }

  /// Applies bold to the current expanded selection.
  ///
  /// Does nothing when the selection is collapsed.
  void applyBold() => _applyInline(const InlineAttributes(bold: true));

  /// Applies italic to the current expanded selection.
  ///
  /// Does nothing when the selection is collapsed.
  void applyItalic() => _applyInline(const InlineAttributes(italic: true));

  /// Applies underline to the current expanded selection.
  ///
  /// Does nothing when the selection is collapsed.
  void applyUnderline() =>
      _applyInline(const InlineAttributes(underline: true));

  /// Moves the cursor to the start of the current block.
  void moveToLineStart() {
    final sel = controller.selection;
    if (sel is! CollapsedSelection) return;
    controller.collapseSelection(sel.point.blockId, 0);
  }

  /// Moves the cursor to the end of the current block.
  void moveToLineEnd() {
    final sel = controller.selection;
    if (sel is! CollapsedSelection) return;
    final node = controller.document.findById(sel.point.blockId);
    if (node == null) return;
    final length = node.delta?.plainText.length ?? 0;
    controller.collapseSelection(sel.point.blockId, length);
  }

  /// Moves the cursor to offset 0 of the first block in the document.
  void moveToDocumentStart() {
    final blocks = controller.document.blocks;
    if (blocks.isEmpty) return;
    controller.collapseSelection(blocks.first.id, 0);
  }

  /// Moves the cursor to the last offset of the last block in the document.
  void moveToDocumentEnd() {
    final blocks = controller.document.blocks;
    if (blocks.isEmpty) return;
    final last = blocks.last;
    final length = last.delta?.plainText.length ?? 0;
    controller.collapseSelection(last.id, length);
  }

  /// Moves the cursor one word to the left within the current block.
  ///
  /// If already at offset 0 moves to the end of the previous block.
  void moveWordLeft() {
    final sel = controller.selection;
    if (sel is! CollapsedSelection) return;
    final blockId = sel.point.blockId;
    final offset = sel.point.offset;
    final node = controller.document.findById(blockId);
    if (node == null) return;
    final text = node.delta?.plainText ?? '';

    if (offset == 0) {
      final blocks = controller.document.blocks;
      final index = blocks.indexWhere((b) => b.id == blockId);
      if (index == 0) return;
      final prev = blocks[index - 1];
      final prevLength = prev.delta?.plainText.length ?? 0;
      controller.collapseSelection(prev.id, prevLength);
      return;
    }

    controller.collapseSelection(blockId, _prevWordBoundary(text, offset));
  }

  /// Moves the cursor one word to the right within the current block.
  ///
  /// If already at the last offset moves to offset 0 of the next block.
  void moveWordRight() {
    final sel = controller.selection;
    if (sel is! CollapsedSelection) return;
    final blockId = sel.point.blockId;
    final offset = sel.point.offset;
    final node = controller.document.findById(blockId);
    if (node == null) return;
    final text = node.delta?.plainText ?? '';

    if (offset >= text.length) {
      final blocks = controller.document.blocks;
      final index = blocks.indexWhere((b) => b.id == blockId);
      if (index == blocks.length - 1) return;
      controller.collapseSelection(blocks[index + 1].id, 0);
      return;
    }

    controller.collapseSelection(blockId, _nextWordBoundary(text, offset));
  }

  List<DeltaOp> _insertIntoOps(
    List<DeltaOp> ops,
    int offset,
    String character,
  ) {
    final attrs = _attributesAtOffset(ops, offset);
    if (ops.isEmpty) {
      return [TextOp(character, attributes: attrs)];
    }
    final result = <DeltaOp>[];
    var cursor = 0;
    var inserted = false;

    for (final op in ops) {
      if (op is! TextOp) {
        if (!inserted && cursor == offset) {
          result.add(TextOp(character, attributes: attrs));
          inserted = true;
        }
        result.add(op);
        continue;
      }
      final opEnd = cursor + op.text.length;
      if (!inserted && offset >= cursor && offset <= opEnd) {
        final splitAt = offset - cursor;
        final before = op.text.substring(0, splitAt);
        final after = op.text.substring(splitAt);
        if (before.isNotEmpty) {
          result.add(TextOp(before, attributes: op.attributes));
        }
        result.add(TextOp(character, attributes: attrs));
        if (after.isNotEmpty) {
          result.add(TextOp(after, attributes: op.attributes));
        }
        inserted = true;
      } else {
        result.add(op);
      }
      cursor = opEnd;
    }

    if (!inserted) {
      result.add(TextOp(character, attributes: attrs));
    }

    return result;
  }

  List<DeltaOp> _deleteRangeFromOps(List<DeltaOp> ops, int start, int end) {
    final result = <DeltaOp>[];
    var cursor = 0;

    for (final op in ops) {
      if (op is! TextOp) {
        result.add(op);
        continue;
      }
      final opStart = cursor;
      final opEnd = cursor + op.text.length;
      cursor = opEnd;

      if (opEnd <= start || opStart >= end) {
        result.add(op);
        continue;
      }

      final keepBefore = op.text.substring(
        0,
        (start - opStart).clamp(0, op.text.length),
      );
      final keepAfter = op.text.substring(
        (end - opStart).clamp(0, op.text.length),
      );

      if (keepBefore.isNotEmpty) {
        result.add(TextOp(keepBefore, attributes: op.attributes));
      }
      if (keepAfter.isNotEmpty) {
        result.add(TextOp(keepAfter, attributes: op.attributes));
      }
    }

    return result;
  }

  InlineAttributes _attributesAtOffset(List<DeltaOp> ops, int offset) {
    if (offset == 0 || ops.isEmpty) return const InlineAttributes();
    var cursor = 0;
    for (final op in ops) {
      if (op is! TextOp) continue;
      final opEnd = cursor + op.text.length;
      if (offset > cursor && offset <= opEnd) return op.attributes;
      cursor = opEnd;
    }
    final last = ops.lastWhere((op) => op is TextOp, orElse: () => ops.last);
    return last is TextOp ? last.attributes : const InlineAttributes();
  }

  void _deleteSelectedRange(ExpandedSelection sel) {
    final ids = controller.document.flatten().map((b) => b.id).toList();
    final resolved = sel.resolveOrder(ids);
    final startId = resolved.start.blockId;
    final endId = resolved.end.blockId;
    final startOffset = resolved.start.offset;
    final endOffset = resolved.end.offset;

    if (startId == endId) {
      final node = controller.document.findById(startId);
      if (node == null) return;
      final delta = node.delta ?? TextDelta.empty();
      final newOps = _deleteRangeFromOps(delta.ops, startOffset, endOffset);
      controller.updateDelta(startId, TextDelta(newOps));
      controller.collapseSelection(startId, startOffset);
      return;
    }

    final startNode = controller.document.findById(startId);
    final endNode = controller.document.findById(endId);
    if (startNode == null || endNode == null) return;

    final startDelta = startNode.delta ?? TextDelta.empty();
    final endDelta = endNode.delta ?? TextDelta.empty();
    final merged = startDelta
        .slice(0, startOffset)
        .concat(endDelta.slice(endOffset, endDelta.plainText.length));

    final allBlocks = controller.document.flatten();
    final startIndex = allBlocks.indexWhere((b) => b.id == startId);
    final endIndex = allBlocks.indexWhere((b) => b.id == endId);
    for (var i = endIndex; i > startIndex; i--) {
      controller.delete(allBlocks[i].id);
    }
    controller.updateDelta(startId, merged);
    controller.collapseSelection(startId, startOffset);
  }

  void _applyInline(InlineAttributes attributes) {
    final sel = controller.selection;
    if (sel is! ExpandedSelection) return;
    final ids = controller.document.flatten().map((b) => b.id).toList();
    final resolved = sel.resolveOrder(ids);
    if (resolved.start.blockId == resolved.end.blockId) {
      controller.applyInlineAttributes(
        resolved.start.blockId,
        resolved.start.offset,
        resolved.end.offset,
        attributes,
      );
      return;
    }
    final startNode = controller.document.findById(resolved.start.blockId);
    if (startNode != null) {
      controller.applyInlineAttributes(
        resolved.start.blockId,
        resolved.start.offset,
        startNode.delta?.plainText.length ?? 0,
        attributes,
      );
    }
    final allBlocks = controller.document.flatten();
    final startIndex = allBlocks.indexWhere(
      (b) => b.id == resolved.start.blockId,
    );
    final endIndex = allBlocks.indexWhere((b) => b.id == resolved.end.blockId);
    for (var i = startIndex + 1; i < endIndex; i++) {
      final node = allBlocks[i];
      final length = node.delta?.plainText.length ?? 0;
      if (length > 0) {
        controller.applyInlineAttributes(node.id, 0, length, attributes);
      }
    }
    controller.applyInlineAttributes(
      resolved.end.blockId,
      0,
      resolved.end.offset,
      attributes,
    );
  }

  bool _isListType(String type) =>
      type == BlockTypes.bulletList ||
      type == BlockTypes.numberedList ||
      type == BlockTypes.todo;

  int _prevWordBoundary(String text, int offset) {
    var i = offset - 1;
    while (i > 0 && _isWhitespace(text[i - 1])) {
      i--;
    }
    while (i > 0 && !_isWhitespace(text[i - 1])) {
      i--;
    }
    return i;
  }

  int _nextWordBoundary(String text, int offset) {
    var i = offset;
    while (i < text.length && _isWhitespace(text[i])) {
      i++;
    }
    while (i < text.length && !_isWhitespace(text[i])) {
      i++;
    }
    return i;
  }

  bool _isWhitespace(String char) => char.trim().isEmpty;
}
