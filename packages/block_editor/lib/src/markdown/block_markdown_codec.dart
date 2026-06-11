library;

import 'dart:convert';

import 'package:block_editor/block_editor.dart';

/// Converts between Markdown text and the block_editor document model.
///
/// The codec intentionally targets the Markdown forms that map cleanly to the
/// built-in block types. Unsupported block constructs are preserved as raw
/// Markdown blocks instead of being degraded or dropped.
abstract final class BlockMarkdownCodec {
  /// One-based source start line attached to blocks decoded from Markdown.
  static const String sourceStartLineAttribute = 'sourceStartLine';

  /// One-based inclusive source end line attached to decoded Markdown blocks.
  static const String sourceEndLineAttribute = 'sourceEndLine';

  /// Zero-based source start offset attached to decoded Markdown blocks.
  static const String sourceStartOffsetAttribute = 'sourceStartOffset';

  /// Zero-based exclusive source end offset attached to decoded Markdown blocks.
  static const String sourceEndOffsetAttribute = 'sourceEndOffset';

  /// Exact original Markdown slice for a decoded block.
  static const String sourceMarkdownAttribute = 'sourceMarkdown';

  /// Semantic fingerprint recorded at decode time for change detection.
  static const String sourceFingerprintAttribute = 'sourceFingerprint';

  static const String _sourceLeadingWhitespaceAttribute =
      'sourceLeadingWhitespace';

  static const Set<String> _sourceAttributeKeys = {
    sourceStartLineAttribute,
    sourceEndLineAttribute,
    sourceStartOffsetAttribute,
    sourceEndOffsetAttribute,
    sourceMarkdownAttribute,
    sourceFingerprintAttribute,
    _sourceLeadingWhitespaceAttribute,
  };

  static const Set<String> _transientAttributeKeys = {
    'number',
    'textAlign',
    'tableColumnWidths',
    'tableRowHeights',
  };

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

  /// Inspects [markdown] for source-fidelity behavior without mutating it.
  ///
  /// This is intended for host diagnostics, fixture tests, and future source
  /// preservation work. It answers the most important trust question for a
  /// Markdown editor: "will this document come back as the same Markdown?"
  static BlockMarkdownFidelityReport inspect(String markdown) {
    final normalized = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final normalizedSource = normalized.trimRight();
    final document = decode(normalized);
    final encoded = encode(document);
    final normalizedEncoded = encodeNormalized(document);
    final issues = <BlockMarkdownFidelityIssue>[];
    final rawKinds = <String, int>{};

    for (final block in document.flatten()) {
      if (block.type != BlockTypes.rawMarkdown) continue;
      final kind = (block.attributes['rawKind'] as String?) ?? 'rawMarkdown';
      rawKinds[kind] = (rawKinds[kind] ?? 0) + 1;
      issues.add(
        BlockMarkdownFidelityIssue(
          kind: BlockMarkdownFidelityIssueKind.rawPreserved,
          severity: BlockMarkdownFidelitySeverity.info,
          message: 'Preserved unsupported Markdown as a raw block.',
          rawKind: kind,
          startLine: block.attributes[sourceStartLineAttribute] as int?,
          endLine: block.attributes[sourceEndLineAttribute] as int?,
        ),
      );
    }

    final roundTripsExactly = encoded == normalizedSource;
    if (!roundTripsExactly) {
      issues.add(
        const BlockMarkdownFidelityIssue(
          kind: BlockMarkdownFidelityIssueKind.normalizedSource,
          severity: BlockMarkdownFidelitySeverity.warning,
          message: 'Markdown output differs from the normalized input source.',
        ),
      );
    } else if (normalizedEncoded != normalizedSource) {
      issues.add(
        const BlockMarkdownFidelityIssue(
          kind: BlockMarkdownFidelityIssueKind.sourcePreserved,
          severity: BlockMarkdownFidelitySeverity.info,
          message:
              'Source-preserving encode keeps the original Markdown, but a normalized encode would differ.',
        ),
      );
    }

    final flattened = document.flatten();
    return BlockMarkdownFidelityReport(
      originalMarkdown: normalizedSource,
      encodedMarkdown: encoded,
      normalizedMarkdown: normalizedEncoded,
      roundTripsExactly: roundTripsExactly,
      normalizedRoundTripsExactly: normalizedEncoded == normalizedSource,
      blockCount: flattened.length,
      sourceBackedBlockCount: flattened.where(_hasSourceMetadata).length,
      preservedSourceBlockCount: flattened.where(_usesOriginalSource).length,
      changedSourceBlockCount: flattened
          .where(
            (block) => _hasSourceMetadata(block) && _isSourceChanged(block),
          )
          .length,
      rawMarkdownBlockCount: rawKinds.values.fold(
        0,
        (sum, count) => sum + count,
      ),
      rawMarkdownKinds: Map.unmodifiable(rawKinds),
      issues: List.unmodifiable(issues),
    );
  }

  /// Parses [markdown] into a [BlockDocument].
  static BlockDocument decode(String markdown) {
    final normalized = markdown.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (normalized.trim().isEmpty) return BlockDocument.empty();

    final lines = normalized.split('\n');
    final lineStarts = _lineStartOffsets(normalized);
    final blocks = <BlockNode>[];
    var previousSourceEndOffset = 0;
    var index = 0;

    void addBlock(BlockNode block, int startLineIndex, int endLineIndex) {
      final blockWithSource = _attachSourceMetadata(
        block,
        normalized,
        lines,
        lineStarts,
        startLineIndex,
        endLineIndex,
        previousSourceEndOffset,
      );
      blocks.add(blockWithSource);
      previousSourceEndOffset =
          blockWithSource.attributes[sourceEndOffsetAttribute] as int;
    }

    while (index < lines.length) {
      final line = lines[index];
      final trimmed = line.trim();

      if (trimmed.isEmpty) {
        index++;
        continue;
      }

      if (index == 0 && trimmed == '---') {
        final start = index;
        final parsed = _tryParseFrontmatter(lines, index);
        if (parsed != null) {
          addBlock(parsed.block, start, parsed.nextIndex);
          index = parsed.nextIndex;
          continue;
        }
      }

      if (trimmed.startsWith('```')) {
        final start = index;
        final language = trimmed.substring(3).trim();
        final code = StringBuffer();
        index++;
        while (index < lines.length && !lines[index].trim().startsWith('```')) {
          if (code.isNotEmpty) code.write('\n');
          code.write(lines[index]);
          index++;
        }
        if (index < lines.length) index++;
        addBlock(
          BlockNode(
            type: language.toLowerCase() == 'mermaid'
                ? BlockTypes.mermaid
                : BlockTypes.code,
            attributes: {if (language.isNotEmpty) 'language': language},
            delta: TextDelta.fromPlainText(code.toString()),
          ),
          start,
          index,
        );
        continue;
      }

      final mathStart = index;
      final mathBlock = _tryParseMathBlock(lines, index);
      if (mathBlock != null) {
        addBlock(mathBlock.block, mathStart, mathBlock.nextIndex);
        index = mathBlock.nextIndex;
        continue;
      }

      final rawStart = index;
      final rawMarkdown = _tryParseRawMarkdownBlock(lines, index);
      if (rawMarkdown != null) {
        addBlock(rawMarkdown.block, rawStart, rawMarkdown.nextIndex);
        index = rawMarkdown.nextIndex;
        continue;
      }

      if (_isTableStart(lines, index)) {
        final start = index;
        final parsed = _parseTable(lines, index);
        addBlock(parsed.block, start, parsed.nextIndex);
        index = parsed.nextIndex;
        continue;
      }

      final heading = _headingPattern.firstMatch(line);
      if (heading != null) {
        final start = index;
        final level = heading.group(1)!.length;
        addBlock(
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
          start,
          start + 1,
        );
        index++;
        continue;
      }

      if (_dividerPattern.hasMatch(line)) {
        addBlock(BlockNode(type: BlockTypes.divider), index, index + 1);
        index++;
        continue;
      }

      final todo = _todoPattern.firstMatch(line);
      if (todo != null) {
        final start = index;
        addBlock(
          BlockNode(
            type: BlockTypes.todo,
            attributes: {
              'checked': todo.group(2)!.toLowerCase() == 'x',
              if (_indentLevel(todo.group(1) ?? '') > 0)
                'indent': _indentLevel(todo.group(1) ?? ''),
            },
            delta: _parseInline(todo.group(3) ?? ''),
          ),
          start,
          start + 1,
        );
        index++;
        continue;
      }

      final bullet = _bulletPattern.firstMatch(line);
      if (bullet != null) {
        final start = index;
        addBlock(
          BlockNode(
            type: BlockTypes.bulletList,
            attributes: {
              if (_indentLevel(bullet.group(1) ?? '') > 0)
                'indent': _indentLevel(bullet.group(1) ?? ''),
            },
            delta: _parseInline(bullet.group(2) ?? ''),
          ),
          start,
          start + 1,
        );
        index++;
        continue;
      }

      final numbered = _numberedPattern.firstMatch(line);
      if (numbered != null) {
        final start = index;
        addBlock(
          BlockNode(
            type: BlockTypes.numberedList,
            attributes: {
              if (_indentLevel(numbered.group(1) ?? '') > 0)
                'indent': _indentLevel(numbered.group(1) ?? ''),
            },
            delta: _parseInline(numbered.group(2) ?? ''),
          ),
          start,
          start + 1,
        );
        index++;
        continue;
      }

      final callout = _calloutPattern.firstMatch(line);
      if (callout != null) {
        final start = index;
        final parsed = _parseCallout(lines, index, callout);
        addBlock(parsed.block, start, parsed.nextIndex);
        index = parsed.nextIndex;
        continue;
      }

      if (trimmed.startsWith('>')) {
        final start = index;
        final quote = StringBuffer();
        while (index < lines.length &&
            lines[index].trimLeft().startsWith('>')) {
          if (quote.isNotEmpty) quote.write('\n');
          quote.write(
            lines[index].trimLeft().replaceFirst(RegExp(r'^>\s?'), ''),
          );
          index++;
        }
        addBlock(
          BlockNode(
            type: BlockTypes.quote,
            delta: _parseInline(quote.toString()),
          ),
          start,
          index,
        );
        continue;
      }

      final image = _imagePattern.firstMatch(trimmed);
      if (image != null) {
        final start = index;
        addBlock(
          BlockNode(
            type: BlockTypes.image,
            attributes: {
              'alt': image.group(1) ?? '',
              'url': image.group(2) ?? '',
            },
          ),
          start,
          start + 1,
        );
        index++;
        continue;
      }

      final link = _linkPattern.firstMatch(trimmed);
      if (link != null) {
        final start = index;
        addBlock(
          BlockNode(
            type: BlockTypes.link,
            attributes: {
              'title': link.group(1) ?? '',
              'url': link.group(2) ?? '',
            },
            delta: TextDelta.fromPlainText(link.group(1) ?? ''),
          ),
          start,
          start + 1,
        );
        index++;
        continue;
      }

      final start = index;
      final paragraphLines = <String>[line];
      index++;
      while (index < lines.length && !_startsBlock(lines[index])) {
        if (lines[index].trim().isEmpty) break;
        paragraphLines.add(lines[index]);
        index++;
      }
      addBlock(
        BlockNode(
          type: BlockTypes.paragraph,
          delta: _parseInline(_normalizeParagraphText(paragraphLines)),
        ),
        start,
        index,
      );
    }

    return BlockDocument(
      blocks.isEmpty ? BlockDocument.empty().blocks : blocks,
    );
  }

  /// Serializes [document] into Markdown.
  ///
  /// When [document] was created by [decode], unchanged blocks reuse their
  /// original Markdown slices. This keeps valid source details such as table
  /// separator spacing, ordered-list starting numbers, raw HTML, and blank-line
  /// rhythm intact while still re-encoding blocks that were actually changed.
  static String encode(BlockDocument document) {
    if (document.flatten().any(_hasSourceMetadata)) {
      return _encodeWithSourcePreservation(document);
    }
    return encodeNormalized(document);
  }

  /// Serializes [document] into normalized Markdown without source preservation.
  ///
  /// This is useful for diagnostics and tests that need to compare the semantic
  /// Markdown shape independently from the source-preserving save path.
  static String encodeNormalized(BlockDocument document) {
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

  static String _encodeWithSourcePreservation(BlockDocument document) {
    final buffer = StringBuffer();
    final blocks = document.flatten();
    BlockNode? previousBlock;
    int? previousSourceEndOffset;

    for (final block in blocks) {
      final line = _usesOriginalSource(block)
          ? block.attributes[sourceMarkdownAttribute] as String?
          : _encodeBlock(block);
      if (line == null) continue;

      if (buffer.isNotEmpty) {
        final sourceGap = _sourceGapBeforeBlock(block, previousSourceEndOffset);
        buffer.write(sourceGap ?? _defaultGapBefore(previousBlock));
      }

      buffer.write(line);
      previousBlock = block;
      previousSourceEndOffset = _hasSourceMetadata(block)
          ? block.attributes[sourceEndOffsetAttribute] as int?
          : null;
    }

    return buffer.toString().trimRight();
  }

  static String _defaultGapBefore(BlockNode? previousBlock) {
    if (previousBlock == null) return '';
    return _separatesFromNext(previousBlock.type) ? '\n\n' : '\n';
  }

  static String? _sourceGapBeforeBlock(
    BlockNode block,
    int? previousSourceEndOffset,
  ) {
    if (previousSourceEndOffset == null || !_hasSourceMetadata(block)) {
      return null;
    }
    final sourceStart = block.attributes[sourceStartOffsetAttribute] as int?;
    final sourceGap =
        block.attributes[_sourceLeadingWhitespaceAttribute] as String?;
    if (sourceStart == null || sourceGap == null) return null;
    if (sourceStart < previousSourceEndOffset) return null;
    return sourceGap;
  }

  static List<int> _lineStartOffsets(String source) {
    final starts = <int>[0];
    for (var i = 0; i < source.length; i++) {
      if (source.codeUnitAt(i) == 0x0A) starts.add(i + 1);
    }
    return starts;
  }

  static BlockNode _attachSourceMetadata(
    BlockNode block,
    String source,
    List<String> lines,
    List<int> lineStarts,
    int startLineIndex,
    int endLineIndex,
    int previousSourceEndOffset,
  ) {
    final startOffset = _sourceStartOffset(
      lineStarts,
      startLineIndex,
      source.length,
    );
    final endOffset = _sourceEndOffset(
      lineStarts,
      lines,
      endLineIndex,
      source.length,
    );
    final safeStart = startOffset.clamp(0, source.length).toInt();
    final safeEnd = endOffset.clamp(safeStart, source.length).toInt();
    final safeGapStart = previousSourceEndOffset.clamp(0, safeStart).toInt();
    final attributes = <String, dynamic>{
      ...block.attributes,
      sourceStartLineAttribute: startLineIndex + 1,
      sourceEndLineAttribute: endLineIndex,
      sourceStartOffsetAttribute: safeStart,
      sourceEndOffsetAttribute: safeEnd,
      sourceMarkdownAttribute: source.substring(safeStart, safeEnd),
      _sourceLeadingWhitespaceAttribute: source.substring(
        safeGapStart,
        safeStart,
      ),
    };
    final semanticBlock = block.copyWith(attributes: attributes);
    attributes[sourceFingerprintAttribute] = _semanticFingerprint(
      semanticBlock,
    );
    return block.copyWith(attributes: attributes);
  }

  static int _sourceStartOffset(
    List<int> lineStarts,
    int startLineIndex,
    int sourceLength,
  ) {
    if (startLineIndex < 0) return 0;
    if (startLineIndex >= lineStarts.length) return sourceLength;
    return lineStarts[startLineIndex];
  }

  static int _sourceEndOffset(
    List<int> lineStarts,
    List<String> lines,
    int endLineIndex,
    int sourceLength,
  ) {
    if (endLineIndex <= 0) return 0;
    if (endLineIndex >= lines.length) return sourceLength;
    return (lineStarts[endLineIndex] - 1).clamp(0, sourceLength).toInt();
  }

  static bool _hasSourceMetadata(BlockNode block) {
    return block.attributes[sourceMarkdownAttribute] is String &&
        block.attributes[sourceFingerprintAttribute] is String &&
        block.attributes[sourceStartOffsetAttribute] is int &&
        block.attributes[sourceEndOffsetAttribute] is int;
  }

  static bool _usesOriginalSource(BlockNode block) {
    return _hasSourceMetadata(block) && !_isSourceChanged(block);
  }

  static bool _isSourceChanged(BlockNode block) {
    final original = block.attributes[sourceFingerprintAttribute] as String?;
    if (original == null) return true;
    return original != _semanticFingerprint(block);
  }

  static String _semanticFingerprint(BlockNode block) {
    return jsonEncode(_stableJson(_semanticBlockJson(block)));
  }

  static Map<String, Object?> _semanticBlockJson(BlockNode block) {
    final attributes = _semanticAttributes(block.attributes);
    return {
      'type': block.type,
      if (attributes.isNotEmpty) 'attributes': attributes,
      if (block.delta != null) 'delta': block.delta!.toJson(),
      if (block.children.isNotEmpty)
        'children': block.children.map(_semanticBlockJson).toList(),
    };
  }

  static Map<String, Object?> _semanticAttributes(
    Map<String, dynamic> attributes,
  ) {
    final result = <String, Object?>{};
    final keys =
        attributes.keys
            .where(
              (key) =>
                  !_sourceAttributeKeys.contains(key) &&
                  !_transientAttributeKeys.contains(key),
            )
            .toList()
          ..sort();
    for (final key in keys) {
      result[key] = _stableJson(attributes[key]);
    }
    return result;
  }

  static Object? _stableJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return {
        for (final key in keys)
          key: _stableJson(
            value.entries
                .firstWhere((entry) => entry.key.toString() == key)
                .value,
          ),
      };
    }
    if (value is Iterable) {
      return value.map(_stableJson).toList();
    }
    return value;
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

  static String _normalizeParagraphText(List<String> lines) {
    if (lines.isEmpty) return '';

    final buffer = StringBuffer();
    var previousWasHardBreak = false;

    for (var i = 0; i < lines.length; i++) {
      final isLast = i == lines.length - 1;
      final line = lines[i];
      final currentHasHardBreak = !isLast && _hasMarkdownHardLineBreak(line);
      final text = _stripMarkdownHardLineBreak(line);

      if (i == 0) {
        buffer.write(text.trimRight());
      } else {
        buffer.write(previousWasHardBreak ? '\n' : ' ');
        buffer.write(text.trimLeft().trimRight());
      }

      previousWasHardBreak = currentHasHardBreak;
    }

    return buffer.toString();
  }

  static bool _hasMarkdownHardLineBreak(String line) {
    if (line.endsWith(r'\')) return true;
    return RegExp(r' {2,}$').hasMatch(line);
  }

  static String _stripMarkdownHardLineBreak(String line) {
    if (line.endsWith(r'\')) {
      return line.substring(0, line.length - 1).trimRight();
    }
    return line.trimRight();
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
        return _rawMarkdownBlockFromLines(
          lines,
          index,
          index + 1,
          rawKind: 'math',
        );
      }
      return _collectDelimitedRawMarkdown(
        lines,
        index,
        rawKind: 'math',
        isClosingLine: (candidate, cursor) =>
            cursor > index && candidate.trim().endsWith(r'$$'),
      );
    }

    if (trimmed.startsWith('%%')) {
      if (trimmed.length > 2 && trimmed.endsWith('%%')) {
        return _rawMarkdownBlockFromLines(
          lines,
          index,
          index + 1,
          rawKind: 'obsidianComment',
        );
      }
      return _collectDelimitedRawMarkdown(
        lines,
        index,
        rawKind: 'obsidianComment',
        isClosingLine: (candidate, cursor) =>
            cursor > index && candidate.trimRight().endsWith('%%'),
      );
    }

    if (trimmed.startsWith('<!--')) {
      if (trimmed.contains('-->')) {
        return _rawMarkdownBlockFromLines(
          lines,
          index,
          index + 1,
          rawKind: 'htmlComment',
        );
      }
      return _collectDelimitedRawMarkdown(
        lines,
        index,
        rawKind: 'htmlComment',
        isClosingLine: (candidate, _) => candidate.contains('-->'),
      );
    }

    if (_footnoteDefinitionPattern.hasMatch(line)) {
      return _collectDefinitionRawMarkdown(
        lines,
        index,
        rawKind: 'footnoteDefinition',
      );
    }

    if (_referenceDefinitionPattern.hasMatch(line)) {
      return _collectDefinitionRawMarkdown(
        lines,
        index,
        rawKind: 'referenceDefinition',
      );
    }

    if (_blockIdPattern.hasMatch(line)) {
      return _rawMarkdownBlockFromLines(
        lines,
        index,
        index + 1,
        rawKind: 'blockId',
      );
    }

    if (trimmed.startsWith('<!') || trimmed.startsWith('<?')) {
      return _rawMarkdownBlockFromLines(
        lines,
        index,
        index + 1,
        rawKind: 'htmlDeclaration',
      );
    }

    if (trimmed.startsWith('</')) {
      return _rawMarkdownBlockFromLines(
        lines,
        index,
        index + 1,
        rawKind: 'html',
      );
    }

    final htmlStart = _htmlBlockStartPattern.firstMatch(line);
    if (htmlStart == null) return null;

    final tag = htmlStart.group(1)!;
    final tagLower = tag.toLowerCase();
    if (_htmlVoidTags.contains(tagLower) ||
        trimmed.endsWith('/>') ||
        _hasClosingHtmlTag(line, tag)) {
      return _rawMarkdownBlockFromLines(
        lines,
        index,
        index + 1,
        rawKind: 'html',
      );
    }

    return _collectDelimitedRawMarkdown(
      lines,
      index,
      rawKind: 'html',
      isClosingLine: (candidate, _) => _hasClosingHtmlTag(candidate, tag),
    );
  }

  static ({BlockNode block, int nextIndex}) _collectDelimitedRawMarkdown(
    List<String> lines,
    int index, {
    required String rawKind,
    required bool Function(String line, int cursor) isClosingLine,
  }) {
    var cursor = index + 1;
    while (cursor < lines.length) {
      if (isClosingLine(lines[cursor], cursor)) {
        return _rawMarkdownBlockFromLines(
          lines,
          index,
          cursor + 1,
          rawKind: rawKind,
        );
      }
      cursor++;
    }
    return _rawMarkdownBlockFromLines(
      lines,
      index,
      index + 1,
      rawKind: rawKind,
    );
  }

  static ({BlockNode block, int nextIndex}) _collectDefinitionRawMarkdown(
    List<String> lines,
    int index, {
    required String rawKind,
  }) {
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
    return _rawMarkdownBlockFromLines(lines, index, cursor, rawKind: rawKind);
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
    int end, {
    required String rawKind,
  }) {
    return (
      block: BlockNode(
        type: BlockTypes.rawMarkdown,
        attributes: {
          'rawKind': rawKind,
          sourceStartLineAttribute: start + 1,
          sourceEndLineAttribute: end,
        },
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

/// Severity for Markdown source-fidelity diagnostics.
enum BlockMarkdownFidelitySeverity {
  /// Informational note. The source is still preserved.
  info,

  /// Source output changed during decode/encode and should be reviewed.
  warning,
}

/// Category for a Markdown source-fidelity diagnostic.
enum BlockMarkdownFidelityIssueKind {
  /// Unsupported Markdown was preserved as an explicit raw Markdown block.
  rawPreserved,

  /// Source preservation kept Markdown that normalized encoding would rewrite.
  sourcePreserved,

  /// Re-encoding changed the Markdown string compared with normalized input.
  normalizedSource,
}

/// One source-fidelity diagnostic produced by [BlockMarkdownCodec.inspect].
final class BlockMarkdownFidelityIssue {
  /// Creates a Markdown source-fidelity diagnostic.
  const BlockMarkdownFidelityIssue({
    required this.kind,
    required this.severity,
    required this.message,
    this.rawKind,
    this.startLine,
    this.endLine,
  });

  /// The issue category.
  final BlockMarkdownFidelityIssueKind kind;

  /// The issue severity.
  final BlockMarkdownFidelitySeverity severity;

  /// Human-readable diagnostic message.
  final String message;

  /// Raw Markdown subtype when this issue describes raw preservation.
  final String? rawKind;

  /// One-based source start line when the diagnostic maps to a source span.
  final int? startLine;

  /// One-based inclusive source end line when the diagnostic maps to a source
  /// span.
  final int? endLine;
}

/// Source-fidelity summary for a Markdown decode/encode cycle.
final class BlockMarkdownFidelityReport {
  /// Creates a Markdown source-fidelity summary.
  const BlockMarkdownFidelityReport({
    required this.originalMarkdown,
    required this.encodedMarkdown,
    required this.normalizedMarkdown,
    required this.roundTripsExactly,
    required this.normalizedRoundTripsExactly,
    required this.blockCount,
    required this.sourceBackedBlockCount,
    required this.preservedSourceBlockCount,
    required this.changedSourceBlockCount,
    required this.rawMarkdownBlockCount,
    required this.rawMarkdownKinds,
    required this.issues,
  });

  /// Normalized input Markdown with trailing whitespace trimmed the same way as
  /// [BlockMarkdownCodec.encode].
  final String originalMarkdown;

  /// Markdown produced after decode/encode.
  ///
  /// This is the source-preserving output used by [BlockMarkdownCodec.encode].
  final String encodedMarkdown;

  /// Markdown produced by normalized semantic encoding without source reuse.
  final String normalizedMarkdown;

  /// Whether [encodedMarkdown] exactly matches [originalMarkdown].
  final bool roundTripsExactly;

  /// Whether [normalizedMarkdown] exactly matches [originalMarkdown].
  final bool normalizedRoundTripsExactly;

  /// Number of flattened document blocks produced by decoding.
  final int blockCount;

  /// Number of blocks that carry original source metadata.
  final int sourceBackedBlockCount;

  /// Number of source-backed blocks currently emitted from original source.
  final int preservedSourceBlockCount;

  /// Number of source-backed blocks whose semantic content changed since
  /// decode.
  final int changedSourceBlockCount;

  /// Number of preserved raw Markdown blocks.
  final int rawMarkdownBlockCount;

  /// Preserved raw Markdown counts by raw kind.
  final Map<String, int> rawMarkdownKinds;

  /// Diagnostics from the inspection pass.
  final List<BlockMarkdownFidelityIssue> issues;

  /// Whether the report contains any warning.
  bool get hasWarnings => issues.any(
    (issue) => issue.severity == BlockMarkdownFidelitySeverity.warning,
  );
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
