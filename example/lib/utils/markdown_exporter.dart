import 'package:block_editor/block_editor.dart';

/// Converts a [BlockDocument] to a Markdown string.
///
/// Delegates to the package Markdown codec so the editable example exports the
/// same broad Markdown/block coverage as the CodeForge integration path.
abstract final class MarkdownExporter {
  /// Converts [document] to a Markdown string.
  static String export(BlockDocument document) =>
      BlockMarkdownCodec.encode(document);
}
