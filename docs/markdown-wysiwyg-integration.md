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
- `BlockMarkdownCodec.encode(document)` produces Markdown. If the document was
  decoded from Markdown, unchanged blocks reuse their original source slices
  instead of being normalized.
- `BlockMarkdownCodec.encodeNormalized(document)` produces semantic normalized
  Markdown without source reuse for diagnostics and comparison.
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
   This now preserves unchanged decoded Markdown source while re-encoding only
   blocks whose semantic content changed.
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

## Real Markdown Workspace Demo

The default **Editor** tab now has a file-backed workspace mode for testing the
Markdown block editor against real documents instead of only the built-in
fixture.

The workspace pane intentionally follows the same interaction model as
`deps/git-client/git_client_app`:

- `file_picker` opens a native folder picker.
- A left file tree lazy-loads directory children.
- Recursive filesystem watching refreshes loaded directories when files are
  added, removed, or renamed.
- The active Markdown file is selected/revealed in the tree.
- Context menus expose open/copy-path/copy-relative-path actions.
- Generated/heavy folders such as `.git`, `.dart_tool`, `.vten`, `build`,
  `node_modules`, `Pods`, and `DerivedData` are filtered out.

This is implemented in the example app only:

- `example/lib/workspace/markdown_workspace_controller.dart`
- `example/lib/workspace/markdown_file_tree_view.dart`
- `example/lib/workspace/markdown_workspace_pane.dart`

The controller keeps the package dependency clean: `block_editor` remains a
pure editor/model package, while the example app owns native folder picking,
real filesystem access, and workspace shell state.

On macOS, this demo requires the sandbox entitlement:

```text
com.apple.security.files.user-selected.read-write
```

The entitlement is present in both `DebugProfile.entitlements` and
`Release.entitlements` so the native folder picker grants the app permission to
read and save files under the selected Markdown workspace.

Opening a Markdown file follows the same host contract CodeForge should use:

1. Read the `.md` file as text.
2. Decode with `BlockMarkdownCodec.decode(markdown)`.
3. Apply `.vten` presentation state for that workspace-relative path.
4. Replace the active `BlockController` document without recording undo.
5. On block changes, debounce `BlockMarkdownCodec.encode(controller.document)`
   and write the Markdown back to the selected file.

The example stores app/workspace shell state under the package `.vten` folder:

```text
.vten/block_editor/workspace_state.json
```

Per-document presentation state for real workspace files is stored inside the
chosen workspace root:

```text
<workspace>/.vten/block_editor/presentation/<document-key>.json
```

The document id is the workspace-relative Markdown path. This mirrors the
intended CodeForge integration: file content stays Markdown, while block
alignment and table sizes stay outside Markdown in `.vten`.

Normal paragraph soft breaks are normalized for rendering. If a Markdown file
hard-wraps prose at 80 or 100 columns, `BlockMarkdownCodec.decode` now turns
those single newlines into spaces in the paragraph `TextDelta`, so the text
flows to the actual editor width instead of visually breaking at the source
line length. The original source slice is still attached to the block, so an
unchanged paragraph saves back with the exact same source wrapping. Explicit
Markdown hard breaks using trailing spaces or a trailing backslash remain
visible as line breaks.

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
- compact reader mode
- centered vs leading document alignment
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

The Markdown document theme now also carries reader-layout preferences:

```dart
MarkdownDocumentThemeData.defaults(context).copyWith(
  density: MarkdownDocumentDensity.compact,
  contentAlignment: MarkdownDocumentContentAlignment.centered,
  blockSpacingScale: 0.58,
  surfacePaddingScale: 0.78,
)
```

`blockSpacingScale` reduces the vertical rhythm between blocks. `surfacePaddingScale`
reduces the internal padding of component-like blocks such as tables, code
blocks, Mermaid/math/source blocks, raw Markdown blocks, callouts, and drag
ghosts. This gives CodeForge a first-class reader-mode compact setting without
changing Markdown serialization.

The example app now exposes those compact/center controls in both the default
`Editor` tab and the rendering playground. Both surfaces share one preference
store and persist the compact/center reader preferences under:

```text
.vten/block_editor/reader_preferences.json
```

Those preferences are intentionally outside Markdown. CodeForge should follow
the same model for per-file or per-workspace presentation state: keep `.md`
content source-backed, and store view preferences under `.vten` keyed by the
workspace/file identity instead of writing layout metadata into Markdown.

Individual paragraph, heading, and table blocks now support a `textAlign`
presentation attribute with `left`, `center`, and `right` values. The block
action menu exposes this as `Align -> Align left/center/right`. Heading and
paragraph blocks apply it to the rendered text; table blocks apply it to the
whole table container, separate from the existing per-column Markdown table
alignment markers. This is also presentation state and should be persisted by
CodeForge under `.vten` rather than encoded into plain Markdown.

`MarkdownPresentationState` is the first reusable package-level contract for
that `.vten` state. It captures presentation-only block attributes from a
`BlockDocument`, keys them by deterministic Markdown-derived block fingerprints,
and reapplies them after the same Markdown file is decoded again:

```dart
final documentId = 'docs/plan.md'; // CodeForge should use workspace-relative path.
final document = BlockMarkdownCodec.decode(markdown);
final presentation = await presentationStore.load(documentId);
final controller = BlockController(
  document: presentation?.applyTo(document) ?? document,
);

// On document changes:
await presentationStore.save(
  documentId,
  MarkdownPresentationState.capture(
    controller.document,
    documentId: documentId,
  ),
);
```

The example app wires this through `VtenPresentationStateStore`, persisted at:

```text
.vten/block_editor/presentation/<document-key>.json
```

The current source mapping is intentionally conservative:

- Block keys are built from block type, semantic block JSON, decoded source
  span/source slice when available, and an occurrence-index fallback for
  repeated identical blocks.
- Source metadata, list numbering helpers, `textAlign`, and reserved table size
  attributes are ignored so presentation changes do not dirty Markdown source
  preservation.
- If a block's Markdown content changes, stale presentation state for that block
  is not reapplied.
- If multiple identical decoded blocks are reordered in memory, source-span
  keys let presentation follow the moved source-backed block before falling back
  to ordinal occurrence matching.
- If identical blocks are externally reordered in raw Markdown without stable
  anchors, the fallback can still follow ordinal position. A future CodeForge
  integration can improve that further with explicit block anchors or a
  source-patch move tracker.

Bulk block selection now keeps a stable paint layer around each block, even
when the block is not selected, so selecting multiple components does not swap
layout wrappers or nudge the measured size. Fully covered blocks suppress
their inline text selection spans and use one block-level selection paint only,
which keeps the selection blue consistent instead of darkening text runs with
double-painted highlight backgrounds.

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

List authoring now has Markdown-aware editing behavior:

- `Tab` and `Shift+Tab` indent and outdent selected list blocks as a group.
- `Enter` on a non-empty list item continues the same list type and indent.
- `Enter` on an empty nested list item dedents one level before exiting the
  list, so repeated Enter presses walk back out naturally.
- `Backspace` at the start of an indented list item dedents before merging.
- `Backspace` at the start of a top-level list item converts it to a paragraph
  and clears list-only attributes before a later Backspace can merge blocks.
- Todo shortcuts work both from paragraph markers such as `- [ ]` and from a
  bullet item whose text becomes `[ ]` or `[x]`.

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
- Table cells own a table-local keyboard layer:
  - `Cmd/Ctrl+B` and `Cmd/Ctrl+I` wrap selected cell text in Markdown syntax.
  - `Tab` and `Shift+Tab` move focus forward/backward through cells.
  - `Tab` from the final body cell appends a row through the same row insertion
    event path used by the hover controls.
  - Plain left/right arrows move to adjacent cells only at text boundaries.
  - Plain up/down arrows move to the cell above/below only from the first or
    last source line of a multiline cell.
  - `Enter` inserts a cell line break; Markdown export serializes it as `<br>`.
- Column and row resize handles anchored to the actual table grid edge rather
  than the padded text area. Handles are available from every visible cell, not
  only edge cells.
- Column and row resize handles commit presentation attributes on pointer-up:
  `tableColumnWidths` and `tableRowHeights`. These attributes are ignored by
  Markdown source fingerprints and captured by `MarkdownPresentationState`, so
  resized table layouts can survive reload through `.vten` without changing
  Markdown table syntax.
- Resize handles only mutate size during an explicit primary-button drag.
  Wheel scrolling and trackpad pan/scroll gestures over a handle are ignored by
  the resize logic, so hovering an expand point cannot accidentally grow a row
  or column.
- Active/hovered cells use a subtle full-cell surface highlight instead of a
  thick colored border.
- Markdown encode/decode for GitHub-style pipe tables.

Current table constraints:

- Table cells are plain strings, not nested rich-text documents.
- Table editing is structural but not yet a full spreadsheet-like selection
  model with rectangular multi-cell selection, fill handles, or formula-like
  behavior.

## Block Controls

Blocks now have Notion-style controls:

- A small add control can insert a new paragraph below the current block.
- A block action handle opens block actions.
- The block menu can select an entire block.
- Existing block actions include delete, duplicate, turn into, move up, and move down.
- Drag previews use the document column as a maximum width and shrink-wrap
  natural content-sized blocks such as headings, paragraphs, quotes, media,
  files, links, and tables. This keeps the floating preview close to the block
  being moved instead of rendering as a full viewport-width row.

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
- Table-local keyboard navigation for Tab, Shift+Tab, Enter line breaks, arrow
  boundary movement, and keyboard-driven row insertion.
- List-aware Backspace, nested empty-list Enter dedent behavior, and todo
  marker shortcuts inside bullet items.
- Markdown source-fidelity inspection, including exact source-preserving
  round-trip detection, raw Markdown preservation kinds, source line/offset
  spans, unchanged-block preservation, normalized-output comparison, and
  fixture-corpus coverage.
- Markdown presentation-state capture/apply, duplicate-block occurrence keys,
  source-span matching for reordered source-backed duplicates, table dimension
  attributes, stale-entry rejection when source content changes, JSON round
  trips, and `.vten` presentation-file persistence/deletion.
- Example-app Markdown workspace selection, `.vten` workspace-state restore,
  active Markdown file loading/saving, lazy file-tree loading, generated-folder
  filtering, active-file reveal, and open-file callbacks.
- Controller-level operation records on document changes for insert, delete,
  update, move, and replace mutations.

## Source Fidelity Diagnostics

`BlockMarkdownCodec.inspect(markdown)` reports what happens when a Markdown
string is decoded and encoded again. This is the source-fidelity layer that lets
CodeForge use block mode without rewriting unchanged Markdown.

The report includes:

- normalized original Markdown
- source-preserving encoded Markdown
- normalized encoded Markdown
- exact source-preserving round-trip status
- exact normalized round-trip status
- decoded block count
- source-backed block count
- preserved source block count
- changed source block count
- raw Markdown block count
- raw Markdown counts by kind
- diagnostics with severity, source line span, and raw kind

All blocks decoded from Markdown now keep:

```text
sourceStartLine
sourceEndLine
sourceStartOffset
sourceEndOffset
sourceMarkdown
sourceFingerprint
```

Raw Markdown fallback blocks additionally keep:

```text
rawKind
```

`sourceFingerprint` is a semantic fingerprint of the decoded block, excluding
source metadata and transient rendering attributes. When the current block still
matches that fingerprint, `BlockMarkdownCodec.encode` emits the original
`sourceMarkdown` slice. When it differs, the block is re-encoded normally and
the surrounding unchanged blocks can still preserve their exact Markdown.

This lets host UI and tests distinguish safe source preservation from actual
loss or normalization. For example, HTML blocks, footnote definitions, reference
definitions, Obsidian comments, block anchors, original ordered-list numbers,
and compact table separators can stay intact while edited blocks are still
written back as normal Markdown.

## Operation Log

`BlockController.changes` now emits a `DocumentChange.operations` list. Each
entry is a `BlockDocumentOperation` with:

```text
type
blockId
before
after
fromIndex
toIndex
```

This is intentionally a block-level log, not a source-offset patcher yet. It is
the foundation for later Markdown patch application, richer undo diagnostics,
table/block operation batching, and host-level dirty-state reporting. Current
operation kinds are:

```text
insert
delete
update
move
replace
```

Useful focused verification commands:

```bash
flutter test test/markdown/block_markdown_codec_test.dart
flutter test test/controller/block_controller_test.dart
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
- Add richer table menus for column alignment, row/column sizing reset, and
  cell-level transforms.
- Add spreadsheet-style table selection features if needed: rectangular
  multi-cell selection, copy/paste cell ranges, and row/column keyboard
  commands.
- Add a reader density control that applies compact/default/comfortable spacing
  presets across paragraph, list, table, media, math, and code blocks.
- Add Markdown-preserving fallbacks for unsupported constructs.
- Add a host-level dirty-state contract for raw/block toggles.
- Add larger real-document golden or snapshot tests using CodeForge docs such as `plan.md`.
- Add performance checks for larger Markdown files.
- Decide whether block-level undo should batch paste and table edits into single undo steps.
