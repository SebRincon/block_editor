library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

/// [BlockPlugin] for [BlockTypes.link].
///
/// Stores link metadata in [BlockNode.attributes]:
///
/// - `url` — the destination URL.
/// - `displayText` — the label shown to the user. Falls back to url when absent.
///
/// Renders a tappable row. When tapped, [LinkBlockConfig.onOpen] is called
/// if provided via [BlockEditorScope]. When no callback is present a
/// [CustomBlockEvent] with `eventType: 'link_open_requested'` is emitted
/// carrying the URL as payload.
///
/// Configuration is read from [LinkBlockConfig] via [BlockEditorScope].
final class LinkBlock extends BlockPlugin {
  /// Creates a [LinkBlock].
  LinkBlock();

  @override
  String get blockType => BlockTypes.link;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) {
    return _LinkBlockWidget(node: node, onEvent: onEvent);
  }

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Link',
    group: 'Basic',
    icon: const Icon(Icons.link),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

class _LinkBlockWidget extends StatelessWidget {
  const _LinkBlockWidget({required this.node, required this.onEvent});

  final BlockNode node;
  final void Function(BlockEvent) onEvent;

  String get _url => node.attributes['url'] as String? ?? '';
  String get _displayText => node.attributes['displayText'] as String? ?? _url;

  void _handleTap(BuildContext context, LinkBlockConfig? config) {
    if (_url.isEmpty) return;
    if (config?.onOpen != null) {
      config!.onOpen!(_url);
    } else {
      onEvent(
        CustomBlockEvent(
          blockId: node.id,
          eventType: 'link_open_requested',
          payload: _url,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = BlockEditorScope.maybeOf(context)?.linkConfig;
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);

    if (_url.isEmpty) {
      return _placeholder(context);
    }

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _handleTap(context, config),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: markdownTheme.codeBlockBackground,
            borderRadius: BorderRadius.circular(editorTheme.radiusMd),
            border: Border.all(color: markdownTheme.codeBlockBorder),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.link_rounded,
                  color: markdownTheme.linkColor,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _displayText,
                        style: editorTheme.smallStyle.copyWith(
                          color: markdownTheme.linkColor,
                          fontWeight: FontWeight.w600,
                          decoration: TextDecoration.underline,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (_displayText != _url)
                        Text(
                          _url,
                          style: editorTheme.xSmallStyle.copyWith(
                            color: editorTheme.mutedForeground,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: markdownTheme.codeBlockBackground,
        borderRadius: BorderRadius.circular(editorTheme.radiusMd),
        border: Border.all(color: markdownTheme.codeBlockBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text('No URL', style: editorTheme.smallStyle),
      ),
    );
  }
}
