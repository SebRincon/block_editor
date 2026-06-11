import 'dart:convert';
import 'dart:io';

import 'package:block_editor/block_editor.dart';

import 'vten_storage_paths.dart';

/// Reads and writes per-document Markdown presentation state under `.vten`.
///
/// The stored JSON is keyed by a host-provided document id, typically a
/// workspace-relative Markdown path in CodeForge. The Markdown file remains the
/// source of truth for content; this store only keeps view/editing preferences
/// such as block alignment.
final class VtenPresentationStateStore {
  VtenPresentationStateStore({Directory? rootDirectory})
    : _rootDirectory = rootDirectory;

  final Directory? _rootDirectory;

  /// Loads presentation state for [documentId].
  Future<MarkdownPresentationState?> load(String documentId) async {
    try {
      final file = await presentationFile(documentId);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      return MarkdownPresentationState.fromJson(decoded);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  /// Saves presentation state for [documentId].
  Future<void> save(
    String documentId,
    MarkdownPresentationState presentationState,
  ) async {
    try {
      final file = await presentationFile(documentId);
      if (presentationState.isEmpty) {
        if (await file.exists()) await file.delete();
        return;
      }
      await file.parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString(
        '${encoder.convert(presentationState.toJson())}\n',
      );
    } on FileSystemException {
      // Presentation state is recoverable. Keep the editor usable when a
      // sandboxed macOS launch cannot write back to the package checkout.
    }
  }

  /// Returns the JSON file used for [documentId].
  Future<File> presentationFile(String documentId) async {
    final root =
        _rootDirectory ?? await VtenStoragePaths.resolveBlockEditorRoot();
    final storageKey = VtenStoragePaths.stableStorageKey(
      documentId.trim().isEmpty ? 'untitled' : documentId,
    );
    return File(
      VtenStoragePaths.joinAll([
        root.path,
        '.vten',
        'block_editor',
        'presentation',
        '$storageKey.json',
      ]),
    );
  }
}
