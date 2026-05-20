library;

import 'package:flutter/material.dart';

import '../theme/block_editor_theme.dart';
import '../theme/markdown_document_theme.dart';

/// Describes a source-backed embedded editor highlight request.
///
/// Hosts can use [blockId], [language], and their own outer document path to
/// route Mermaid, Markdown, math, or fenced code blocks through the same syntax
/// pipeline as the primary editor.
final class BlockSourceHighlightRequest {
  /// Creates a source highlight request.
  const BlockSourceHighlightRequest({
    required this.blockId,
    required this.source,
    required this.language,
    required this.baseStyle,
    required this.editorTheme,
    required this.markdownTheme,
  });

  /// The block that owns this embedded source editor.
  final String blockId;

  /// The complete source text to render.
  final String source;

  /// The requested language identifier, such as `markdown`, `mermaid`, or
  /// `dart`.
  final String language;

  /// The base monospace style selected by the block editor.
  final TextStyle baseStyle;

  /// The active block editor shell theme.
  final BlockEditorThemeData editorTheme;

  /// The active Markdown document theme.
  final MarkdownDocumentThemeData markdownTheme;
}

/// Builds a highlighted source span for an embedded block source editor.
typedef BlockSourceHighlighter =
    TextSpan Function(BlockSourceHighlightRequest request);

/// Shared configuration for embedded source editors inside block_editor.
final class BlockSourceEditingConfig {
  /// Creates source editor configuration.
  const BlockSourceEditingConfig({this.textStyle, this.highlighter});

  /// Optional monospace text style used by source-backed blocks.
  final TextStyle? textStyle;

  /// Optional host-provided syntax highlighter.
  final BlockSourceHighlighter? highlighter;
}
