library;

import 'package:flutter/widgets.dart';
import 'package:block_editor/block_editor.dart';

/// [BlockPlugin] for [BlockTypes.callout].
///
/// Stores the variant in `attributes['variant']`. Valid values are `'info'`,
/// `'warning'`, and `'error'`. Defaults to `'info'` when absent.
///
/// The block content is stored as a [TextDelta] on the [BlockNode], so full
/// inline formatting is supported. The content is rendered via
/// [RichTextRenderer].
///
/// Colours, icons, and border radius are read from [CalloutBlockConfig] via
/// [BlockEditorScope]. When no config is present the block uses internal
/// defaults for each variant.
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
    icon: const SizedBox(),
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

  static const Color _infoColor = Color(0xFFEBF5FB);
  static const Color _warningColor = Color(0xFFFEF9E7);
  static const Color _errorColor = Color(0xFFFDECEC);

  static const Widget _infoIcon = Text('ℹ️');
  static const Widget _warningIcon = Text('⚠️');
  static const Widget _errorIcon = Text('🚫');

  String get _variant => node.attributes['variant'] as String? ?? 'info';

  Color _resolveColor(CalloutBlockConfig? config) {
    switch (_variant) {
      case 'warning':
        return config?.warningColor ?? _warningColor;
      case 'error':
        return config?.errorColor ?? _errorColor;
      default:
        return config?.infoColor ?? _infoColor;
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
    final color = _resolveColor(config);
    final icon = _resolveIcon(config);
    final borderRadius =
        config?.borderRadius ?? const BorderRadius.all(Radius.circular(6));
    final delta = node.delta ?? TextDelta.empty();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: color, borderRadius: borderRadius),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 2),
            child: icon,
          ),
          Expanded(
            child: GestureDetector(
              onTapDown: (details) =>
                  onEvent(TapEvent(blockId: node.id, offset: 0)),
              child: RichTextRenderer(
                delta: delta,
                blockId: node.id,
                selection: selection,
                baseStyle: const TextStyle(fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
