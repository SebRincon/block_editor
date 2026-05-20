import 'dart:async';
import 'dart:convert';

import 'package:block_editor/block_editor.dart';
import 'package:flutter/material.dart';

import '../shell/export_modal.dart';
import '../theme/app_theme.dart';
import '../utils/markdown_exporter.dart';
import 'editor_top_bar.dart';
import 'tag_strip.dart';

/// The main editing surface section.
///
/// Owns a [BlockController] seeded with a starter document. Mounts a live
/// [BlockEditorWidget] and wires up the top bar, export modals, read-only
/// toggle, document clear, and tag strip. The [themeMode] and [onToggleTheme]
/// are forwarded from [App] so the theme toggle button works from within the
/// editor surface.
class EditorSection extends StatefulWidget {
  /// Creates an [EditorSection].
  const EditorSection({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<EditorSection> createState() => _EditorSectionState();
}

class _EditorSectionState extends State<EditorSection> {
  late final BlockController _controller;
  late final TextEditingController _titleController;
  late final StreamSubscription<DocumentChange> _changesSub;
  bool _readOnly = false;
  Set<String> _tags = {};

  static const Map<String, String> _variables = {
    'authorName': 'Stanly Silas',
    'packageName': 'block_editor',
    'version': '0.1.0',
  };

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: 'Getting started');
    _controller = BlockController(document: _starterDocument());
    _tags = _controller.tags;
    _changesSub = _controller.changes.listen((_) {
      if (mounted) setState(() => _tags = _controller.tags);
    });
  }

  @override
  void dispose() {
    _changesSub.cancel();
    _controller.dispose();
    _titleController.dispose();
    super.dispose();
  }

  BlockDocument _starterDocument() {
    final decoded = BlockMarkdownCodec.decode(_editableStarterMarkdown);
    return BlockDocument([...decoded.blocks, ..._editableBlockShowcase()]);
  }

  List<BlockNode> _editableBlockShowcase() {
    return [
      BlockNode(type: BlockTypes.divider),
      BlockNode(
        type: BlockTypes.heading2,
        delta: TextDelta.fromPlainText('Editable manual block variants'),
      ),
      BlockNode(
        type: BlockTypes.paragraph,
        delta: BlockMarkdownCodec.parseInline(
          'These blocks are created directly from BlockNode values, so the '
          'main editable editor exercises plugin renderers that may not appear '
          'in plain Markdown. Try editing, duplicating, moving, copying, and '
          'exporting them.',
        ),
      ),
      BlockNode(
        type: BlockTypes.heading3,
        delta: TextDelta.fromPlainText('Inline and list blocks'),
      ),
      BlockNode(
        type: BlockTypes.paragraph,
        delta: BlockMarkdownCodec.parseInline(
          'Manual paragraph: **bold**, *italic*, ***bold italic***, '
          '~~strike~~, ==highlight==, `inline code`, [link](https://example.com), '
          '[[wiki alias|Wiki page]], ![[Embedded block]], {{version}}, and '
          '#manual-editor-example.',
        ),
      ),
      BlockNode(
        type: BlockTypes.bulletList,
        delta: BlockMarkdownCodec.parseInline('Manual bullet at depth 0.'),
      ),
      BlockNode(
        type: BlockTypes.bulletList,
        attributes: const {'indent': 1},
        delta: BlockMarkdownCodec.parseInline('Manual bullet at depth 1.'),
      ),
      BlockNode(
        type: BlockTypes.bulletList,
        attributes: const {'indent': 2},
        delta: BlockMarkdownCodec.parseInline(
          'Manual bullet at depth 2 with enough text to wrap and expose hanging indent behavior.',
        ),
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
          'Manual numbered item at depth 1 for number baseline checks.',
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
          'Manual quote block with **formatted text**.\n'
          'Second quote line for multiline rhythm.',
        ),
      ),
      BlockNode(
        type: BlockTypes.callout,
        attributes: const {'variant': 'info', 'title': 'Manual info callout'},
        delta: BlockMarkdownCodec.parseInline(
          'Callout block created directly from attributes.',
        ),
      ),
      BlockNode(
        type: BlockTypes.callout,
        attributes: const {
          'variant': 'warning',
          'title': 'Manual warning callout',
        },
        delta: BlockMarkdownCodec.parseInline(
          'Warning callout variant for tone and spacing checks.',
        ),
      ),
      BlockNode(
        type: BlockTypes.table,
        attributes: const {
          'headers': ['Block', 'Editable variant', 'Notes'],
          'alignments': ['left', 'center', 'right'],
          'rows': [
            ['Paragraph', 'Rich inline', 'cursor and selection'],
            ['Inline markdown', '**bold** and *italic*', 'renders in cells'],
            ['Highlight/code', '==mark== plus `code`', 'mixed spans'],
            [
              'Links',
              '[Docs](https://example.com) and [[Page|alias]]',
              'labels only',
            ],
            ['Todo', 'Nested', 'checkbox marker Y'],
            ['Table', 'Resizable', 'row and column controls'],
            ['Code', 'Source-backed', 'language label'],
          ],
        },
      ),
      BlockNode(
        type: BlockTypes.code,
        attributes: const {'language': 'typescript'},
        delta: TextDelta.fromPlainText(
          '''
type EditableBlock = {
  id: string;
  type: string;
  editable: boolean;
};
'''
              .trim(),
        ),
      ),
      BlockNode(
        type: BlockTypes.math,
        delta: TextDelta.fromPlainText(
          'editing\\ quality = fidelity + keyboard\\ ergonomics',
        ),
      ),
      BlockNode(
        type: BlockTypes.mermaid,
        delta: TextDelta.fromPlainText(
          '''
flowchart LR
  User --> Editor
  Editor --> Blocks
  Blocks --> Markdown
'''
              .trim(),
        ),
      ),
      BlockNode(
        type: BlockTypes.rawMarkdown,
        delta: TextDelta.fromPlainText(
          '''
::: editable-custom-container
Manual raw Markdown block inside the editable starter document.
:::
'''
              .trim(),
        ),
      ),
      BlockNode(type: BlockTypes.divider),
      BlockNode(
        type: BlockTypes.heading3,
        delta: TextDelta.fromPlainText('Editable media and reference cards'),
      ),
      BlockNode(
        type: BlockTypes.image,
        attributes: const {
          'source': 'network',
          'url': 'https://picsum.photos/seed/editor-editable-image/1000/420',
          'alt': 'Editable editor sample image',
        },
      ),
      BlockNode(
        type: BlockTypes.video,
        attributes: const {
          'source': 'network',
          'url': 'https://example.com/editor-demo-video.mp4',
        },
      ),
      BlockNode(
        type: BlockTypes.youtube,
        attributes: const {'videoId': 'aqz-KE-bpKQ'},
      ),
      BlockNode(
        type: BlockTypes.file,
        attributes: const {
          'filename': 'editable-editor-fixture.md',
          'size': '24 KB',
          'path':
              '/Users/sebastian/Developer/vibe-coder/vibe_coder/deps/v2/vibecode_chat_ui/plan.md',
        },
      ),
      BlockNode(
        type: BlockTypes.link,
        attributes: const {
          'displayText': 'Block editor Markdown docs',
          'title': 'Block editor Markdown docs',
          'url': 'https://example.com/block-editor-markdown',
        },
      ),
    ];
  }

  void _exportJson() {
    final json = const JsonEncoder.withIndent(
      '  ',
    ).convert(_controller.document.toJson());
    ExportModal.show(context, title: 'Export JSON', content: json);
  }

  void _exportMarkdown() {
    final markdown = MarkdownExporter.export(_controller.document);
    ExportModal.show(context, title: 'Export Markdown', content: markdown);
  }

  void _toggleReadOnly() {
    setState(() => _readOnly = !_readOnly);
  }

  void _clearDocument() {
    showDialog<void>(
      context: context,
      builder: (ctx) => _ClearConfirmDialog(
        onConfirm: () {
          _controller.replaceDocument(BlockDocument.empty());
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        EditorTopBar(
          titleController: _titleController,
          readOnly: _readOnly,
          themeMode: widget.themeMode,
          onExportJson: _exportJson,
          onExportMarkdown: _exportMarkdown,
          onToggleReadOnly: _toggleReadOnly,
          onClear: _clearDocument,
          onToggleTheme: widget.onToggleTheme,
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final hPad = (constraints.maxWidth * 0.08).clamp(16.0, 64.0);
              return BlockEditorWidget(
                controller: _controller,
                readOnly: _readOnly,
                variables: _variables,
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 32),
              );
            },
          ),
        ),
        TagStrip(tags: _tags),
      ],
    );
  }
}

const _editableStarterMarkdown = r'''
# Welcome to {{packageName}}

Built by {{authorName}}. Version {{version}}. This first tab is intentionally
seeded with a broad editable document so keyboard behavior, cursor placement,
block controls, slash commands, copy/paste, export, and Markdown fidelity can be
tested without leaving the editor surface. Tag strip seed: #gettingstarted
#editable-fixture #markdown-lab.

Try the slash command menu by typing `/` anywhere in an empty paragraph. Try
`Cmd+B`, `Cmd+I`, `Cmd+U`, copy, paste, block duplication, table editing, and
drag/reorder controls on the examples below.

## Inline text variations

Plain text, **bold text**, *italic text*, ***bold italic text***,
~~strikethrough text~~, ==highlighted text==, `inline code`, [inline link](https://example.com),
[[Wiki target]], [[Wiki target|wiki alias]], ![[Embedded target]], {{authorName}},
{{packageName}}, #inline-tag, #nested/tag, and footnote markers[^starter].

This paragraph is intentionally long so the editable cursor, wrapped selection
rectangles, word movement, visual-line movement, and line-height rhythm can all
be checked inside a normal CodeForge-width editor pane while the document is in
active editing mode.

## Heading variants

# Editable H1
## Editable H2
### Editable H3
#### Editable H4
##### Editable H5
###### Editable H6

## Ordered lists

1. First ordered item.
2. Second ordered item with enough text to wrap across multiple visual lines so
   the hanging indent and number marker baseline can be inspected.
   1. Nested ordered item.
   2. Nested ordered item with `inline code`.
      1. Third-level ordered item.
      2. Third-level ordered item with **bold** text.
3. Final ordered item.

## Bullet lists

- First bullet item.
  - Second-level bullet item.
    - Third-level bullet item.
      - Fourth-level bullet item.
- Bullet with **bold**, *italic*, ==highlight==, `inline code`, [[wiki link]], and #tag.
- Wrapped bullet item that should maintain a clean hanging indent after it
  wraps onto another visual line in the editable editor surface.

## Todo lists

- [x] Completed root task.
  - [ ] Nested open task.
    - [x] Nested completed task.
      - [ ] Deep nested open task.
- [ ] Open task with enough text to wrap onto a second visual line so checkbox
  marker alignment can be tuned.
- [ ] Task with **bold**, *italic*, `inline code`, and [task link](https://example.com/task).

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

> [!note] Editable note
> This note callout should feel like part of the document, not a heavy app alert.

> [!tip] Editable tip
> Use this as the main surface for tuning authoring micro-interactions.

> [!warning]+ Expanded warning
> Warning callouts need strong enough tone without overwhelming the editor.

> [!danger]- Collapsed danger
> Danger/error variants should keep contrast and spacing stable.

> [!success] Success state
> Success callout variant for green tone checks.

> [!question] Open question
> Question/help variants exercise the callout tone resolver.

---

## Editable tables

| Area | Alignment | Status |
|:-----|:---------:|------:|
| Lists | marker Y and indent width | **tuning** |
| Tables | cell editing and controls | ready |
| Code | editable source blocks | testing |
| Preview blocks | Mermaid and math | planned |

| Compact | Count |
| --- | ---: |
| Headings | 6 |
| Lists | 4 |
| Tables | 4 |

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
| Italic | Cmd+I | Ctrl+I |

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

## Images, links, wiki links, embeds

![Editable sample image](https://picsum.photos/seed/editor-source-image/1200/420)

[Standalone link block](https://example.com/standalone-link)

Reference-style links preserve their definitions: [reference link][docs].

[[Daily note]]
[[Daily note|Aliased daily note]]
![[embedded-canvas]]

## Mermaid diagrams

```mermaid
graph TD
  Editor[Editable editor] --> Blocks[Block document]
  Blocks --> Markdown[Markdown export]
  Blocks --> UI[Block UI]
```

```mermaid
sequenceDiagram
  participant User
  participant Editor
  participant Codec
  User->>Editor: edit blocks
  Editor->>Codec: export Markdown
  Codec-->>Editor: decode Markdown
```

## Math blocks

$$
score = fidelity * usability
$$

$$E = mc^2$$

$$
\frac{\partial}{\partial x}(x^2 + y^2) = 2x
$$

## Code blocks

```dart
final controller = BlockController(
  document: BlockMarkdownCodec.decode(markdown),
);
```

```typescript
export function applyEditorPreset(tokens: MarkdownTokens) {
  return {
    contentWidth: tokens.contentWidth,
    listMarkerY: tokens.numberedListMarkerVerticalOffset,
  };
}
```

```json
{
  "surface": "editor",
  "mode": "editable-blocks",
  "features": ["tables", "callouts", "math", "mermaid", "raw"]
}
```

```bash
flutter run -d macos
flutter test test/editor_section_test.dart
```

```python
def score_editor(fidelity: float, ergonomics: float) -> float:
    return fidelity * 0.5 + ergonomics * 0.5
```

## Raw Markdown preservation

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

[^starter]: Footnote definition preserved as raw Markdown.

[docs]: https://example.com/reference-docs

[^table-matrix]: Footnote used by the table rendering matrix.

^editable-block-id-anchor
''';

class _ClearConfirmDialog extends StatelessWidget {
  const _ClearConfirmDialog({required this.onConfirm});
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return AlertDialog(
      title: const Text('Clear document?'),
      content: const Text(
        'All blocks will be removed. This cannot be undone once the undo stack is cleared.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Cancel', style: TextStyle(color: colors.textMuted)),
        ),
        TextButton(
          onPressed: onConfirm,
          child: const Text(
            'Clear',
            style: TextStyle(color: Color(0xFFEF4444)),
          ),
        ),
      ],
    );
  }
}
