library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

/// [BlockPlugin] for [BlockTypes.callout].
///
/// Stores the variant in `attributes['variant']`. Common values include
/// `'note'`, `'info'`, `'warning'`, `'error'`, `'tip'`, and `'success'`.
/// Defaults to `'info'` when absent.
///
/// The block content is stored as a [TextDelta] on the [BlockNode], so full
/// inline formatting is supported. The content is rendered via
/// [RichTextRenderer].
///
/// Colors, icons, and border radius are read from [CalloutBlockConfig] via
/// [BlockEditorScope]. When config values are null, falls back to the shared
/// [MarkdownDocumentThemeData] tokens so callouts stay aligned with the
/// document surface in light and dark themes.
final class CalloutBlock extends BlockPlugin {
  /// Creates a [CalloutBlock].
  CalloutBlock();

  @override
  String get blockType => BlockTypes.callout;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) {
    return _CalloutBlockWidget(
      node: node,
      selection: selection,
      onEvent: onEvent,
    );
  }

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Callout',
    group: 'Basic',
    icon: const Icon(Icons.info_outline),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

class _CalloutBlockWidget extends StatelessWidget {
  const _CalloutBlockWidget({
    required this.node,
    required this.selection,
    required this.onEvent,
  });

  final BlockNode node;
  final EditorSelection selection;
  final void Function(BlockEvent) onEvent;

  static const Widget _infoIcon = Icon(Icons.info_outline_rounded);
  static const Widget _warningIcon = Icon(Icons.warning_amber_rounded);
  static const Widget _errorIcon = Icon(Icons.error_outline_rounded);

  String get _variant => node.attributes['variant'] as String? ?? 'info';

  Color _resolveColor(
    MarkdownDocumentThemeData markdownTheme,
    CalloutBlockConfig? config,
  ) {
    switch (_variant) {
      case 'warning':
        return config?.warningColor ?? markdownTheme.warningCallout.background;
      case 'error':
        return config?.errorColor ?? markdownTheme.errorCallout.background;
      default:
        return config?.infoColor ??
            markdownTheme.calloutTone(_variant).background;
    }
  }

  Widget _resolveIcon(CalloutBlockConfig? config) {
    switch (_variant) {
      case 'warning':
        return config?.warningIcon ?? _warningIcon;
      case 'error':
        return config?.errorIcon ?? _errorIcon;
      default:
        return config?.infoIcon ?? _infoIcon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = BlockEditorScope.maybeOf(context)?.calloutConfig;
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final tone = markdownTheme.calloutTone(_variant);
    final color = _resolveColor(markdownTheme, config);
    final icon = _resolveIcon(config);
    final borderRadius =
        config?.borderRadius ??
        BorderRadius.all(Radius.circular(editorTheme.radiusMd));
    final delta = node.delta ?? TextDelta.empty();
    final title = (node.attributes['title'] as String?)?.trim();
    final effectiveTitle = title == null || title.isEmpty
        ? _defaultTitle(_variant)
        : title;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 13, 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: tone.border.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: tone.iconBackground,
              borderRadius: BorderRadius.circular(editorTheme.radiusSm),
            ),
            child: SizedBox.square(
              dimension: 24,
              child: IconTheme(
                data: IconThemeData(size: 16, color: tone.accent),
                child: Center(child: icon),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: GestureDetector(
                onTapDown: (details) =>
                    onEvent(TapEvent(blockId: node.id, offset: 0)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      effectiveTitle,
                      style: markdownTheme.calloutTitleStyle,
                    ),
                    if (delta.plainText.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      RichTextRenderer(
                        delta: delta,
                        blockId: node.id,
                        selection: selection,
                        baseStyle: markdownTheme.calloutTextStyle,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _defaultTitle(String variant) {
    final normalized = variant.trim();
    if (normalized.isEmpty) return 'Info';
    return normalized
        .split(RegExp(r'[-_\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }
}
