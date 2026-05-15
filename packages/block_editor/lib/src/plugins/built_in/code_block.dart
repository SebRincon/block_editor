library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

/// [BlockPlugin] for [BlockTypes.code].
///
/// Stores code content in [BlockNode.delta] for Markdown-backed documents.
/// Legacy nodes may still provide the code string in [BlockNode.attributes]:
///
/// - `code` — the code string to display.
/// - `language` — the language identifier (e.g. `'dart'`, `'python'`).
///
/// Renders the code in a monospace multiline editor. When
/// [CodeBlockConfig.showLineNumbers] is true, line numbers are shown to the
/// left of each line. When
/// [CodeBlockConfig.showLanguageSelector] is true, a tappable language label
/// is shown in the top-right corner — tapping it emits a [CustomBlockEvent]
/// with `eventType: 'code_language_change_requested'` carrying the current
/// language as payload.
///
/// Configuration is read from [CodeBlockConfig] via [BlockEditorScope].
final class CodeBlock extends BlockPlugin {
  /// Creates a [CodeBlock].
  CodeBlock();

  @override
  String get blockType => BlockTypes.code;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) {
    return _CodeBlockWidget(node: node, onEvent: onEvent);
  }

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Code',
    group: 'Basic',
    description: 'code fence, ```',
    icon: const Icon(Icons.code),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

class _CodeBlockWidget extends StatefulWidget {
  const _CodeBlockWidget({required this.node, required this.onEvent});

  final BlockNode node;
  final void Function(BlockEvent) onEvent;

  @override
  State<_CodeBlockWidget> createState() => _CodeBlockWidgetState();
}

class _CodeBlockWidgetState extends State<_CodeBlockWidget> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  ValueChanged<bool>? _embeddedInputFocusChanged;
  bool _reportedFocus = false;

  String get _code => _controller.text;
  String get _language =>
      widget.node.attributes['language'] as String? ?? 'plaintext';

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _codeForNode(widget.node));
    _focusNode = FocusNode();
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _embeddedInputFocusChanged = BlockEditorScope.maybeOf(
      context,
    )?.onEmbeddedInputFocusChanged;
  }

  @override
  void didUpdateWidget(covariant _CodeBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextCode = _codeForNode(widget.node);
    if (!_focusNode.hasFocus && nextCode != _controller.text) {
      _controller.text = nextCode;
    }
  }

  @override
  void dispose() {
    if (_reportedFocus) {
      _embeddedInputFocusChanged?.call(false);
    }
    _focusNode.removeListener(_handleFocusChanged);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (_reportedFocus == focused) return;
    _reportedFocus = focused;
    _embeddedInputFocusChanged?.call(focused);
  }

  void _handleChanged(String value) {
    setState(() {});
    widget.onEvent(CodeBlockChangedEvent(blockId: widget.node.id, text: value));
  }

  int get _lineCount {
    if (_code.isEmpty) return 1;
    return '\n'.allMatches(_code).length + 1;
  }

  static String _codeForNode(BlockNode node) =>
      node.delta?.plainText ?? (node.attributes['code'] as String? ?? '');

  @override
  Widget build(BuildContext context) {
    final scope = BlockEditorScope.maybeOf(context);
    final config = scope?.codeConfig;
    final readOnly = scope?.readOnly ?? false;
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final fontSize = config?.fontSize ?? 14.0;
    final fontFamily = config?.fontFamily ?? 'JetBrainsMono';
    final fontFamilyFallback =
        config?.fontFamilyFallback ?? const ['MesloLGS NF', 'monospace'];
    final showLineNumbers = config?.showLineNumbers ?? true;
    final showLanguageSelector = config?.showLanguageSelector ?? true;
    final textStyle = TextStyle(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      color: markdownTheme.codeBlockForeground,
      height: 1.5,
      letterSpacing: 0,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: markdownTheme.codeBlockBackground,
        borderRadius: BorderRadius.all(Radius.circular(editorTheme.radiusMd)),
        border: Border.all(color: markdownTheme.codeBlockBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLanguageSelector) const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showLineNumbers)
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: List.generate(
                            _lineCount,
                            (i) => Text(
                              '${i + 1}',
                              style: TextStyle(
                                fontFamily: fontFamily,
                                fontFamilyFallback: fontFamilyFallback,
                                fontSize: fontSize,
                                color: markdownTheme.codeBlockMutedForeground,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    Expanded(
                      child: readOnly
                          ? SelectableText(_code, style: textStyle)
                          : Material(
                              color: Colors.transparent,
                              child: TextField(
                                controller: _controller,
                                focusNode: _focusNode,
                                minLines: _lineCount,
                                maxLines: null,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                style: textStyle,
                                cursorColor: editorTheme.cursor,
                                decoration: const InputDecoration(
                                  isDense: true,
                                  border: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  contentPadding: EdgeInsets.zero,
                                ),
                                onChanged: _handleChanged,
                              ),
                            ),
                    ),
                  ],
                ),
              ],
            ),
            if (showLanguageSelector)
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => widget.onEvent(
                    CustomBlockEvent(
                      blockId: widget.node.id,
                      eventType: 'code_language_change_requested',
                      payload: _language,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: editorTheme.background.withValues(alpha: 0.66),
                      border: Border.all(
                        color: markdownTheme.codeBlockBorder.withValues(
                          alpha: 0.72,
                        ),
                      ),
                      borderRadius: BorderRadius.circular(editorTheme.radiusSm),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      child: Text(
                        _language,
                        style: TextStyle(
                          fontFamily: fontFamily,
                          fontFamilyFallback: fontFamilyFallback,
                          fontSize: 12,
                          color: markdownTheme.codeBlockMutedForeground,
                          height: 1,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
