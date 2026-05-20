# Markdown WYSIWYG Integration Notes

This document captures the current state of the `block_editor` work intended for CodeForge's Markdown editing mode. The target behavior is:

- Markdown files can open as block-based WYSIWYG documents.
- The source of truth can still round-trip back to Markdown.
- The user can toggle between block editing and raw Markdown editing in the host editor.
- The editor UI can be embedded into the same shadcn-aligned chrome used by the rest of the app.

## Current Architecture

`BlockEditorWidget` remains the main editor surface. It is controlled by a caller-owned `BlockController`, so CodeForge can create a controller per opened Markdown document and dispose it when the editor tab closes.

Markdown conversion is handled by `BlockMarkdownCodec`:

- `BlockMarkdownCodec.decode(markdown)` produces a `BlockDocument`.
- `BlockMarkdownCodec.encode(document)` produces Markdown.
- Markdown-specific features are mapped onto built-in block types instead of being stored as opaque raw strings where possible.

The current Markdown block mappings are:

| Markdown | Block representation |
| --- | --- |
| Paragraph text | `BlockTypes.paragraph` with `TextDelta` |
| `#`, `##`, `###` | `heading1`, `heading2`, `heading3` |
| `- item` / `* item` | `bulletList` |
| `1. item` | `numberedList` |
| `- [ ] task` / `- [x] task` | `todo` with `checked` attribute |
| `>` quote blocks | `quote` |
| `---` / `***` / `___` | `divider` |
| Fenced code blocks | `code` with `language` attribute and code stored in `delta` |
| GitHub-style pipe tables | `table` with `headers`, `rows`, and optional `alignments` attributes |
| Images and links | `image` / `link` blocks where they fit the built-in model |

Inline Markdown currently supports bold, italic, bold+italic, strikethrough, inline code, links, variables, and tags through `TextDelta` operations.

## CodeForge Integration Contract

CodeForge should treat the block editor as a Markdown view mode rather than a separate document format.

Recommended host flow:

1. On opening a `.md` file, keep the original raw Markdown string in the CodeForge document model.
2. Create a `BlockController(document: BlockMarkdownCodec.decode(markdown))`.
3. Render `BlockEditorWidget(controller: controller)` inside the Markdown editor pane.
4. When saving from block mode, call `BlockMarkdownCodec.encode(controller.document)`.
5. When toggling to raw Markdown mode, encode the current block document first.
6. When toggling back to block mode, decode the raw Markdown buffer into a fresh `BlockDocument` or replace the current controller document.

The safest toggle model is one active editing surface at a time:

- Raw Markdown mode owns the raw text buffer and CodeForge text editor shortcuts.
- Block mode owns the `BlockController`, selection, IME, toolbar, slash menu, table controls, and block controls.
- Toggling modes performs an explicit Markdown encode/decode handoff.

This avoids two independent editors racing to mutate the same file.

## UI Ownership

`BlockEditorWidget.showFormattingToolbar` allows the host to decide whether the package renders its own floating toolbar. This matters for CodeForge because the desired UI has the formatting controls pinned in host chrome above the editor.

Use:

```dart
BlockEditorWidget(
  controller: markdownController,
  showFormattingToolbar: false,
)
```

Then render `FormattingToolbarControls` from host UI where CodeForge wants the pinned controls. That keeps the editing behavior inside `block_editor` while letting the app own final placement and visual alignment.

The block editor should continue to consume the same shared shadcn Flutter dependency as the rest of the app. Package-local duplicate UI libraries should be avoided so controls, menus, colors, surfaces, border radii, and icon treatment stay consistent.

The block editor package and its example app now both point at the shared
`/Users/sebastian/Developer/vibe-coder/vibe_coder/deps/v2/shadcn_flutter`
dependency. The example app uses the same top-level styling shape as
`mock_ui`: `ShadcnApp`, VS Code dark color scheme, `radius: 0.5`, and
`Typography.geist()`. A Material theme adapter remains only for legacy example
widgets; `BlockEditorThemeData` reads the shadcn theme first.

## Rendering Playground

The example app has two complementary Markdown surfaces:

- **Editor**: an editable authoring matrix for cursor movement, selection,
  copy/paste, keyboard formatting, slash commands, block controls, table
  editing, media/reference cards, export, and read-only toggling.
- **Playground**: a rendering-token matrix for tuning document width, spacing,
  typography, list marker alignment, table text, code text, source visibility,
  and block-only showcase visibility.

The example app includes a dedicated Playground section for Markdown rendering
tuning:

```bash
cd example
flutter run -d macos
```

Use the **Playground** navigation item to inspect the real
`BlockEditorWidget`/`BlockMarkdownCodec` rendering path with a dense Markdown
fixture and optional block-only components.

The Playground opens on the `mock_ui` dark theme by default. This makes it the
right surface for tuning Markdown UI/UX before moving values back into package
defaults or CodeForge host overrides.

The default fixture is intentionally a renderer matrix, not a small demo. It
includes frontmatter, all heading levels, long paragraphs, rich inline spans,
nested numbers, bullets, todos, quotes, several callout variants, compact and
wide tables, escaped pipes, table line breaks, image/link/reference examples,
wiki links, embeds, Mermaid, math, multi-language code fences, raw Markdown
fallbacks, footnotes, block anchors, and an appended manual BlockNode matrix
for media/reference card renderers.

The playground exposes live controls for:

- readable content width
- horizontal and vertical document padding
- paragraph size and line height
- list indent width
- list marker width
- bullet, numbered, and todo marker vertical offsets
- table text size
- code text size
- read-only/editable mode
- source pane visibility
- block-only showcase visibility

The numbered-list marker baseline is now a Markdown document theme token:

```dart
MarkdownDocumentThemeData.defaults(context).copyWith(
  bulletListMarkerVerticalOffset: -1.5,
  numberedListMarkerVerticalOffset: -2.0,
)
```

Hosts can wrap any editor subtree in `MarkdownDocumentTheme` to override these
tokens without forking the built-in list widgets.

Bullet list markers are drawn Flutter shapes rather than text glyphs. This
keeps the marker centered against the first text line across font stacks and
avoids symbol/emoji-style rendering differences. Nested bullet levels use
inverted markers: level 1 is a hollow circle, level 2 is a hollow square, and
the pattern repeats for deeper indentation.

## Keyboard And Clipboard Behavior

The editor now has a command routing layer and a widget-level clipboard layer.

Command routing handles synchronous editor commands:

- Undo / redo
- Select all
- Bold / italic / underline
- Backspace / delete
- Enter / tab
- Character insertion
- Arrow navigation
- Shift-arrow selection
- Word, line, visual-line, and document movement

Clipboard handling lives in `BlockEditorWidget` because paste needs async platform clipboard access:

- `Cmd/Ctrl+C` copies expanded selection text.
- `Cmd/Ctrl+X` copies and deletes selection immediately.
- `Cmd/Ctrl+V` pastes plain text at the current cursor.
- Platform selectors `copy:`, `cut:`, and `paste:` use the same path.

Paste is currently plain-text-first. Multi-line pasted text is split into block boundaries by inserting newlines through editor operations.

## Tables

Tables are represented as block attributes:

- `headers`: `List<String>`
- `rows`: `List<List<String>>`
- `alignments`: optional `List<String>` with `left`, `right`, `center`, or empty values

The table UI supports:

- Text entry into header and body cells.
- Hover-scoped row and column controls.
- Small add/delete controls positioned outside the editable cells.
- Immediate state updates for row and column insertion/deletion.
- Inline Markdown preview for inactive cells so bold, italic, links, code, and
  line breaks read like rendered Markdown while the focused cell remains an
  editable text field.
- Column and row resize handles anchored to the actual table grid edge rather
  than the padded text area. Handles are available from every visible cell, not
  only edge cells.
- Resize handles only mutate size during an explicit primary-button drag.
  Wheel scrolling and trackpad pan/scroll gestures over a handle are ignored by
  the resize logic, so hovering an expand point cannot accidentally grow a row
  or column.
- Active/hovered cells use a subtle full-cell surface highlight instead of a
  thick colored border.
- Markdown encode/decode for GitHub-style pipe tables.

Current table constraints:

- Table cells are plain strings, not nested rich-text documents.
- Table editing is structural but not yet a full spreadsheet-like selection model.
- Keyboard navigation across cells is still basic.

## Block Controls

Blocks now have Notion-style controls:

- A small add control can insert a new paragraph below the current block.
- A block action handle opens block actions.
- The block menu can select an entire block.
- Existing block actions include delete, duplicate, turn into, move up, and move down.

This gives the Markdown WYSIWYG mode enough block-level manipulation for document editing, but it is not yet a full Notion clone. Drag, multi-block select, and command-menu workflows still need more polish before they feel complete.

## Selection, Cursor, And IME Notes

Selection and cursor behavior were tightened for block editing:

- Dragging across rendered text creates an expanded selection.
- Shift-arrow expands selection.
- Meta-arrow movement uses visual line boundaries when text wraps.
- Cursor placement uses shared text measurement logic for rendered spans.
- Embedded inputs, such as table cells, temporarily own text input focus so the root editor does not fight them.

Known remaining risk areas:

- Complex rich inline spans can still expose offset mapping edge cases.
- Very large Markdown documents may need batching and virtualization work.
- Code blocks use a lightweight syntax-highlighting overlay, but they are not
  TextMate/LSP-backed code editors.

## Code Blocks

Fenced Markdown code blocks decode into `BlockTypes.code` with:

- `attributes['language']` storing the fence language.
- `delta.plainText` storing the code content.

The renderer also supports legacy nodes that store code in `attributes['code']`.

The editable code/source fields explicitly opt out of ambient filled
`InputDecorationTheme` values. This keeps the shadcn/mock_ui input styling from
turning code, Mermaid, raw Markdown, and table text into heavy grey filled
controls inside document blocks.

Code blocks now render through a monospace, syntax-highlighted read/edit
hybrid. While focused, the text field remains the editing target and a
highlighted overlay supplies token color for comments, strings, numbers, and
common language keywords. In read-only mode the same highlighter feeds a
selectable rich text view.

Current limitations:

- Highlighting is lightweight and regex-token based, not a full parser.
- The code block is still a multiline text field, not a full CodeForge editor
  embed.
- Language switching currently emits an event and expects a host/plugin flow to complete the change.

The next code-block phase should decide whether this lightweight hybrid is
enough for Markdown authoring, or whether CodeForge should mount its existing
editor engine inside fenced code blocks for full TextMate/LSP behavior.

## Mermaid Blocks

Fenced `mermaid` blocks decode into `BlockTypes.mermaid` and round-trip as
Mermaid fences. The preview path now renders common `graph`/`flowchart` and
`sequenceDiagram` sources as lightweight Flutter-painted diagrams.

When a Mermaid block is being edited, the editor shows a split source/preview
layout on wide screens and a stacked source/preview layout on narrow screens.
Invalid or unsupported source stays visible and is surfaced as a readable
preview state rather than disappearing.

This is intentionally not a full Mermaid engine yet:

- Supported: simple node/edge flowcharts and participant/message sequence
  diagrams.
- Unsupported or complex syntax falls back to a readable source preview.
- The source is still the Markdown Mermaid text, so editing and export preserve
  the original fenced block.

## Math Blocks

Fenced or display math blocks render through `flutter_math_fork`. The editable
state mirrors Mermaid: the Markdown/LaTeX source remains the left or top editor,
and a live rendered preview stays visible beside or below it. Invalid LaTeX is
shown as an explicit error preview with the source retained.

Current math constraints:

- The package renders block math, not inline math spans inside regular
  paragraph text.
- The source is still Markdown/LaTeX text and round-trips through the block
  document.
- Advanced TeX packages/macros are limited by `flutter_math_fork`.

## Callouts

Callout blocks now have editable structure instead of a fixed rendered title:

- The title is an embedded field that emits `CalloutTitleChangedEvent`.
- The leading icon opens a small variant menu in editable mode.
- Variants currently map to `info`, `note`, `tip`, `success`, `warning`, and
  `error`.
- Variant changes emit `CalloutVariantChangedEvent` and are persisted into the
  block attributes by `BlockEditorWidget`.

The body remains regular rich Markdown content managed by the block delta. The
callout color/icon model is intentionally small for now so it stays aligned with
theme tokens rather than becoming a separate style system.

## Media And References

Image, file, link, video, and YouTube blocks were restyled to use the document
theme and shadcn-aligned tokens instead of hard-coded grey surfaces.

The current behavior is intentionally preview-first:

- Images preserve their natural aspect ratio inside max-width/max-height
  constraints. Failed images render as compact error cards with a tappable URL
  affordance.
- Link and file blocks render as compact clickable rows with theme-colored
  icons and URLs.
- Video and YouTube blocks render as constrained 16:9 preview cards with play
  affordances, not huge full-width placeholders.

Current media constraints:

- The package does not embed a full native video or YouTube player yet.
- Link opening is still event/callback based so CodeForge can own the actual
  navigation behavior.
- Broken network assets depend on the host callback if the app wants to open,
  retry, or inspect the failing URL.

## Testing Coverage Added

The current changes include focused coverage for:

- Markdown decode/encode including tables and fenced code.
- Command registry and keymap behavior.
- Arrow navigation and expanded selection shortcuts.
- Clipboard shortcuts for copy, cut, and paste.
- Formatting toolbar state and actions.
- Slash menu filtering and keyboard movement.
- Table row/column add and delete behavior.
- Table/editor/code embedded input styling against filled Material themes.
- Table resize, active-cell highlighting, inline Markdown preview, and
  optimistic structural updates.
- Trackpad pan/scroll regression coverage for table resize handles, plus
  positive coverage that primary mouse drags still resize rows and columns.
- Footnote marker measurement/rendering and list marker alignment.
- Callout title editing and variant events.
- Math and Mermaid source editing with live preview.
- Lightweight code syntax highlighting.
- Mermaid flowchart and sequence preview rendering.
- Block controls and action menu selection.
- Rich text rendering and cursor/selection behavior.

Useful focused verification commands:

```bash
flutter test test/markdown/block_markdown_codec_test.dart
flutter test test/plugins/code_block_test.dart
flutter test test/rendering/block_editor_widget_test.dart
flutter test test/rendering/block_widgets_test.dart
flutter test test/rendering/keyboard_shortcuts_test.dart
flutter analyze
```

## Recommended Next Phase

The best next phase is to stabilize the Markdown authoring experience rather than add broad new block types.

- Decide whether code blocks should stay lightweight or embed a CodeForge-backed
  editor for real TextMate/LSP behavior.
- Replace the lightweight Mermaid preview with a full Mermaid-compatible renderer
  if advanced diagrams become a requirement.
- Add richer table keyboard interactions: Tab, Shift+Tab, Enter, row/column focus movement.
- Add richer table menus for column alignment, row/column sizing reset, and
  cell-level transforms.
- Add a reader density control that applies compact/default/comfortable spacing
  presets across paragraph, list, table, media, math, and code blocks.
- Add Markdown-preserving fallbacks for unsupported constructs.
- Add a host-level dirty-state contract for raw/block toggles.
- Add larger real-document golden or snapshot tests using CodeForge docs such as `plan.md`.
- Add performance checks for larger Markdown files.
- Decide whether block-level undo should batch paste and table edits into single undo steps.
