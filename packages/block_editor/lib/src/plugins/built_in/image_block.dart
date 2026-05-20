library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

/// [BlockPlugin] for [BlockTypes.image].
///
/// Supports three source variants stored in [BlockNode.attributes]:
///
/// - `source: 'network'` — renders a network image from `attributes['url']`.
/// - `source: 'local'` — renders a local file image from `attributes['path']`.
/// - `source: 'upload_pending'` — shows a loading indicator while the host
///   app performs an upload. The block emits a [CustomBlockEvent] with
///   `eventType: 'image_upload_requested'` carrying the local path as payload.
///
/// Configuration is read from [ImageBlockConfig] via [BlockEditorScope].
/// When no config is present the block uses internal defaults.
final class ImageBlock extends BlockPlugin {
  /// Creates an [ImageBlock].
  ImageBlock();

  @override
  String get blockType => BlockTypes.image;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) {
    return _ImageBlockWidget(node: node, onEvent: onEvent);
  }

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Image',
    group: 'Media',
    icon: const Icon(Icons.image_outlined),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Media';
}

class _ImageBlockWidget extends StatelessWidget {
  const _ImageBlockWidget({required this.node, required this.onEvent});

  final BlockNode node;
  final void Function(BlockEvent) onEvent;

  static const double _fallbackHeight = 96.0;
  static const double _maxImageWidth = 760.0;
  static const double _maxImageHeight = 520.0;

  @override
  Widget build(BuildContext context) {
    final config = BlockEditorScope.maybeOf(context)?.imageConfig;
    final source = node.attributes['source'] as String? ?? 'network';
    final fit = config?.fit ?? BoxFit.contain;
    final scale = config?.scale ?? 1.0;
    final borderRadius = config?.borderRadius ?? BorderRadius.zero;

    return ClipRRect(
      borderRadius: borderRadius,
      child: Transform.scale(
        scale: scale,
        child: _buildContent(context, source, fit, config),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    String source,
    BoxFit fit,
    ImageBlockConfig? config,
  ) {
    switch (source) {
      case 'network':
        final url = node.attributes['url'] as String? ?? '';
        if (url.isEmpty) return _placeholder(context);
        return Align(
          alignment: AlignmentDirectional.centerStart,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: _maxImageWidth,
              maxHeight: _maxImageHeight,
            ),
            child: Image.network(
              url,
              fit: fit,
              errorBuilder: (ctx, error, _) =>
                  config?.onError?.call(ctx, error) ??
                  _errorWidget(ctx, url: url),
              loadingBuilder: (ctx, child, progress) {
                if (progress == null) return child;
                return config?.onLoading?.call(ctx) ?? _loadingWidget(ctx);
              },
            ),
          ),
        );

      case 'local':
        final path = node.attributes['path'] as String? ?? '';
        if (path.isEmpty) return _placeholder(context);
        onEvent(
          CustomBlockEvent(
            blockId: node.id,
            eventType: 'image_upload_requested',
            payload: path,
          ),
        );
        return config?.onLoading?.call(context) ?? _loadingWidget(context);

      case 'upload_pending':
        return config?.onLoading?.call(context) ?? _loadingWidget(context);

      default:
        return _placeholder(context);
    }
  }

  Widget _placeholder(BuildContext context) {
    return _statusCard(
      context,
      icon: Icons.image_not_supported_outlined,
      title: 'No image',
    );
  }

  Widget _loadingWidget(BuildContext context) {
    return _statusCard(
      context,
      icon: Icons.downloading_rounded,
      title: 'Loading…',
    );
  }

  Widget _errorWidget(BuildContext context, {required String url}) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: url.isEmpty
          ? null
          : () => onEvent(
              CustomBlockEvent(
                blockId: node.id,
                eventType: 'image_open_requested',
                payload: url,
              ),
            ),
      child: _statusCard(
        context,
        icon: Icons.broken_image_outlined,
        title: 'Failed to load image',
        subtitle: url,
        clickable: url.isNotEmpty,
      ),
    );
  }

  Widget _statusCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    bool clickable = false,
  }) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: markdownTheme.codeBlockBackground,
            border: Border.all(color: markdownTheme.codeBlockBorder),
            borderRadius: BorderRadius.circular(editorTheme.radiusMd),
          ),
          child: SizedBox(
            height: _fallbackHeight,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  Icon(icon, size: 20, color: editorTheme.mutedForeground),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: editorTheme.smallStyle),
                        if (subtitle != null && subtitle.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: editorTheme.xSmallStyle.copyWith(
                              color: clickable
                                  ? markdownTheme.linkColor
                                  : editorTheme.mutedForeground,
                              decoration: clickable
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
