library;

import 'package:block_editor/block_editor.dart';

/// Performs all character-level editing operations on a [BlockController].
///
/// [EditorEditingOperations] is a pure-Dart helper with no Flutter dependency.
/// [BlockEditorWidget] holds one instance and delegates all keyboard editing
/// events to it. Every method is independently testable without a widget tree.
class EditorEditingOperations {
  /// Creates an [EditorEditingOperations] bound to [controller].
  const EditorEditingOperations(this.controller);

  /// The controller whose document and selection are mutated.
  final BlockController controller;

  /// Inserts [character] at the current cursor position.
  ///
  /// Does nothing when the current selection is not a [CollapsedSelection]
  /// or when [character] is empty.
  void insertCharacter(String character) {
    if (character.isEmpty) return;
    final sel = controller.selection;
    if (sel is! CollapsedSelection) return;
    final blockId = sel.point.blockId;
    final offset = sel.point.offset;
    final node = controller.document.findById(blockId);
    if (node == null) return;
    final delta = node.delta ?? TextDelta.empty();
    final text = delta.plainText;
    final newText =
        text.substring(0, offset) + character + text.substring(offset);
    controller.updateDelta(blockId, TextDelta.fromPlainText(newText));
    controller.collapseSelection(blockId, offset + character.length);
  }

  /// Deletes the character before the cursor or the selected range.
  ///
  /// When the cursor is at offset 0 and there is a previous block, merges
  /// this block's content into the end of the previous block.
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
      final text = delta.plainText;
      final newText = text.substring(0, offset - 1) + text.substring(offset);
      controller.updateDelta(blockId, TextDelta.fromPlainText(newText));
      controller.collapseSelection(blockId, offset - 1);
      return;
    }

    final blocks = controller.document.blocks;
    final index = blocks.indexWhere((b) => b.id == blockId);
    if (index == 0) return;
    final prevNode = blocks[index - 1];
    if (prevNode.delta == null) return;
    final prevText = prevNode.delta!.plainText;
    final thisText = (node.delta ?? TextDelta.empty()).plainText;
    final joinOffset = prevText.length;
    controller.updateDelta(
      prevNode.id,
      TextDelta.fromPlainText(prevText + thisText),
    );
    controller.delete(blockId);
    controller.collapseSelection(prevNode.id, joinOffset);
  }

  /// Deletes the character at the cursor or the selected range.
  ///
  /// When the cursor is at the last offset of the block and there is a next
  /// block, merges the next block's content into this block.
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
    final text = delta.plainText;

    if (offset < text.length) {
      final newText = text.substring(0, offset) + text.substring(offset + 1);
      controller.updateDelta(blockId, TextDelta.fromPlainText(newText));
      controller.collapseSelection(blockId, offset);
      return;
    }

    final blocks = controller.document.blocks;
    final index = blocks.indexWhere((b) => b.id == blockId);
    if (index == blocks.length - 1) return;
    final nextNode = blocks[index + 1];
    final nextText = (nextNode.delta ?? TextDelta.empty()).plainText;
    controller.updateDelta(blockId, TextDelta.fromPlainText(text + nextText));
    controller.delete(nextNode.id);
    controller.collapseSelection(blockId, offset);
  }

  /// Splits the current block at the cursor offset or transforms an empty
  /// list block to a paragraph.
  ///
  /// For list block types ([BlockTypes.bulletList], [BlockTypes.numberedList],
  /// [BlockTypes.todo]) with an empty delta, transforms the block to a
  /// [BlockTypes.paragraph] in place instead of splitting.
  void insertNewline() {
    final sel = controller.selection;
    if (sel is! CollapsedSelection) return;
    final blockId = sel.point.blockId;
    final offset = sel.point.offset;
    final node = controller.document.findById(blockId);
    if (node == null) return;
    final delta = node.delta ?? TextDelta.empty();
    final text = delta.plainText;
    final isListType = _isListType(node.type);

    if (isListType && text.isEmpty) {
      controller.transformType(blockId, BlockTypes.paragraph);
      controller.collapseSelection(blockId, 0);
      return;
    }

    final before = text.substring(0, offset);
    final after = text.substring(offset);
    controller.updateDelta(blockId, TextDelta.fromPlainText(before));
    final newNode = BlockNode(
      type: node.type,
      attributes: Map.of(node.attributes)..remove('checked'),
      delta: TextDelta.fromPlainText(after),
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
      final text = node.delta?.plainText ?? '';
      final newText =
          text.substring(0, startOffset) + text.substring(endOffset);
      controller.updateDelta(startId, TextDelta.fromPlainText(newText));
      controller.collapseSelection(startId, startOffset);
      return;
    }

    final startNode = controller.document.findById(startId);
    final endNode = controller.document.findById(endId);
    if (startNode == null || endNode == null) return;

    final startText = startNode.delta?.plainText ?? '';
    final endText = endNode.delta?.plainText ?? '';
    final mergedText =
        startText.substring(0, startOffset) + endText.substring(endOffset);

    final allBlocks = controller.document.flatten();
    final startIndex = allBlocks.indexWhere((b) => b.id == startId);
    final endIndex = allBlocks.indexWhere((b) => b.id == endId);
    for (var i = endIndex; i > startIndex; i--) {
      controller.delete(allBlocks[i].id);
    }
    controller.updateDelta(startId, TextDelta.fromPlainText(mergedText));
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
