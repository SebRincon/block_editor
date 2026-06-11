library;

// ignore_for_file: prefer_interpolation_to_compose_strings

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

import '../../rendering/embedded_text_editing_shortcuts.dart';
import '../../rendering/source_syntax_highlighter.dart';

InputDecoration _embeddedCodeInputDecoration() {
  return const InputDecoration(
    isDense: true,
    filled: false,
    fillColor: Colors.transparent,
    hoverColor: Colors.transparent,
    border: InputBorder.none,
    enabledBorder: InputBorder.none,
    focusedBorder: InputBorder.none,
    disabledBorder: InputBorder.none,
    errorBorder: InputBorder.none,
    focusedErrorBorder: InputBorder.none,
    contentPadding: EdgeInsets.zero,
  );
}

TextSelectionThemeData _embeddedCodeSelectionTheme(
  BlockEditorThemeData editorTheme,
) {
  return TextSelectionThemeData(
    cursorColor: editorTheme.cursor,
    selectionColor: editorTheme.selection,
    selectionHandleColor: editorTheme.cursor,
  );
}

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
    _focusNode = FocusNode(
      onKeyEvent: (_, event) =>
          handleEmbeddedTextEditingShortcut(_controller, event),
    );
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
    final configuredSourceStyle = scope?.sourceEditingConfig?.textStyle;
    final fontSize =
        configuredSourceStyle?.fontSize ?? config?.fontSize ?? 13.0;
    final fontFamily =
        configuredSourceStyle?.fontFamily ??
        config?.fontFamily ??
        'Cascadia Mono';
    final fontFamilyFallback =
        configuredSourceStyle?.fontFamilyFallback ??
        config?.fontFamilyFallback ??
        const [
          'JetBrains Mono',
          'Fira Code',
          'MesloLGS NF',
          'Monaco',
          'monospace',
        ];
    final showLineNumbers = config?.showLineNumbers ?? true;
    final showLanguageSelector = config?.showLanguageSelector ?? true;
    final textStyle = (configuredSourceStyle ?? const TextStyle()).copyWith(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFamilyFallback,
      fontSize: fontSize,
      color: configuredSourceStyle?.color ?? markdownTheme.codeBlockForeground,
      height: configuredSourceStyle?.height ?? 1.45,
      letterSpacing: 0,
    );
    final highlightedCode = buildHighlightedCodeSpan(
      _code,
      context: context,
      blockId: widget.node.id,
      language: _language,
      baseStyle: textStyle,
      editorTheme: editorTheme,
      markdownTheme: markdownTheme,
    );
    final transparentTextStyle = textStyle.copyWith(
      color: Colors.transparent,
      decorationColor: Colors.transparent,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: markdownTheme.codeBlockBackground,
        borderRadius: BorderRadius.all(Radius.circular(editorTheme.radiusMd)),
        border: Border.all(color: markdownTheme.codeBlockBorder),
      ),
      child: Padding(
        padding: markdownTheme.scaleSurfaceInsets(
          const EdgeInsets.fromLTRB(14, 12, 14, 14),
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showLanguageSelector)
                  SizedBox(height: markdownTheme.scaleSurfaceDimension(24)),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (showLineNumbers)
                      Padding(
                        padding: EdgeInsets.only(
                          right: markdownTheme.scaleSurfaceDimension(16),
                        ),
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
                          ? SelectableText.rich(highlightedCode)
                          : Material(
                              color: Colors.transparent,
                              child: Stack(
                                alignment: AlignmentDirectional.topStart,
                                children: [
                                  IgnorePointer(
                                    child: Text.rich(
                                      highlightedCode,
                                      textHeightBehavior:
                                          const TextHeightBehavior(
                                            applyHeightToFirstAscent: false,
                                            applyHeightToLastDescent: false,
                                          ),
                                    ),
                                  ),
                                  TextSelectionTheme(
                                    data: _embeddedCodeSelectionTheme(
                                      editorTheme,
                                    ),
                                    child: TextField(
                                      controller: _controller,
                                      focusNode: _focusNode,
                                      minLines: _lineCount,
                                      maxLines: null,
                                      keyboardType: TextInputType.multiline,
                                      textInputAction: TextInputAction.newline,
                                      style: transparentTextStyle,
                                      cursorColor: editorTheme.cursor,
                                      decoration:
                                          _embeddedCodeInputDecoration(),
                                      onChanged: _handleChanged,
                                    ),
                                  ),
                                ],
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
                      padding: markdownTheme.scaleSurfaceInsets(
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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

  @visibleForTesting
  TextSpan buildHighlightedCodeSpan(
    String code, {
    required BuildContext context,
    required String blockId,
    required String language,
    required TextStyle baseStyle,
    required BlockEditorThemeData editorTheme,
    required MarkdownDocumentThemeData markdownTheme,
  }) {
    final highlighter = BlockEditorScope.maybeOf(
      context,
    )?.sourceEditingConfig?.highlighter;
    if (highlighter != null) {
      try {
        return highlighter(
          BlockSourceHighlightRequest(
            blockId: blockId,
            source: code,
            language: language,
            baseStyle: baseStyle,
            editorTheme: editorTheme,
            markdownTheme: markdownTheme,
          ),
        );
      } catch (_) {
        // Syntax highlighting should never break editing.
      }
    }
    return buildHighlightedSourceSpan(
      code,
      language: language,
      baseStyle: baseStyle,
      editorTheme: editorTheme,
      markdownTheme: markdownTheme,
    );
  }
}
