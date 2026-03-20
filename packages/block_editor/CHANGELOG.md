# Changelog

All notable changes to the `block_editor` package are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).
This package adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [0.0.2-dev.1] — 2026-03-20

First published pre-release. Covers Phase 1 (Document Model), Phase 2 (Rendering Engine), and Phase 3 (Block Plugin System). API is unstable — breaking changes are expected in future pre-release versions before `1.0.0`.

### Added

**Document Model (Phase 1)**
- `BlockNode` — typed content node with `id`, `type`, `attributes`, and `children`
- `BlockDocument` — root container with ordered `BlockNode` list, JSON serialisation and deserialisation
- `TextDelta` — inline rich text model as a list of `DeltaOp` objects
- `DeltaOp` sealed class with `TextOp` subtype carrying `InlineAttributes`
- `InlineAttributes` — bold, italic, underline, strikethrough, inline code, link, text color, background color
- `BlockController` — document state manager with insert, delete, update, move, and transform operations
- `BlockTypes` — typed constants for all built-in block type identifiers
- `EditorSelection` — sealed class replacing `BlockSelection` for cursor and range selection
- Undo/redo stack with snapshot-based history
- `selectionStream` on `BlockController` alongside the document change stream

**Rendering Engine (Phase 2)**
- `BlockRenderer` — stateless widget mapping `BlockNode` to its Flutter widget via `BlockRegistry`
- `BlockEditorWidget` — root editor widget with external `BlockController` ownership, keyboard events, focus, and scroll
- `RichTextRenderer` — converts `TextDelta` into a `TextSpan` tree
- Block widgets for Paragraph, H1, H2, H3, BulletList, NumberedList, Todo, Quote, and Divider
- Cursor rendering with public animation API
- Single-block and cross-block selection highlight
- Character-level editing operations in pure Dart
- Drag and drop block reordering with ghost preview and drop indicator
- `readOnly` flag on `BlockEditorWidget`
- `BlockEvent` sealed class as the universal block interaction contract
- `CustomBlockEvent` wrapper subtype for external package event extensibility

**Block Plugin System (Phase 3)**
- `BlockPlugin` abstract interface — `blockType`, `build()`, `serialize()`, `deserialize()`, optional `toolbarButton()`, `slashCommandItem()`, `slashCommandGroup()`
- `BlockRegistry` with public `register(BlockPlugin)` method — built-in blocks pre-registered internally
- Per-block stream system via `BlockController.streamForBlock(String blockId)`
- `EditorEditingOperations` extended to operate on `TextDelta.ops` preserving inline formatting
- IME and mobile soft keyboard input via `TextInputConnection`
- Built-in media block plugins: Image, Video, YouTube embed, File attachment, Code, Callout, Link
- Inline embed `DeltaOp` subtypes for variables and tags

---

## [0.0.1] — 2026-01-01

Initial mono-repo scaffold. No functional code. Repository structure, CI pipeline, Melos workspace configuration, and pubspec files only.