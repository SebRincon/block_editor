library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

/// [BlockPlugin] for [BlockTypes.file].
///
/// Stores file metadata in [BlockNode.attributes]:
///
/// - `filename` — the display name of the file.
/// - `size` — the human-readable file size string (e.g. `'2.4 MB'`).
/// - `path` — the local file path or network URL.
///
/// Renders a row with the filename, size, and two action buttons — download
/// and open. Each action first checks [FileBlockConfig] for a callback. When
/// a callback is present it is invoked directly. When absent a
/// [CustomBlockEvent] is emitted with `eventType: 'file_download_requested'`
/// or `'file_open_requested'` carrying the path as payload, and the host app
/// handles the action.
///
/// Configuration is read from [FileBlockConfig] via [BlockEditorScope].
final class FileBlock extends BlockPlugin {
  /// Creates a [FileBlock].
  FileBlock();

  @override
  String get blockType => BlockTypes.file;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) {
    return _FileBlockWidget(node: node, onEvent: onEvent);
  }

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'File',
    group: 'Media',
    icon: const Icon(Icons.insert_drive_file),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Media';
}

class _FileBlockWidget extends StatelessWidget {
  const _FileBlockWidget({required this.node, required this.onEvent});

  final BlockNode node;
  final void Function(BlockEvent) onEvent;

  String get _filename =>
      node.attributes['filename'] as String? ?? 'Untitled file';
  String get _size => node.attributes['size'] as String? ?? '';
  String get _path => node.attributes['path'] as String? ?? '';

  void _handleDownload(BuildContext context, FileBlockConfig? config) {
    if (_path.isEmpty) return;
    if (config?.onDownload != null) {
      config!.onDownload!(_path);
    } else {
      onEvent(
        CustomBlockEvent(
          blockId: node.id,
          eventType: 'file_download_requested',
          payload: _path,
        ),
      );
    }
  }

  void _handleOpen(BuildContext context, FileBlockConfig? config) {
    if (_path.isEmpty) return;
    if (config?.onOpen != null) {
      config!.onOpen!(_path);
    } else {
      onEvent(
        CustomBlockEvent(
          blockId: node.id,
          eventType: 'file_open_requested',
          payload: _path,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = BlockEditorScope.maybeOf(context)?.fileConfig;
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: markdownTheme.codeBlockBackground,
        border: Border.all(color: markdownTheme.codeBlockBorder),
        borderRadius: BorderRadius.circular(editorTheme.radiusMd),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.insert_drive_file_outlined,
              color: editorTheme.mutedForeground,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _filename,
                    style: editorTheme.smallStyle.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (_size.isNotEmpty)
                    Text(
                      _size,
                      style: editorTheme.xSmallStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            _FileIconButton(
              icon: Icons.download_rounded,
              onTap: () => _handleDownload(context, config),
            ),
            _FileIconButton(
              icon: Icons.open_in_new_rounded,
              onTap: () => _handleOpen(context, config),
            ),
          ],
        ),
      ),
    );
  }
}

class _FileIconButton extends StatelessWidget {
  const _FileIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Icon(icon, color: editorTheme.mutedForeground, size: 18),
        ),
      ),
    );
  }
}
