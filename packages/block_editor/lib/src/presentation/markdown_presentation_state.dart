library;

import 'dart:convert';

import '../model/block_document.dart';
import '../model/block_node.dart';

/// Presentation-only Markdown state keyed by stable block fingerprints.
///
/// This object is intentionally separate from the Markdown codec. Hosts can
/// persist it under a workspace-local `.vten` directory and reapply it after a
/// Markdown file is decoded, without writing nonstandard layout metadata back
/// into the `.md` file.
final class MarkdownPresentationState {
  /// Creates presentation state for a Markdown-backed document.
  const MarkdownPresentationState({
    this.schemaVersion = 1,
    this.documentId,
    this.blocks = const {},
  });

  /// Captures presentation attributes from [document].
  factory MarkdownPresentationState.capture(
    BlockDocument document, {
    String? documentId,
  }) {
    final keyBuilder = _MarkdownBlockKeyBuilder();
    final blocks = <String, MarkdownBlockPresentation>{};

    for (final block in document.flatten()) {
      final keys = keyBuilder.nextKeys(block);
      final presentation = MarkdownBlockPresentation.fromBlock(block);
      if (!presentation.isEmpty) {
        for (final key in keys.persistedKeys) {
          blocks[key] = presentation;
        }
      }
    }

    return MarkdownPresentationState(
      documentId: documentId,
      blocks: Map.unmodifiable(blocks),
    );
  }

  /// Decodes presentation state from JSON.
  factory MarkdownPresentationState.fromJson(Map<String, Object?> json) {
    final rawBlocks = json['blocks'];
    final blocks = <String, MarkdownBlockPresentation>{};
    if (rawBlocks is Map) {
      for (final entry in rawBlocks.entries) {
        final value = entry.value;
        if (value is! Map) continue;
        final presentation = MarkdownBlockPresentation.fromJson(
          value.cast<String, Object?>(),
        );
        if (!presentation.isEmpty) {
          blocks[entry.key.toString()] = presentation;
        }
      }
    }

    return MarkdownPresentationState(
      schemaVersion: _parseInt(json['schemaVersion']) ?? 1,
      documentId: json['documentId']?.toString(),
      blocks: Map.unmodifiable(blocks),
    );
  }

  /// Current schema version.
  final int schemaVersion;

  /// Host-provided document identity, usually workspace-relative file path.
  final String? documentId;

  /// Presentation records keyed by deterministic block key.
  final Map<String, MarkdownBlockPresentation> blocks;

  /// Whether this state contains no presentation records.
  bool get isEmpty => blocks.isEmpty;

  /// Applies matching presentation attributes onto [document].
  BlockDocument applyTo(BlockDocument document) {
    if (blocks.isEmpty) return document;
    final keyBuilder = _MarkdownBlockKeyBuilder();
    return document.copyWith(blocks: _applyBlocks(document.blocks, keyBuilder));
  }

  /// Serializes this state to JSON.
  Map<String, Object?> toJson() {
    return {
      'schemaVersion': schemaVersion,
      if (documentId != null) 'documentId': documentId,
      'blocks': {
        for (final entry in blocks.entries) entry.key: entry.value.toJson(),
      },
    };
  }

  List<BlockNode> _applyBlocks(
    List<BlockNode> source,
    _MarkdownBlockKeyBuilder keyBuilder,
  ) {
    return [for (final block in source) _applyBlock(block, keyBuilder)];
  }

  BlockNode _applyBlock(BlockNode block, _MarkdownBlockKeyBuilder keyBuilder) {
    final keys = keyBuilder.nextKeys(block);
    final presentation = _presentationForKeys(keys.lookupKeys);
    final children = _applyBlocks(block.children, keyBuilder);
    final attributes = presentation == null
        ? block.attributes
        : {...block.attributes, ...presentation.toAttributes()};
    if (identical(children, block.children) && presentation == null) {
      return block;
    }
    return block.copyWith(attributes: attributes, children: children);
  }

  MarkdownBlockPresentation? _presentationForKeys(Iterable<String> keys) {
    for (final key in keys) {
      final presentation = blocks[key];
      if (presentation != null) return presentation;
    }
    return null;
  }
}

/// Presentation-only attributes for one Markdown block.
final class MarkdownBlockPresentation {
  /// Creates a block presentation record.
  const MarkdownBlockPresentation({
    this.textAlign,
    this.tableColumnWidths = const {},
    this.tableRowHeights = const {},
  });

  /// Captures presentation attributes from [block].
  factory MarkdownBlockPresentation.fromBlock(BlockNode block) {
    return MarkdownBlockPresentation(
      textAlign: _normalizeTextAlign(block.attributes['textAlign']),
      tableColumnWidths: _parseDimensionMap(
        block.attributes['tableColumnWidths'],
      ),
      tableRowHeights: _parseDimensionMap(block.attributes['tableRowHeights']),
    );
  }

  /// Decodes a block presentation record from JSON.
  factory MarkdownBlockPresentation.fromJson(Map<String, Object?> json) {
    return MarkdownBlockPresentation(
      textAlign: _normalizeTextAlign(json['textAlign']),
      tableColumnWidths: _parseDimensionMap(json['tableColumnWidths']),
      tableRowHeights: _parseDimensionMap(json['tableRowHeights']),
    );
  }

  /// Block-level alignment: `left`, `center`, or `right`.
  final String? textAlign;

  /// Future table column widths keyed by zero-based column index.
  final Map<int, double> tableColumnWidths;

  /// Future table row heights keyed by zero-based row index.
  final Map<int, double> tableRowHeights;

  /// Whether this record carries no presentation data.
  bool get isEmpty =>
      textAlign == null && tableColumnWidths.isEmpty && tableRowHeights.isEmpty;

  /// Converts this presentation record into block attributes.
  Map<String, dynamic> toAttributes() {
    return {
      if (textAlign != null) 'textAlign': textAlign,
      if (tableColumnWidths.isNotEmpty)
        'tableColumnWidths': _dimensionMapToJson(tableColumnWidths),
      if (tableRowHeights.isNotEmpty)
        'tableRowHeights': _dimensionMapToJson(tableRowHeights),
    };
  }

  /// Serializes this record to JSON.
  Map<String, Object?> toJson() {
    return {
      if (textAlign != null) 'textAlign': textAlign,
      if (tableColumnWidths.isNotEmpty)
        'tableColumnWidths': _dimensionMapToJson(tableColumnWidths),
      if (tableRowHeights.isNotEmpty)
        'tableRowHeights': _dimensionMapToJson(tableRowHeights),
    };
  }

  static String? _normalizeTextAlign(Object? value) {
    final raw = value?.toString();
    return switch (raw) {
      'start' => 'left',
      'end' => 'right',
      'left' || 'center' || 'right' => raw,
      _ => null,
    };
  }

  static Map<int, double> _parseDimensionMap(Object? value) {
    if (value is! Map) return const {};
    final result = <int, double>{};
    for (final entry in value.entries) {
      final key = int.tryParse(entry.key.toString());
      final dimension = _parseDouble(entry.value);
      if (key == null || dimension == null || !dimension.isFinite) continue;
      result[key] = dimension;
    }
    return Map.unmodifiable(result);
  }

  static Map<String, Object?> _dimensionMapToJson(Map<int, double> value) {
    return {
      for (final entry in value.entries) entry.key.toString(): entry.value,
    };
  }
}

final class _MarkdownBlockKeyBuilder {
  final Map<String, int> _occurrences = {};

  ({List<String> persistedKeys, List<String> lookupKeys}) nextKeys(
    BlockNode block,
  ) {
    final fingerprint = _fingerprint(block);
    final occurrence = _occurrences.update(
      fingerprint,
      (value) => value + 1,
      ifAbsent: () => 0,
    );
    final sourceKey = _sourceKey(block, fingerprint);
    final occurrenceKey = 'v2:${block.type}:$fingerprint:occ:$occurrence';
    final legacyOccurrenceKey = 'v1:${block.type}:$fingerprint:$occurrence';
    return (
      persistedKeys: [?sourceKey, occurrenceKey],
      lookupKeys: [?sourceKey, occurrenceKey, legacyOccurrenceKey],
    );
  }

  String _fingerprint(BlockNode block) {
    final signature = jsonEncode(_stableJson(_semanticBlockJson(block)));
    return _stableHash(signature);
  }

  String? _sourceKey(BlockNode block, String fingerprint) {
    final start = _parseInt(block.attributes['sourceStartOffset']);
    final end = _parseInt(block.attributes['sourceEndOffset']);
    final source = block.attributes['sourceMarkdown'];
    if (start == null || end == null || source is! String) return null;
    return 'v2:${block.type}:$fingerprint:src:$start:$end:${_stableHash(source)}';
  }

  Map<String, Object?> _semanticBlockJson(BlockNode block) {
    final attributes = _semanticAttributes(block.attributes);
    return {
      'type': block.type,
      if (attributes.isNotEmpty) 'attributes': attributes,
      if (block.delta != null) 'delta': block.delta!.toJson(),
      if (block.children.isNotEmpty)
        'children': block.children.map(_semanticBlockJson).toList(),
    };
  }

  Map<String, Object?> _semanticAttributes(Map<String, dynamic> attributes) {
    final result = <String, Object?>{};
    final keys =
        attributes.keys
            .where((key) => !_transientAttributeKeys.contains(key))
            .toList()
          ..sort();
    for (final key in keys) {
      result[key] = _stableJson(attributes[key]);
    }
    return result;
  }
}

const Set<String> _transientAttributeKeys = {
  'number',
  'sourceStartLine',
  'sourceEndLine',
  'sourceStartOffset',
  'sourceEndOffset',
  'sourceMarkdown',
  'sourceFingerprint',
  'sourceLeadingWhitespace',
  'textAlign',
  'tableColumnWidths',
  'tableRowHeights',
};

Object? _stableJson(Object? value) {
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

String _stableHash(String input) {
  const mask = 0xFFFFFFFFFFFFFFFF;
  var hash = 0xcbf29ce484222325;
  for (final byte in utf8.encode(input)) {
    hash ^= byte;
    hash = (hash * 0x100000001b3) & mask;
  }
  return hash.toRadixString(16).padLeft(16, '0');
}

int? _parseInt(Object? value) {
  if (value is int) return value;
  return int.tryParse(value?.toString() ?? '');
}

double? _parseDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '');
}
