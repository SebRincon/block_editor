library;

import 'package:block_editor/block_editor.dart';

/// Converts between Markdown text and the block_editor document model.
///
/// The codec intentionally targets the Markdown forms that map cleanly to the
/// built-in block types. Unsupported block constructs are preserved as raw
/// Markdown blocks instead of being degraded or dropped.
abstract final class BlockMarkdownCodec {
  static final RegExp _headingPattern = RegExp(r'^(#{1,6})\s+(.*)$');
  static final RegExp _todoPattern = RegExp(
    r'^([ \t]*)[-*+]\s+\[([ xX])\]\s+(.*)$',
  );
  static final RegExp _bulletPattern = RegExp(r'^([ \t]*)[-*+]\s+(.*)$');
  static final RegExp _numberedPattern = RegExp(r'^([ \t]*)\d+[.)]\s+(.*)$');
  static final RegExp _dividerPattern = RegExp(r'^\s{0,3}(([-*_])\s*){3,}$');
  static final RegExp _imagePattern = RegExp(r'^!\[([^\]]*)\]\(([^)]*)\)\s*$');
  static final RegExp _linkPattern = RegExp(r'^\[([^\]]+)\]\(([^)]*)\)\s*$');
  static final RegExp _calloutPattern = RegExp(
    r'^\s*>\s*\[!([A-Za-z][\w-]*)\]([+-])?(?:\s+(.*))?\s*$',
  );
  static final RegExp _tableSeparatorCellPattern = RegExp(r'^:?-{3,}:?$');
  static final RegExp _htmlBlockStartPattern = RegExp(
    r'^\s{0,3}<([A-Za-z][\w:-]*)(?:\s|>|/>)',
  );
  static final RegExp _footnoteDefinitionPattern = RegExp(
    r'^\s{0,3}\[\^[^\]]+\]:',
  );
  static final RegExp _referenceDefinitionPattern = RegExp(
    r'^\s{0,3}\[[^\]^][^\]]*\]:\s+\S+',
  );
  static final RegExp _blockIdPattern = RegExp(r'^\s{0,3}\^[A-Za-z0-9_-]+\s*$');

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

      if (index == 0 && trimmed == '---') {
        final parsed = _tryParseFrontmatter(lines, index);
        if (parsed != null) {
          blocks.add(parsed.block);
          index = parsed.nextIndex;
          continue;
        }
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
            type: language.toLowerCase() == 'mermaid'
                ? BlockTypes.mermaid
                : BlockTypes.code,
            attributes: {if (language.isNotEmpty) 'language': language},
            delta: TextDelta.fromPlainText(code.toString()),
          ),
        );
        continue;
      }

      final mathBlock = _tryParseMathBlock(lines, index);
      if (mathBlock != null) {
        blocks.add(mathBlock.block);
        index = mathBlock.nextIndex;
        continue;
      }

      final rawMarkdown = _tryParseRawMarkdownBlock(lines, index);
      if (rawMarkdown != null) {
        blocks.add(rawMarkdown.block);
        index = rawMarkdown.nextIndex;
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
              3 => BlockTypes.heading3,
              4 => BlockTypes.heading4,
              5 => BlockTypes.heading5,
              _ => BlockTypes.heading6,
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
            attributes: {
              'checked': todo.group(2)!.toLowerCase() == 'x',
              if (_indentLevel(todo.group(1) ?? '') > 0)
                'indent': _indentLevel(todo.group(1) ?? ''),
            },
            delta: _parseInline(todo.group(3) ?? ''),
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
            attributes: {
              if (_indentLevel(bullet.group(1) ?? '') > 0)
                'indent': _indentLevel(bullet.group(1) ?? ''),
            },
            delta: _parseInline(bullet.group(2) ?? ''),
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
            attributes: {
              if (_indentLevel(numbered.group(1) ?? '') > 0)
                'indent': _indentLevel(numbered.group(1) ?? ''),
            },
            delta: _parseInline(numbered.group(2) ?? ''),
          ),
        );
        index++;
        continue;
      }

      final callout = _calloutPattern.firstMatch(line);
      if (callout != null) {
        final parsed = _parseCallout(lines, index, callout);
        blocks.add(parsed.block);
        index = parsed.nextIndex;
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
        _startsRawMarkdownBlock(line) ||
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
      BlockTypes.heading4 => '#### $text',
      BlockTypes.heading5 => '##### $text',
      BlockTypes.heading6 => '###### $text',
      BlockTypes.bulletList => '${_listIndent(block)}- $text',
      BlockTypes.numberedList => '${_listIndent(block)}1. $text',
      BlockTypes.todo =>
        '${_listIndent(block)}- [${block.attributes['checked'] == true ? 'x' : ' '}] $text',
      BlockTypes.quote =>
        text
            .split('\n')
            .map((line) => line.isEmpty ? '>' : '> $line')
            .join('\n'),
      BlockTypes.code => _encodeCodeBlock(block),
      BlockTypes.math => _encodeMathBlock(block),
      BlockTypes.mermaid => _encodeMermaidBlock(block),
      BlockTypes.rawMarkdown => block.delta?.plainText ?? '',
      BlockTypes.table => _encodeTableBlock(block),
      BlockTypes.callout => _encodeCalloutBlock(block),
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

    if (attrs.footnote != null && attrs.footnote!.isNotEmpty) {
      return '[^${attrs.footnote}]';
    }
    if (attrs.wikiLink != null && attrs.wikiLink!.isNotEmpty) {
      final target = attrs.wikiLink!;
      final alias = text == target || text.isEmpty ? '' : '|$text';
      return '${attrs.embed == true ? '!' : ''}[[$target$alias]]';
    }
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
    if (attrs.highlight == true) {
      text = '==$text==';
    }

    return text;
  }

  static String _encodeCodeBlock(BlockNode block) {
    final language = block.attributes['language'] as String? ?? '';
    final text = block.delta?.plainText ?? '';
    if (block.attributes['frontmatter'] == true) {
      return '---\n$text\n---';
    }
    return '```$language\n$text\n```';
  }

  static String _encodeMathBlock(BlockNode block) {
    final text = block.delta?.plainText ?? '';
    return '\$\$\n$text\n\$\$';
  }

  static String _encodeMermaidBlock(BlockNode block) {
    final text = block.delta?.plainText ?? '';
    return '```mermaid\n$text\n```';
  }

  static String _encodeImageBlock(BlockNode block) {
    final alt = block.attributes['alt'] as String? ?? 'image';
    final url = block.attributes['url'] as String? ?? '';
    return '![$alt]($url)';
  }

  static String _encodeCalloutBlock(BlockNode block) {
    final variant = block.attributes['variant'] as String? ?? 'note';
    final title = (block.attributes['title'] as String?)?.trim();
    final expanded = block.attributes['expanded'];
    final marker = expanded == true
        ? '+'
        : expanded == false
        ? '-'
        : '';
    final header =
        '> [!$variant]$marker${title == null || title.isEmpty ? '' : ' $title'}';
    final text = block.delta?.plainText ?? '';
    if (text.isEmpty) return header;
    final body = text
        .split('\n')
        .map((line) => line.isEmpty ? '>' : '> $line')
        .join('\n');
    return '$header\n$body';
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
        type == BlockTypes.heading4 ||
        type == BlockTypes.heading5 ||
        type == BlockTypes.heading6 ||
        type == BlockTypes.code ||
        type == BlockTypes.math ||
        type == BlockTypes.mermaid ||
        type == BlockTypes.rawMarkdown ||
        type == BlockTypes.divider ||
        type == BlockTypes.table ||
        type == BlockTypes.quote;
  }

  static int _indentLevel(String leadingWhitespace) {
    final spaces = leadingWhitespace.runes.fold<int>(
      0,
      (total, rune) => total + (rune == 0x09 ? 2 : 1),
    );
    return (spaces ~/ 2).clamp(0, 8).toInt();
  }

  static String _listIndent(BlockNode block) {
    final indent = (block.attributes['indent'] as int? ?? 0).clamp(0, 8);
    return '  ' * indent.toInt();
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

      final embed = _tryParseWikiLink(input, index, embed: true);
      if (embed != null) {
        ops.add(embed.op);
        index = embed.end;
        continue;
      }

      final wikiLink = _tryParseWikiLink(input, index, embed: false);
      if (wikiLink != null) {
        ops.add(wikiLink.op);
        index = wikiLink.end;
        continue;
      }

      final footnote = _tryParseFootnote(input, index);
      if (footnote != null) {
        ops.add(footnote.op);
        index = footnote.end;
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

      final tag = _tryParseTag(input, index);
      if (tag != null) {
        ops.add(tag.op);
        index = tag.end;
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

  static const Set<String> _htmlVoidTags = {
    'area',
    'base',
    'br',
    'col',
    'embed',
    'hr',
    'img',
    'input',
    'link',
    'meta',
    'param',
    'source',
    'track',
    'wbr',
  };

  static bool _startsRawMarkdownBlock(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return false;
    return trimmed.startsWith(r'$$') ||
        trimmed.startsWith('%%') ||
        trimmed.startsWith('<!--') ||
        trimmed.startsWith('<!') ||
        trimmed.startsWith('<?') ||
        trimmed.startsWith('</') ||
        _footnoteDefinitionPattern.hasMatch(line) ||
        _referenceDefinitionPattern.hasMatch(line) ||
        _blockIdPattern.hasMatch(line) ||
        _htmlBlockStartPattern.hasMatch(line);
  }

  static ({BlockNode block, int nextIndex})? _tryParseMathBlock(
    List<String> lines,
    int index,
  ) {
    final trimmed = lines[index].trim();
    if (!trimmed.startsWith(r'$$')) return null;

    if (trimmed.length > 2 && trimmed.endsWith(r'$$')) {
      return _mathBlockFromSource(
        trimmed.substring(2, trimmed.length - 2).trim(),
        index + 1,
      );
    }

    final body = StringBuffer();
    var cursor = index + 1;
    while (cursor < lines.length) {
      if (lines[cursor].trim().endsWith(r'$$')) {
        return _mathBlockFromSource(body.toString(), cursor + 1);
      }
      if (body.isNotEmpty) body.write('\n');
      body.write(lines[cursor]);
      cursor++;
    }

    return null;
  }

  static ({BlockNode block, int nextIndex}) _mathBlockFromSource(
    String source,
    int nextIndex,
  ) {
    return (
      block: BlockNode(
        type: BlockTypes.math,
        delta: TextDelta.fromPlainText(source),
      ),
      nextIndex: nextIndex,
    );
  }

  static ({BlockNode block, int nextIndex})? _tryParseRawMarkdownBlock(
    List<String> lines,
    int index,
  ) {
    final line = lines[index];
    final trimmed = line.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.startsWith(r'$$')) {
      if (trimmed.length > 2 && trimmed.endsWith(r'$$')) {
        return _rawMarkdownBlockFromLines(lines, index, index + 1);
      }
      return _collectDelimitedRawMarkdown(
        lines,
        index,
        isClosingLine: (candidate, cursor) =>
            cursor > index && candidate.trim().endsWith(r'$$'),
      );
    }

    if (trimmed.startsWith('%%')) {
      if (trimmed.length > 2 && trimmed.endsWith('%%')) {
        return _rawMarkdownBlockFromLines(lines, index, index + 1);
      }
      return _collectDelimitedRawMarkdown(
        lines,
        index,
        isClosingLine: (candidate, cursor) =>
            cursor > index && candidate.trimRight().endsWith('%%'),
      );
    }

    if (trimmed.startsWith('<!--')) {
      if (trimmed.contains('-->')) {
        return _rawMarkdownBlockFromLines(lines, index, index + 1);
      }
      return _collectDelimitedRawMarkdown(
        lines,
        index,
        isClosingLine: (candidate, _) => candidate.contains('-->'),
      );
    }

    if (_footnoteDefinitionPattern.hasMatch(line) ||
        _referenceDefinitionPattern.hasMatch(line)) {
      return _collectDefinitionRawMarkdown(lines, index);
    }

    if (_blockIdPattern.hasMatch(line)) {
      return _rawMarkdownBlockFromLines(lines, index, index + 1);
    }

    if (trimmed.startsWith('<!') || trimmed.startsWith('<?')) {
      return _rawMarkdownBlockFromLines(lines, index, index + 1);
    }

    if (trimmed.startsWith('</')) {
      return _rawMarkdownBlockFromLines(lines, index, index + 1);
    }

    final htmlStart = _htmlBlockStartPattern.firstMatch(line);
    if (htmlStart == null) return null;

    final tag = htmlStart.group(1)!;
    final tagLower = tag.toLowerCase();
    if (_htmlVoidTags.contains(tagLower) ||
        trimmed.endsWith('/>') ||
        _hasClosingHtmlTag(line, tag)) {
      return _rawMarkdownBlockFromLines(lines, index, index + 1);
    }

    return _collectDelimitedRawMarkdown(
      lines,
      index,
      isClosingLine: (candidate, _) => _hasClosingHtmlTag(candidate, tag),
    );
  }

  static ({BlockNode block, int nextIndex}) _collectDelimitedRawMarkdown(
    List<String> lines,
    int index, {
    required bool Function(String line, int cursor) isClosingLine,
  }) {
    var cursor = index + 1;
    while (cursor < lines.length) {
      if (isClosingLine(lines[cursor], cursor)) {
        return _rawMarkdownBlockFromLines(lines, index, cursor + 1);
      }
      cursor++;
    }
    return _rawMarkdownBlockFromLines(lines, index, index + 1);
  }

  static ({BlockNode block, int nextIndex}) _collectDefinitionRawMarkdown(
    List<String> lines,
    int index,
  ) {
    var cursor = index + 1;
    while (cursor < lines.length) {
      final line = lines[cursor];
      if (line.trim().isEmpty) {
        final next = cursor + 1;
        if (next < lines.length && _isIndentedContinuation(lines[next])) {
          cursor++;
          continue;
        }
        break;
      }
      if (!_isIndentedContinuation(line)) break;
      cursor++;
    }
    return _rawMarkdownBlockFromLines(lines, index, cursor);
  }

  static bool _isIndentedContinuation(String line) {
    return line.startsWith('\t') || line.startsWith('  ');
  }

  static bool _hasClosingHtmlTag(String line, String tag) {
    return RegExp(
      '</\\s*${RegExp.escape(tag)}\\s*>',
      caseSensitive: false,
    ).hasMatch(line);
  }

  static ({BlockNode block, int nextIndex}) _rawMarkdownBlockFromLines(
    List<String> lines,
    int start,
    int end,
  ) {
    return (
      block: BlockNode(
        type: BlockTypes.rawMarkdown,
        delta: TextDelta.fromPlainText(lines.sublist(start, end).join('\n')),
      ),
      nextIndex: end,
    );
  }

  static ({BlockNode block, int nextIndex})? _tryParseFrontmatter(
    List<String> lines,
    int index,
  ) {
    if (lines[index].trim() != '---') return null;
    final body = StringBuffer();
    var cursor = index + 1;
    while (cursor < lines.length) {
      if (lines[cursor].trim() == '---') {
        return (
          block: BlockNode(
            type: BlockTypes.code,
            attributes: const {'language': 'yaml', 'frontmatter': true},
            delta: TextDelta.fromPlainText(body.toString()),
          ),
          nextIndex: cursor + 1,
        );
      }
      if (body.isNotEmpty) body.write('\n');
      body.write(lines[cursor]);
      cursor++;
    }
    return null;
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

  static ({BlockNode block, int nextIndex}) _parseCallout(
    List<String> lines,
    int index,
    RegExpMatch match,
  ) {
    final variant = (match.group(1) ?? 'note').toLowerCase();
    final fold = match.group(2);
    final title = match.group(3)?.trim();
    final body = StringBuffer();
    index++;

    while (index < lines.length && lines[index].trimLeft().startsWith('>')) {
      if (body.isNotEmpty) body.write('\n');
      body.write(lines[index].trimLeft().replaceFirst(RegExp(r'^>\s?'), ''));
      index++;
    }

    return (
      block: BlockNode(
        type: BlockTypes.callout,
        attributes: {
          'variant': variant,
          if (title != null && title.isNotEmpty) 'title': title,
          if (fold != null) 'expanded': fold == '+',
        },
        delta: body.isEmpty ? TextDelta.empty() : _parseInline(body.toString()),
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
    if (trimmed.endsWith('|') && !_isEscapedAt(trimmed, trimmed.length - 1)) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return _splitUnescapedPipes(trimmed)
        .map(
          (cell) => cell.trim().replaceAll(
            RegExp(r'<br\s*/?>', caseSensitive: false),
            '\n',
          ),
        )
        .toList();
  }

  static List<String> _splitUnescapedPipes(String input) {
    final cells = <String>[];
    final buffer = StringBuffer();
    var escaping = false;
    var inlineCode = false;
    var wikiLinkDepth = 0;
    var linkLabelDepth = 0;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (escaping) {
        if (char == '|') {
          buffer.write('|');
        } else {
          buffer
            ..write('\\')
            ..write(char);
        }
        escaping = false;
        continue;
      }
      if (char == '\\') {
        escaping = true;
        continue;
      }
      if (char == '`') {
        inlineCode = !inlineCode;
        buffer.write(char);
        continue;
      }

      if (!inlineCode && input.startsWith('[[', i)) {
        wikiLinkDepth++;
        buffer.write('[[');
        i++;
        continue;
      }
      if (!inlineCode && wikiLinkDepth > 0 && input.startsWith(']]', i)) {
        wikiLinkDepth--;
        buffer.write(']]');
        i++;
        continue;
      }

      if (!inlineCode && wikiLinkDepth == 0 && char == '[') {
        linkLabelDepth++;
        buffer.write(char);
        continue;
      }
      if (!inlineCode &&
          wikiLinkDepth == 0 &&
          linkLabelDepth > 0 &&
          char == ']') {
        linkLabelDepth--;
        buffer.write(char);
        continue;
      }

      if (char == '|' &&
          !inlineCode &&
          wikiLinkDepth == 0 &&
          linkLabelDepth == 0) {
        cells.add(buffer.toString());
        buffer.clear();
        continue;
      }
      buffer.write(char);
    }
    if (escaping) buffer.write('\\');
    cells.add(buffer.toString());
    return cells;
  }

  static bool _isEscapedAt(String input, int index) {
    var slashCount = 0;
    for (var i = index - 1; i >= 0 && input[i] == '\\'; i--) {
      slashCount++;
    }
    return slashCount.isOdd;
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

  static _FormattedToken? _tryParseWikiLink(
    String input,
    int index, {
    required bool embed,
  }) {
    final prefix = embed ? '![[' : '[[';
    if (!input.startsWith(prefix, index)) return null;
    final close = input.indexOf(']]', index + prefix.length);
    if (close < 0) return null;
    final raw = input.substring(index + prefix.length, close);
    if (raw.trim().isEmpty) return null;
    final separator = raw.indexOf('|');
    final target = separator >= 0
        ? raw.substring(0, separator).trim()
        : raw.trim();
    final label = separator >= 0 ? raw.substring(separator + 1).trim() : target;
    if (target.isEmpty) return null;
    return _FormattedToken(
      op: TextOp(
        label.isEmpty ? target : label,
        attributes: InlineAttributes(
          wikiLink: target,
          embed: embed ? true : null,
        ),
      ),
      end: close + 2,
    );
  }

  static _FormattedToken? _tryParseFootnote(String input, int index) {
    if (!input.startsWith('[^', index)) return null;
    final close = input.indexOf(']', index + 2);
    if (close < 0) return null;
    final id = input.substring(index + 2, close).trim();
    if (id.isEmpty || id.contains('\n')) return null;
    return _FormattedToken(
      op: TextOp('[^$id]', attributes: InlineAttributes(footnote: id)),
      end: close + 1,
    );
  }

  static _FormattedToken? _tryParseTag(String input, int index) {
    if (!input.startsWith('#', index)) return null;
    if (index > 0 && _isTagBodyRune(input.codeUnitAt(index - 1))) {
      return null;
    }
    final start = index + 1;
    if (start >= input.length || !_isTagBodyRune(input.codeUnitAt(start))) {
      return null;
    }
    var end = start;
    while (end < input.length && _isTagBodyRune(input.codeUnitAt(end))) {
      end++;
    }
    final tag = input.substring(start, end);
    if (!tag.contains(RegExp(r'[A-Za-z_]'))) return null;
    return _FormattedToken(op: TagOp(tag), end: end);
  }

  static bool _isTagBodyRune(int codeUnit) {
    return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
        (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
        (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
        codeUnit == 0x2D ||
        codeUnit == 0x2F ||
        codeUnit == 0x5F;
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
    if (input.startsWith('==', index)) {
      return _formatted(
        input,
        index,
        '==',
        const InlineAttributes(highlight: true),
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
    for (final marker in const [
      '{{',
      '![[',
      '[[',
      '[^',
      '[',
      '#',
      '***',
      '**',
      '~~',
      '==',
      '`',
      '*',
    ]) {
      final found = input.indexOf(marker, start);
      if (found >= 0 && found < next) next = found;
    }
    return next;
  }
}

final class _FormattedToken {
  const _FormattedToken({required this.op, required this.end});

  final DeltaOp op;
  final int end;
}

final class _LinkToken {
  const _LinkToken({required this.label, required this.url, required this.end});

  final String label;
  final String url;
  final int end;
}
