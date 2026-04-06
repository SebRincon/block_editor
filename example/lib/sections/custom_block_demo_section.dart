import 'package:block_editor/block_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../plugins/callout_with_author_block.dart';
import '../theme/app_theme.dart';

/// Demonstrates the [BlockPlugin] registration API.
///
/// Shows a [CalloutWithAuthorBlock] — a custom block that extends the built-in
/// callout pattern with author and timestamp fields — rendered in a live
/// editor alongside a code snippet panel showing exactly how the plugin was
/// registered. The registration itself happens in [main] before [runApp].
class CustomBlockDemoSection extends StatefulWidget {
  /// Creates a [CustomBlockDemoSection].
  const CustomBlockDemoSection({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<CustomBlockDemoSection> createState() => _CustomBlockDemoSectionState();
}

class _CustomBlockDemoSectionState extends State<CustomBlockDemoSection> {
  late final BlockController _controller;

  @override
  void initState() {
    super.initState();
    _controller = BlockController(document: _demoDocument());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  BlockDocument _demoDocument() {
    final now = DateTime.now();
    final earlier = now.subtract(const Duration(hours: 3));

    return BlockDocument([
      BlockNode(
        type: BlockTypes.paragraph,
        delta: TextDelta.fromPlainText(
          'The block below is a custom plugin — not a built-in. '
          'It was registered with a single line before runApp.',
        ),
      ),
      BlockNode(
        type: calloutWithAuthorBlockType,
        attributes: {
          'variant': 'info',
          'author': 'Stanly Silas',
          'timestamp': now.toIso8601String(),
        },
        delta: TextDelta.fromPlainText(
          'Custom blocks are fully self-contained. They import only '
          'block_editor, implement BlockPlugin, and register via '
          'BlockRegistry.instance.register(). No internal types leak '
          'across the package boundary.',
        ),
      ),
      BlockNode(
        type: calloutWithAuthorBlockType,
        attributes: {
          'variant': 'warning',
          'author': 'Architecture Review',
          'timestamp': earlier.toIso8601String(),
        },
        delta: TextDelta.fromPlainText(
          'The slashCommandGroup() return value controls which section '
          'of the slash menu this block appears under. Return null to '
          'fall under the default Custom group.',
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isWide = MediaQuery.of(context).size.width >= 900;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionHeader(colors: colors),
        Expanded(
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _EditorPanel(controller: _controller)),
                    VerticalDivider(
                      width: 1,
                      thickness: 1,
                      color: colors.border,
                    ),
                    Expanded(child: const _CodePanel()),
                  ],
                )
              : Column(
                  children: [
                    Expanded(child: _EditorPanel(controller: _controller)),
                    Divider(height: 1, color: colors.border),
                    Expanded(child: const _CodePanel()),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Custom Block Demo',
            style: TextStyle(
              color: colors.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'CalloutWithAuthorBlock — registered via BlockRegistry.instance.register()',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _EditorPanel extends StatelessWidget {
  const _EditorPanel({required this.controller});
  final BlockController controller;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Text(
            'Live render',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
        Expanded(
          child: BlockEditorWidget(
            controller: controller,
            readOnly: true,
            padding: const EdgeInsets.all(24),
          ),
        ),
      ],
    );
  }
}

class _CodePanel extends StatefulWidget {
  const _CodePanel();

  @override
  State<_CodePanel> createState() => _CodePanelState();
}

class _CodePanelState extends State<_CodePanel> {
  bool _copied = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  static const String _snippet = '''// 1. Implement BlockPlugin
final class CalloutWithAuthorBlock extends BlockPlugin {
  @override
  String get blockType => 'example.calloutWithAuthor';

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) {
    return CalloutWithAuthorWidget(
      node: node,
      selection: selection,
      onEvent: onEvent,
    );
  }

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) =>
      BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Callout with author',
    group: 'Custom',
    icon: Icon(Icons.record_voice_over_outlined),
    onSelected: () {},
  );

  @override
  String? slashCommandGroup() => 'Custom';
}

// 2. Register once before runApp — that's it
void main() {
  BlockRegistry.instance.register(CalloutWithAuthorBlock());
  runApp(const App());
}

// 3. Insert nodes with the custom type anywhere
final node = BlockNode(
  type: 'example.calloutWithAuthor',
  attributes: {
    'variant': 'info',
    'author': 'Stanly Silas',
    'timestamp': DateTime.now().toIso8601String(),
  },
  delta: TextDelta.fromPlainText('Hello from a custom block.'),
);
controller.append(node);''';

  Future<void> _copy() async {
    await Clipboard.setData(const ClipboardData(text: _snippet));
    if (!mounted) return;
    setState(() => _copied = true);
    await Future<void>.delayed(const Duration(seconds: 2));
    if (mounted) setState(() => _copied = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(bottom: BorderSide(color: colors.border)),
          ),
          child: Row(
            children: [
              Text(
                'Registration',
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              _CopyButton(copied: _copied, onCopy: _copy, colors: colors),
            ],
          ),
        ),
        Expanded(
          child: Container(
            color: const Color(0xFF1E1E1E),
            child: Scrollbar(
              controller: _scrollController,
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(20),
                child: SelectableText(
                  _snippet,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    color: Color(0xFFD4D4D4),
                    height: 1.6,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CopyButton extends StatefulWidget {
  const _CopyButton({
    required this.copied,
    required this.onCopy,
    required this.colors,
  });

  final bool copied;
  final VoidCallback onCopy;
  final AppColors colors;

  @override
  State<_CopyButton> createState() => _CopyButtonState();
}

class _CopyButtonState extends State<_CopyButton> {
  bool hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (event) => setState(() => hover = true),
      onExit: (event) => setState(() => hover = false),
      child: GestureDetector(
        onTap: widget.onCopy,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: hover
                ? widget.colors.surface
                : widget.copied
                ? const Color(0xFF22C55E).withValues(alpha: 0.12)
                : widget.colors.surfaceVariant,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: widget.copied
                  ? const Color(0xFF22C55E)
                  : widget.colors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.copied ? Icons.check : Icons.copy_outlined,
                size: 13,
                color: widget.copied
                    ? const Color(0xFF22C55E)
                    : widget.colors.textMuted,
              ),
              const SizedBox(width: 5),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 200),
                style: TextStyle(
                  color: widget.copied
                      ? const Color(0xFF22C55E)
                      : widget.colors.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                child: Text(widget.copied ? 'Copied' : 'Copy'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
