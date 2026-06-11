import 'dart:convert';
import 'dart:io';

/// Shared `.vten` path helpers for the block editor example app.
final class VtenStoragePaths {
  const VtenStoragePaths._();

  /// Resolves the nearest block editor package root.
  static Future<Directory> resolveBlockEditorRoot() async {
    final candidates = <Directory>[
      Directory.current,
      File(Platform.resolvedExecutable).parent,
    ];

    for (final candidate in candidates) {
      final root = await findNearestBlockEditorRoot(candidate.absolute);
      if (root != null) return root;
    }

    return Directory.current.absolute;
  }

  /// Finds the closest package root from [start].
  static Future<Directory?> findNearestBlockEditorRoot(Directory start) async {
    var current = start;
    for (var depth = 0; depth < 16; depth++) {
      final pubspec = File(joinAll([current.path, 'pubspec.yaml']));
      if (await pubspec.exists()) {
        final text = await readFileIfAllowed(pubspec);
        if (text == null) {
          final parent = current.parent;
          if (parent.path == current.path) return null;
          current = parent;
          continue;
        }
        if (text.contains(
          RegExp(r'^name:\s*block_editor\s*$', multiLine: true),
        )) {
          return current;
        }
        if (text.contains(
          RegExp(r'^name:\s*block_editor_example\s*$', multiLine: true),
        )) {
          final parentPubspec = File(
            joinAll([current.parent.path, 'pubspec.yaml']),
          );
          if (await parentPubspec.exists()) {
            final parentText = await readFileIfAllowed(parentPubspec);
            if (parentText != null &&
                parentText.contains(
                  RegExp(r'^name:\s*block_editor\s*$', multiLine: true),
                )) {
              return current.parent;
            }
          }
          return current;
        }
      }

      final parent = current.parent;
      if (parent.path == current.path) return null;
      current = parent;
    }
    return null;
  }

  /// Reads [file] and returns null when platform access is denied.
  static Future<String?> readFileIfAllowed(File file) async {
    try {
      return await file.readAsString();
    } on FileSystemException {
      return null;
    }
  }

  /// Joins path [parts] using the current platform separator.
  static String joinAll(List<String> parts) {
    return parts.where((part) => part.isNotEmpty).join(Platform.pathSeparator);
  }

  /// Stable filesystem key for workspace-relative document identifiers.
  static String stableStorageKey(String value) {
    const mask = 0xFFFFFFFFFFFFFFFF;
    var hash = 0xcbf29ce484222325;
    for (final byte in utf8.encode(value)) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }
}
