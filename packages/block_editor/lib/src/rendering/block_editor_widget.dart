library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:block_editor/block_editor.dart';

/// The root widget of the block editor.
///
/// [BlockEditorWidget] assembles the full rendering pipeline — block layout,
/// cursor, selection highlight, keyboard routing, scroll, and IME input — on
/// top of a [BlockController] supplied by the caller.
///
/// The caller owns the [controller] and is responsible for calling
/// [BlockController.dispose] when it is no longer needed.
///
/// Setting [readOnly] to true switches the editor into a clean viewer mode.
/// All editing operations, keyboard shortcuts, and IME input are disabled.
class BlockEditorWidget extends StatefulWidget {
  /// Creates a [BlockEditorWidget] driven by [controller].
  ///
  /// [controller] must not be null and must outlive this widget.
  ///
  /// [scrollController] is optional. When not supplied an internal
  /// [ScrollController] is created and managed by this widget.
  ///
  /// [padding] is applied around the block list. Defaults to 16px on all
  /// sides.
  ///
  /// [cursorColor] is forwarded to every [BlockCursor] in the list.
  ///
  /// [selectionColor] is forwarded to every [BlockSelectionOverlay] and
  /// [BlockRenderer] in the list.
  ///
  /// [onCustomEvent] receives every [CustomBlockEvent] emitted by a
  /// third-party block plugin. When null, custom events are silently dropped.
  ///
  /// [variables] is the map used to resolve inline [VariableOp] embeds at
  /// render time. It is threaded to all block renderers via [BlockEditorScope].
  const BlockEditorWidget({
    super.key,
    required this.controller,
    this.scrollController,
    this.readOnly = false,
    this.padding = const EdgeInsets.all(16),
    this.cursorColor = const Color(0xFF000000),
    this.selectionColor = const Color(0x443399FF),
    this.onCustomEvent,
    this.variables = const {},
  });

  /// The controller that owns the document and selection state.
  final BlockController controller;

  /// An optional scroll controller for the block list.
  final ScrollController? scrollController;

  /// When true the editor is in read-only viewer mode.
  final bool readOnly;

  /// Padding around the block list.
  final EdgeInsets padding;

  /// The color of the blinking cursor.
  final Color cursorColor;

  /// The color of selection highlights.
  final Color selectionColor;

  /// Called when a third-party block plugin emits a [CustomBlockEvent].
  ///
  /// When null, custom events are silently dropped.
  final void Function(CustomBlockEvent)? onCustomEvent;

  /// The variable resolution map for inline [VariableOp] embeds.
  ///
  /// Threaded to all block renderers via [BlockEditorScope]. The document
  /// is never modified during variable resolution.
  final Map<String, String> variables;

  @override
  State<BlockEditorWidget> createState() => _BlockEditorWidgetState();
}

class _BlockEditorWidgetState extends State<BlockEditorWidget>
    implements TextInputClient {
  late StreamSubscription<DocumentChange> _changesSub;
  late StreamSubscription<EditorSelection> _selectionSub;
  late FocusNode _focusNode;
  late EditorEditingOperations _ops;
  ScrollController? _internalScrollController;
  TextInputConnection? _inputConnection;
  TextRange _composingRange = TextRange.empty;

  ScrollController get _scrollController =>
      widget.scrollController ?? _internalScrollController!;

  @override
  void initState() {
    super.initState();
    _ops = EditorEditingOperations(widget.controller);
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);
    if (widget.scrollController == null) {
      _internalScrollController = ScrollController();
    }
    _changesSub = widget.controller.changes.listen((change) {
      if (!mounted) return;
      if (change.type != ChangeType.update) setState(() {});
      _syncIMEState();
    });
    _selectionSub = widget.controller.selectionStream.listen((_) {
      if (mounted) setState(() {});
      _syncIMEState();
    });
  }

  @override
  void didUpdateWidget(BlockEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _ops = EditorEditingOperations(widget.controller);
      _changesSub.cancel();
      _selectionSub.cancel();
      _changesSub = widget.controller.changes.listen((change) {
        if (!mounted) return;
        if (change.type != ChangeType.update) setState(() {});
        _syncIMEState();
      });
      _selectionSub = widget.controller.selectionStream.listen((_) {
        if (mounted) setState(() {});
        _syncIMEState();
      });
    }
    if (oldWidget.scrollController != widget.scrollController) {
      if (widget.scrollController == null &&
          _internalScrollController == null) {
        _internalScrollController = ScrollController();
      } else if (widget.scrollController != null) {
        _internalScrollController?.dispose();
        _internalScrollController = null;
      }
    }
  }

  @override
  void dispose() {
    _changesSub.cancel();
    _selectionSub.cancel();
    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _inputConnection?.close();
    _internalScrollController?.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    if (_focusNode.hasFocus) {
      _openIMEConnection();
    } else {
      _closeIMEConnection();
    }
  }

  void _openIMEConnection() {
    if (widget.readOnly) return;
    final sel = widget.controller.selection;
    if (sel is! CollapsedSelection) return;
    _inputConnection?.close();
    _inputConnection = TextInput.attach(
      this,
      const TextInputConfiguration(
        inputType: TextInputType.multiline,
        inputAction: TextInputAction.newline,
      ),
    );
    _inputConnection!.show();
    _syncIMEState();
  }

  void _closeIMEConnection() {
    _inputConnection?.close();
    _inputConnection = null;
    if (mounted) setState(() => _composingRange = TextRange.empty);
  }

  void _syncIMEState() {
    final connection = _inputConnection;
    if (connection == null || !connection.attached) return;
    final sel = widget.controller.selection;
    if (sel is! CollapsedSelection) return;
    final node = widget.controller.document.findById(sel.point.blockId);
    if (node == null) return;
    final text = node.delta?.plainText ?? '';
    final offset = sel.point.offset.clamp(0, text.length);
    connection.setEditingState(
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: offset),
        composing: _composingRange,
      ),
    );
  }

  @override
  void updateEditingValue(TextEditingValue value) {
    if (widget.readOnly) return;
    final sel = widget.controller.selection;
    if (sel is! CollapsedSelection) return;
    final blockId = sel.point.blockId;
    final node = widget.controller.document.findById(blockId);
    if (node == null) return;
    final currentText = node.delta?.plainText ?? '';
    final newText = value.text;

    if (newText != currentText) {
      _applyTextChange(
        blockId,
        currentText,
        newText,
        value.selection.baseOffset,
      );
    }

    if (mounted) {
      setState(() => _composingRange = value.composing);
    }
  }

  void _applyTextChange(
    String blockId,
    String currentText,
    String newText,
    int newCursorOffset,
  ) {
    final node = widget.controller.document.findById(blockId);
    if (node == null) return;
    final delta = node.delta ?? TextDelta.empty();

    int prefixLen = 0;
    while (prefixLen < currentText.length &&
        prefixLen < newText.length &&
        currentText[prefixLen] == newText[prefixLen]) {
      prefixLen++;
    }

    int suffixLen = 0;
    while (suffixLen < currentText.length - prefixLen &&
        suffixLen < newText.length - prefixLen &&
        currentText[currentText.length - 1 - suffixLen] ==
            newText[newText.length - 1 - suffixLen]) {
      suffixLen++;
    }

    final deleteStart = prefixLen;
    final deleteEnd = currentText.length - suffixLen;
    final insertedText = newText.substring(
      prefixLen,
      newText.length - suffixLen,
    );

    List<DeltaOp> ops = List.of(delta.ops);

    if (deleteEnd > deleteStart) {
      ops = _deleteRangeFromOps(ops, deleteStart, deleteEnd);
    }

    if (insertedText.isNotEmpty) {
      ops = _insertIntoOps(ops, deleteStart, insertedText);
    }

    widget.controller.updateDelta(blockId, TextDelta(ops));
    widget.controller.collapseSelection(
      blockId,
      newCursorOffset.clamp(0, newText.length),
    );
  }

  List<DeltaOp> _insertIntoOps(List<DeltaOp> ops, int offset, String text) {
    final attrs = _attributesAtOffset(ops, offset);
    if (ops.isEmpty) return [TextOp(text, attributes: attrs)];
    final result = <DeltaOp>[];
    var cursor = 0;
    var inserted = false;

    for (final op in ops) {
      if (op is! TextOp) {
        if (!inserted && cursor == offset) {
          result.add(TextOp(text, attributes: attrs));
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
        result.add(TextOp(text, attributes: attrs));
        if (after.isNotEmpty) {
          result.add(TextOp(after, attributes: op.attributes));
        }
        inserted = true;
      } else {
        result.add(op);
      }
      cursor = opEnd;
    }

    if (!inserted) result.add(TextOp(text, attributes: attrs));
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

  @override
  void performAction(TextInputAction action) {
    if (action == TextInputAction.newline) {
      _ops.insertNewline();
    }
  }

  @override
  void performPrivateCommand(String action, Map<String, dynamic> data) {}

  @override
  void insertContent(KeyboardInsertedContent content) {}

  @override
  void updateFloatingCursor(RawFloatingCursorPoint point) {}

  @override
  void showAutocorrectionPromptRect(int start, int end) {}

  @override
  void connectionClosed() {
    _inputConnection = null;
    if (mounted) setState(() => _composingRange = TextRange.empty);
  }

  @override
  void didChangeInputControl(
    TextInputControl? oldControl,
    TextInputControl? newControl,
  ) {}

  @override
  void insertTextPlaceholder(Size size) {}

  @override
  void removeTextPlaceholder() {}

  @override
  void performSelector(String selectorName) {}

  @override
  void showToolbar() {}

  @override
  TextEditingValue get currentTextEditingValue {
    final sel = widget.controller.selection;
    if (sel is! CollapsedSelection) return TextEditingValue.empty;
    final node = widget.controller.document.findById(sel.point.blockId);
    if (node == null) return TextEditingValue.empty;
    final text = node.delta?.plainText ?? '';
    final offset = sel.point.offset.clamp(0, text.length);
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
      composing: _composingRange,
    );
  }

  @override
  AutofillScope? get currentAutofillScope => null;

  void _handleEvent(BlockEvent event) {
    if (widget.readOnly) return;
    switch (event) {
      case TapEvent():
        final offset = event.offset < 0 ? 0 : event.offset;
        widget.controller.collapseSelection(event.blockId, offset);
        _focusNode.requestFocus();
      case CheckboxToggledEvent():
        widget.controller.updateAttributes(event.blockId, {
          'checked': event.checked,
        });
      case BlockReorderedEvent():
        widget.controller.move(event.blockId, event.newIndex);
      case CustomBlockEvent():
        widget.onCustomEvent?.call(event);
    }
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.readOnly) return KeyEventResult.ignored;
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final isCmd =
        HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;
    final isAlt = HardwareKeyboard.instance.isAltPressed;
    final key = event.logicalKey;

    if (isCmd && !isShift && key == LogicalKeyboardKey.keyA) {
      widget.controller.selectAll();
      return KeyEventResult.handled;
    }
    if (isCmd && !isShift && key == LogicalKeyboardKey.keyZ) {
      widget.controller.undo();
      return KeyEventResult.handled;
    }
    if ((isCmd && isShift && key == LogicalKeyboardKey.keyZ) ||
        (isCmd && key == LogicalKeyboardKey.keyY)) {
      widget.controller.redo();
      return KeyEventResult.handled;
    }
    if (isCmd && key == LogicalKeyboardKey.keyB) {
      _ops.applyBold();
      return KeyEventResult.handled;
    }
    if (isCmd && key == LogicalKeyboardKey.keyI) {
      _ops.applyItalic();
      return KeyEventResult.handled;
    }
    if (isCmd && key == LogicalKeyboardKey.keyU) {
      _ops.applyUnderline();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.escape) {
      widget.controller.clearSelection();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.backspace) {
      _ops.backspace();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.delete) {
      _ops.delete();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _ops.insertNewline();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      isShift ? _ops.dedent() : _ops.indent();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.home) {
      isCmd ? _ops.moveToDocumentStart() : _ops.moveToLineStart();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      isCmd ? _ops.moveToDocumentEnd() : _ops.moveToLineEnd();
      return KeyEventResult.handled;
    }
    if (isAlt && key == LogicalKeyboardKey.arrowLeft) {
      _ops.moveWordLeft();
      return KeyEventResult.handled;
    }
    if (isAlt && key == LogicalKeyboardKey.arrowRight) {
      _ops.moveWordRight();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowLeft) {
      _ops.moveWordLeft();
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _ops.moveWordRight();
      return KeyEventResult.handled;
    }

    if (!isCmd && !isAlt && event.character != null) {
      final char = event.character!;
      if (char.isNotEmpty && !_isControlCharacter(char)) {
        _ops.insertCharacter(char);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  bool _isControlCharacter(String char) {
    final code = char.codeUnitAt(0);
    return code < 32 || code == 127;
  }

  bool _isFullyCovered(String blockId) {
    final sel = widget.controller.selection;
    if (sel is! ExpandedSelection) return false;
    final covered = widget.controller.selectedBlockIds;
    if (covered.length < 3) return false;
    final interior = covered.sublist(1, covered.length - 1);
    return interior.contains(blockId);
  }

  int _resolveNumber(List<BlockNode> blocks, int index) {
    var count = 1;
    for (var i = index - 1; i >= 0; i--) {
      if (blocks[i].type == BlockTypes.numberedList) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  EditorSelection _selectionForBlock(String blockId) {
    if (widget.readOnly) return EditorSelection.none;
    return widget.controller.selection;
  }

  String? _focusedBlockId() {
    final sel = widget.controller.selection;
    if (sel is CollapsedSelection) return sel.point.blockId;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.controller.document.blocks;
    final focusedId = _focusedBlockId();

    final content = ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final rawNode = blocks[index];
        final selection = _selectionForBlock(rawNode.id);
        final number = rawNode.type == BlockTypes.numberedList
            ? _resolveNumber(blocks, index)
            : 1;
        final node = rawNode.type == BlockTypes.numberedList
            ? rawNode.copyWith(
                attributes: {...rawNode.attributes, 'number': number},
              )
            : rawNode;
        final covered = _isFullyCovered(rawNode.id);
        final editorWidth =
            MediaQuery.of(context).size.width - widget.padding.horizontal;
        final composing = focusedId == rawNode.id
            ? _composingRange
            : TextRange.empty;

        return BlockDropTarget(
          key: ValueKey('drop_${rawNode.id}'),
          index: index,
          blockId: rawNode.id,
          onEvent: _handleEvent,
          totalBlocks: blocks.length,
          blockIdResolver: (dragIndex) =>
              dragIndex < blocks.length ? blocks[dragIndex].id : null,
          child: BlockDragHandle(
            key: ValueKey('handle_${rawNode.id}'),
            index: index,
            blockId: rawNode.id,
            onEvent: _handleEvent,
            readOnly: widget.readOnly,
            feedbackWidget: BlockGhost(node: rawNode, width: editorWidth),
            child: _BlockItemWidget(
              key: ValueKey(rawNode.id),
              initialNode: node,
              controller: widget.controller,
              selection: selection,
              covered: covered,
              cursorColor: widget.cursorColor,
              selectionColor: widget.selectionColor,
              onEvent: _handleEvent,
              composingRange: composing,
            ),
          ),
        );
      },
    );

    if (widget.readOnly) {
      return BlockEditorScope(
        variables: widget.variables,
        readOnly: true,
        child: content,
      );
    }

    return BlockEditorScope(
      variables: widget.variables,
      readOnly: false,
      child: Focus(
        focusNode: _focusNode,
        onKeyEvent: _handleKeyEvent,
        child: content,
      ),
    );
  }
}

class _BlockItemWidget extends StatefulWidget {
  const _BlockItemWidget({
    super.key,
    required this.initialNode,
    required this.controller,
    required this.selection,
    required this.covered,
    required this.cursorColor,
    required this.selectionColor,
    required this.onEvent,
    required this.composingRange,
  });

  final BlockNode initialNode;
  final BlockController controller;
  final EditorSelection selection;
  final bool covered;
  final Color cursorColor;
  final Color selectionColor;
  final void Function(BlockEvent) onEvent;
  final TextRange composingRange;

  @override
  State<_BlockItemWidget> createState() => _BlockItemWidgetState();
}

class _BlockItemWidgetState extends State<_BlockItemWidget> {
  late BlockNode _node;
  StreamSubscription<BlockNode>? _blockSub;

  BlockNode _applyTransientAttributes(BlockNode updated) {
    final transient = widget.initialNode.attributes;
    if (transient.isEmpty) return updated;
    return updated.copyWith(attributes: {...updated.attributes, ...transient});
  }

  @override
  void initState() {
    super.initState();
    _node = widget.initialNode;
    _blockSub = widget.controller.streamForBlock(widget.initialNode.id).listen((
      updated,
    ) {
      if (mounted) setState(() => _node = _applyTransientAttributes(updated));
    });
  }

  @override
  void didUpdateWidget(_BlockItemWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialNode.id != widget.initialNode.id ||
        oldWidget.controller != widget.controller) {
      _blockSub?.cancel();
      _node = widget.initialNode;
      _blockSub = widget.controller
          .streamForBlock(widget.initialNode.id)
          .listen((updated) {
            if (mounted) {
              setState(() => _node = _applyTransientAttributes(updated));
            }
          });
    } else {
      _node = widget.initialNode;
    }
  }

  @override
  void dispose() {
    _blockSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlockSelectionOverlay(
      isCovered: widget.covered,
      highlightColor: widget.selectionColor,
      child: BlockCursor(
        blockId: _node.id,
        delta: _node.delta ?? TextDelta.empty(),
        selection: widget.selection,
        cursorColor: widget.cursorColor,
        child: BlockRenderer(
          node: _node,
          onEvent: widget.onEvent,
          selection: widget.selection,
        ),
      ),
    );
  }
}
