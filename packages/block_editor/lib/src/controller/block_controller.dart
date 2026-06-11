// ignore_for_file: close_sinks

library;

import 'dart:async';
import 'dart:ui' show TextAffinity;

import 'package:block_editor/block_editor.dart';

/// Describes the structural change that occurred to the document.
enum ChangeType { insert, delete, update, move, replace }

/// Describes one high-level block operation inside a document change.
enum BlockOperationType { insert, delete, update, move, replace }

/// Structured operation data emitted with [DocumentChange].
///
/// This is intentionally higher-level than text offsets. It records the block
/// operation that occurred so Markdown save paths can later derive focused
/// source patches instead of treating every mutation as a whole-document
/// rewrite.
final class BlockDocumentOperation {
  /// Creates a structured block operation record.
  const BlockDocumentOperation({
    required this.type,
    this.blockId,
    this.before,
    this.after,
    this.fromIndex,
    this.toIndex,
  });

  /// Operation kind.
  final BlockOperationType type;

  /// Primary affected block id, when the operation targets a single block.
  final String? blockId;

  /// Block state before the operation, when available.
  final BlockNode? before;

  /// Block state after the operation, when available.
  final BlockNode? after;

  /// Root index before the operation, when relevant.
  final int? fromIndex;

  /// Root index after the operation, when relevant.
  final int? toIndex;
}

/// Carries a document mutation event emitted by [BlockController.changes].
///
/// Every mutation that modifies document structure produces one
/// [DocumentChange]. Selection changes are emitted separately on
/// [BlockController.selectionStream] and do not produce a [DocumentChange].
final class DocumentChange {
  /// Creates a [DocumentChange] of the given [type] for [document].
  const DocumentChange({
    required this.type,
    required this.document,
    this.affectedIds = const [],
    this.operations = const [],
  });

  /// The kind of structural mutation that occurred.
  final ChangeType type;

  /// The document state after the mutation.
  final BlockDocument document;

  /// The ids of blocks directly involved in the mutation.
  final List<String> affectedIds;

  /// Structured operation records for this mutation.
  final List<BlockDocumentOperation> operations;
}

/// The central state engine for a block editor document.
///
/// [BlockController] owns the [BlockDocument], the undo and redo stacks,
/// the current [EditorSelection], and the broadcast streams that the
/// rendering layer subscribes to.
///
/// Every document mutation is atomic: a snapshot is pushed to the undo stack,
/// a new document is built immutably, and a [DocumentChange] is emitted.
/// Selection mutations emit on [selectionStream] only and never push an undo
/// snapshot.
final class BlockController {
  /// Creates a [BlockController] optionally seeded with [document].
  ///
  /// [maxUndoSteps] caps the undo stack depth. Defaults to 100.
  BlockController({BlockDocument? document, int maxUndoSteps = 100})
    : _document = document ?? BlockDocument.empty(),
      _maxUndoSteps = maxUndoSteps {
    _undoStack.add(_document);
  }

  BlockDocument _document;
  final int _maxUndoSteps;
  final _undoStack = <BlockDocument>[];
  final _redoStack = <BlockDocument>[];
  final _streamController = StreamController<DocumentChange>.broadcast();
  final _selectionStreamController =
      StreamController<EditorSelection>.broadcast();
  final _blockStreamControllers = <String, StreamController<BlockNode>>{};
  EditorSelection _selection = EditorSelection.none;

  /// Emits a [DocumentChange] on every structural document mutation.
  ///
  /// Selection changes do not appear on this stream. Subscribe to
  /// [selectionStream] for selection updates.
  Stream<DocumentChange> get changes => _streamController.stream;

  /// Emits the new [EditorSelection] whenever the selection changes.
  ///
  /// Document mutations do not appear on this stream. Subscribe to [changes]
  /// for structural document updates.
  Stream<EditorSelection> get selectionStream =>
      _selectionStreamController.stream;

  /// The current document state.
  BlockDocument get document => _document;

  /// The current selection state.
  EditorSelection get selection => _selection;

  /// All block ids fully or partially covered by the current [selection].
  ///
  /// Returns an empty list when [selection] is [NoSelection].
  /// Returns a single id when [selection] is [CollapsedSelection].
  /// Returns all ids from the start block to the end block inclusive when
  /// [selection] is [ExpandedSelection].
  List<String> get selectedBlockIds {
    final sel = _selection;
    switch (sel) {
      case NoSelection():
        return [];
      case CollapsedSelection():
        return [sel.point.blockId];
      case ExpandedSelection():
        final ids = _document.flatten().map((b) => b.id).toList();
        final resolved = sel.resolveOrder(ids);
        final startIndex = ids.indexOf(resolved.start.blockId);
        final endIndex = ids.indexOf(resolved.end.blockId);
        if (startIndex == -1 || endIndex == -1) return [];
        return ids.sublist(startIndex, endIndex + 1);
    }
  }

  /// Returns a [Stream] that emits the updated [BlockNode] whenever the block
  /// identified by [blockId] changes.
  ///
  /// The stream is created on first access and reused for subsequent calls
  /// with the same [blockId]. It is closed automatically when the block is
  /// deleted from the document.
  ///
  /// Subscribers should cancel their subscription when the block widget is
  /// disposed to avoid receiving events after the widget is removed.
  Stream<BlockNode> streamForBlock(String blockId) {
    if (!_blockStreamControllers.containsKey(blockId)) {
      _blockStreamControllers[blockId] =
          StreamController<BlockNode>.broadcast();
    }
    return _blockStreamControllers[blockId]!.stream;
  }

  void _pushSnapshot() {
    _undoStack.add(_document);
    if (_undoStack.length > _maxUndoSteps + 1) _undoStack.removeAt(0);
    _redoStack.clear();
  }

  void _emit(DocumentChange change) {
    _document = change.document;
    _streamController.add(change);
    for (final id in change.affectedIds) {
      final node = _document.findById(id);
      final sc = _blockStreamControllers[id];
      if (sc != null && !sc.isClosed) {
        if (node != null) {
          sc.add(node);
        }
      }
    }
  }

  List<BlockNode> _replaceInList(
    List<BlockNode> nodes,
    String id,
    BlockNode Function(BlockNode) updater,
  ) {
    return nodes.map((node) {
      if (node.id == id) return updater(node);
      if (node.children.isNotEmpty) {
        return node.copyWith(
          children: _replaceInList(node.children, id, updater),
        );
      }
      return node;
    }).toList();
  }

  List<BlockNode> _mergeAttributesInList(
    List<BlockNode> nodes,
    Map<String, Map<String, dynamic>> attributesById,
    List<String> affectedIds,
  ) {
    return nodes.map((node) {
      var updatedNode = node;
      final attributes = attributesById[node.id];
      if (attributes != null) {
        updatedNode = updatedNode.copyWith(
          attributes: {...updatedNode.attributes, ...attributes},
        );
        affectedIds.add(node.id);
      }
      if (updatedNode.children.isNotEmpty) {
        updatedNode = updatedNode.copyWith(
          children: _mergeAttributesInList(
            updatedNode.children,
            attributesById,
            affectedIds,
          ),
        );
      }
      return updatedNode;
    }).toList();
  }

  List<BlockNode> _removeFromList(List<BlockNode> nodes, String id) {
    final result = <BlockNode>[];
    for (final node in nodes) {
      if (node.id == id) continue;
      result.add(node.copyWith(children: _removeFromList(node.children, id)));
    }
    return result;
  }

  /// Inserts [node] at [index] in the root block list.
  ///
  /// Throws [RangeError] if [index] is out of bounds.
  void insertAt(int index, BlockNode node) {
    RangeError.checkValueInInterval(index, 0, _document.blocks.length, 'index');
    _pushSnapshot();
    final updated = List.of(_document.blocks)..insert(index, node);
    _emit(
      DocumentChange(
        type: ChangeType.insert,
        document: _document.copyWith(blocks: updated),
        affectedIds: [node.id],
        operations: [
          BlockDocumentOperation(
            type: BlockOperationType.insert,
            blockId: node.id,
            after: node,
            toIndex: index,
          ),
        ],
      ),
    );
  }

  /// Appends [node] after the last root block.
  void append(BlockNode node) => insertAt(_document.blocks.length, node);

  /// Inserts [node] immediately after the block identified by [afterId].
  ///
  /// Throws [StateError] if no root block with [afterId] exists.
  void insertAfter(String afterId, BlockNode node) {
    final index = _document.blocks.indexWhere((b) => b.id == afterId);
    if (index == -1) throw StateError('No root block with id $afterId');
    insertAt(index + 1, node);
  }

  /// Removes the block identified by [id] from the document.
  ///
  /// Does nothing if no block with [id] exists. Closes and removes the
  /// per-block stream for [id] if one is open.
  void delete(String id) {
    final index = _document.blocks.indexWhere((block) => block.id == id);
    final deleted = _document.findById(id);
    if (deleted == null) return;
    _pushSnapshot();
    final updated = _removeFromList(_document.blocks, id);
    _emit(
      DocumentChange(
        type: ChangeType.delete,
        document: _document.copyWith(blocks: updated),
        affectedIds: [id],
        operations: [
          BlockDocumentOperation(
            type: BlockOperationType.delete,
            blockId: id,
            before: deleted,
            fromIndex: index < 0 ? null : index,
          ),
        ],
      ),
    );
    final sc = _blockStreamControllers.remove(id);
    if (sc != null && !sc.isClosed) sc.close();
  }

  /// Replaces the block identified by [id] with [updatedNode].
  ///
  /// Does nothing if no block with [id] exists.
  void update(String id, BlockNode updatedNode) {
    final before = _document.findById(id);
    if (before == null) return;
    _pushSnapshot();
    final updated = _replaceInList(_document.blocks, id, (_) => updatedNode);
    _emit(
      DocumentChange(
        type: ChangeType.update,
        document: _document.copyWith(blocks: updated),
        affectedIds: [id],
        operations: [
          BlockDocumentOperation(
            type: BlockOperationType.update,
            blockId: id,
            before: before,
            after: updatedNode,
          ),
        ],
      ),
    );
  }

  /// Replaces the [TextDelta] of the block identified by [id].
  void updateDelta(String id, TextDelta delta) {
    final node = _document.findById(id);
    if (node == null) return;
    update(id, node.copyWith(delta: delta));
  }

  /// Merges [attributes] into the block attributes of the block identified
  /// by [id]. Existing keys not present in [attributes] are preserved.
  void updateAttributes(String id, Map<String, dynamic> attributes) {
    final node = _document.findById(id);
    if (node == null) return;
    update(id, node.copyWith(attributes: {...node.attributes, ...attributes}));
  }

  /// Merges attributes into several blocks as a single undoable mutation.
  ///
  /// Unknown block ids are ignored. Existing keys not present in each block's
  /// attribute patch are preserved.
  void updateAttributesForBlocks(
    Map<String, Map<String, dynamic>> attributesById,
  ) {
    if (attributesById.isEmpty) return;
    final affectedIds = <String>[];
    final updated = _mergeAttributesInList(
      _document.blocks,
      attributesById,
      affectedIds,
    );
    if (affectedIds.isEmpty) return;
    final updatedDocument = _document.copyWith(blocks: updated);
    _pushSnapshot();
    _emit(
      DocumentChange(
        type: ChangeType.update,
        document: updatedDocument,
        affectedIds: affectedIds,
        operations: [
          for (final id in affectedIds)
            BlockDocumentOperation(
              type: BlockOperationType.update,
              blockId: id,
              before: _document.findById(id),
              after: updatedDocument.findById(id),
            ),
        ],
      ),
    );
  }

  /// Changes the type string of the block identified by [id] to [type].
  void transformType(String id, String type) {
    final node = _document.findById(id);
    if (node == null) return;
    update(id, node.copyWith(type: type));
  }

  /// Applies [attributes] to the inline range [[start], [end]) within the
  /// block identified by [id].
  void applyInlineAttributes(
    String id,
    int start,
    int end,
    InlineAttributes attributes,
  ) {
    final node = _document.findById(id);
    if (node == null || node.delta == null) return;
    updateDelta(id, node.delta!.applyAttributes(start, end, attributes));
  }

  /// Moves the root block identified by [id] to [newIndex].
  ///
  /// Throws [StateError] if [id] does not identify a root-level block.
  void move(String id, int newIndex) {
    final currentIndex = _document.blocks.indexWhere((b) => b.id == id);
    if (currentIndex == -1) {
      throw StateError('Block $id is not a root-level block');
    }
    _pushSnapshot();
    final list = List.of(_document.blocks);
    final node = list.removeAt(currentIndex);
    final targetIndex = newIndex.clamp(0, list.length);
    list.insert(targetIndex, node);
    _emit(
      DocumentChange(
        type: ChangeType.move,
        document: _document.copyWith(blocks: list),
        affectedIds: [id],
        operations: [
          BlockDocumentOperation(
            type: BlockOperationType.move,
            blockId: id,
            before: node,
            after: node,
            fromIndex: currentIndex,
            toIndex: targetIndex,
          ),
        ],
      ),
    );
  }

  /// Inserts a copy of the block identified by [blockId] immediately below it.
  ///
  /// The duplicate is a new [BlockNode] with a fresh UUID, identical type,
  /// attributes, children, and delta to the original. Does nothing when
  /// no block with [blockId] exists in the document.
  void duplicate(String blockId) {
    final blocks = document.blocks;
    final index = blocks.indexWhere((b) => b.id == blockId);
    if (index < 0) return;
    final original = blocks[index];
    final copy = BlockNode(
      type: original.type,
      attributes: Map.of(original.attributes),
      children: List.of(original.children),
      delta: original.delta,
    );
    insertAt(index + 1, copy);
  }

  /// Whether the undo stack has any steps to revert.
  bool get canUndo => _undoStack.length > 1;

  /// Whether the redo stack has any steps to re-apply.
  bool get canRedo => _redoStack.isNotEmpty;

  /// Reverts the most recent document mutation.
  ///
  /// Does nothing when [canUndo] is false.
  void undo() {
    if (!canUndo) return;
    _redoStack.add(_document);
    _undoStack.removeLast();
    _document = _undoStack.last;
    _streamController.add(
      DocumentChange(
        type: ChangeType.replace,
        document: _document,
        operations: const [
          BlockDocumentOperation(type: BlockOperationType.replace),
        ],
      ),
    );
  }

  /// Re-applies the most recently undone mutation.
  ///
  /// Does nothing when [canRedo] is false.
  void redo() {
    if (!canRedo) return;
    final next = _redoStack.removeLast();
    _undoStack.add(next);
    _document = next;
    _streamController.add(
      DocumentChange(
        type: ChangeType.replace,
        document: _document,
        operations: const [
          BlockDocumentOperation(type: BlockOperationType.replace),
        ],
      ),
    );
  }

  /// Replaces the entire document with [newDocument].
  ///
  /// The replacement is undoable unless [recordUndo] is false.
  void replaceDocument(BlockDocument newDocument, {bool recordUndo = true}) {
    if (recordUndo) _pushSnapshot();
    _emit(
      DocumentChange(
        type: ChangeType.replace,
        document: newDocument,
        operations: const [
          BlockDocumentOperation(type: BlockOperationType.replace),
        ],
      ),
    );
  }

  /// Updates the current selection and emits on [selectionStream].
  ///
  /// Does not push an undo snapshot.
  void updateSelection(EditorSelection selection) {
    _selection = selection;
    _selectionStreamController.add(_selection);
  }

  /// Collapses the selection to a caret at [offset] inside [blockId].
  void collapseSelection(
    String blockId,
    int offset, {
    TextAffinity affinity = TextAffinity.downstream,
  }) {
    updateSelection(
      CollapsedSelection(
        SelectionPoint(blockId: blockId, offset: offset, affinity: affinity),
      ),
    );
  }

  /// Expands the selection to cover the entire document.
  ///
  /// Does nothing when the document has no blocks.
  void selectAll() {
    final flat = _document.flatten();
    if (flat.isEmpty) return;
    final first = flat.first;
    final last = flat.last;
    final lastOffset = last.delta?.plainText.length ?? 0;
    updateSelection(
      ExpandedSelection(
        anchor: SelectionPoint(blockId: first.id, offset: 0),
        focus: SelectionPoint(blockId: last.id, offset: lastOffset),
      ),
    );
  }

  /// Clears the selection, setting it to [EditorSelection.none].
  void clearSelection() {
    updateSelection(EditorSelection.none);
  }

  /// Returns all unique tag strings present anywhere in the current document.
  ///
  /// Walks every block's [TextDelta] and collects the [TagOp.tag] value from
  /// every [TagOp] encountered. The returned set preserves insertion order and
  /// contains no duplicates. The document is never modified by this call.
  Set<String> get tags {
    final result = <String>{};
    for (final block in _document.flatten()) {
      final delta = block.delta;
      if (delta == null) continue;
      for (final op in delta.ops) {
        if (op is TagOp) result.add(op.tag);
      }
    }
    return result;
  }

  /// Releases all stream resources.
  ///
  /// Call when the controller is no longer needed.
  void dispose() {
    _streamController.close();
    _selectionStreamController.close();
    for (final sc in _blockStreamControllers.values) {
      if (!sc.isClosed) sc.close();
    }
    _blockStreamControllers.clear();
  }
}
