import 'package:block_editor/block_editor.dart';
import 'package:flutter/material.dart';

/// The block type string for [CalloutWithAuthorBlock].
///
/// Chosen with a namespace prefix to avoid collisions with any current or
/// future built-in block type.
const String calloutWithAuthorBlockType = 'example.calloutWithAuthor';

/// A custom [BlockPlugin] that extends the built-in callout with an author
/// name and timestamp.
///
/// Demonstrates the full plugin registration pattern. Registered at app
/// startup via [BlockRegistry.instance.register]. Once registered it is
/// indistinguishable from a built-in block type — the slash command menu
/// surfaces it, [BlockRenderer] renders it, and serialization round-trips
/// correctly through [serialize] and [deserialize].
///
/// Attributes stored in [BlockNode.attributes]:
/// - `variant` — `'info'`, `'warning'`, or `'error'`. Defaults to `'info'`.
/// - `author` — display name of the person who wrote the callout.
/// - `timestamp` — ISO 8601 date-time string recorded when the block was
///   created. Rendered as a human-readable relative string at display time.
final class CalloutWithAuthorBlock extends BlockPlugin {
  /// Creates a [CalloutWithAuthorBlock].
  CalloutWithAuthorBlock();

  @override
  String get blockType => calloutWithAuthorBlockType;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) {
    return _CalloutWithAuthorWidget(
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
    label: 'Callout with author',
    group: 'Custom',
    description: 'A callout block that shows who wrote it and when.',
    icon: const Icon(Icons.record_voice_over_outlined, size: 16),
    onSelected: () {},
  );

  @override
  String? slashCommandGroup() => 'Custom';
}

class _CalloutWithAuthorWidget extends StatelessWidget {
  const _CalloutWithAuthorWidget({
    required this.node,
    required this.selection,
    required this.onEvent,
  });

  final BlockNode node;
  final EditorSelection selection;
  final void Function(BlockEvent) onEvent;

  String get _variant => node.attributes['variant'] as String? ?? 'info';

  String get _author => node.attributes['author'] as String? ?? 'Anonymous';

  String get _timestamp => node.attributes['timestamp'] as String? ?? '';

  Widget get _icon => switch (_variant) {
    'warning' => const Text('⚠️'),
    'error' => const Text('🚫'),
    _ => const Text('ℹ️'),
  };

  String _formatTimestamp(String iso) {
    if (iso.isEmpty) return '';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    final now = DateTime.now();
    final diff = now.difference(parsed);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${parsed.year}-${parsed.month.toString().padLeft(2, '0')}-'
        '${parsed.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final delta = node.delta ?? TextDelta.empty();
    final timestampLabel = _formatTimestamp(_timestamp);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = switch (_variant) {
      'warning' => isDark ? const Color(0xFF332B1E) : const Color(0xFFFEF9E7),
      'error' => isDark ? const Color(0xFF3A1F1F) : const Color(0xFFFDECEC),
      _ => isDark ? const Color(0xFF1E2A38) : const Color(0xFFEBF5FB),
    };

    final borderColor = switch (_variant) {
      'warning' => isDark ? const Color(0xFFFACC15) : const Color(0xFFFAF089),
      'error' => isDark ? const Color(0xFFF87171) : const Color(0xFFFEB2B2),
      _ => isDark ? const Color(0xFF3B82F6) : const Color(0xFFBEE3F8),
    };

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 10, top: 2),
                  child: _icon,
                ),
                Expanded(
                  child: GestureDetector(
                    onTapDown: (_) =>
                        onEvent(TapEvent(blockId: node.id, offset: 0)),
                    child: RichTextRenderer(
                      delta: delta,
                      blockId: node.id,
                      selection: selection,
                      baseStyle: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: borderColor)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            child: Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 13,
                  color: Color(0xFF718096),
                ),
                const SizedBox(width: 4),
                Text(
                  _author,
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFE2E8F0)
                        : const Color(0xFF4A5568),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (timestampLabel.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    '·',
                    style: const TextStyle(
                      color: Color(0xFF718096),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timestampLabel,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF718096),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
