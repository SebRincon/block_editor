import 'dart:async';
import 'dart:math' as math;

import 'package:block_editor/block_editor.dart';
import 'package:flutter/material.dart';

import '../storage/vten_reader_preferences_store.dart';
import '../theme/app_theme.dart';

/// Interactive Markdown rendering playground for tuning document tokens.
class RenderingPlaygroundSection extends StatefulWidget {
  /// Creates a [RenderingPlaygroundSection].
  const RenderingPlaygroundSection({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
    this.preferencesStore,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VtenReaderPreferencesStore? preferencesStore;

  @override
  State<RenderingPlaygroundSection> createState() =>
      _RenderingPlaygroundSectionState();
}

class _RenderingPlaygroundSectionState
    extends State<RenderingPlaygroundSection> {
  late final BlockController _controller;
  late final TextEditingController _sourceController;
  late final ScrollController _controlsScrollController;
  StreamSubscription<DocumentChange>? _changesSub;

  bool _syncing = false;
  bool _readOnly = true;
  bool _showSource = true;
  bool _includeBlockOnlyShowcase = true;
  MarkdownDocumentDensity _readerDensity = MarkdownDocumentDensity.comfortable;
  MarkdownDocumentContentAlignment _contentAlignment =
      MarkdownDocumentContentAlignment.centered;
  double _maxContentWidth = 1248;
  double _horizontalPadding = 32;
  double _verticalPadding = 28;
  double _paragraphSize = 16;
  double _paragraphHeight = 1.58;
  double _listIndentWidth = 28;
  double _listMarkerWidth = 28;
  double _bulletMarkerY = -1.5;
  double _numberMarkerY = -2.0;
  double _todoMarkerY = 2;
  double _tableTextSize = 14.5;
  double _codeTextSize = 13.5;

  static const Map<String, String> _variables = {
    'authorName': 'Sebastian',
    'packageName': 'block_editor',
    'version': '0.0.4-dev.1',
  };

  @override
  void initState() {
    super.initState();
    _sourceController = TextEditingController(text: _playgroundMarkdown);
    _controlsScrollController = ScrollController();
    _controller = BlockController(document: _buildDocumentFromSource());
    _loadReaderPreferences();
    _changesSub = _controller.changes.listen((_) {
      if (_syncing) return;
      final markdown = BlockMarkdownCodec.encode(_controller.document);
      _syncing = true;
      _sourceController.value = TextEditingValue(
        text: markdown,
        selection: TextSelection.collapsed(offset: markdown.length),
      );
      _syncing = false;
    });
  }

  Future<void> _loadReaderPreferences() async {
    final store = widget.preferencesStore;
    if (store == null) return;
    final preferences = await store.load();
    if (!mounted || preferences == null) return;
    setState(() {
      _readerDensity = preferences.density;
      _contentAlignment = preferences.contentAlignment;
    });
  }

  void _persistReaderPreferences() {
    final store = widget.preferencesStore;
    if (store == null) return;
    unawaited(
      store.save(
        VtenReaderPreferences(
          density: _readerDensity,
          contentAlignment: _contentAlignment,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _changesSub?.cancel();
    _controller.dispose();
    _sourceController.dispose();
    _controlsScrollController.dispose();
    super.dispose();
  }

  BlockDocument _buildDocumentFromSource() {
    final decoded = BlockMarkdownCodec.decode(_sourceController.text);
    if (!_includeBlockOnlyShowcase) return decoded;
    return BlockDocument([...decoded.blocks, ..._blockOnlyShowcase()]);
  }

  List<BlockNode> _blockOnlyShowcase() {
    return [
      BlockNode(type: BlockTypes.divider),
      BlockNode(
        type: BlockTypes.heading2,
        delta: TextDelta.fromPlainText('Block-only components'),
      ),
      BlockNode(
        type: BlockTypes.paragraph,
        delta: BlockMarkdownCodec.parseInline(
          'These blocks are appended after the Markdown fixture so every '
          'built-in renderer can be tuned in one place, including source-backed '
          'blocks and media cards that do not always appear in raw Markdown.',
        ),
      ),
      BlockNode(
        type: BlockTypes.heading3,
        delta: TextDelta.fromPlainText('Manual block variants'),
      ),
      BlockNode(
        type: BlockTypes.paragraph,
        delta: BlockMarkdownCodec.parseInline(
          'Manual paragraph with **bold**, *italic*, ~~strike~~, ==highlight==, '
          '`inline code`, [[Block playground|wiki alias]], ![[Embedded card]], '
          '{{packageName}}, and #block-fixture.',
        ),
      ),
      BlockNode(
        type: BlockTypes.bulletList,
        delta: BlockMarkdownCodec.parseInline('Manual bullet at depth 0.'),
      ),
      BlockNode(
        type: BlockTypes.bulletList,
        attributes: const {'indent': 1},
        delta: BlockMarkdownCodec.parseInline(
          'Manual bullet at depth 1 with a longer wrapped line for marker tuning.',
        ),
      ),
      BlockNode(
        type: BlockTypes.bulletList,
        attributes: const {'indent': 2},
        delta: BlockMarkdownCodec.parseInline('Manual bullet at depth 2.'),
      ),
      BlockNode(
        type: BlockTypes.numberedList,
        delta: BlockMarkdownCodec.parseInline(
          'Manual numbered item at depth 0.',
        ),
      ),
      BlockNode(
        type: BlockTypes.numberedList,
        attributes: const {'indent': 1},
        delta: BlockMarkdownCodec.parseInline(
          'Manual numbered item at depth 1 for number marker baseline checks.',
        ),
      ),
      BlockNode(
        type: BlockTypes.todo,
        attributes: const {'checked': true},
        delta: BlockMarkdownCodec.parseInline('Manual completed todo.'),
      ),
      BlockNode(
        type: BlockTypes.todo,
        attributes: const {'checked': false, 'indent': 1},
        delta: BlockMarkdownCodec.parseInline(
          'Manual nested open todo with wrapping text and checkbox alignment.',
        ),
      ),
      BlockNode(
        type: BlockTypes.quote,
        delta: BlockMarkdownCodec.parseInline(
          'Manual quote block with **formatted text** and a second line.\n'
          'The quote renderer should preserve quiet rhythm.',
        ),
      ),
      BlockNode(
        type: BlockTypes.callout,
        attributes: const {'variant': 'warning', 'title': 'Manual callout'},
        delta: BlockMarkdownCodec.parseInline(
          'Callout block built directly from BlockNode attributes.',
        ),
      ),
      BlockNode(
        type: BlockTypes.table,
        attributes: const {
          'headers': ['Block', 'Variant', 'Notes'],
          'alignments': ['left', 'center', 'right'],
          'rows': [
            ['Paragraph', 'Rich inline', '**bold** stays visible in source'],
            ['Inline markdown', '**bold** and *italic*', 'renders in cells'],
            ['Highlight/code', '==mark== plus `code`', 'mixed spans'],
            [
              'Links',
              '[Docs](https://example.com) and [[Page|alias]]',
              'labels only',
            ],
            ['Todo', 'Nested', 'checkbox marker Y'],
            ['Table', 'Resizable', 'hover controls'],
          ],
        },
      ),
      BlockNode(
        type: BlockTypes.code,
        attributes: const {'language': 'typescript'},
        delta: TextDelta.fromPlainText(
          '''
type MarkdownBlock = {
  type: string;
  source: 'markdown' | 'manual';
  editable: boolean;
};
'''
              .trim(),
        ),
      ),
      BlockNode(
        type: BlockTypes.math,
        delta: TextDelta.fromPlainText(
          'quality = fidelity + ergonomics + visual\\ consistency',
        ),
      ),
      BlockNode(
        type: BlockTypes.mermaid,
        delta: TextDelta.fromPlainText(
          '''
sequenceDiagram
  participant User
  participant Playground
  participant Renderer
  User->>Playground: tune tokens
  Playground->>Renderer: rebuild MarkdownDocumentTheme
'''
              .trim(),
        ),
      ),
      BlockNode(
        type: BlockTypes.rawMarkdown,
        delta: TextDelta.fromPlainText(
          '''
::: custom-container
Raw Markdown block inserted manually through BlockNode.
:::
'''
              .trim(),
        ),
      ),
      BlockNode(type: BlockTypes.divider),
      BlockNode(
        type: BlockTypes.heading3,
        delta: TextDelta.fromPlainText('Media and reference cards'),
      ),
      BlockNode(
        type: BlockTypes.image,
        attributes: const {
          'source': 'network',
          'url': 'https://picsum.photos/seed/markdown-playground/1000/420',
          'alt': 'Playground image',
        },
      ),
      BlockNode(
        type: BlockTypes.image,
        attributes: const {
          'source': 'network',
          'url':
              'https://picsum.photos/seed/markdown-playground-detail/720/360',
          'alt': 'Secondary image card',
        },
      ),
      BlockNode(
        type: BlockTypes.video,
        attributes: const {
          'source': 'network',
          'url': 'https://example.com/preview.mp4',
        },
      ),
      BlockNode(
        type: BlockTypes.video,
        attributes: const {
          'source': 'local',
          'path': '/Users/sebastian/Desktop/design-review.mov',
        },
      ),
      BlockNode(
        type: BlockTypes.youtube,
        attributes: const {'videoId': 'dQw4w9WgXcQ'},
      ),
      BlockNode(
        type: BlockTypes.youtube,
        attributes: const {
          'url': 'https://www.youtube.com/watch?v=aqz-KE-bpKQ',
        },
      ),
      BlockNode(
        type: BlockTypes.file,
        attributes: const {
          'filename': 'rendering-token-notes.pdf',
          'size': '284 KB',
          'path': 'https://example.com/rendering-token-notes.pdf',
        },
      ),
      BlockNode(
        type: BlockTypes.file,
        attributes: const {
          'filename': 'plan-fixture.md',
          'size': '18 KB',
          'path':
              '/Users/sebastian/Developer/vibe-coder/vibe_coder/deps/v2/vibecode_chat_ui/plan.md',
        },
      ),
      BlockNode(
        type: BlockTypes.link,
        attributes: const {
          'displayText': 'CodeForge Markdown integration notes',
          'title': 'CodeForge Markdown integration notes',
          'url': 'https://example.com/codeforge-markdown',
        },
      ),
    ];
  }

  void _replaceDocumentFromSource() {
    if (_syncing) return;
    _syncing = true;
    _controller.replaceDocument(_buildDocumentFromSource());
    _syncing = false;
  }

  void _resetTuning() {
    setState(() {
      _readerDensity = MarkdownDocumentDensity.comfortable;
      _contentAlignment = MarkdownDocumentContentAlignment.centered;
      _maxContentWidth = 1248;
      _horizontalPadding = 32;
      _verticalPadding = 28;
      _paragraphSize = 16;
      _paragraphHeight = 1.58;
      _listIndentWidth = 28;
      _listMarkerWidth = 28;
      _bulletMarkerY = -1.5;
      _numberMarkerY = -2.0;
      _todoMarkerY = 2;
      _tableTextSize = 14.5;
      _codeTextSize = 13.5;
    });
    _persistReaderPreferences();
  }

  MarkdownDocumentThemeData _themeData(BuildContext context) {
    final base = MarkdownDocumentThemeData.defaults(context);
    final compact = _readerDensity == MarkdownDocumentDensity.compact;
    final fontScale = compact ? 0.94 : 1.0;
    final paragraphSize = _paragraphSize * fontScale;
    final paragraphHeight = compact
        ? math.min(_paragraphHeight, 1.46)
        : _paragraphHeight;
    final paragraph = base.paragraphStyle.copyWith(
      fontSize: paragraphSize,
      height: paragraphHeight,
    );
    return base.copyWith(
      density: _readerDensity,
      contentAlignment: _contentAlignment,
      maxContentWidth: _maxContentWidth,
      pagePadding: EdgeInsets.symmetric(
        horizontal: compact ? _horizontalPadding * 0.74 : _horizontalPadding,
        vertical: compact ? _verticalPadding * 0.58 : _verticalPadding,
      ),
      blockSpacingScale: compact ? 0.58 : 1,
      surfacePaddingScale: compact ? 0.78 : 1,
      paragraphStyle: paragraph,
      heading1Style: paragraph.copyWith(
        fontSize: paragraphSize * 1.94,
        height: 1.14,
        fontWeight: FontWeight.w700,
      ),
      heading2Style: paragraph.copyWith(
        fontSize: paragraphSize * 1.56,
        height: 1.18,
        fontWeight: FontWeight.w700,
      ),
      heading3Style: paragraph.copyWith(
        fontSize: paragraphSize * 1.25,
        height: 1.25,
        fontWeight: FontWeight.w600,
      ),
      heading4Style: paragraph.copyWith(
        fontSize: paragraphSize * 1.125,
        height: 1.28,
        fontWeight: FontWeight.w600,
      ),
      heading5Style: paragraph.copyWith(
        fontSize: paragraphSize,
        height: 1.34,
        fontWeight: FontWeight.w600,
      ),
      heading6Style: paragraph.copyWith(
        fontSize: paragraphSize * 0.90,
        height: 1.35,
        fontWeight: FontWeight.w700,
        color: base.codeBlockMutedForeground,
      ),
      listMarkerStyle: paragraph.copyWith(color: base.codeBlockMutedForeground),
      listIndentWidth: compact ? _listIndentWidth * 0.9 : _listIndentWidth,
      listMarkerWidth: compact ? _listMarkerWidth * 0.9 : _listMarkerWidth,
      bulletListMarkerVerticalOffset: _bulletMarkerY,
      numberedListMarkerVerticalOffset: _numberMarkerY,
      todoMarkerVerticalOffset: _todoMarkerY,
      tableCellStyle: base.tableCellStyle.copyWith(
        fontSize: compact ? _tableTextSize * 0.94 : _tableTextSize,
      ),
      tableHeaderStyle: base.tableHeaderStyle.copyWith(
        fontSize: compact ? (_tableTextSize - 1) * 0.94 : _tableTextSize - 1,
      ),
      inlineCodeStyle: base.inlineCodeStyle.copyWith(
        fontSize: compact ? _codeTextSize * 0.94 : _codeTextSize,
      ),
      codeBlockForeground: base.codeBlockForeground,
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final markdownTheme = _themeData(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PlaygroundHeader(
          colors: colors,
          themeMode: widget.themeMode,
          onToggleTheme: widget.onToggleTheme,
          onReset: _resetTuning,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final wide = constraints.maxWidth >= 1060;
              final controls = _ControlsPane(
                colors: colors,
                scrollController: _controlsScrollController,
                readOnly: _readOnly,
                showSource: _showSource,
                includeBlockOnlyShowcase: _includeBlockOnlyShowcase,
                compactReader:
                    _readerDensity == MarkdownDocumentDensity.compact,
                centerContent:
                    _contentAlignment ==
                    MarkdownDocumentContentAlignment.centered,
                maxContentWidth: _maxContentWidth,
                horizontalPadding: _horizontalPadding,
                verticalPadding: _verticalPadding,
                paragraphSize: _paragraphSize,
                paragraphHeight: _paragraphHeight,
                listIndentWidth: _listIndentWidth,
                listMarkerWidth: _listMarkerWidth,
                bulletMarkerY: _bulletMarkerY,
                numberMarkerY: _numberMarkerY,
                todoMarkerY: _todoMarkerY,
                tableTextSize: _tableTextSize,
                codeTextSize: _codeTextSize,
                onReadOnlyChanged: (value) => setState(() => _readOnly = value),
                onShowSourceChanged: (value) =>
                    setState(() => _showSource = value),
                onIncludeBlockOnlyChanged: (value) {
                  setState(() => _includeBlockOnlyShowcase = value);
                  _replaceDocumentFromSource();
                },
                onCompactReaderChanged: (value) {
                  setState(() {
                    _readerDensity = value
                        ? MarkdownDocumentDensity.compact
                        : MarkdownDocumentDensity.comfortable;
                  });
                  _persistReaderPreferences();
                },
                onCenterContentChanged: (value) {
                  setState(() {
                    _contentAlignment = value
                        ? MarkdownDocumentContentAlignment.centered
                        : MarkdownDocumentContentAlignment.leading;
                  });
                  _persistReaderPreferences();
                },
                onMaxContentWidthChanged: (value) =>
                    setState(() => _maxContentWidth = value),
                onHorizontalPaddingChanged: (value) =>
                    setState(() => _horizontalPadding = value),
                onVerticalPaddingChanged: (value) =>
                    setState(() => _verticalPadding = value),
                onParagraphSizeChanged: (value) =>
                    setState(() => _paragraphSize = value),
                onParagraphHeightChanged: (value) =>
                    setState(() => _paragraphHeight = value),
                onListIndentWidthChanged: (value) =>
                    setState(() => _listIndentWidth = value),
                onListMarkerWidthChanged: (value) =>
                    setState(() => _listMarkerWidth = value),
                onBulletMarkerYChanged: (value) =>
                    setState(() => _bulletMarkerY = value),
                onNumberMarkerYChanged: (value) =>
                    setState(() => _numberMarkerY = value),
                onTodoMarkerYChanged: (value) =>
                    setState(() => _todoMarkerY = value),
                onTableTextSizeChanged: (value) =>
                    setState(() => _tableTextSize = value),
                onCodeTextSizeChanged: (value) =>
                    setState(() => _codeTextSize = value),
              );
              final preview = _PreviewPane(
                colors: colors,
                markdownTheme: markdownTheme,
                controller: _controller,
                readOnly: _readOnly,
              );
              final source = _SourcePane(
                colors: colors,
                controller: _sourceController,
                visible: _showSource,
                onChanged: (_) => _replaceDocumentFromSource(),
              );

              if (!wide) {
                return ListView(
                  children: [
                    SizedBox(height: 380, child: controls),
                    Divider(height: 1, color: colors.border),
                    SizedBox(height: 620, child: preview),
                    if (_showSource) ...[
                      Divider(height: 1, color: colors.border),
                      SizedBox(height: 360, child: source),
                    ],
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(width: 324, child: controls),
                  VerticalDivider(width: 1, color: colors.border),
                  Expanded(child: preview),
                  if (_showSource) ...[
                    VerticalDivider(width: 1, color: colors.border),
                    SizedBox(width: 390, child: source),
                  ],
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PlaygroundHeader extends StatelessWidget {
  const _PlaygroundHeader({
    required this.colors,
    required this.themeMode,
    required this.onToggleTheme,
    required this.onReset,
  });

  final AppColors colors;
  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final dark = themeMode == ThemeMode.dark;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rendering Playground',
                style: TextStyle(
                  color: colors.text,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Markdown document tuning',
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Reset tuning',
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded),
          ),
          IconButton(
            tooltip: dark ? 'Switch to light mode' : 'Switch to dark mode',
            onPressed: onToggleTheme,
            icon: Icon(dark ? Icons.light_mode : Icons.dark_mode),
          ),
        ],
      ),
    );
  }
}

class _ControlsPane extends StatelessWidget {
  const _ControlsPane({
    required this.colors,
    required this.scrollController,
    required this.readOnly,
    required this.showSource,
    required this.includeBlockOnlyShowcase,
    required this.compactReader,
    required this.centerContent,
    required this.maxContentWidth,
    required this.horizontalPadding,
    required this.verticalPadding,
    required this.paragraphSize,
    required this.paragraphHeight,
    required this.listIndentWidth,
    required this.listMarkerWidth,
    required this.bulletMarkerY,
    required this.numberMarkerY,
    required this.todoMarkerY,
    required this.tableTextSize,
    required this.codeTextSize,
    required this.onReadOnlyChanged,
    required this.onShowSourceChanged,
    required this.onIncludeBlockOnlyChanged,
    required this.onCompactReaderChanged,
    required this.onCenterContentChanged,
    required this.onMaxContentWidthChanged,
    required this.onHorizontalPaddingChanged,
    required this.onVerticalPaddingChanged,
    required this.onParagraphSizeChanged,
    required this.onParagraphHeightChanged,
    required this.onListIndentWidthChanged,
    required this.onListMarkerWidthChanged,
    required this.onBulletMarkerYChanged,
    required this.onNumberMarkerYChanged,
    required this.onTodoMarkerYChanged,
    required this.onTableTextSizeChanged,
    required this.onCodeTextSizeChanged,
  });

  final AppColors colors;
  final ScrollController scrollController;
  final bool readOnly;
  final bool showSource;
  final bool includeBlockOnlyShowcase;
  final bool compactReader;
  final bool centerContent;
  final double maxContentWidth;
  final double horizontalPadding;
  final double verticalPadding;
  final double paragraphSize;
  final double paragraphHeight;
  final double listIndentWidth;
  final double listMarkerWidth;
  final double bulletMarkerY;
  final double numberMarkerY;
  final double todoMarkerY;
  final double tableTextSize;
  final double codeTextSize;
  final ValueChanged<bool> onReadOnlyChanged;
  final ValueChanged<bool> onShowSourceChanged;
  final ValueChanged<bool> onIncludeBlockOnlyChanged;
  final ValueChanged<bool> onCompactReaderChanged;
  final ValueChanged<bool> onCenterContentChanged;
  final ValueChanged<double> onMaxContentWidthChanged;
  final ValueChanged<double> onHorizontalPaddingChanged;
  final ValueChanged<double> onVerticalPaddingChanged;
  final ValueChanged<double> onParagraphSizeChanged;
  final ValueChanged<double> onParagraphHeightChanged;
  final ValueChanged<double> onListIndentWidthChanged;
  final ValueChanged<double> onListMarkerWidthChanged;
  final ValueChanged<double> onBulletMarkerYChanged;
  final ValueChanged<double> onNumberMarkerYChanged;
  final ValueChanged<double> onTodoMarkerYChanged;
  final ValueChanged<double> onTableTextSizeChanged;
  final ValueChanged<double> onCodeTextSizeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: colors.surface,
      child: Scrollbar(
        controller: scrollController,
        child: ListView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
          children: [
            _SwitchTile(
              label: 'Read only',
              value: readOnly,
              onChanged: onReadOnlyChanged,
            ),
            _SwitchTile(
              label: 'Source pane',
              value: showSource,
              onChanged: onShowSourceChanged,
            ),
            _SwitchTile(
              label: 'Block-only blocks',
              value: includeBlockOnlyShowcase,
              onChanged: onIncludeBlockOnlyChanged,
            ),
            _SwitchTile(
              label: 'Compact reader',
              value: compactReader,
              onChanged: onCompactReaderChanged,
            ),
            _SwitchTile(
              label: 'Center content',
              value: centerContent,
              onChanged: onCenterContentChanged,
            ),
            _ControlGroup(
              title: 'Layout',
              children: [
                _TuningSlider(
                  label: 'Content width',
                  value: maxContentWidth,
                  min: 640,
                  max: 1320,
                  divisions: 34,
                  onChanged: onMaxContentWidthChanged,
                ),
                _TuningSlider(
                  label: 'Horizontal padding',
                  value: horizontalPadding,
                  min: 12,
                  max: 72,
                  divisions: 30,
                  onChanged: onHorizontalPaddingChanged,
                ),
                _TuningSlider(
                  label: 'Vertical padding',
                  value: verticalPadding,
                  min: 8,
                  max: 64,
                  divisions: 28,
                  onChanged: onVerticalPaddingChanged,
                ),
              ],
            ),
            _ControlGroup(
              title: 'Typography',
              children: [
                _TuningSlider(
                  label: 'Paragraph size',
                  value: paragraphSize,
                  min: 13,
                  max: 20,
                  divisions: 28,
                  onChanged: onParagraphSizeChanged,
                ),
                _TuningSlider(
                  label: 'Line height',
                  value: paragraphHeight,
                  min: 1.20,
                  max: 1.90,
                  divisions: 35,
                  decimals: 2,
                  onChanged: onParagraphHeightChanged,
                ),
              ],
            ),
            _ControlGroup(
              title: 'Lists',
              children: [
                _TuningSlider(
                  label: 'Indent width',
                  value: listIndentWidth,
                  min: 16,
                  max: 52,
                  divisions: 36,
                  onChanged: onListIndentWidthChanged,
                ),
                _TuningSlider(
                  label: 'Marker width',
                  value: listMarkerWidth,
                  min: 18,
                  max: 46,
                  divisions: 28,
                  onChanged: onListMarkerWidthChanged,
                ),
                _TuningSlider(
                  label: 'Bullet marker Y',
                  value: bulletMarkerY,
                  min: -6,
                  max: 8,
                  divisions: 56,
                  decimals: 2,
                  onChanged: onBulletMarkerYChanged,
                ),
                _TuningSlider(
                  label: 'Number marker Y',
                  value: numberMarkerY,
                  min: -6,
                  max: 8,
                  divisions: 56,
                  decimals: 2,
                  onChanged: onNumberMarkerYChanged,
                ),
                _TuningSlider(
                  label: 'Todo marker Y',
                  value: todoMarkerY,
                  min: -4,
                  max: 10,
                  divisions: 56,
                  decimals: 2,
                  onChanged: onTodoMarkerYChanged,
                ),
              ],
            ),
            _ControlGroup(
              title: 'Blocks',
              children: [
                _TuningSlider(
                  label: 'Table text',
                  value: tableTextSize,
                  min: 12,
                  max: 18,
                  divisions: 24,
                  onChanged: onTableTextSizeChanged,
                ),
                _TuningSlider(
                  label: 'Code text',
                  value: codeTextSize,
                  min: 11,
                  max: 17,
                  divisions: 24,
                  onChanged: onCodeTextSizeChanged,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewPane extends StatelessWidget {
  const _PreviewPane({
    required this.colors,
    required this.markdownTheme,
    required this.controller,
    required this.readOnly,
  });

  final AppColors colors;
  final MarkdownDocumentThemeData markdownTheme;
  final BlockController controller;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final alignment =
        markdownTheme.contentAlignment ==
            MarkdownDocumentContentAlignment.centered
        ? Alignment.topCenter
        : Alignment.topLeft;
    return ColoredBox(
      color: colors.background,
      child: Align(
        alignment: alignment,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: markdownTheme.maxContentWidth),
          child: MarkdownDocumentTheme(
            data: markdownTheme,
            child: BlockEditorWidget(
              controller: controller,
              readOnly: readOnly,
              variables: _RenderingPlaygroundSectionState._variables,
              padding: markdownTheme.pagePadding,
            ),
          ),
        ),
      ),
    );
  }
}

class _SourcePane extends StatelessWidget {
  const _SourcePane({
    required this.colors,
    required this.controller,
    required this.visible,
    required this.onChanged,
  });

  final AppColors colors;
  final TextEditingController controller;
  final bool visible;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    return Container(
      color: colors.surface,
      padding: const EdgeInsets.all(14),
      child: ValueListenableBuilder<TextEditingValue>(
        valueListenable: controller,
        builder: (context, value, _) {
          final report = BlockMarkdownCodec.inspect(value.text);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _FidelitySummary(colors: colors, report: report),
              const SizedBox(height: 10),
              Expanded(
                child: TextField(
                  controller: controller,
                  expands: true,
                  maxLines: null,
                  minLines: null,
                  onChanged: onChanged,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.45,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Markdown source',
                    alignLabelWithHint: true,
                    fillColor: colors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _FidelitySummary extends StatelessWidget {
  const _FidelitySummary({required this.colors, required this.report});

  final AppColors colors;
  final BlockMarkdownFidelityReport report;

  @override
  Widget build(BuildContext context) {
    final statusColor = report.roundTripsExactly
        ? const Color(0xFF22C55E)
        : const Color(0xFFF59E0B);
    final statusLabel = report.roundTripsExactly
        ? report.normalizedRoundTripsExactly
              ? 'Fidelity: exact round trip'
              : 'Fidelity: source preserved'
        : 'Fidelity: normalized output';
    final rawKinds = report.rawMarkdownKinds.entries
        .map((entry) => '${entry.key} ${entry.value}')
        .join('  ');
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.background,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: DefaultTextStyle(
          style: TextStyle(color: colors.textMuted, fontSize: 11, height: 1.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: colors.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Blocks ${report.blockCount}  Raw ${report.rawMarkdownBlockCount}'
                '  Source ${report.preservedSourceBlockCount}/${report.sourceBackedBlockCount}'
                '${report.changedSourceBlockCount == 0 ? '' : '  Changed ${report.changedSourceBlockCount}'}'
                '${rawKinds.isEmpty ? '' : '  $rawKinds'}',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlGroup extends StatelessWidget {
  const _ControlGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: TextStyle(
              color: colors.text,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }
}

class _SwitchTile extends StatelessWidget {
  const _SwitchTile({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(color: colors.text, fontSize: 13),
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _TuningSlider extends StatelessWidget {
  const _TuningSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.decimals = 1,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final int divisions;
  final ValueChanged<double> onChanged;
  final int decimals;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(color: colors.textMuted, fontSize: 12),
                ),
              ),
              Text(
                value.toStringAsFixed(decimals),
                style: TextStyle(
                  color: colors.text,
                  fontSize: 12,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

const _playgroundMarkdown = r'''
---
title: Rendering playground
status: tuning
aliases:
  - markdown-lab
  - codeforge-playground
tags:
  - codeforge
  - markdown
  - block-editor
---

# Markdown rendering playground

Paragraphs can mix **bold**, *italic*, ***bold italic***, ~~strikethrough~~,
==highlight==, `inline code`, [[wikilinks]], [[Target note|wiki aliases]],
![[embedded-note]], [external links](https://example.com), {{authorName}},
{{packageName}}, #tags, #nested/tag-paths, and footnotes[^render].

This second paragraph is intentionally long. It is here to inspect line height,
selection boxes, cursor rhythm, link color, inline-code background, highlight
treatment, and how the renderer handles enough text to wrap several times in a
normal CodeForge-sized document pane.

## Heading scale

# H1 top-level document title
## H2 major section
### H3 subsection
#### H4 small subsection
##### H5 compact heading
###### H6 eyebrow heading

## Lists

1. Numbered item that should align tightly with the first line.
2. Wrapped numbered item with enough content to cross onto a second visual line
   so marker position, marker width, and text rhythm can be tuned together.
   1. Nested number item.
   2. Another nested number item.
      1. Third-level number item.
      2. Third-level number item with `inline code`.
3. Final numbered item.
4. Numbered item with **bold**, *italic*, ==highlight==, and [inline link](https://example.com/list).

- Bullet item.
  - Nested bullet item with **bold** text.
    - Third-level bullet item.
      - Fourth-level bullet item for deep indent rhythm.
- Bullet item with `inline code`, [[wiki link]], and #tag.
- Bullet item using a wrapped line that should maintain a clear hanging indent
  when it crosses onto the next visual line in a narrow editor pane.
- [x] Completed task.
  - [ ] Nested task under the completed task.
    - [x] Third-level completed nested task.
      - [ ] Fourth-level nested task.
- [ ] Open task with wrapped text that makes checkbox alignment obvious across
  multiple lines.
- [ ] Task with **bold**, *italic*, `inline code`, and [link](https://example.com/task).

## Mixed list stress

1. Ordered parent
   - Bullet child under ordered parent
     - [ ] Todo grandchild under bullet child
   1. Ordered child under ordered parent
2. Second ordered parent
   - Bullet child with a long sentence that should wrap with the marker staying
     visually attached to the first line while subsequent lines hang correctly.

## Quotes

> Single-line quote with **bold** text and `inline code`.

> Multi-line quote first line.
> Multi-line quote second line with [a link](https://example.com/quote).
>
> Final quote line after a blank quote spacer.

## Callouts

> [!note] Callout
> Callouts should feel integrated with document rhythm and table/code spacing.

> [!tip] Tip callout
> Use this surface to tune Markdown render tokens before moving the values into
> CodeForge or package defaults.

> [!warning]+ Expanded warning
> Warning callouts should be visible without feeling like app error banners.

> [!danger]- Collapsed danger
> Danger/error callouts need strong contrast but still belong to the document.

> [!success] Done state
> Success callouts show the green/success tone.

> [!question] Open question
> Question/help variants currently map through the same callout tone resolver.

---

## Tables

| Area | Alignment | Status |
|:-----|:---------:|------:|
| Lists | marker Y and indent width | **tuning** |
| Tables | cell wrapping and controls | ready |
| Preview blocks | Mermaid and math | planned |
| Inline styles | `code`, **bold**, ==mark== | supported |

| Compact | Count |
| --- | ---: |
| Headings | 6 |
| Lists | 4 |
| Tables | 3 |

| Long column | Centered status | Right metric |
| --- | :---: | ---: |
| This row intentionally contains a long paragraph-like value so table wrapping, row height, resize handles, and text alignment can all be inspected together. | **active** | 98% |
| Escaped pipe value A \| B should stay in one cell. | pending | 12 |
| Manual line break<br>inside a table cell should render as multiple lines. | review | 3 |

| Keyboard | macOS | Windows/Linux |
| --- | --- | --- |
| Copy | Cmd+C | Ctrl+C |
| Paste | Cmd+V | Ctrl+V |
| Bold | Cmd+B | Ctrl+B |

## Table inline rendering matrix

| Case | Markdown source | Expected visual result |
| --- | --- | --- |
| Bold | **bold text** | bold text should be heavy |
| Italic | *italic text* | italic text should be slanted |
| Bold italic | ***bold italic text*** | bold italic should combine styles |
| Strike | ~~struck text~~ | struck text should show line-through |
| Highlight | ==highlighted text== | highlighted text should have a mark background |
| Inline code | `final value = 42` | code should use monospace styling |
| Link | [Docs](https://example.com/docs) | link label should be blue and readable |
| Wiki | [[Target page|alias]] | alias should render without wiki brackets |
| Embed | ![[Embedded page]] | embed should render as an inline embed token |
| Footnote | footnote marker[^table-matrix] | footnote marker should be compact |
| Variable | {{version}} | variable token should use the variable style |
| Escaped pipe | A \| B | escaped pipe should stay inside the cell |
| Line break | first<br>second | text should split across two lines |
| Mixed | **bold**, *italic*, ==mark==, `code`, [link](https://example.com) | all styles should render in one cell |

## Links, images, and references

![Wide image](https://picsum.photos/seed/markdown-source-wide/1200/420)

[Standalone link block](https://example.com/standalone-link)

Reference-style links should preserve the definition below even when not fully
rendered as a first-class inline link: [reference link][docs].

[[Daily note]]
[[Daily note|Aliased daily note]]
![[embedded-canvas]]

## Inline styling matrix

| Syntax | Example |
| --- | --- |
| Bold | **bold text** |
| Italic | *italic text* |
| Bold italic | ***bold italic text*** |
| Strike | ~~struck text~~ |
| Highlight | ==highlighted text== |
| Inline code | `final value = 42` |
| Wiki | [[Target page|alias]] |
| Embed | ![[Embedded page]] |
| Footnote | footnote marker[^matrix] |
| Variable | {{version}} |
| Tag | #markdown-matrix |

## Mermaid

```mermaid
graph TD
  Markdown[Markdown source] --> Blocks[Block document]
  Blocks --> Preview[Rendering playground]
  Preview --> Tokens[MarkdownDocumentTheme tokens]
```

```mermaid
sequenceDiagram
  participant C as CodeForge
  participant B as Block editor
  participant M as Markdown source
  C->>B: open .md as blocks
  B->>M: encode on save
  M-->>B: decode on mode switch
```

## Math

$$
score = fidelity * usability
$$

$$E = mc^2$$

$$
\frac{\partial}{\partial x}(x^2 + y^2) = 2x
$$

## Code

```dart
final controller = BlockController(
  document: BlockMarkdownCodec.decode(markdown),
);
```

```typescript
export function applyMarkdownPreset(tokens: MarkdownTokens) {
  return {
    contentWidth: tokens.contentWidth,
    listMarkerY: tokens.numberedListMarkerVerticalOffset,
  };
}
```

```json
{
  "editor": "codeforge",
  "mode": "markdown-blocks",
  "features": ["tables", "callouts", "math", "mermaid"]
}
```

```bash
flutter run -d macos
flutter test test/rendering_playground_section_test.dart
```

```python
def score_rendering(fidelity: float, usability: float) -> float:
    return fidelity * 0.55 + usability * 0.45
```

## Raw source

<aside class="source-preserved">
Unsupported Markdown should stay visible instead of silently disappearing.
</aside>

<!-- HTML comment raw block should survive decode/encode. -->

%%
Obsidian-style comment block preserved as raw Markdown.
%%

::: warning
Container/directive syntax is preserved as raw Markdown today.
:::

<details>
<summary>Raw HTML details block</summary>

Nested raw HTML content should remain visible in the editor.

</details>

[^matrix]: Footnote from the inline styling matrix.
[^render]: Footnote definitions are preserved as raw Markdown.

[docs]: https://example.com/reference-docs

[^table-matrix]: Footnote used by the table rendering matrix.

^block-id-anchor
''';
