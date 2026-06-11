import 'dart:convert';
import 'dart:io';

import 'package:block_editor/block_editor.dart';

import 'vten_storage_paths.dart';

/// Non-Markdown reader preferences persisted beside the local workspace.
///
/// These settings affect how a Markdown document is presented, but they are
/// intentionally not encoded back into the `.md` file.
final class VtenReaderPreferences {
  const VtenReaderPreferences({
    this.density = MarkdownDocumentDensity.comfortable,
    this.contentAlignment = MarkdownDocumentContentAlignment.centered,
  });

  final MarkdownDocumentDensity density;
  final MarkdownDocumentContentAlignment contentAlignment;

  factory VtenReaderPreferences.fromJson(Map<String, Object?> json) {
    return VtenReaderPreferences(
      density: _parseDensity(json['density']),
      contentAlignment: _parseAlignment(json['contentAlignment']),
    );
  }

  Map<String, Object?> toJson() {
    return {
      'schemaVersion': 1,
      'density': density.name,
      'contentAlignment': contentAlignment.name,
    };
  }

  static MarkdownDocumentDensity _parseDensity(Object? value) {
    final raw = value?.toString();
    return MarkdownDocumentDensity.values.firstWhere(
      (density) => density.name == raw,
      orElse: () => MarkdownDocumentDensity.comfortable,
    );
  }

  static MarkdownDocumentContentAlignment _parseAlignment(Object? value) {
    final raw = value?.toString();
    return MarkdownDocumentContentAlignment.values.firstWhere(
      (alignment) => alignment.name == raw,
      orElse: () => MarkdownDocumentContentAlignment.centered,
    );
  }
}

/// Reads and writes the block editor reader preferences under `.vten`.
final class VtenReaderPreferencesStore {
  VtenReaderPreferencesStore({Directory? rootDirectory})
    : _rootDirectory = rootDirectory;

  final Directory? _rootDirectory;

  Future<VtenReaderPreferences?> load() async {
    try {
      final file = await _preferencesFile();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      return VtenReaderPreferences.fromJson(decoded);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(VtenReaderPreferences preferences) async {
    try {
      final file = await _preferencesFile();
      await file.parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString('${encoder.convert(preferences.toJson())}\n');
    } on FileSystemException {
      // Reader preferences are presentation-only. The demo should keep editing
      // available even when macOS sandboxing denies source-tree file access.
    }
  }

  Future<File> _preferencesFile() async {
    final root =
        _rootDirectory ?? await VtenStoragePaths.resolveBlockEditorRoot();
    return File(
      VtenStoragePaths.joinAll([
        root.path,
        '.vten',
        'block_editor',
        'reader_preferences.json',
      ]),
    );
  }
}
