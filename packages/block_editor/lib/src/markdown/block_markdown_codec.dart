library;

import 'package:block_editor/block_editor.dart';

/// Converts between Markdown text and the block_editor document model.
///
/// The codec intentionally targets the Markdown forms that map cleanly to the
/// built-in block types. Unsupported constructs are preserved as paragraph
/// text instead of being dropped.
abstract final class BlockMarkdownCodec {
  static final RegExp _headingPattern = RegExp(r'^(#{1,3})\s+(.*)$');
  static final RegExp _todoPattern = RegExp(r'^\s*[-*+]\s+\[([ xX])\]\s+(.*)$');
  static final RegExp _bulletPattern = RegExp(r'^\s*[-*+]\s+(.*)$');
  static final RegExp _numberedPattern = RegExp(r'^\s*\d+[.)]\s+(.*)$');
  static final RegExp _dividerPattern = RegExp(r'^\s{0,3}(([-*_])\s*){3,}$');
  static final RegExp _imagePattern = RegExp(r'^!\[([^\]]*)\]\(([^)]*)\)\s*$');
  static final RegExp _linkPattern = RegExp(r'^\[([^\]]+)\]\(([^)]*)\)\s*$');
  static final RegExp _tableSeparatorCellPattern = RegExp(r'^:?-{3,}:?$');

  /// Parses [markdown] into a [BlockDocument].
  static BlockDocument decode(String markdown) {
    final normalized = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) return BlockDocument.empty();

    final lines = normalized.split('\n');
    final blocks = <BlockNode>[];
    var index = 0;

    while (index < lines.length) {
      final line = lines[index];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        index++;
        continue;
      }

      if (trimmed.startsWith('```')) {
        final language = trimmed.substring(3).trim();
        final code = StringBuffer();
        index++;
        while (index < lines.length && !lines[index].trim().startsWith('```')) {
          if (code.isNotEmpty) code.write('\n');
          code.write(lines[index]);
          index++;
        }
        if (index < lines.length) index++;
        blocks.add(
          BlockNode(
            type: BlockTypes.code,
            attributes: {if (language.isNotEmpty) 'language': language},
            delta: TextDelta.fromPlainText(code.toString()),
          ),
        );
        continue;
      }

      if (_isTableStart(lines, index)) {
        final parsed = _parseTable(lines, index);
        blocks.add(parsed.block);
        index = parsed.nextIndex;
        continue;
      }

      final heading = _headingPattern.firstMatch(line);
      if (heading != null) {
        final level = heading.group(1)!.length;
        blocks.add(
          BlockNode(
            type: switch (level) {
              1 => BlockTypes.heading1,
              2 => BlockTypes.heading2,
              _ => BlockTypes.heading3,
            },
            delta: _parseInline(heading.group(2) ?? ''),
          ),
        );
        index++;
        continue;
      }

      if (_dividerPattern.hasMatch(line)) {
        blocks.add(BlockNode(type: BlockTypes.divider));
        index++;
        continue;
      }

      final todo = _todoPattern.firstMatch(line);
      if (todo != null) {
        blocks.add(
          BlockNode(
            type: BlockTypes.todo,
            attributes: {'checked': todo.group(1)!.toLowerCase() == 'x'},
            delta: _parseInline(todo.group(2) ?? ''),
          ),
        );
        index++;
        continue;
      }

      final bullet = _bulletPattern.firstMatch(line);
      if (bullet != null) {
        blocks.add(
          BlockNode(
            type: BlockTypes.bulletList,
            delta: _parseInline(bullet.group(1) ?? ''),
          ),
        );
        index++;
        continue;
      }

      final numbered = _numberedPattern.firstMatch(line);
      if (numbered != null) {
        blocks.add(
          BlockNode(
            type: BlockTypes.numberedList,
            delta: _parseInline(numbered.group(1) ?? ''),
          ),
        );
        index++;
        continue;
      }

      if (trimmed.startsWith('>')) {
        final quote = StringBuffer();
        while (index < lines.length &&
            lines[index].trimLeft().startsWith('>')) {
          if (quote.isNotEmpty) quote.write('\n');
          quote.write(
            lines[index].trimLeft().replaceFirst(RegExp(r'^>\s?'), ''),
          );
          index++;
        }
        blocks.add(
          BlockNode(
            type: BlockTypes.quote,
            delta: _parseInline(quote.toString()),
          ),
        );
        continue;
      }

      final image = _imagePattern.firstMatch(trimmed);
      if (image != null) {
        blocks.add(
          BlockNode(
            type: BlockTypes.image,
            attributes: {
              'alt': image.group(1) ?? '',
              'url': image.group(2) ?? '',
            },
          ),
        );
        index++;
        continue;
      }

      final link = _linkPattern.firstMatch(trimmed);
      if (link != null) {
        blocks.add(
          BlockNode(
            type: BlockTypes.link,
            attributes: {
              'title': link.group(1) ?? '',
              'url': link.group(2) ?? '',
            },
            delta: TextDelta.fromPlainText(link.group(1) ?? ''),
          ),
        );
        index++;
        continue;
      }

      final paragraph = StringBuffer(line);
      index++;
      while (index < lines.length && !_startsBlock(lines[index])) {
        if (lines[index].trim().isEmpty) break;
        paragraph.write('\n');
        paragraph.write(lines[index]);
        index++;
      }
      blocks.add(
        BlockNode(
          type: BlockTypes.paragraph,
          delta: _parseInline(paragraph.toString()),
        ),
      );
    }

    return BlockDocument(
      blocks.isEmpty ? BlockDocument.empty().blocks : blocks,
    );
  }

  /// Serializes [document] into Markdown.
  static String encode(BlockDocument document) {
    final buffer = StringBuffer();
    final blocks = document.flatten();

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      final line = _encodeBlock(block);
      if (line == null) continue;
      if (buffer.isNotEmpty) buffer.writeln();
      buffer.write(line);
      if (_separatesFromNext(block.type) && i < blocks.length - 1) {
        buffer.writeln();
      }
    }

    return buffer.toString().trimRight();
  }

  static bool _startsBlock(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return true;
    return trimmed.startsWith('```') ||
        trimmed.startsWith('>') ||
        _headingPattern.hasMatch(line) ||
        _todoPattern.hasMatch(line) ||
        _bulletPattern.hasMatch(line) ||
        _numberedPattern.hasMatch(line) ||
        _dividerPattern.hasMatch(line) ||
        _imagePattern.hasMatch(trimmed) ||
        _linkPattern.hasMatch(trimmed) ||
        _isTableRow(line);
  }

  static String? _encodeBlock(BlockNode block) {
    final text = block.delta == null ? '' : _encodeDelta(block.delta!);
    return switch (block.type) {
      BlockTypes.paragraph => text,
      BlockTypes.heading1 => '# $text',
      BlockTypes.heading2 => '## $text',
      BlockTypes.heading3 => '### $text',
      BlockTypes.bulletList => '- $text',
      BlockTypes.numberedList => '1. $text',
      BlockTypes.todo =>
        '- [${block.attributes['checked'] == true ? 'x' : ' '}] $text',
      BlockTypes.quote =>
        text
            .split('\n')
            .map((line) => line.isEmpty ? '>' : '> $line')
            .join('\n'),
      BlockTypes.code => _encodeCodeBlock(block),
      BlockTypes.table => _encodeTableBlock(block),
      BlockTypes.callout =>
        '> **${block.attributes['variant'] ?? 'info'}** $text',
      BlockTypes.divider => '---',
      BlockTypes.image => _encodeImageBlock(block),
      BlockTypes.video => _encodeReferenceBlock('Video', block),
      BlockTypes.youtube => _encodeReferenceBlock('YouTube', block),
      BlockTypes.file => _encodeReferenceBlock(
        block.attributes['name'] as String? ?? 'File',
        block,
      ),
      BlockTypes.link => _encodeReferenceBlock(
        block.attributes['title'] as String? ?? text,
        block,
      ),
      _ => text,
    };
  }

  static String _encodeDelta(TextDelta delta) {
    final buffer = StringBuffer();
    for (final op in delta.ops) {
      switch (op) {
        case TextOp():
          buffer.write(_encodeTextOp(op));
        case VariableOp():
          buffer.write('{{${op.variableName}}}');
        case TagOp():
          buffer.write('#${op.tag}');
      }
    }
    return buffer.toString();
  }

  static String _encodeTextOp(TextOp op) {
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

  static String _encodeCodeBlock(BlockNode block) {
    final language = block.attributes['language'] as String? ?? '';
    final text = block.delta?.plainText ?? '';
    return '```$language\n$text\n```';
  }

  static String _encodeImageBlock(BlockNode block) {
    final alt = block.attributes['alt'] as String? ?? 'image';
    final url = block.attributes['url'] as String? ?? '';
    return '![$alt]($url)';
  }

  static String _encodeReferenceBlock(String label, BlockNode block) {
    final url = block.attributes['url'] as String? ?? '';
    if (url.isEmpty) return label;
    return '[$label]($url)';
  }

  static bool _separatesFromNext(String type) {
    return type == BlockTypes.heading1 ||
        type == BlockTypes.heading2 ||
        type == BlockTypes.heading3 ||
        type == BlockTypes.code ||
        type == BlockTypes.divider ||
        type == BlockTypes.table ||
        type == BlockTypes.quote;
  }

  /// Parses inline Markdown supported by the block editor into a [TextDelta].
  static TextDelta parseInline(String input) => _parseInline(input);

  static TextDelta _parseInline(String input) {
    final ops = <DeltaOp>[];
    var index = 0;

    while (index < input.length) {
      final variableEnd = input.startsWith('{{', index)
          ? input.indexOf('}}', index + 2)
          : -1;
      if (variableEnd > index + 2) {
        ops.add(VariableOp(input.substring(index + 2, variableEnd).trim()));
        index = variableEnd + 2;
        continue;
      }

      final link = _tryParseLink(input, index);
      if (link != null) {
        ops.add(
          TextOp(link.label, attributes: InlineAttributes(link: link.url)),
        );
        index = link.end;
        continue;
      }

      final formatted = _tryParseDelimited(input, index);
      if (formatted != null) {
        ops.add(formatted.op);
        index = formatted.end;
        continue;
      }

      final next = _nextInlineMarker(input, index + 1);
      ops.add(TextOp(input.substring(index, next)));
      index = next;
    }

    return TextDelta(ops);
  }

  static bool _isTableStart(List<String> lines, int index) {
    if (index + 1 >= lines.length) return false;
    return _isTableRow(lines[index]) && _isTableSeparator(lines[index + 1]);
  }

  static ({BlockNode block, int nextIndex}) _parseTable(
    List<String> lines,
    int index,
  ) {
    final headers = _splitTableRow(lines[index]);
    final alignments = _splitTableRow(
      lines[index + 1],
    ).map(_parseAlignment).toList();
    final rows = <List<String>>[];
    index += 2;
    while (index < lines.length && _isTableRow(lines[index])) {
      rows.add(
        _normalizeTableRow(_splitTableRow(lines[index]), headers.length),
      );
      index++;
    }
    return (
      block: BlockNode(
        type: BlockTypes.table,
        attributes: {
          'headers': headers,
          'rows': rows,
          if (alignments.any((value) => value != null))
            'alignments': alignments,
        },
      ),
      nextIndex: index,
    );
  }

  static bool _isTableRow(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || !trimmed.contains('|')) return false;
    return _splitTableRow(trimmed).length >= 2;
  }

  static bool _isTableSeparator(String line) {
    final cells = _splitTableRow(line);
    if (cells.length < 2) return false;
    return cells.every((cell) => _tableSeparatorCellPattern.hasMatch(cell));
  }

  static List<String> _splitTableRow(String line) {
    var trimmed = line.trim();
    if (trimmed.startsWith('|')) trimmed = trimmed.substring(1);
    if (trimmed.endsWith('|')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.split('|').map((cell) => cell.trim()).toList();
  }

  static String? _parseAlignment(String separatorCell) {
    final starts = separatorCell.startsWith(':');
    final ends = separatorCell.endsWith(':');
    if (starts && ends) return 'center';
    if (ends) return 'right';
    if (starts) return 'left';
    return null;
  }

  static List<String> _normalizeTableRow(List<String> row, int columns) {
    if (row.length == columns) return row;
    if (row.length > columns) return row.sublist(0, columns);
    return [...row, ...List.filled(columns - row.length, '')];
  }

  static String _encodeTableBlock(BlockNode block) {
    final headers = _stringList(block.attributes['headers']);
    final rows = _rowsList(block.attributes['rows']);
    if (headers.isEmpty) return '';
    final alignments = _stringList(block.attributes['alignments']);
    final buffer = StringBuffer()
      ..writeln(_encodeTableRow(headers))
      ..writeln(_encodeTableRow(_separatorCells(headers.length, alignments)));
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) buffer.writeln();
      buffer.write(
        _encodeTableRow(_normalizeTableRow(rows[i], headers.length)),
      );
    }
    return buffer.toString();
  }

  static List<String> _stringList(Object? value) {
    if (value is! Iterable<Object?>) return const [];
    return value.map((item) => item?.toString() ?? '').toList();
  }

  static List<List<String>> _rowsList(Object? value) {
    if (value is! Iterable<Object?>) return const [];
    return value
        .whereType<Iterable<Object?>>()
        .map((row) => row.map((item) => item?.toString() ?? '').toList())
        .toList();
  }

  static List<String> _separatorCells(int count, List<String> alignments) {
    return List.generate(count, (index) {
      final alignment = index < alignments.length ? alignments[index] : null;
      return switch (alignment) {
        'left' => ':---',
        'right' => '---:',
        'center' => ':---:',
        _ => '---',
      };
    });
  }

  static String _encodeTableRow(List<String> cells) {
    final escaped = cells.map(
      (cell) => cell.replaceAll('\n', '<br>').replaceAll('|', r'\|'),
    );
    return '| ${escaped.join(' | ')} |';
  }

  static _LinkToken? _tryParseLink(String input, int index) {
    if (!input.startsWith('[', index)) return null;
    final closeLabel = input.indexOf('](', index + 1);
    if (closeLabel < 0) return null;
    final closeUrl = input.indexOf(')', closeLabel + 2);
    if (closeUrl < 0) return null;
    return _LinkToken(
      label: input.substring(index + 1, closeLabel),
      url: input.substring(closeLabel + 2, closeUrl),
      end: closeUrl + 1,
    );
  }

  static _FormattedToken? _tryParseDelimited(String input, int index) {
    if (input.startsWith('***', index)) {
      return _formatted(
        input,
        index,
        '***',
        const InlineAttributes(bold: true, italic: true),
      );
    }
    if (input.startsWith('**', index)) {
      return _formatted(input, index, '**', const InlineAttributes(bold: true));
    }
    if (input.startsWith('~~', index)) {
      return _formatted(
        input,
        index,
        '~~',
        const InlineAttributes(strikethrough: true),
      );
    }
    if (input.startsWith('`', index)) {
      return _formatted(
        input,
        index,
        '`',
        const InlineAttributes(inlineCode: true),
      );
    }
    if (input.startsWith('*', index)) {
      return _formatted(
        input,
        index,
        '*',
        const InlineAttributes(italic: true),
      );
    }
    return null;
  }

  static _FormattedToken? _formatted(
    String input,
    int index,
    String delimiter,
    InlineAttributes attributes,
  ) {
    final close = input.indexOf(delimiter, index + delimiter.length);
    if (close <= index + delimiter.length) return null;
    return _FormattedToken(
      op: TextOp(
        input.substring(index + delimiter.length, close),
        attributes: attributes,
      ),
      end: close + delimiter.length,
    );
  }

  static int _nextInlineMarker(String input, int start) {
    var next = input.length;
    for (final marker in const ['{{', '[', '***', '**', '~~', '`', '*']) {
      final found = input.indexOf(marker, start);
      if (found >= 0 && found < next) next = found;
    }
    return next;
  }
}

final class _FormattedToken {
  const _FormattedToken({required this.op, required this.end});

  final TextOp op;
  final int end;
}

final class _LinkToken {
  const _LinkToken({required this.label, required this.url, required this.end});

  final String label;
  final String url;
  final int end;
}
