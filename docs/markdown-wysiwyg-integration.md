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
- Code blocks are displayed from Markdown, but they are not yet rich editable code editors.

## Code Blocks

Fenced Markdown code blocks decode into `BlockTypes.code` with:

- `attributes['language']` storing the fence language.
- `delta.plainText` storing the code content.

The renderer also supports legacy nodes that store code in `attributes['code']`.

Current limitations:

- Code blocks render as a monospace block, not a full code editor.
- There is no syntax-highlighting pass wired into Markdown code blocks yet.
- There is no cursor or block-native editing model inside code blocks yet.
- Language switching currently emits an event and expects a host/plugin flow to complete the change.

The next code-block phase should decide whether code blocks use a lightweight editable text area, a CodeForge editor embed, or a syntax-highlighted read/edit hybrid.

## Testing Coverage Added

The current changes include focused coverage for:

- Markdown decode/encode including tables and fenced code.
- Command registry and keymap behavior.
- Arrow navigation and expanded selection shortcuts.
- Clipboard shortcuts for copy, cut, and paste.
- Formatting toolbar state and actions.
- Slash menu filtering and keyboard movement.
- Table row/column add and delete behavior.
- Block controls and action menu selection.
- Rich text rendering and cursor/selection behavior.

Useful focused verification commands:

```bash
flutter test test/markdown/block_markdown_codec_test.dart
flutter test test/plugins/code_block_test.dart
flutter test test/rendering/block_editor_widget_test.dart
flutter test test/rendering/keyboard_shortcuts_test.dart
flutter analyze
```

## Recommended Next Phase

The best next phase is to stabilize the Markdown authoring experience rather than add broad new block types.

- Make code blocks editable and syntax-highlighted.
- Add richer table keyboard interactions: Tab, Shift+Tab, Enter, row/column focus movement.
- Add Markdown-preserving fallbacks for unsupported constructs.
- Add a host-level dirty-state contract for raw/block toggles.
- Add larger real-document golden or snapshot tests using CodeForge docs such as `plan.md`.
- Add performance checks for larger Markdown files.
- Decide whether block-level undo should batch paste and table edits into single undo steps.

