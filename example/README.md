# block_editor example

The example app is the local development surface for exercising the editor,
block plugins, and Markdown rendering behavior.

The app shell is intentionally wired through the same shadcn setup used by
`mock_ui`: `ShadcnApp`, the VS Code dark color scheme, `radius: 0.5`, and
`Typography.geist()` from `/Users/sebastian/Developer/vibe-coder/vibe_coder/deps/v2/shadcn_flutter`.
The Material theme exists only as an adapter for example widgets that have not
yet been moved to shadcn components.

## Run

```bash
flutter run -d macos
```

For browser-based tuning:

```bash
flutter run -d chrome --web-port 5174
```

## Sections

- **Editor**: editable block document with export, tags, slash menu, toolbar,
  read-only toggle, and theme toggle.
- **Demo Blocks**: read-only showcase for built-in block types.
- **Custom Block**: plugin registration and custom block rendering demo.
- **Playground**: Markdown rendering tuning surface.

## Rendering Playground

The **Editor** section is also seeded with a broad editable fixture. Use it to
exercise actual authoring behavior: cursor movement, selection, copy/paste,
keyboard formatting, slash transforms, block controls, table editing, media
cards, export, and read-only toggling across many block variants.

The Playground section is the fastest way to tune Markdown rendering without
editing package internals on every pass.

It starts in the `mock_ui` dark theme so spacing, contrast, typography, popover
surfaces, and editor tokens can be tuned against the same visual baseline used
by the real app.

It renders the real `BlockEditorWidget` and `BlockMarkdownCodec` pipeline while
allowing live changes to:

- document width
- page padding
- paragraph size
- paragraph line height
- list indent width
- list marker width
- bullet marker vertical offset
- numbered marker vertical offset
- todo checkbox vertical offset
- table text size
- code text size
- read-only/editable mode
- source-pane visibility
- block-only showcase visibility

The default fixture is intentionally broad. It includes frontmatter, all heading
levels, long paragraphs, rich inline spans, nested numbers, bullets, nested
todos, quotes, multiple callout variants, compact and wide tables, escaped
table pipes, table line breaks, images, links, reference definitions, wiki
links, embeds, Mermaid diagrams, math blocks, code fences in several languages,
HTML/raw Markdown fallbacks, footnotes, block anchors, and an appended manual
BlockNode matrix for media/reference blocks.

The table, code, Mermaid, and raw Markdown blocks use package-owned transparent
embedded text fields, so they stay visually aligned with the mock_ui/shadcn
theme instead of inheriting filled input backgrounds. Mermaid previews render
simple flowcharts and sequence diagrams while preserving the original fenced
Markdown source.

Bullet list markers are drawn shapes instead of symbol glyphs. Root bullets use
a filled dot; nested bullets use hollow inverted circle/square markers so they
stay centered and consistent across fonts.

The Markdown source pane reparses into the preview as you type. When editable
mode is enabled, block edits serialize back into the source pane.
