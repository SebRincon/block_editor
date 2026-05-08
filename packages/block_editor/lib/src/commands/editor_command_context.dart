library;

import 'package:block_editor/block_editor.dart';
import 'package:meta/meta.dart';

/// Runtime state passed to an [EditorCommand] when it executes.
@immutable
final class EditorCommandContext {
  /// Creates an [EditorCommandContext].
  const EditorCommandContext({
    required this.controller,
    required this.operations,
    this.character,
    this.readOnly = false,
  });

  /// The document and selection owner.
  final BlockController controller;

  /// The editing operations delegate.
  final EditorEditingOperations operations;

  /// The printable character associated with the current key event, if any.
  final String? character;

  /// Whether the editor surface is read-only.
  final bool readOnly;
}
