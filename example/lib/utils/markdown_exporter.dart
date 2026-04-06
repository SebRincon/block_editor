import 'package:block_editor/block_editor.dart';

/// Converts a [BlockDocument] to a Markdown string.
///
/// Walks every block in document order via [BlockDocument.flatten]. Each
/// block type maps to a Markdown prefix or structure. Inline [TextDelta] ops
/// are converted to their Markdown equivalents — bold, italic, inline code,
/// and links are all handled. [VariableOp] renders as `{{variableName}}` and
/// [TagOp] renders as `#tag`.
abstract final class MarkdownExporter {
  /// Converts [document] to a Markdown string.
  static String export(BlockDocument document) {
    final buffer = StringBuffer();
    final blocks = document.flatten();

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final line = _convertBlock(block);
      if (line != null) {
        buffer.writeln(line);
        if (_needsTrailingNewline(block.type)) buffer.writeln();
      }
    }

    return buffer.toString().trimRight();
  }

  static String? _convertBlock(BlockNode block) {
    final text = block.delta != null ? _convertDelta(block.delta!) : '';

    return switch (block.type) {
      BlockTypes.paragraph => text,
      BlockTypes.heading1 => '# $text',
      BlockTypes.heading2 => '## $text',
      BlockTypes.heading3 => '### $text',
      BlockTypes.bulletList => '- $text',
      BlockTypes.numberedList => '1. $text',
      BlockTypes.todo => _todoLine(block, text),
      BlockTypes.quote => '> $text',
      BlockTypes.code => _codeBlock(block),
      BlockTypes.callout => '> **${_variantLabel(block)}** $text',
      BlockTypes.divider => '---',
      BlockTypes.image => _imageBlock(block),
      BlockTypes.video => _linkBlock(
        'Video',
        block.attributes['url'] as String?,
      ),
      BlockTypes.youtube => _linkBlock(
        'YouTube',
        block.attributes['url'] as String?,
      ),
      BlockTypes.file => _linkBlock(
        block.attributes['name'] as String? ?? 'File',
        block.attributes['url'] as String?,
      ),
      BlockTypes.link => _linkBlock(
        block.attributes['title'] as String? ?? text,
        block.attributes['url'] as String?,
      ),
      _ => text,
    };
  }

  static String _convertDelta(TextDelta delta) {
    final buffer = StringBuffer();
    for (final op in delta.ops) {
      switch (op) {
        case TextOp():
          buffer.write(_applyInlineFormatting(op));
        case VariableOp():
          buffer.write('{{${op.variableName}}}');
        case TagOp():
          buffer.write('#${op.tag}');
      }
    }
    return buffer.toString();
  }

  static String _applyInlineFormatting(TextOp op) {
    var text = op.text;
    final attrs = op.attributes;

    if (attrs.link != null && attrs.link!.isNotEmpty) {
      text = '[$text](${attrs.link})';
    }
    if (attrs.inlineCode == true) {
      text = '`$text`';
    }
    if (attrs.bold == true && attrs.italic == true) {
      text = '***$text***';
    } else if (attrs.bold == true) {
      text = '**$text**';
    } else if (attrs.italic == true) {
      text = '*$text*';
    }
    if (attrs.strikethrough == true) {
      text = '~~$text~~';
    }

    return text;
  }

  static String _todoLine(BlockNode block, String text) {
    final checked = block.attributes['checked'] == true;
    return '- [${checked ? 'x' : ' '}] $text';
  }

  static String _codeBlock(BlockNode block) {
    final language = block.attributes['language'] as String? ?? '';
    final text = block.delta?.plainText ?? '';
    return '```$language\n$text\n```';
  }

  static String _imageBlock(BlockNode block) {
    final url = block.attributes['url'] as String? ?? '';
    final alt = block.attributes['alt'] as String? ?? 'image';
    return '![$alt]($url)';
  }

  static String _linkBlock(String label, String? url) {
    if (url == null || url.isEmpty) return label;
    return '[$label]($url)';
  }

  static String _variantLabel(BlockNode block) {
    return switch (block.attributes['variant'] as String? ?? 'info') {
      'warning' => '⚠️ Warning',
      'error' => '🚫 Error',
      _ => 'ℹ️ Info',
    };
  }

  static bool _needsTrailingNewline(String type) {
    return type == BlockTypes.heading1 ||
        type == BlockTypes.heading2 ||
        type == BlockTypes.heading3 ||
        type == BlockTypes.code ||
        type == BlockTypes.divider;
  }
}
