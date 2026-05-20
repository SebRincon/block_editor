library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

/// [BlockPlugin] for [BlockTypes.youtube].
///
/// Stores the YouTube video ID in `attributes['videoId']`. An optional raw
/// URL may be stored in `attributes['url']` — the video ID is parsed from it
/// at serialization time by the host app before storing the node.
///
/// Renders a tappable placeholder. Tapping emits a [CustomBlockEvent] with
/// `eventType: 'youtube_play_requested'` carrying the video ID as payload.
/// The host app opens or embeds the video in response.
///
/// The embed URL is constructed respecting [YouTubeBlockConfig.privacyEnhanced].
/// Configuration is read from [YouTubeBlockConfig] via [BlockEditorScope].
final class YouTubeBlock extends BlockPlugin {
  /// Creates a [YouTubeBlock].
  YouTubeBlock();

  @override
  String get blockType => BlockTypes.youtube;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) {
    return _YouTubeBlockWidget(node: node, onEvent: onEvent);
  }

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'YouTube',
    group: 'Media',
    icon: const Icon(Icons.ondemand_video),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Media';
}

class _YouTubeBlockWidget extends StatelessWidget {
  const _YouTubeBlockWidget({required this.node, required this.onEvent});

  final BlockNode node;
  final void Function(BlockEvent) onEvent;

  static const double _maxPreviewWidth = 720.0;
  static const Color _youTubeRed = Color(0xFFFF0000);

  String get _videoId => node.attributes['videoId'] as String? ?? '';

  String embedUrl(bool privacyEnhanced) {
    final domain = privacyEnhanced ? 'youtube-nocookie.com' : 'youtube.com';
    return 'https://www.$domain/embed/$_videoId';
  }

  @override
  Widget build(BuildContext context) {
    final config = BlockEditorScope.maybeOf(context)?.youTubeConfig;
    final privacyEnhanced = config?.privacyEnhanced ?? false;

    if (_videoId.isEmpty) {
      return _placeholder(context);
    }

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onEvent(
        CustomBlockEvent(
          blockId: node.id,
          eventType: 'youtube_play_requested',
          payload: _videoId,
        ),
      ),
      child: Align(
        alignment: AlignmentDirectional.centerStart,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _maxPreviewWidth),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _YouTubePreviewSurface(
              url: embedUrl(privacyEnhanced),
              showControls: config?.showControls ?? true,
            ),
          ),
        ),
      ),
    );
  }

  Widget _placeholder(BuildContext context) => const _YouTubePlaceholder();
}

class _YouTubePreviewSurface extends StatelessWidget {
  const _YouTubePreviewSurface({required this.url, required this.showControls});

  final String url;
  final bool showControls;

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: markdownTheme.codeBlockBackground,
        border: Border.all(color: markdownTheme.codeBlockBorder),
        borderRadius: BorderRadius.circular(editorTheme.radiusMd),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 14,
            right: 14,
            bottom: 12,
            child: Text(
              url,
              style: editorTheme.xSmallStyle,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showControls)
            Container(
              width: 54,
              height: 38,
              decoration: BoxDecoration(
                color: _YouTubeBlockWidget._youTubeRed,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.18),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(
                Icons.play_arrow,
                color: Colors.white,
                size: 24,
              ),
            ),
        ],
      ),
    );
  }
}

class _YouTubePlaceholder extends StatelessWidget {
  const _YouTubePlaceholder();

  @override
  Widget build(BuildContext context) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: markdownTheme.codeBlockBackground,
            border: Border.all(color: markdownTheme.codeBlockBorder),
            borderRadius: BorderRadius.circular(editorTheme.radiusMd),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.ondemand_video_outlined,
                  size: 18,
                  color: editorTheme.mutedForeground,
                ),
                const SizedBox(width: 10),
                Text('No video ID', style: editorTheme.smallStyle),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
