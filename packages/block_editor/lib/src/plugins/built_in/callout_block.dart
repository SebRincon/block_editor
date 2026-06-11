library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

import '../../rendering/editor_span_builder.dart';

InputDecoration _calloutTitleDecoration() {
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

class _CalloutBlockWidget extends StatefulWidget {
  const _CalloutBlockWidget({
    required this.node,
    required this.selection,
    required this.onEvent,
  });

  final BlockNode node;
  final EditorSelection selection;
  final void Function(BlockEvent) onEvent;

  @override
  State<_CalloutBlockWidget> createState() => _CalloutBlockWidgetState();
}

class _CalloutBlockWidgetState extends State<_CalloutBlockWidget> {
  late final TextEditingController _titleController;
  late final FocusNode _titleFocusNode;
  final _bodyTextKey = GlobalKey();
  ValueChanged<bool>? _embeddedInputFocusChanged;
  bool _reportedTitleFocus = false;

  static const Widget _infoIcon = Icon(Icons.info_outline_rounded);
  static const Widget _warningIcon = Icon(Icons.warning_amber_rounded);
  static const Widget _errorIcon = Icon(Icons.error_outline_rounded);
  static const Widget _successIcon = Icon(Icons.check_circle_outline_rounded);
  static const Widget _tipIcon = Icon(Icons.lightbulb_outline_rounded);
  static const Widget _noteIcon = Icon(Icons.sticky_note_2_outlined);

  static const List<String> _variants = [
    'info',
    'note',
    'tip',
    'success',
    'warning',
    'error',
  ];

  String get _variant => widget.node.attributes['variant'] as String? ?? 'info';

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: _resolvedTitle(widget.node));
    _titleFocusNode = FocusNode();
    _titleFocusNode.addListener(_handleTitleFocusChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _embeddedInputFocusChanged = BlockEditorScope.maybeOf(
      context,
    )?.onEmbeddedInputFocusChanged;
  }

  @override
  void didUpdateWidget(covariant _CalloutBlockWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextTitle = _resolvedTitle(widget.node);
    if (!_titleFocusNode.hasFocus && nextTitle != _titleController.text) {
      _titleController.text = nextTitle;
    }
  }

  @override
  void dispose() {
    if (_reportedTitleFocus) {
      _embeddedInputFocusChanged?.call(false);
    }
    _titleFocusNode.removeListener(_handleTitleFocusChanged);
    _titleFocusNode.dispose();
    _titleController.dispose();
    super.dispose();
  }

  void _handleTitleFocusChanged() {
    final focused = _titleFocusNode.hasFocus;
    if (_reportedTitleFocus == focused) return;
    _reportedTitleFocus = focused;
    _embeddedInputFocusChanged?.call(focused);
  }

  void _handleTitleChanged(String value) {
    widget.onEvent(
      CalloutTitleChangedEvent(blockId: widget.node.id, title: value),
    );
  }

  void _handleVariantChanged(String variant) {
    if (variant == _variant) return;
    widget.onEvent(
      CalloutVariantChangedEvent(blockId: widget.node.id, variant: variant),
    );
  }

  void _handleBodyTapDown(
    TapDownDetails details,
    TextDelta delta,
    TextStyle baseStyle,
  ) {
    final position = _resolveBodyOffset(
      details.globalPosition,
      delta,
      baseStyle,
    );
    widget.onEvent(
      TapEvent(
        blockId: widget.node.id,
        offset: position.offset,
        affinity: position.affinity,
      ),
    );
  }

  ({int offset, TextAffinity affinity}) _resolveBodyOffset(
    Offset globalPosition,
    TextDelta delta,
    TextStyle baseStyle,
  ) {
    final renderBox =
        _bodyTextKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) {
      return (offset: 0, affinity: TextAffinity.downstream);
    }
    final context = _bodyTextKey.currentContext!;
    final localPosition = renderBox.globalToLocal(globalPosition);
    final constrainedWidth = renderBox.size.width;
    final renderedHeight = renderBox.size.height;
    final effectiveBase = resolveBlockEditorTextStyle(context, baseStyle);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final span = buildMeasurementSpan(
      delta,
      effectiveBase,
      BlockEditorScope.maybeOf(context)?.variables ?? const {},
      markdownTheme,
    );
    final painter = TextPainter(
      text: span,
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      textHeightBehavior: blockEditorTextHeightBehavior,
    )..layout(maxWidth: constrainedWidth);
    final scale = renderedHeight > 0 && painter.height > 0
        ? painter.height / renderedHeight
        : 1.0;
    final visualPosition = painter.getPositionForOffset(
      Offset(localPosition.dx, localPosition.dy * scale),
    );
    return (
      offset: visualToModelOffset(
        delta,
        visualPosition.offset,
        BlockEditorScope.maybeOf(context)?.variables ?? const {},
      ),
      affinity: visualPosition.affinity,
    );
  }

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
    return _resolveIconForVariant(_variant, config);
  }

  Widget _resolveIconForVariant(String variant, CalloutBlockConfig? config) {
    switch (variant) {
      case 'warning':
        return config?.warningIcon ?? _warningIcon;
      case 'error':
        return config?.errorIcon ?? _errorIcon;
      case 'success':
      case 'check':
        return _successIcon;
      case 'tip':
      case 'hint':
        return _tipIcon;
      case 'note':
        return _noteIcon;
      default:
        return config?.infoIcon ?? _infoIcon;
    }
  }

  String _resolvedTitle(BlockNode node) {
    final title = (node.attributes['title'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      return _defaultTitle(node.attributes['variant'] as String? ?? 'info');
    }
    return title;
  }

  @override
  Widget build(BuildContext context) {
    final config = BlockEditorScope.maybeOf(context)?.calloutConfig;
    final readOnly = BlockEditorScope.maybeOf(context)?.readOnly ?? false;
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final markdownTheme = MarkdownDocumentThemeData.fromContext(context);
    final tone = markdownTheme.calloutTone(_variant);
    final color = _resolveColor(markdownTheme, config);
    final icon = _resolveIcon(config);
    final borderRadius =
        config?.borderRadius ??
        BorderRadius.all(Radius.circular(editorTheme.radiusMd));
    final delta = widget.node.delta ?? TextDelta.empty();

    return Container(
      padding: markdownTheme.scaleSurfaceInsets(
        const EdgeInsets.fromLTRB(12, 11, 13, 12),
      ),
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius,
        border: Border.all(color: tone.border.withValues(alpha: 0.24)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIconButton(
            context,
            config: config,
            readOnly: readOnly,
            tone: tone,
            icon: icon,
          ),
          SizedBox(width: markdownTheme.scaleSurfaceDimension(10)),
          Expanded(
            child: MouseRegion(
              cursor: SystemMouseCursors.text,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  readOnly
                      ? Text(
                          _titleController.text,
                          style: markdownTheme.calloutTitleStyle,
                        )
                      : Material(
                          color: Colors.transparent,
                          child: TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            maxLines: 1,
                            style: markdownTheme.calloutTitleStyle,
                            cursorColor: editorTheme.cursor,
                            decoration: _calloutTitleDecoration(),
                            onChanged: _handleTitleChanged,
                          ),
                        ),
                  if (delta.plainText.isNotEmpty) ...[
                    SizedBox(height: markdownTheme.scaleSurfaceDimension(4)),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (details) => _handleBodyTapDown(
                        details,
                        delta,
                        markdownTheme.calloutTextStyle,
                      ),
                      child: RichTextRenderer(
                        key: _bodyTextKey,
                        delta: delta,
                        blockId: widget.node.id,
                        selection: widget.selection,
                        baseStyle: markdownTheme.calloutTextStyle,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    BuildContext context, {
    required CalloutBlockConfig? config,
    required bool readOnly,
    required MarkdownCalloutTone tone,
    required Widget icon,
  }) {
    final editorTheme = BlockEditorThemeData.fromContext(context);
    final iconBox = DecoratedBox(
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
    );
    if (readOnly) return iconBox;
    return PopupMenuButton<String>(
      tooltip: 'Callout style',
      padding: EdgeInsets.zero,
      position: PopupMenuPosition.under,
      initialValue: _variant,
      onSelected: _handleVariantChanged,
      itemBuilder: (context) => [
        for (final variant in _variants)
          PopupMenuItem<String>(
            value: variant,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconTheme(
                  data: IconThemeData(
                    size: 16,
                    color: MarkdownDocumentThemeData.fromContext(
                      context,
                    ).calloutTone(variant).accent,
                  ),
                  child: _resolveIconForVariant(variant, config),
                ),
                const SizedBox(width: 8),
                Text(_defaultTitle(variant)),
              ],
            ),
          ),
      ],
      child: iconBox,
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
