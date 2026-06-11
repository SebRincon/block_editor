library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';
import 'package:flutter/services.dart';

/// A small floating menu that appears when the drag handle of a block is
/// clicked, providing block-level operations for the target block.
///
/// [BlockActionMenu] is displayed as an [OverlayEntry] managed by
/// [BlockEditorWidget]. It is never shown when readOnly is true.
///
/// The menu provides block-level selection, deletion, duplication, transform,
/// and move actions. All actions dispatch through [BlockController].
///
/// The menu dismisses when any action is selected, when Escape is pressed,
/// or when the user taps outside the menu.
class BlockActionMenu extends StatefulWidget {
  /// Creates a [BlockActionMenu] for [blockId].
  const BlockActionMenu({
    super.key,
    required this.controller,
    required this.blockId,
    required this.globalPosition,
    required this.onDismiss,
  });

  /// The controller used to perform block operations.
  final BlockController controller;

  /// The id of the block this menu targets.
  final String blockId;

  /// The global position at which the menu should be anchored.
  final Offset globalPosition;

  /// Called when the menu should be dismissed.
  final VoidCallback onDismiss;

  @override
  State<BlockActionMenu> createState() => _BlockActionMenuState();
}

class _BlockActionMenuState extends State<BlockActionMenu> {
  bool _showTurnInto = false;
  bool _showAlign = false;
  late final FocusNode _focusNode;

  static const double _menuWidth = 200.0;
  static const double _turnIntoWidth = 200.0;
  static const double _alignWidth = 172.0;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  Offset _clampedPosition(
    BuildContext context,
    Offset raw,
    double menuWidth,
    double menuHeight,
  ) {
    final screen = MediaQuery.of(context).size;
    return Offset(
      raw.dx.clamp(8.0, screen.width - menuWidth - 8.0),
      raw.dy.clamp(8.0, screen.height - menuHeight - 8.0),
    );
  }

  void _selectNode(BlockNode node) {
    final length = node.delta?.plainText.length ?? 0;
    widget.controller.updateSelection(
      ExpandedSelection(
        anchor: SelectionPoint(blockId: node.id, offset: 0),
        focus: SelectionPoint(blockId: node.id, offset: length),
      ),
    );
  }

  void _selectBlock() {
    final node = widget.controller.document.findById(widget.blockId);
    if (node == null) {
      widget.onDismiss();
      return;
    }
    _selectNode(node);
    widget.onDismiss();
  }

  void _copyMarkdown() {
    final node = widget.controller.document.findById(widget.blockId);
    if (node == null) {
      widget.onDismiss();
      return;
    }
    _selectNode(node);
    final markdown = BlockMarkdownCodec.encode(BlockDocument([node]));
    unawaited(Clipboard.setData(ClipboardData(text: markdown)));
    widget.onDismiss();
  }

  void _delete() {
    widget.controller.delete(widget.blockId);
    widget.onDismiss();
  }

  void _duplicate() {
    widget.controller.duplicate(widget.blockId);
    widget.onDismiss();
  }

  void _moveUp() {
    final blocks = widget.controller.document.blocks;
    final index = blocks.indexWhere((b) => b.id == widget.blockId);
    if (index <= 0) {
      widget.onDismiss();
      return;
    }
    widget.controller.move(widget.blockId, index - 1);
    widget.onDismiss();
  }

  void _moveDown() {
    final blocks = widget.controller.document.blocks;
    final index = blocks.indexWhere((b) => b.id == widget.blockId);
    if (index >= blocks.length - 1) {
      widget.onDismiss();
      return;
    }
    widget.controller.move(widget.blockId, index + 1);
    widget.onDismiss();
  }

  void _turnInto(String blockType) {
    widget.controller.transformType(widget.blockId, blockType);
    widget.onDismiss();
  }

  void _alignBlock(String alignment) {
    final node = widget.controller.document.findById(widget.blockId);
    if (node == null || !_supportsBlockAlignment(node)) {
      widget.onDismiss();
      return;
    }
    widget.controller.updateAttributes(widget.blockId, {
      'textAlign': alignment,
    });
    widget.onDismiss();
  }

  bool _supportsBlockAlignment(BlockNode node) {
    return node.type == BlockTypes.paragraph ||
        node.type == BlockTypes.heading1 ||
        node.type == BlockTypes.heading2 ||
        node.type == BlockTypes.heading3 ||
        node.type == BlockTypes.heading4 ||
        node.type == BlockTypes.heading5 ||
        node.type == BlockTypes.heading6 ||
        node.type == BlockTypes.table;
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      widget.onDismiss();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    const mainMenuHeight = 8 * 40.0 + 8.0;
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final pos = _clampedPosition(
      context,
      widget.globalPosition,
      _menuWidth,
      mainMenuHeight,
    );

    final blocks = widget.controller.document.blocks;
    final index = blocks.indexWhere((b) => b.id == widget.blockId);
    final canMoveUp = index > 0;
    final canMoveDown = index < blocks.length - 1;
    final activeNode = widget.controller.document.findById(widget.blockId);
    final canAlign = activeNode != null && _supportsBlockAlignment(activeNode);
    final activeAlignment =
        activeNode?.attributes['textAlign']?.toString() ?? 'left';

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            behavior: HitTestBehavior.opaque,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        Positioned(
          left: pos.dx,
          top: pos.dy,
          width: _menuWidth,
          child: Focus(
            focusNode: _focusNode,
            onKeyEvent: _handleKey,
            child: Material(
              elevation: 6,
              color: editorTheme.popover,
              shadowColor: Colors.black.withValues(alpha: 0.20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(editorTheme.radiusMd),
                side: BorderSide(color: editorTheme.border),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ActionItem(
                      icon: Icons.select_all,
                      label: 'Select block',
                      onTap: _selectBlock,
                    ),
                    _ActionItem(
                      icon: Icons.content_copy,
                      label: 'Copy Markdown',
                      onTap: _copyMarkdown,
                    ),
                    _ActionItem(
                      icon: Icons.delete_outline,
                      label: 'Delete block',
                      isDestructive: true,
                      onTap: _delete,
                    ),
                    _ActionItem(
                      icon: Icons.copy_outlined,
                      label: 'Duplicate block',
                      onTap: _duplicate,
                    ),
                    _ActionItem(
                      icon: Icons.transform_outlined,
                      label: 'Turn into',
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: editorTheme.mutedForeground,
                      ),
                      onTap: () => setState(() {
                        _showAlign = false;
                        _showTurnInto = !_showTurnInto;
                      }),
                    ),
                    _ActionItem(
                      icon: Icons.format_align_left,
                      label: 'Align',
                      enabled: canAlign,
                      trailing: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: editorTheme.mutedForeground,
                      ),
                      onTap: canAlign
                          ? () => setState(() {
                              _showTurnInto = false;
                              _showAlign = !_showAlign;
                            })
                          : null,
                    ),
                    _ActionItem(
                      icon: Icons.arrow_upward,
                      label: 'Move up',
                      enabled: canMoveUp,
                      onTap: canMoveUp ? _moveUp : null,
                    ),
                    _ActionItem(
                      icon: Icons.arrow_downward,
                      label: 'Move down',
                      enabled: canMoveDown,
                      onTap: canMoveDown ? _moveDown : null,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_showTurnInto)
          Positioned(
            left: (pos.dx + _menuWidth + 4.0).clamp(
              8.0,
              MediaQuery.of(context).size.width - _turnIntoWidth - 8.0,
            ),
            top: pos.dy,
            width: _turnIntoWidth,
            child: Material(
              elevation: 6,
              color: editorTheme.popover,
              shadowColor: Colors.black.withValues(alpha: 0.20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(editorTheme.radiusMd),
                side: BorderSide(color: editorTheme.border),
              ),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 300),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  children: _buildTurnIntoItems(),
                ),
              ),
            ),
          ),
        if (_showAlign)
          Positioned(
            left: (pos.dx + _menuWidth + 4.0).clamp(
              8.0,
              MediaQuery.of(context).size.width - _alignWidth - 8.0,
            ),
            top: pos.dy,
            width: _alignWidth,
            child: _AlignSubmenu(
              activeAlignment: activeAlignment,
              onSelect: _alignBlock,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildTurnIntoItems() {
    final items = <Widget>[];
    for (final plugin in BlockRegistry.instance.plugins) {
      final config = plugin.slashCommandItem();
      if (config == null) continue;
      items.add(
        _ActionItem(
          icon: null,
          iconWidget: SizedBox(width: 18, height: 18, child: config.icon),
          label: config.label,
          onTap: () => _turnInto(plugin.blockType),
        ),
      );
    }
    return items;
  }
}

class _AlignSubmenu extends StatelessWidget {
  const _AlignSubmenu({required this.activeAlignment, required this.onSelect});

  final String activeAlignment;
  final void Function(String alignment) onSelect;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    return Material(
      elevation: 6,
      color: editorTheme.popover,
      shadowColor: Colors.black.withValues(alpha: 0.20),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(editorTheme.radiusMd),
        side: BorderSide(color: editorTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _ActionItem(
              icon: Icons.format_align_left,
              label: 'Align left',
              trailing: _AlignmentCheck(
                visible:
                    activeAlignment != 'center' &&
                    activeAlignment != 'right' &&
                    activeAlignment != 'end',
              ),
              onTap: () => onSelect('left'),
            ),
            _ActionItem(
              icon: Icons.format_align_center,
              label: 'Align center',
              trailing: _AlignmentCheck(visible: activeAlignment == 'center'),
              onTap: () => onSelect('center'),
            ),
            _ActionItem(
              icon: Icons.format_align_right,
              label: 'Align right',
              trailing: _AlignmentCheck(
                visible: activeAlignment == 'right' || activeAlignment == 'end',
              ),
              onTap: () => onSelect('right'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AlignmentCheck extends StatelessWidget {
  const _AlignmentCheck({required this.visible});

  final bool visible;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    return SizedBox(
      width: 18,
      child: visible
          ? Icon(Icons.check, size: 16, color: editorTheme.primary)
          : null,
    );
  }
}

class _ActionItem extends StatefulWidget {
  const _ActionItem({
    required this.label,
    required this.onTap,
    this.icon,
    this.iconWidget,
    this.trailing,
    this.isDestructive = false,
    this.enabled = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Widget? iconWidget;
  final Widget? trailing;
  final bool isDestructive;
  final bool enabled;

  @override
  State<_ActionItem> createState() => _ActionItemState();
}

class _ActionItemState extends State<_ActionItem> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final textColor = widget.isDestructive
        ? editorTheme.destructive
        : widget.enabled
        ? editorTheme.popoverForeground
        : editorTheme.mutedForeground.withValues(alpha: 0.55);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.enabled ? widget.onTap : null,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(editorTheme.radiusMd),
            color: widget.enabled
                ? _hovered
                      ? editorTheme.accent
                      : Colors.transparent
                : Colors.transparent,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: Row(
            children: [
              if (widget.icon != null)
                Icon(widget.icon, size: 18, color: textColor)
              else if (widget.iconWidget != null)
                widget.iconWidget!
              else
                const SizedBox(width: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.label,
                  style: editorTheme.smallStyle.copyWith(color: textColor),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
