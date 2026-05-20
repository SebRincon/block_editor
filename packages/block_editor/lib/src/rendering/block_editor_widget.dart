library;

import 'dart:async';

import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:block_editor/block_editor.dart';
import 'editor_span_builder.dart';

/// The root widget of the block editor.
///
/// [BlockEditorWidget] assembles the full rendering pipeline — block layout,
/// cursor, selection highlight, keyboard routing, scroll, IME input, the
/// context-sensitive formatting toolbar, and the slash command menu — on top
/// of a [BlockController] supplied by the caller.
///
/// The caller owns the [controller] and is responsible for calling
/// [BlockController.dispose] when it is no longer needed.
///
/// Setting [readOnly] to true switches the editor into a clean viewer mode.
/// All editing operations, keyboard shortcuts, IME input, and the formatting
/// toolbar are disabled.
///
/// ## Formatting toolbar display modes
///
/// The toolbar appears whenever the editor has an active [ExpandedSelection]
/// and [readOnly] is false. Its layout adapts to the available screen width
/// compared to [toolbarBreakpoint]:
///
/// - **Wide** (available width ≥ [toolbarBreakpoint]): the toolbar floats
///   above the selected block, horizontally centered and clamped to screen
///   edges.
/// - **Narrow / desktop**: the toolbar is pinned to the bottom of the
///   editor's own bounds.
///
/// ## Color picker
///
/// The toolbar includes text color and background color buttons. Their
/// behavior depends on [onColorPickerRequested]:
///
/// **Zero-config (default, [onColorPickerRequested] is null):**
/// ```dart
/// BlockEditorWidget(controller: controller)
/// ```
/// Tapping either color button opens a built-in 12-swatch palette popover
/// with a clear option. The palette is a private implementation detail of the
/// toolbar and is not part of the public API.
///
/// **Custom color picker ([onColorPickerRequested] is non-null):**
/// ```dart
/// BlockEditorWidget(
///   controller: controller,
///   onColorPickerRequested: (currentColor) async {
///     final picked = await showMyColorPicker(
///       context: context,
///       initialColor: currentColor,
///     );
///     return picked;
///   },
/// )
/// ```
/// The callback receives the current color of the first op in the selection
/// (may be null if no color is set) and must return a [Future<Color?>].
/// When the future resolves to a non-null [Color] that color is applied to
/// the selection. When it resolves to null no change is made. The built-in
/// palette is never shown when this callback is provided.
class BlockEditorWidget extends StatefulWidget {
  const BlockEditorWidget({
    super.key,
    required this.controller,
    this.focusNode,
    this.scrollController,
    this.readOnly = false,
    this.padding = const EdgeInsets.all(16),
    this.cursorColor,
    this.selectionColor,
    this.onCustomEvent,
    this.variables = const {},
    this.toolbarBreakpoint = 768.0,
    this.showFormattingToolbar = true,
    this.onColorPickerRequested,
    this.sourceEditingConfig,
  });

  /// The controller that owns the document and selection state.
  final BlockController controller;

  /// Optional focus node used by the editor keyboard and IME pipeline.
  ///
  /// Supplying this lets hosts integrate the block editor into an existing
  /// focus system, for example a tab-level workbench focus handle.
  final FocusNode? focusNode;

  /// An optional scroll controller for the block list.
  final ScrollController? scrollController;

  /// When true the editor is in read-only viewer mode.
  final bool readOnly;

  /// Padding around the block list.
  final EdgeInsets padding;

  /// The color of the blinking cursor.
  final Color? cursorColor;

  /// The color of selection highlights.
  final Color? selectionColor;

  /// Called when a third-party block plugin emits a [CustomBlockEvent].
  final void Function(CustomBlockEvent)? onCustomEvent;

  /// The variable resolution map for inline [VariableOp] embeds.
  final Map<String, String> variables;

  /// The screen width threshold in logical pixels that determines the
  /// formatting toolbar display mode. Defaults to 768.
  final double toolbarBreakpoint;

  /// Whether the editor owns and displays the floating formatting toolbar.
  ///
  /// Hosts that render [FormattingToolbarControls] in their own chrome can set
  /// this to false to avoid showing a duplicate floating toolbar.
  final bool showFormattingToolbar;

  /// Optional callback invoked when the user taps a color button in the
  /// formatting toolbar.
  ///
  /// When null the built-in 12-swatch palette popover is shown. When
  /// non-null this callback is awaited and its returned [Color] is applied
  /// if non-null. See the class-level documentation for full usage details.
  final Future<Color?> Function(Color? currentColor)? onColorPickerRequested;

  /// Optional shared styling/highlighting for embedded source editors such as
  /// code fences, Mermaid source, math source, and raw Markdown blocks.
  final BlockSourceEditingConfig? sourceEditingConfig;

  @override
  State<BlockEditorWidget> createState() => _BlockEditorWidgetState();
}

class _BlockEditorWidgetState extends State<BlockEditorWidget>
    implements TextInputClient {
  late StreamSubscription<DocumentChange> _changesSub;
  late StreamSubscription<EditorSelection> _selectionSub;
  late FocusNode _focusNode;
  late bool _ownsFocusNode;
  late EditorEditingOperations _ops;
  late KeyboardShortcutHandler _shortcuts;
  final GlobalKey _editorKey = GlobalKey();
  final Map<String, GlobalKey> _blockKeys = {};
  final OverlayPortalController _toolbarController = OverlayPortalController();
  final OverlayPortalController _slashMenuController =
      OverlayPortalController();
  final OverlayPortalController _actionMenuController =
      OverlayPortalController();
  ScrollController? _internalScrollController;
  TextInputConnection? _inputConnection;
  TextRange _composingRange = TextRange.empty;
  bool _toolbarVisible = false;
  bool _slashMenuVisible = false;
  String? _slashTriggerBlockId;
  int _slashTriggerOffset = 0;
  bool _actionMenuVisible = false;
  String? _actionMenuBlockId;
  Offset _actionMenuPosition = Offset.zero;
  int? _selectionPointer;
  Offset? _selectionPointerStart;
  SelectionPoint? _selectionDragAnchor;
  bool _selectionDragActive = false;
  int _embeddedInputFocusDepth = 0;

  ScrollController get _scrollController =>
      widget.scrollController ?? _internalScrollController!;

  KeyboardShortcutHandler _createShortcutHandler() {
    return KeyboardShortcutHandler(
      controller: widget.controller,
      ops: _ops,
      commandRegistry: _createCommandRegistry(),
      onPostCommand: _handlePostCommand,
    );
  }

  EditorCommandRegistry _createCommandRegistry() {
    return EditorCommandRegistry([
      EditorCommand(
        id: EditorCommandIds.moveToLineStart,
        title: 'Move To Visual Line Start',
        category: 'Navigation',
        execute: (_) {
          _moveToVisualLineBoundary(end: false, expand: false);
          return const EditorCommandResult.handled();
        },
      ),
      EditorCommand(
        id: EditorCommandIds.moveToLineEnd,
        title: 'Move To Visual Line End',
        category: 'Navigation',
        execute: (_) {
          _moveToVisualLineBoundary(end: true, expand: false);
          return const EditorCommandResult.handled();
        },
      ),
      EditorCommand(
        id: EditorCommandIds.extendSelectionToLineStart,
        title: 'Extend Selection To Visual Line Start',
        category: 'Selection',
        execute: (_) {
          _moveToVisualLineBoundary(end: false, expand: true);
          return const EditorCommandResult.handled();
        },
      ),
      EditorCommand(
        id: EditorCommandIds.extendSelectionToLineEnd,
        title: 'Extend Selection To Visual Line End',
        category: 'Selection',
        execute: (_) {
          _moveToVisualLineBoundary(end: true, expand: true);
          return const EditorCommandResult.handled();
        },
      ),
      ...EditorCommands.standard,
    ]);
  }

  @override
  void initState() {
    super.initState();
    _ops = EditorEditingOperations(widget.controller);
    _shortcuts = _createShortcutHandler();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode = widget.focusNode ?? FocusNode();
    _focusNode.addListener(_onFocusChange);
    if (widget.scrollController == null) {
      _internalScrollController = ScrollController();
    }
    _changesSub = widget.controller.changes.listen((change) {
      if (!mounted) return;
      if (change.type != ChangeType.update) setState(() {});
      _syncIMEState();
    });
    _selectionSub = widget.controller.selectionStream.listen((sel) {
      if (!mounted) return;
      setState(() {});
      _syncIMEState();
      _updateToolbarVisibility(sel);
    });
    _updateToolbarVisibility(widget.controller.selection);
  }

  @override
  void didUpdateWidget(BlockEditorWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      _ops = EditorEditingOperations(widget.controller);
      _shortcuts = _createShortcutHandler();
      _changesSub.cancel();
      _selectionSub.cancel();
      _changesSub = widget.controller.changes.listen((change) {
        if (!mounted) return;
        if (change.type != ChangeType.update) setState(() {});
        _syncIMEState();
      });
      _selectionSub = widget.controller.selectionStream.listen((sel) {
        if (!mounted) return;
        setState(() {});
        _syncIMEState();
        _updateToolbarVisibility(sel);
      });
    }
    if (oldWidget.focusNode != widget.focusNode) {
      _focusNode.removeListener(_onFocusChange);
      if (_ownsFocusNode) _focusNode.dispose();
      _ownsFocusNode = widget.focusNode == null;
      _focusNode = widget.focusNode ?? FocusNode();
      _focusNode.addListener(_onFocusChange);
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
    if (oldWidget.controller != widget.controller ||
        oldWidget.readOnly != widget.readOnly ||
        oldWidget.showFormattingToolbar != widget.showFormattingToolbar) {
      _updateToolbarVisibility(widget.controller.selection);
    }
  }

  @override
  void dispose() {
    _changesSub.cancel();
    _selectionSub.cancel();
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    _inputConnection?.close();
    _internalScrollController?.dispose();
    super.dispose();
  }

  void _updateToolbarVisibility(EditorSelection sel) {
    if (widget.readOnly || !widget.showFormattingToolbar) {
      if (_toolbarVisible) {
        _toolbarController.hide();
        setState(() => _toolbarVisible = false);
      }
      return;
    }
    final shouldShow = sel is ExpandedSelection;
    if (shouldShow && !_toolbarVisible) {
      _toolbarController.show();
      setState(() => _toolbarVisible = true);
    } else if (!shouldShow && _toolbarVisible) {
      _toolbarController.hide();
      setState(() => _toolbarVisible = false);
    }
  }

  void _handleSelectionPointerDown(PointerDownEvent event) {
    if (widget.readOnly) return;
    if ((event.buttons & kPrimaryButton) == 0) return;
    final anchor = _selectionPointAtGlobal(
      event.position,
      requireTextHit: true,
    );
    if (anchor == null) return;
    _selectionPointer = event.pointer;
    _selectionPointerStart = event.position;
    _selectionDragAnchor = anchor;
    _selectionDragActive = false;
  }

  void _handleSelectionPointerMove(PointerMoveEvent event) {
    if (widget.readOnly) return;
    if (event.pointer != _selectionPointer) return;
    if ((event.buttons & kPrimaryButton) == 0) {
      _clearSelectionDrag();
      return;
    }

    final anchor = _selectionDragAnchor;
    final start = _selectionPointerStart;
    if (anchor == null || start == null) return;
    if (!_selectionDragActive && (event.position - start).distance < 3.0) {
      return;
    }

    final focus = _selectionPointAtGlobal(
      event.position,
      requireTextHit: false,
    );
    if (focus == null) return;

    _selectionDragActive = true;
    _focusNode.requestFocus();
    if (anchor.blockId == focus.blockId && anchor.offset == focus.offset) {
      widget.controller.collapseSelection(
        anchor.blockId,
        anchor.offset,
        affinity: anchor.affinity,
      );
      return;
    }

    widget.controller.updateSelection(
      ExpandedSelection(anchor: anchor, focus: focus),
    );
  }

  void _handleSelectionPointerUp(PointerUpEvent event) {
    if (event.pointer == _selectionPointer) _clearSelectionDrag();
  }

  void _handleSelectionPointerCancel(PointerCancelEvent event) {
    if (event.pointer == _selectionPointer) _clearSelectionDrag();
  }

  void _clearSelectionDrag() {
    _selectionPointer = null;
    _selectionPointerStart = null;
    _selectionDragAnchor = null;
    _selectionDragActive = false;
  }

  void _showSlashMenu({required String blockId, required int triggerOffset}) {
    setState(() {
      _slashTriggerBlockId = blockId;
      _slashTriggerOffset = triggerOffset;
      _slashMenuVisible = true;
    });
    _slashMenuController.show();
  }

  void _hideSlashMenu() {
    if (!_slashMenuVisible) return;
    _slashMenuController.hide();
    setState(() {
      _slashMenuVisible = false;
      _slashTriggerBlockId = null;
      _slashTriggerOffset = 0;
    });
  }

  void _showActionMenu(String blockId, Offset globalPosition) {
    setState(() {
      _actionMenuBlockId = blockId;
      _actionMenuPosition = globalPosition;
      _actionMenuVisible = true;
    });
    _actionMenuController.show();
  }

  void _hideActionMenu() {
    if (!_actionMenuVisible) return;
    _actionMenuController.hide();
    setState(() {
      _actionMenuVisible = false;
      _actionMenuBlockId = null;
      _actionMenuPosition = Offset.zero;
    });
  }

  void _insertParagraphAfterBlock(String blockId) {
    final blocks = widget.controller.document.blocks;
    final index = blocks.indexWhere((block) => block.id == blockId);
    if (index < 0) return;
    final node = BlockNode(
      type: BlockTypes.paragraph,
      delta: TextDelta.empty(),
    );
    widget.controller.insertAt(index + 1, node);
    widget.controller.collapseSelection(node.id, 0);
    _focusNode.requestFocus();
  }

  GlobalKey _keyForBlock(String blockId) =>
      _blockKeys.putIfAbsent(blockId, () => GlobalKey());

  GlobalKey? _anchorKeyForSelection() {
    final sel = widget.controller.selection;
    if (sel is! ExpandedSelection) return null;
    return _blockKeys[sel.anchor.blockId];
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
    if (_embeddedInputFocusDepth > 0) return;
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
    if (_embeddedInputFocusDepth > 0) return;
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
    if (_embeddedInputFocusDepth > 0) return;
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
        value.selection.affinity,
      );
    }
    if (mounted) setState(() => _composingRange = value.composing);
  }

  void _applyTextChange(
    String blockId,
    String currentText,
    String newText,
    int newCursorOffset,
    TextAffinity affinity,
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
      affinity: affinity,
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
        cursor++;
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
        if (cursor < start || cursor >= end) result.add(op);
        cursor++;
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
      if (op is! TextOp) {
        cursor++;
        continue;
      }
      final opEnd = cursor + op.text.length;
      if (offset > cursor && offset <= opEnd) return op.attributes;
      cursor = opEnd;
    }
    final last = ops.lastWhere((op) => op is TextOp, orElse: () => ops.last);
    return last is TextOp ? last.attributes : const InlineAttributes();
  }

  @override
  void performAction(TextInputAction action) {
    if (_embeddedInputFocusDepth > 0) return;
    if (action == TextInputAction.newline) _ops.insertNewline();
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
  void didChangeInputControl(TextInputControl? o, TextInputControl? n) {}
  @override
  void insertTextPlaceholder(Size size) {}
  @override
  void removeTextPlaceholder() {}
  @override
  void performSelector(String selectorName) {
    if (widget.readOnly || _embeddedInputFocusDepth > 0) return;
    switch (selectorName) {
      case 'copy:':
      case 'copy':
        unawaited(_copySelectionToClipboard());
        return;
      case 'cut:':
      case 'cut':
        _cutSelectionToClipboard();
        return;
      case 'paste:':
      case 'paste':
        unawaited(_pasteFromClipboard());
        return;
    }
  }

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
        widget.controller.collapseSelection(
          event.blockId,
          offset,
          affinity: event.affinity,
        );
        _focusNode.requestFocus();
      case CheckboxToggledEvent():
        widget.controller.updateAttributes(event.blockId, {
          'checked': event.checked,
        });
      case TableCellChangedEvent():
        _updateTableCell(event);
      case TableRowInsertedEvent():
        _insertTableRow(event);
      case TableColumnInsertedEvent():
        _insertTableColumn(event);
      case TableRowDeletedEvent():
        _deleteTableRow(event);
      case TableColumnDeletedEvent():
        _deleteTableColumn(event);
      case TableColumnAlignmentChangedEvent():
        _alignTableColumn(event);
      case CodeBlockChangedEvent():
        _updateCodeBlock(event);
      case MathBlockChangedEvent():
        _updateMathBlock(event);
      case MermaidBlockChangedEvent():
        _updateMermaidBlock(event);
      case RawMarkdownChangedEvent():
        _updateRawMarkdownBlock(event);
      case CalloutTitleChangedEvent():
        _updateCalloutTitle(event);
      case CalloutVariantChangedEvent():
        _updateCalloutVariant(event);
      case BlockReorderedEvent():
        widget.controller.move(event.blockId, event.newIndex);
      case CustomBlockEvent():
        widget.onCustomEvent?.call(event);
    }
  }

  void _handleEmbeddedInputFocusChanged(bool focused) {
    if (focused) {
      _embeddedInputFocusDepth++;
      _closeIMEConnection();
      return;
    }

    if (_embeddedInputFocusDepth > 0) _embeddedInputFocusDepth--;
    if (_embeddedInputFocusDepth > 0) return;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _embeddedInputFocusDepth > 0) return;
      if (_focusNode.hasFocus) _openIMEConnection();
    });
  }

  void _updateTableCell(TableCellChangedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.table) return;

    final headers = _tableHeaders(node);
    final rows = _tableRows(node, headers.length);
    if (event.columnIndex < 0 || event.columnIndex >= headers.length) return;

    if (event.header) {
      headers[event.columnIndex] = event.text;
    } else {
      if (event.rowIndex < 0 || event.rowIndex >= rows.length) return;
      rows[event.rowIndex][event.columnIndex] = event.text;
    }

    widget.controller.updateAttributes(event.blockId, {
      'headers': headers,
      'rows': rows,
    });
  }

  void _insertTableRow(TableRowInsertedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.table) return;

    final headers = _tableHeaders(node);
    final rows = _tableRows(node, headers.length);
    final index = event.index.clamp(0, rows.length);
    rows.insert(index, List.filled(headers.length, ''));

    widget.controller.updateAttributes(event.blockId, {
      'headers': headers,
      'rows': rows,
    });
  }

  void _insertTableColumn(TableColumnInsertedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.table) return;

    final headers = _tableHeaders(node);
    final rows = _tableRows(node, headers.length);
    final index = event.index.clamp(0, headers.length);
    headers.insert(index, 'Column ${headers.length + 1}');
    for (final row in rows) {
      row.insert(index, '');
    }

    final updatedAttributes = <String, dynamic>{
      'headers': headers,
      'rows': rows,
    };
    final alignments = _tableAlignments(node);
    if (alignments.isNotEmpty) {
      while (alignments.length < headers.length - 1) {
        alignments.add('');
      }
      alignments.insert(index, '');
      updatedAttributes['alignments'] = alignments;
    }
    widget.controller.updateAttributes(event.blockId, updatedAttributes);
  }

  void _deleteTableRow(TableRowDeletedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.table) return;

    final headers = _tableHeaders(node);
    final rows = _tableRows(node, headers.length);
    if (rows.length <= 1) return;

    final index = event.index.clamp(0, rows.length - 1);
    rows.removeAt(index);

    widget.controller.updateAttributes(event.blockId, {
      'headers': headers,
      'rows': rows,
    });
  }

  void _deleteTableColumn(TableColumnDeletedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.table) return;

    final headers = _tableHeaders(node);
    if (headers.length <= 1) return;

    final rows = _tableRows(node, headers.length);
    final index = event.index.clamp(0, headers.length - 1);
    headers.removeAt(index);
    for (final row in rows) {
      if (index < row.length) row.removeAt(index);
    }

    final updatedAttributes = <String, dynamic>{
      'headers': headers,
      'rows': rows,
    };
    final alignments = _tableAlignments(node);
    if (alignments.isNotEmpty) {
      while (alignments.length < headers.length + 1) {
        alignments.add('');
      }
      alignments.removeAt(index);
      updatedAttributes['alignments'] = alignments;
    }
    widget.controller.updateAttributes(event.blockId, updatedAttributes);
  }

  void _alignTableColumn(TableColumnAlignmentChangedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.table) return;

    final headers = _tableHeaders(node);
    if (event.columnIndex < 0 || event.columnIndex >= headers.length) return;
    final alignments = _tableAlignments(node);
    while (alignments.length < headers.length) {
      alignments.add('');
    }
    final alignment = event.alignment;
    alignments[event.columnIndex] = alignment == null || alignment.isEmpty
        ? ''
        : alignment;

    widget.controller.updateAttributes(event.blockId, {
      'alignments': alignments,
    });
  }

  void _updateCodeBlock(CodeBlockChangedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.code) return;
    widget.controller.updateDelta(
      event.blockId,
      TextDelta.fromPlainText(event.text),
    );
  }

  void _updateMathBlock(MathBlockChangedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.math) return;
    widget.controller.updateDelta(
      event.blockId,
      TextDelta.fromPlainText(event.text),
    );
  }

  void _updateMermaidBlock(MermaidBlockChangedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.mermaid) return;
    widget.controller.updateDelta(
      event.blockId,
      TextDelta.fromPlainText(event.text),
    );
  }

  void _updateRawMarkdownBlock(RawMarkdownChangedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.rawMarkdown) return;
    widget.controller.updateDelta(
      event.blockId,
      TextDelta.fromPlainText(event.text),
    );
  }

  void _updateCalloutTitle(CalloutTitleChangedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.callout) return;
    widget.controller.updateAttributes(event.blockId, {'title': event.title});
  }

  void _updateCalloutVariant(CalloutVariantChangedEvent event) {
    final node = widget.controller.document.findById(event.blockId);
    if (node == null || node.type != BlockTypes.callout) return;
    widget.controller.updateAttributes(event.blockId, {
      'variant': event.variant,
    });
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (widget.readOnly) return KeyEventResult.ignored;
    if (_embeddedInputFocusDepth > 0) return KeyEventResult.ignored;
    final clipboardResult = _handleClipboardShortcut(event);
    if (clipboardResult == KeyEventResult.handled) return clipboardResult;
    final result = _shortcuts.handle(event, ModifierKeys.fromHardware());
    if (result == KeyEventResult.handled) _checkSlashTrigger(event);
    return result;
  }

  void _handlePostCommand() {
    _syncIMEState();
  }

  KeyEventResult _handleClipboardShortcut(KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final hardware = HardwareKeyboard.instance;
    final primaryPressed = hardware.isMetaPressed || hardware.isControlPressed;
    if (!primaryPressed || hardware.isAltPressed) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.keyC) {
      unawaited(_copySelectionToClipboard());
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyX) {
      _cutSelectionToClipboard();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.keyV) {
      unawaited(_pasteFromClipboard());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _copySelectionToClipboard() async {
    final selectedText = _selectedClipboardText();
    if (selectedText == null) return;
    await Clipboard.setData(ClipboardData(text: selectedText));
  }

  void _cutSelectionToClipboard() {
    final selectedText = _selectedClipboardText();
    if (selectedText == null) return;
    unawaited(Clipboard.setData(ClipboardData(text: selectedText)));
    _ops.delete();
    _syncIMEState();
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final text = data?.text;
    if (text == null || text.isEmpty) return;
    _insertPlainText(text);
    _syncIMEState();
  }

  void _insertPlainText(String text) {
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.isEmpty) return;
    if (widget.controller.selection is ExpandedSelection) {
      _ops.delete();
    }
    for (final rune in normalized.runes) {
      final character = String.fromCharCode(rune);
      if (character == '\n') {
        _ops.insertNewline();
      } else {
        _ops.insertCharacter(character);
      }
    }
  }

  String? _selectedClipboardText() {
    return _selectedWholeBlockMarkdown() ?? _selectedPlainText();
  }

  String? _selectedWholeBlockMarkdown() {
    final selectedBlocks = _selectedWholeBlocks();
    if (selectedBlocks == null || selectedBlocks.isEmpty) return null;
    return BlockMarkdownCodec.encode(BlockDocument(selectedBlocks));
  }

  List<BlockNode>? _selectedWholeBlocks() {
    final sel = widget.controller.selection;
    if (sel is! ExpandedSelection) return null;

    final blocks = widget.controller.document.flatten();
    final ids = blocks.map((block) => block.id).toList();
    final resolved = sel.resolveOrder(ids);
    final startIndex = ids.indexOf(resolved.start.blockId);
    final endIndex = ids.indexOf(resolved.end.blockId);
    if (startIndex < 0 || endIndex < 0) return null;

    final startBlock = blocks[startIndex];
    final endBlock = blocks[endIndex];
    final startLength = startBlock.delta?.plainText.length ?? 0;
    final endLength = endBlock.delta?.plainText.length ?? 0;
    final startsAtBlockStart = resolved.start.offset <= 0;
    final endsAtBlockEnd = resolved.end.offset >= endLength;
    final emptySingleBlock =
        startIndex == endIndex && startLength == 0 && resolved.end.offset == 0;
    if ((!startsAtBlockStart || !endsAtBlockEnd) && !emptySingleBlock) {
      return null;
    }

    return blocks.sublist(startIndex, endIndex + 1);
  }

  String? _selectedPlainText() {
    final sel = widget.controller.selection;
    if (sel is! ExpandedSelection) return null;

    final blocks = widget.controller.document.flatten();
    final ids = blocks.map((block) => block.id).toList();
    final resolved = sel.resolveOrder(ids);
    final startIndex = ids.indexOf(resolved.start.blockId);
    final endIndex = ids.indexOf(resolved.end.blockId);
    if (startIndex < 0 || endIndex < 0) return null;

    final lines = <String>[];
    for (var i = startIndex; i <= endIndex; i++) {
      final block = blocks[i];
      final text = block.delta?.plainText ?? '';
      final start = i == startIndex
          ? resolved.start.offset.clamp(0, text.length).toInt()
          : 0;
      final end = i == endIndex
          ? resolved.end.offset.clamp(0, text.length).toInt()
          : text.length;
      if (end < start) continue;
      lines.add(text.substring(start, end));
    }
    return lines.join('\n');
  }

  void _moveToVisualLineBoundary({required bool end, required bool expand}) {
    final sel = widget.controller.selection;
    final focus = switch (sel) {
      CollapsedSelection() => sel.point,
      ExpandedSelection() => sel.focus,
      NoSelection() => null,
    };
    if (focus == null) return;

    final target = _resolveVisualLineBoundary(focus, end: end);
    if (target == null) return;

    if (!expand) {
      widget.controller.collapseSelection(
        target.blockId,
        target.offset,
        affinity: target.affinity,
      );
      return;
    }

    final anchor = switch (sel) {
      CollapsedSelection() => sel.point,
      ExpandedSelection() => sel.anchor,
      NoSelection() => null,
    };
    if (anchor == null) return;
    widget.controller.updateSelection(
      ExpandedSelection(anchor: anchor, focus: target),
    );
  }

  SelectionPoint? _resolveVisualLineBoundary(
    SelectionPoint point, {
    required bool end,
  }) {
    final node = widget.controller.document.findById(point.blockId);
    final delta = node?.delta ?? TextDelta.empty();
    final textLength = delta.plainText.length;
    final renderer = _findRichTextRenderer(point.blockId);
    if (renderer == null) {
      return SelectionPoint(
        blockId: point.blockId,
        offset: end ? textLength : 0,
        affinity: end ? TextAffinity.upstream : TextAffinity.downstream,
      );
    }

    final box = renderer.context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return SelectionPoint(
        blockId: point.blockId,
        offset: end ? textLength : 0,
        affinity: end ? TextAffinity.upstream : TextAffinity.downstream,
      );
    }

    final variables =
        BlockEditorScope.maybeOf(renderer.context)?.variables ??
        widget.variables;
    final effectiveBase = resolveBlockEditorTextStyle(
      renderer.context,
      renderer.widget.baseStyle,
    );
    final span = buildMeasurementSpan(
      delta,
      effectiveBase,
      variables,
      MarkdownDocumentThemeData.fromContext(renderer.context),
    );
    final textDirection = Directionality.of(renderer.context);
    final textScaler = MediaQuery.textScalerOf(renderer.context);
    final painter = TextPainter(
      text: span,
      textAlign: renderer.widget.textAlign,
      textDirection: textDirection,
      textScaler: textScaler,
      textHeightBehavior: blockEditorTextHeightBehavior,
    )..layout(maxWidth: box.size.width);

    final visualOffset = modelToVisualOffset(delta, point.offset, variables);
    final plainVisualLength = span.toPlainText().length;
    final visualPosition = TextPosition(
      offset: visualOffset.clamp(0, plainVisualLength),
      affinity: point.affinity,
    );
    final targetVisualOffset = _visualLineBoundaryOffset(
      painter,
      visualPosition,
      end: end,
    );
    final targetOffset = visualToModelOffset(
      delta,
      targetVisualOffset,
      variables,
    ).clamp(0, textLength);

    return SelectionPoint(
      blockId: point.blockId,
      offset: targetOffset,
      affinity: end ? TextAffinity.upstream : TextAffinity.downstream,
    );
  }

  int _visualLineBoundaryOffset(
    TextPainter painter,
    TextPosition position, {
    required bool end,
  }) {
    final caretPrototype = Rect.fromLTWH(0, 0, 1, painter.preferredLineHeight);
    final textLength = painter.text?.toPlainText().length ?? 0;
    final probeY =
        _probeLineY(painter, position, textLength) ??
        painter.getOffsetForCaret(position, caretPrototype).dy;
    final lines = painter.computeLineMetrics();
    if (lines.isEmpty) return 0;

    LineMetrics line = lines.last;
    for (final candidate in lines) {
      final top = candidate.baseline - candidate.ascent;
      final bottom = top + candidate.height;
      if (probeY >= top - 0.5 && probeY <= bottom + 0.5) {
        line = candidate;
        break;
      }
    }

    final lineTop = line.baseline - line.ascent;
    final lineMiddleY = lineTop + line.height / 2;
    final lineX = end ? line.left + line.width + 1 : line.left;
    final target = painter.getPositionForOffset(Offset(lineX, lineMiddleY));
    return target.offset;
  }

  double? _probeLineY(
    TextPainter painter,
    TextPosition position,
    int textLength,
  ) {
    if (textLength == 0) return null;
    final start = position.affinity == TextAffinity.upstream
        ? (position.offset - 1).clamp(0, textLength - 1)
        : position.offset.clamp(0, textLength - 1);
    final end = (start + 1).clamp(0, textLength);
    if (end <= start) return null;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: start, extentOffset: end),
    );
    if (boxes.isEmpty) return null;
    final box = boxes.first;
    return box.top + (box.bottom - box.top) / 2;
  }

  _RichTextRendererEntry? _findRichTextRenderer(String blockId) {
    final rootContext = _blockKeys[blockId]?.currentContext;
    if (rootContext == null) return null;
    _RichTextRendererEntry? found;

    void visit(Element element) {
      if (found != null) return;
      final widget = element.widget;
      if (widget is RichTextRenderer && widget.blockId == blockId) {
        found = _RichTextRendererEntry(context: element, widget: widget);
        return;
      }
      element.visitChildren(visit);
    }

    rootContext.visitChildElements(visit);
    return found;
  }

  SelectionPoint? _selectionPointAtGlobal(
    Offset globalPosition, {
    required bool requireTextHit,
  }) {
    _RichTextRendererEntry? bestEntry;
    String? bestBlockId;
    var bestScore = double.infinity;

    for (final block in widget.controller.document.flatten()) {
      final entry = _findRichTextRenderer(block.id);
      if (entry == null) continue;
      final box = entry.context.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;

      final origin = box.localToGlobal(Offset.zero);
      final rect = origin & box.size;
      if (requireTextHit && !rect.inflate(6).contains(globalPosition)) {
        continue;
      }

      final score = _rectDistanceScore(globalPosition, rect);
      if (score < bestScore) {
        bestScore = score;
        bestEntry = entry;
        bestBlockId = block.id;
      }
    }

    if (bestEntry == null || bestBlockId == null) return null;
    return _selectionPointFromRenderer(bestBlockId, bestEntry, globalPosition);
  }

  double _rectDistanceScore(Offset point, Rect rect) {
    final dx = point.dx < rect.left
        ? rect.left - point.dx
        : point.dx > rect.right
        ? point.dx - rect.right
        : 0.0;
    final dy = point.dy < rect.top
        ? rect.top - point.dy
        : point.dy > rect.bottom
        ? point.dy - rect.bottom
        : 0.0;
    return dy * 10000 + dx;
  }

  SelectionPoint _selectionPointFromRenderer(
    String blockId,
    _RichTextRendererEntry entry,
    Offset globalPosition,
  ) {
    final box = entry.context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return SelectionPoint(blockId: blockId, offset: 0);
    }

    final delta = entry.widget.delta;
    final variables =
        BlockEditorScope.maybeOf(entry.context)?.variables ?? widget.variables;
    final effectiveBase = resolveBlockEditorTextStyle(
      entry.context,
      entry.widget.baseStyle,
    );
    final span = buildMeasurementSpan(
      delta,
      effectiveBase,
      variables,
      MarkdownDocumentThemeData.fromContext(entry.context),
    );
    final painter = TextPainter(
      text: span,
      textAlign: entry.widget.textAlign,
      textDirection: Directionality.of(entry.context),
      textScaler: MediaQuery.textScalerOf(entry.context),
      textHeightBehavior: blockEditorTextHeightBehavior,
    )..layout(maxWidth: box.size.width);

    final local = box.globalToLocal(globalPosition);
    final clampedLocal = Offset(
      local.dx.clamp(0.0, box.size.width),
      local.dy.clamp(0.0, box.size.height),
    );
    final visualPosition = painter.getPositionForOffset(clampedLocal);
    final offset = visualToModelOffset(
      delta,
      visualPosition.offset,
      variables,
    ).clamp(0, delta.plainText.length);

    return SelectionPoint(
      blockId: blockId,
      offset: offset,
      affinity: visualPosition.affinity,
    );
  }

  void _checkSlashTrigger(KeyEvent event) {
    if (event.character != '/') return;
    final sel = widget.controller.selection;
    if (sel is! CollapsedSelection) return;
    final blockId = sel.point.blockId;
    final offset = sel.point.offset;
    final node = widget.controller.document.findById(blockId);
    if (node == null) return;
    final text = node.delta?.plainText ?? '';
    final isAtStart = offset == 1;
    final isAfterSpace = offset >= 2 && text[offset - 2] == ' ';
    if (isAtStart || isAfterSpace) {
      _showSlashMenu(blockId: blockId, triggerOffset: offset);
    }
  }

  bool _isFullyCovered(String blockId) {
    final sel = widget.controller.selection;
    if (sel is! ExpandedSelection) return false;
    final covered = widget.controller.selectedBlockIds;
    if (covered.length == 1 && covered.single == blockId) {
      final node = widget.controller.document.findById(blockId);
      final length = node?.delta?.plainText.length ?? 0;
      final ids = widget.controller.document
          .flatten()
          .map((b) => b.id)
          .toList();
      final resolved = sel.resolveOrder(ids);
      return resolved.start.blockId == blockId &&
          resolved.end.blockId == blockId &&
          resolved.start.offset == 0 &&
          resolved.end.offset >= length;
    }
    if (covered.length < 3) return false;
    return covered.sublist(1, covered.length - 1).contains(blockId);
  }

  int _resolveNumber(List<BlockNode> blocks, int index) {
    final currentIndent = _listIndentLevel(blocks[index]);
    var count = 1;
    for (var i = index - 1; i >= 0; i--) {
      final previousIndent = _listIndentLevel(blocks[i]);
      if (previousIndent > currentIndent) continue;
      if (previousIndent < currentIndent) break;
      if (blocks[i].type == BlockTypes.numberedList) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  int _listIndentLevel(BlockNode block) =>
      (block.attributes['indent'] as int? ?? 0).clamp(0, 8).toInt();

  EdgeInsets _spacingForBlock(List<BlockNode> blocks, int index) {
    final type = blocks[index].type;
    final previousType = index > 0 ? blocks[index - 1].type : null;
    final nextType = index < blocks.length - 1 ? blocks[index + 1].type : null;
    final first = index == 0;

    if (_isListType(type)) {
      return EdgeInsets.only(
        top: _isListType(previousType) ? 0 : 4,
        bottom: _isListType(nextType) ? 3 : 10,
      );
    }

    return switch (type) {
      BlockTypes.heading1 => EdgeInsets.only(top: first ? 0 : 26, bottom: 10),
      BlockTypes.heading2 => EdgeInsets.only(top: first ? 0 : 22, bottom: 8),
      BlockTypes.heading3 => EdgeInsets.only(top: first ? 0 : 18, bottom: 6),
      BlockTypes.heading4 => EdgeInsets.only(top: first ? 0 : 16, bottom: 6),
      BlockTypes.heading5 => EdgeInsets.only(top: first ? 0 : 14, bottom: 5),
      BlockTypes.heading6 => EdgeInsets.only(top: first ? 0 : 12, bottom: 5),
      BlockTypes.paragraph => const EdgeInsets.only(top: 2, bottom: 10),
      BlockTypes.quote => const EdgeInsets.only(top: 8, bottom: 12),
      BlockTypes.code => const EdgeInsets.only(top: 10, bottom: 14),
      BlockTypes.math => const EdgeInsets.only(top: 10, bottom: 14),
      BlockTypes.mermaid => const EdgeInsets.only(top: 10, bottom: 14),
      BlockTypes.rawMarkdown => const EdgeInsets.only(top: 10, bottom: 14),
      BlockTypes.table => const EdgeInsets.only(top: 10, bottom: 14),
      BlockTypes.divider => const EdgeInsets.symmetric(vertical: 14),
      _ => const EdgeInsets.only(top: 4, bottom: 10),
    };
  }

  bool _isListType(String? type) {
    return type == BlockTypes.bulletList ||
        type == BlockTypes.numberedList ||
        type == BlockTypes.todo;
  }

  EditorSelection _selectionForBlock(String blockId) {
    if (widget.readOnly) return EditorSelection.none;
    final sel = widget.controller.selection;
    if (sel is! ExpandedSelection) return sel;
    final ids = widget.controller.document.flatten().map((b) => b.id).toList();
    final resolved = sel.resolveOrder(ids);
    if (!widget.controller.selectedBlockIds.contains(blockId)) {
      return EditorSelection.none;
    }
    return ExpandedSelection(anchor: resolved.start, focus: resolved.end);
  }

  String? _focusedBlockId() {
    final sel = widget.controller.selection;
    if (sel is CollapsedSelection) return sel.point.blockId;
    return null;
  }

  double _editorWidth() {
    final box = _editorKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return widget.toolbarBreakpoint;
    return box.size.width;
  }

  @override
  Widget build(BuildContext context) {
    final blocks = widget.controller.document.blocks;
    final focusedId = _focusedBlockId();
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final cursorColor = widget.cursorColor ?? editorTheme.cursor;
    final selectionColor = widget.selectionColor ?? editorTheme.selection;

    final list = ListView.builder(
      controller: _scrollController,
      padding: widget.padding,
      itemCount: blocks.length,
      itemBuilder: (context, index) {
        final rawNode = blocks[index];
        final blockKey = _keyForBlock(rawNode.id);
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
          child: Padding(
            padding: _spacingForBlock(blocks, index),
            child: BlockDragHandle(
              key: ValueKey('handle_${rawNode.id}'),
              index: index,
              blockId: rawNode.id,
              onEvent: _handleEvent,
              readOnly: widget.readOnly,
              onActionMenuRequested: widget.readOnly ? null : _showActionMenu,
              onAddBlockRequested: widget.readOnly
                  ? null
                  : () => _insertParagraphAfterBlock(rawNode.id),
              feedbackWidget: BlockGhost(
                node: rawNode,
                width: MediaQuery.of(context).size.width,
              ),
              child: KeyedSubtree(
                key: blockKey,
                child: _BlockItemWidget(
                  key: ValueKey(rawNode.id),
                  initialNode: node,
                  controller: widget.controller,
                  selection: selection,
                  covered: covered,
                  cursorColor: cursorColor,
                  selectionColor: selectionColor,
                  onEvent: _handleEvent,
                  composingRange: composing,
                ),
              ),
            ),
          ),
        );
      },
    );
    final selectionSurface = Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handleSelectionPointerDown,
      onPointerMove: _handleSelectionPointerMove,
      onPointerUp: _handleSelectionPointerUp,
      onPointerCancel: _handleSelectionPointerCancel,
      child: list,
    );

    if (widget.readOnly) {
      return BlockEditorScope(
        variables: widget.variables,
        readOnly: true,
        cursorColor: cursorColor,
        selectionColor: selectionColor,
        sourceEditingConfig: widget.sourceEditingConfig,
        child: selectionSurface,
      );
    }

    final focusedEditor = Focus(
      key: _editorKey,
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: selectionSurface,
    );

    final menuLayer = OverlayPortal(
      controller: _slashMenuController,
      overlayChildBuilder: (_) => SlashCommandMenu(
        controller: widget.controller,
        ops: _ops,
        anchorKey: _slashTriggerBlockId != null
            ? _blockKeys[_slashTriggerBlockId]
            : null,
        editorKey: _editorKey,
        editorFocusNode: _focusNode,
        triggerBlockId: _slashTriggerBlockId ?? '',
        triggerOffset: _slashTriggerOffset,
        onDismiss: _hideSlashMenu,
      ),
      child: OverlayPortal(
        controller: _actionMenuController,
        overlayChildBuilder: (_) => BlockActionMenu(
          controller: widget.controller,
          blockId: _actionMenuBlockId ?? '',
          globalPosition: _actionMenuPosition,
          onDismiss: _hideActionMenu,
        ),
        child: focusedEditor,
      ),
    );

    final editorChild = widget.showFormattingToolbar
        ? OverlayPortal(
            controller: _toolbarController,
            overlayChildBuilder: (_) => FormattingToolbar(
              controller: widget.controller,
              ops: _ops,
              anchorKey: _anchorKeyForSelection(),
              editorKey: _editorKey,
              toolbarBreakpoint: widget.toolbarBreakpoint,
              availableWidth: _editorWidth(),
              onColorPickerRequested: widget.onColorPickerRequested,
            ),
            child: menuLayer,
          )
        : menuLayer;

    return BlockEditorScope(
      variables: widget.variables,
      readOnly: false,
      cursorColor: cursorColor,
      selectionColor: selectionColor,
      onEmbeddedInputFocusChanged: _handleEmbeddedInputFocusChanged,
      sourceEditingConfig: widget.sourceEditingConfig,
      child: editorChild,
    );
  }
}

List<String> _tableHeaders(BlockNode node) {
  final raw = node.attributes['headers'];
  if (raw is Iterable<Object?>) {
    final headers = raw.map((item) => item?.toString() ?? '').toList();
    if (headers.isNotEmpty) return headers;
  }
  return ['Column 1', 'Column 2'];
}

List<List<String>> _tableRows(BlockNode node, int columnCount) {
  final raw = node.attributes['rows'];
  if (raw is Iterable<Object?>) {
    final rows = raw
        .whereType<Iterable<Object?>>()
        .map((row) => _normalizeTableRow(row, columnCount))
        .toList();
    if (rows.isNotEmpty) return rows;
  }
  return [List.filled(columnCount, ''), List.filled(columnCount, '')];
}

List<String> _tableAlignments(BlockNode node) {
  final raw = node.attributes['alignments'];
  if (raw is! Iterable<Object?>) return <String>[];
  return raw.map((item) => item?.toString() ?? '').toList();
}

List<String> _normalizeTableRow(Iterable<Object?> row, int columnCount) {
  final cells = row.map((item) => item?.toString() ?? '').toList();
  if (cells.length == columnCount) return cells;
  if (cells.length > columnCount) return cells.sublist(0, columnCount);
  return [...cells, ...List.filled(columnCount - cells.length, '')];
}

final class _RichTextRendererEntry {
  const _RichTextRendererEntry({required this.context, required this.widget});

  final BuildContext context;
  final RichTextRenderer widget;
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
    final transientNumber = widget.initialNode.attributes['number'];
    if (widget.initialNode.type != BlockTypes.numberedList ||
        transientNumber == null) {
      return updated;
    }
    return updated.copyWith(
      attributes: {...updated.attributes, 'number': transientNumber},
    );
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
