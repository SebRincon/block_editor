library;

import 'package:block_editor/block_editor.dart';
import 'package:meta/meta.dart';

/// Executes an [EditorCommand] against the provided [EditorCommandContext].
typedef EditorCommandExecutor =
    EditorCommandResult Function(EditorCommandContext context);

/// Stable command ids used by the block editor command layer.
abstract final class EditorCommandIds {
  /// Selects the whole document.
  static const selectAll = 'blockEditor.selectAll';

  /// Undoes the most recent document mutation.
  static const undo = 'blockEditor.undo';

  /// Redoes the most recently undone document mutation.
  static const redo = 'blockEditor.redo';

  /// Applies or pend bold inline formatting.
  static const formatBold = 'blockEditor.formatBold';

  /// Applies or pend italic inline formatting.
  static const formatItalic = 'blockEditor.formatItalic';

  /// Applies or pend underline inline formatting.
  static const formatUnderline = 'blockEditor.formatUnderline';

  /// Clears the current selection.
  static const clearSelection = 'blockEditor.clearSelection';

  /// Deletes backward from the current selection.
  static const backspace = 'blockEditor.backspace';

  /// Deletes forward from the current selection.
  static const delete = 'blockEditor.delete';

  /// Inserts a newline or splits the current block.
  static const insertNewline = 'blockEditor.insertNewline';

  /// Indents the current list block.
  static const indent = 'blockEditor.indent';

  /// Dedents the current list block.
  static const dedent = 'blockEditor.dedent';

  /// Moves to the start of the current block.
  static const moveToLineStart = 'blockEditor.moveToLineStart';

  /// Moves to the end of the current block.
  static const moveToLineEnd = 'blockEditor.moveToLineEnd';

  /// Moves to the start of the document.
  static const moveToDocumentStart = 'blockEditor.moveToDocumentStart';

  /// Moves to the end of the document.
  static const moveToDocumentEnd = 'blockEditor.moveToDocumentEnd';

  /// Extends the selection to the start of the current block.
  static const extendSelectionToLineStart =
      'blockEditor.extendSelectionToLineStart';

  /// Extends the selection to the end of the current block.
  static const extendSelectionToLineEnd =
      'blockEditor.extendSelectionToLineEnd';

  /// Extends the selection to the start of the document.
  static const extendSelectionToDocumentStart =
      'blockEditor.extendSelectionToDocumentStart';

  /// Extends the selection to the end of the document.
  static const extendSelectionToDocumentEnd =
      'blockEditor.extendSelectionToDocumentEnd';

  /// Moves one word left.
  static const moveWordLeft = 'blockEditor.moveWordLeft';

  /// Moves one word right.
  static const moveWordRight = 'blockEditor.moveWordRight';

  /// Extends the selection one word left.
  static const extendSelectionWordLeft = 'blockEditor.extendSelectionWordLeft';

  /// Extends the selection one word right.
  static const extendSelectionWordRight =
      'blockEditor.extendSelectionWordRight';

  /// Extends the selection one character left.
  static const extendSelectionLeft = 'blockEditor.extendSelectionLeft';

  /// Extends the selection one character right.
  static const extendSelectionRight = 'blockEditor.extendSelectionRight';

  /// Extends the selection up one block.
  static const extendSelectionUp = 'blockEditor.extendSelectionUp';

  /// Extends the selection down one block.
  static const extendSelectionDown = 'blockEditor.extendSelectionDown';

  /// Moves one character left.
  static const moveCharLeft = 'blockEditor.moveCharLeft';

  /// Moves one character right.
  static const moveCharRight = 'blockEditor.moveCharRight';

  /// Moves up one block.
  static const moveLineUp = 'blockEditor.moveLineUp';

  /// Moves down one block.
  static const moveLineDown = 'blockEditor.moveLineDown';

  /// Inserts the current printable key event character.
  static const insertCharacter = 'blockEditor.insertCharacter';
}

/// A named editor command with metadata and executable behavior.
@immutable
final class EditorCommand {
  /// Creates an [EditorCommand].
  const EditorCommand({
    required this.id,
    required this.title,
    required this.category,
    required this.execute,
    this.readOnly = false,
  });

  /// Stable command id.
  final String id;

  /// Human-readable command title.
  final String title;

  /// Human-readable command category.
  final String category;

  /// Whether this command may execute in read-only mode.
  final bool readOnly;

  /// Command implementation.
  final EditorCommandExecutor execute;

  /// Executes this command, respecting [readOnly].
  EditorCommandResult call(EditorCommandContext context) {
    if (context.readOnly && !readOnly) {
      return const EditorCommandResult.ignored();
    }
    return execute(context);
  }
}

/// Registry that resolves and executes editor commands by id.
final class EditorCommandRegistry {
  const EditorCommandRegistry._({required this.commands});

  /// Creates an [EditorCommandRegistry] from [commands].
  EditorCommandRegistry(Iterable<EditorCommand> commands)
    : commands = List.unmodifiable(commands);

  /// The standard block editor command registry.
  static const standardRegistry = EditorCommandRegistry._(
    commands: EditorCommands.standard,
  );

  /// Creates the standard block editor command registry.
  factory EditorCommandRegistry.standard() => standardRegistry;

  /// Registered commands.
  final List<EditorCommand> commands;

  /// Returns the command registered for [id], if any.
  EditorCommand? commandFor(String id) {
    for (final command in commands) {
      if (command.id == id) return command;
    }
    return null;
  }

  /// Executes the command registered for [id].
  EditorCommandResult execute(String id, EditorCommandContext context) {
    final command = commandFor(id);
    if (command == null) return const EditorCommandResult.ignored();
    return command(context);
  }
}

/// Built-in block editor commands.
abstract final class EditorCommands {
  /// The standard command set used by [KeyboardShortcutHandler].
  static const List<EditorCommand> standard = [
    EditorCommand(
      id: EditorCommandIds.selectAll,
      title: 'Select All',
      category: 'Selection',
      execute: _selectAll,
    ),
    EditorCommand(
      id: EditorCommandIds.undo,
      title: 'Undo',
      category: 'History',
      execute: _undo,
    ),
    EditorCommand(
      id: EditorCommandIds.redo,
      title: 'Redo',
      category: 'History',
      execute: _redo,
    ),
    EditorCommand(
      id: EditorCommandIds.formatBold,
      title: 'Bold',
      category: 'Formatting',
      execute: _formatBold,
    ),
    EditorCommand(
      id: EditorCommandIds.formatItalic,
      title: 'Italic',
      category: 'Formatting',
      execute: _formatItalic,
    ),
    EditorCommand(
      id: EditorCommandIds.formatUnderline,
      title: 'Underline',
      category: 'Formatting',
      execute: _formatUnderline,
    ),
    EditorCommand(
      id: EditorCommandIds.clearSelection,
      title: 'Clear Selection',
      category: 'Selection',
      readOnly: true,
      execute: _clearSelection,
    ),
    EditorCommand(
      id: EditorCommandIds.backspace,
      title: 'Backspace',
      category: 'Editing',
      execute: _backspace,
    ),
    EditorCommand(
      id: EditorCommandIds.delete,
      title: 'Delete',
      category: 'Editing',
      execute: _delete,
    ),
    EditorCommand(
      id: EditorCommandIds.insertNewline,
      title: 'Insert Newline',
      category: 'Editing',
      execute: _insertNewline,
    ),
    EditorCommand(
      id: EditorCommandIds.indent,
      title: 'Indent',
      category: 'Editing',
      execute: _indent,
    ),
    EditorCommand(
      id: EditorCommandIds.dedent,
      title: 'Dedent',
      category: 'Editing',
      execute: _dedent,
    ),
    EditorCommand(
      id: EditorCommandIds.moveToLineStart,
      title: 'Move To Line Start',
      category: 'Navigation',
      execute: _moveToLineStart,
    ),
    EditorCommand(
      id: EditorCommandIds.moveToLineEnd,
      title: 'Move To Line End',
      category: 'Navigation',
      execute: _moveToLineEnd,
    ),
    EditorCommand(
      id: EditorCommandIds.moveToDocumentStart,
      title: 'Move To Document Start',
      category: 'Navigation',
      execute: _moveToDocumentStart,
    ),
    EditorCommand(
      id: EditorCommandIds.moveToDocumentEnd,
      title: 'Move To Document End',
      category: 'Navigation',
      execute: _moveToDocumentEnd,
    ),
    EditorCommand(
      id: EditorCommandIds.extendSelectionToLineStart,
      title: 'Extend Selection To Line Start',
      category: 'Selection',
      execute: _extendSelectionToLineStart,
    ),
    EditorCommand(
      id: EditorCommandIds.extendSelectionToLineEnd,
      title: 'Extend Selection To Line End',
      category: 'Selection',
      execute: _extendSelectionToLineEnd,
    ),
    EditorCommand(
      id: EditorCommandIds.extendSelectionToDocumentStart,
      title: 'Extend Selection To Document Start',
      category: 'Selection',
      execute: _extendSelectionToDocumentStart,
    ),
    EditorCommand(
      id: EditorCommandIds.extendSelectionToDocumentEnd,
      title: 'Extend Selection To Document End',
      category: 'Selection',
      execute: _extendSelectionToDocumentEnd,
    ),
    EditorCommand(
      id: EditorCommandIds.moveWordLeft,
      title: 'Move Word Left',
      category: 'Navigation',
      execute: _moveWordLeft,
    ),
    EditorCommand(
      id: EditorCommandIds.moveWordRight,
      title: 'Move Word Right',
      category: 'Navigation',
      execute: _moveWordRight,
    ),
    EditorCommand(
      id: EditorCommandIds.extendSelectionWordLeft,
      title: 'Extend Selection Word Left',
      category: 'Selection',
      execute: _extendSelectionWordLeft,
    ),
    EditorCommand(
      id: EditorCommandIds.extendSelectionWordRight,
      title: 'Extend Selection Word Right',
      category: 'Selection',
      execute: _extendSelectionWordRight,
    ),
    EditorCommand(
      id: EditorCommandIds.extendSelectionLeft,
      title: 'Extend Selection Left',
      category: 'Selection',
      execute: _extendSelectionLeft,
    ),
    EditorCommand(
      id: EditorCommandIds.extendSelectionRight,
      title: 'Extend Selection Right',
      category: 'Selection',
      execute: _extendSelectionRight,
    ),
    EditorCommand(
      id: EditorCommandIds.extendSelectionUp,
      title: 'Extend Selection Up',
      category: 'Selection',
      execute: _extendSelectionUp,
    ),
    EditorCommand(
      id: EditorCommandIds.extendSelectionDown,
      title: 'Extend Selection Down',
      category: 'Selection',
      execute: _extendSelectionDown,
    ),
    EditorCommand(
      id: EditorCommandIds.moveCharLeft,
      title: 'Move Character Left',
      category: 'Navigation',
      execute: _moveCharLeft,
    ),
    EditorCommand(
      id: EditorCommandIds.moveCharRight,
      title: 'Move Character Right',
      category: 'Navigation',
      execute: _moveCharRight,
    ),
    EditorCommand(
      id: EditorCommandIds.moveLineUp,
      title: 'Move Line Up',
      category: 'Navigation',
      execute: _moveLineUp,
    ),
    EditorCommand(
      id: EditorCommandIds.moveLineDown,
      title: 'Move Line Down',
      category: 'Navigation',
      execute: _moveLineDown,
    ),
    EditorCommand(
      id: EditorCommandIds.insertCharacter,
      title: 'Insert Character',
      category: 'Editing',
      execute: _insertCharacter,
    ),
  ];

  static const _handled = EditorCommandResult.handled();

  static EditorCommandResult _selectAll(EditorCommandContext context) {
    context.controller.selectAll();
    return _handled;
  }

  static EditorCommandResult _undo(EditorCommandContext context) {
    context.controller.undo();
    return _handled;
  }

  static EditorCommandResult _redo(EditorCommandContext context) {
    context.controller.redo();
    return _handled;
  }

  static EditorCommandResult _formatBold(EditorCommandContext context) {
    context.operations.applyBold();
    return _handled;
  }

  static EditorCommandResult _formatItalic(EditorCommandContext context) {
    context.operations.applyItalic();
    return _handled;
  }

  static EditorCommandResult _formatUnderline(EditorCommandContext context) {
    context.operations.applyUnderline();
    return _handled;
  }

  static EditorCommandResult _clearSelection(EditorCommandContext context) {
    context.controller.clearSelection();
    return _handled;
  }

  static EditorCommandResult _backspace(EditorCommandContext context) {
    context.operations.backspace();
    return _handled;
  }

  static EditorCommandResult _delete(EditorCommandContext context) {
    context.operations.delete();
    return _handled;
  }

  static EditorCommandResult _insertNewline(EditorCommandContext context) {
    context.operations.insertNewline();
    return _handled;
  }

  static EditorCommandResult _indent(EditorCommandContext context) {
    context.operations.indent();
    return _handled;
  }

  static EditorCommandResult _dedent(EditorCommandContext context) {
    context.operations.dedent();
    return _handled;
  }

  static EditorCommandResult _moveToLineStart(EditorCommandContext context) {
    context.operations.moveToLineStart();
    return _handled;
  }

  static EditorCommandResult _moveToLineEnd(EditorCommandContext context) {
    context.operations.moveToLineEnd();
    return _handled;
  }

  static EditorCommandResult _moveToDocumentStart(
    EditorCommandContext context,
  ) {
    context.operations.moveToDocumentStart();
    return _handled;
  }

  static EditorCommandResult _moveToDocumentEnd(EditorCommandContext context) {
    context.operations.moveToDocumentEnd();
    return _handled;
  }

  static EditorCommandResult _extendSelectionToLineStart(
    EditorCommandContext context,
  ) {
    context.operations.extendSelectionToLineStart();
    return _handled;
  }

  static EditorCommandResult _extendSelectionToLineEnd(
    EditorCommandContext context,
  ) {
    context.operations.extendSelectionToLineEnd();
    return _handled;
  }

  static EditorCommandResult _extendSelectionToDocumentStart(
    EditorCommandContext context,
  ) {
    context.operations.extendSelectionToDocumentStart();
    return _handled;
  }

  static EditorCommandResult _extendSelectionToDocumentEnd(
    EditorCommandContext context,
  ) {
    context.operations.extendSelectionToDocumentEnd();
    return _handled;
  }

  static EditorCommandResult _moveWordLeft(EditorCommandContext context) {
    context.operations.moveWordLeft();
    return _handled;
  }

  static EditorCommandResult _moveWordRight(EditorCommandContext context) {
    context.operations.moveWordRight();
    return _handled;
  }

  static EditorCommandResult _extendSelectionWordLeft(
    EditorCommandContext context,
  ) {
    context.operations.extendSelectionWordLeft();
    return _handled;
  }

  static EditorCommandResult _extendSelectionWordRight(
    EditorCommandContext context,
  ) {
    context.operations.extendSelectionWordRight();
    return _handled;
  }

  static EditorCommandResult _extendSelectionLeft(
    EditorCommandContext context,
  ) {
    context.operations.extendSelectionLeft();
    return _handled;
  }

  static EditorCommandResult _extendSelectionRight(
    EditorCommandContext context,
  ) {
    context.operations.extendSelectionRight();
    return _handled;
  }

  static EditorCommandResult _extendSelectionUp(EditorCommandContext context) {
    context.operations.extendSelectionUp();
    return _handled;
  }

  static EditorCommandResult _extendSelectionDown(
    EditorCommandContext context,
  ) {
    context.operations.extendSelectionDown();
    return _handled;
  }

  static EditorCommandResult _moveCharLeft(EditorCommandContext context) {
    context.operations.moveCharLeft();
    return _handled;
  }

  static EditorCommandResult _moveCharRight(EditorCommandContext context) {
    context.operations.moveCharRight();
    return _handled;
  }

  static EditorCommandResult _moveLineUp(EditorCommandContext context) {
    context.operations.moveLineUp();
    return _handled;
  }

  static EditorCommandResult _moveLineDown(EditorCommandContext context) {
    context.operations.moveLineDown();
    return _handled;
  }

  static EditorCommandResult _insertCharacter(EditorCommandContext context) {
    final character = context.character;
    if (character == null || character.isEmpty) {
      return const EditorCommandResult.ignored();
    }
    context.operations.insertCharacter(character);
    return _handled;
  }
}
