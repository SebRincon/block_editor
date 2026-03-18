library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:block_editor/block_editor.dart';

/// The root widget of the block editor.
///
/// [BlockEditorWidget] assembles the full rendering pipeline — block layout,
/// cursor, selection highlight, keyboard routing, and scroll — on top of a
/// [BlockController] supplied by the caller.
///
/// The caller owns the [controller] and is responsible for calling
/// [BlockController.dispose] when it is no longer needed. This mirrors the
/// contract of [TextEditingController] with [TextField].
///
/// Setting [readOnly] to true switches the editor into a clean viewer mode.
/// All editing operations and keyboard shortcuts are disabled. The cursor
/// and selection highlight are suppressed. Text remains visible and
/// the widget tree remains fully built.
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
  const BlockEditorWidget({
    super.key,
    required this.controller,
    this.scrollController,
    this.readOnly = false,
    this.padding = const EdgeInsets.all(16),
    this.cursorColor = const Color(0xFF000000),
    this.selectionColor = const Color(0x443399FF),
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

  @override
  State<BlockEditorWidget> createState() => _BlockEditorWidgetState();
}

class _BlockEditorWidgetState extends State<BlockEditorWidget> {
  late StreamSubscription<DocumentChange> _changesSub;
  late StreamSubscription<EditorSelection> _selectionSub;
  late FocusNode _focusNode;
  late EditorEditingOperations _ops;
  ScrollController? _internalScrollController;

  ScrollController get _scrollController =>
      widget.scrollController ?? _internalScrollController!;

  @override
  void initState() {
    super.initState();
    _ops = EditorEditingOperations(widget.controller);
    _focusNode = FocusNode();
    if (widget.scrollController == null) {
      _internalScrollController = ScrollController();
    }
    _changesSub = widget.controller.changes.listen((_) {
      if (mounted) setState(() {});
    });
    _selectionSub = widget.controller.selectionStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(BlockEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _ops = EditorEditingOperations(widget.controller);
      _changesSub.cancel();
      _selectionSub.cancel();
      _changesSub = widget.controller.changes.listen((_) {
        if (mounted) setState(() {});
      });
      _selectionSub = widget.controller.selectionStream.listen((_) {
        if (mounted) setState(() {});
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
    _focusNode.dispose();
    _internalScrollController?.dispose();
    super.dispose();
  }

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

  @override
  Widget build(BuildContext context) {
    final blocks = widget.controller.document.blocks;

    final content = ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final node = blocks[index];
        final selection = _selectionForBlock(node.id);
        final number = node.type == BlockTypes.numberedList
            ? _resolveNumber(blocks, index)
            : 1;
        final covered = _isFullyCovered(node.id);
        final editorWidth =
            MediaQuery.of(context).size.width - widget.padding.horizontal;

        final blockWidget = BlockSelectionOverlay(
          isCovered: covered,
          highlightColor: widget.selectionColor,
          child: BlockCursor(
            blockId: node.id,
            delta: node.delta ?? TextDelta.empty(),
            selection: selection,
            cursorColor: widget.cursorColor,
            child: BlockRenderer(
              node: node,
              onEvent: _handleEvent,
              number: number,
              selection: selection,
            ),
          ),
        );

        return BlockDropTarget(
          key: ValueKey('drop_${node.id}'),
          index: index,
          blockId: node.id,
          onEvent: _handleEvent,
          totalBlocks: blocks.length,
          blockIdResolver: (dragIndex) =>
              dragIndex < blocks.length ? blocks[dragIndex].id : null,
          child: BlockDragHandle(
            key: ValueKey('handle_${node.id}'),
            index: index,
            blockId: node.id,
            onEvent: _handleEvent,
            readOnly: widget.readOnly,
            feedbackWidget: BlockGhost(node: node, width: editorWidth),
            child: blockWidget,
          ),
        );
      },
    );

    if (widget.readOnly) return content;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: content,
    );
  }
}
