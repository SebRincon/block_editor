library;

import 'package:block_editor/block_editor.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// Maps keyboard events to editor command ids.
@immutable
final class EditorKeymap {
  const EditorKeymap._({required this.bindings});

  /// Creates an [EditorKeymap].
  EditorKeymap({required Iterable<EditorKeyBinding> bindings})
    : bindings = List.unmodifiable(bindings);

  /// The standard block editor keymap.
  static const EditorKeymap standard = EditorKeymap._(
    bindings: [
      EditorKeyBinding(
        key: LogicalKeyboardKey.keyA,
        cmd: true,
        commandId: EditorCommandIds.selectAll,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.keyZ,
        cmd: true,
        commandId: EditorCommandIds.undo,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.keyZ,
        cmd: true,
        shift: true,
        commandId: EditorCommandIds.redo,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.keyY,
        cmd: true,
        commandId: EditorCommandIds.redo,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.keyB,
        cmd: true,
        commandId: EditorCommandIds.formatBold,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.keyI,
        cmd: true,
        commandId: EditorCommandIds.formatItalic,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.keyU,
        cmd: true,
        commandId: EditorCommandIds.formatUnderline,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.escape,
        commandId: EditorCommandIds.clearSelection,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.backspace,
        commandId: EditorCommandIds.backspace,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.delete,
        commandId: EditorCommandIds.delete,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.enter,
        shift: null,
        commandId: EditorCommandIds.insertNewline,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.numpadEnter,
        shift: null,
        commandId: EditorCommandIds.insertNewline,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.tab,
        commandId: EditorCommandIds.indent,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.tab,
        shift: true,
        commandId: EditorCommandIds.dedent,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.home,
        cmd: true,
        shift: true,
        commandId: EditorCommandIds.extendSelectionToDocumentStart,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.home,
        cmd: true,
        commandId: EditorCommandIds.moveToDocumentStart,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.home,
        shift: true,
        commandId: EditorCommandIds.extendSelectionToLineStart,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.home,
        commandId: EditorCommandIds.moveToLineStart,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.end,
        cmd: true,
        shift: true,
        commandId: EditorCommandIds.extendSelectionToDocumentEnd,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.end,
        cmd: true,
        commandId: EditorCommandIds.moveToDocumentEnd,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.end,
        shift: true,
        commandId: EditorCommandIds.extendSelectionToLineEnd,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.end,
        commandId: EditorCommandIds.moveToLineEnd,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowLeft,
        cmd: null,
        meta: true,
        control: false,
        shift: true,
        commandId: EditorCommandIds.extendSelectionToLineStart,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowLeft,
        cmd: null,
        meta: true,
        control: false,
        commandId: EditorCommandIds.moveToLineStart,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowRight,
        cmd: null,
        meta: true,
        control: false,
        shift: true,
        commandId: EditorCommandIds.extendSelectionToLineEnd,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowRight,
        cmd: null,
        meta: true,
        control: false,
        commandId: EditorCommandIds.moveToLineEnd,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowUp,
        cmd: null,
        meta: true,
        control: false,
        shift: true,
        commandId: EditorCommandIds.extendSelectionToDocumentStart,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowUp,
        cmd: null,
        meta: true,
        control: false,
        commandId: EditorCommandIds.moveToDocumentStart,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowDown,
        cmd: null,
        meta: true,
        control: false,
        shift: true,
        commandId: EditorCommandIds.extendSelectionToDocumentEnd,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowDown,
        cmd: null,
        meta: true,
        control: false,
        commandId: EditorCommandIds.moveToDocumentEnd,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowLeft,
        cmd: null,
        meta: false,
        control: true,
        shift: true,
        commandId: EditorCommandIds.extendSelectionWordLeft,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowLeft,
        cmd: null,
        meta: false,
        control: true,
        commandId: EditorCommandIds.moveWordLeft,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowRight,
        cmd: null,
        meta: false,
        control: true,
        shift: true,
        commandId: EditorCommandIds.extendSelectionWordRight,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowRight,
        cmd: null,
        meta: false,
        control: true,
        commandId: EditorCommandIds.moveWordRight,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowLeft,
        alt: true,
        shift: true,
        commandId: EditorCommandIds.extendSelectionWordLeft,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowLeft,
        alt: true,
        commandId: EditorCommandIds.moveWordLeft,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowRight,
        alt: true,
        shift: true,
        commandId: EditorCommandIds.extendSelectionWordRight,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowRight,
        alt: true,
        commandId: EditorCommandIds.moveWordRight,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowLeft,
        shift: true,
        commandId: EditorCommandIds.extendSelectionLeft,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowRight,
        shift: true,
        commandId: EditorCommandIds.extendSelectionRight,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowUp,
        shift: true,
        commandId: EditorCommandIds.extendSelectionUp,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowDown,
        shift: true,
        commandId: EditorCommandIds.extendSelectionDown,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowLeft,
        commandId: EditorCommandIds.moveCharLeft,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowRight,
        commandId: EditorCommandIds.moveCharRight,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowUp,
        commandId: EditorCommandIds.moveLineUp,
      ),
      EditorKeyBinding(
        key: LogicalKeyboardKey.arrowDown,
        commandId: EditorCommandIds.moveLineDown,
      ),
    ],
  );

  /// Ordered bindings. Earlier bindings win when multiple entries match.
  final List<EditorKeyBinding> bindings;

  /// Resolves [key], [modifiers], and [character] to a command id.
  String? resolve(
    LogicalKeyboardKey key,
    EditorModifierKeys modifiers, {
    String? character,
  }) {
    for (final binding in bindings) {
      if (binding.matches(key, modifiers)) return binding.commandId;
    }
    if (!modifiers.cmd &&
        !modifiers.alt &&
        character != null &&
        character.isNotEmpty &&
        !_isControlCharacter(character)) {
      return EditorCommandIds.insertCharacter;
    }
    return null;
  }

  bool _isControlCharacter(String character) {
    final code = character.codeUnitAt(0);
    return code < 32 || code == 127;
  }
}
