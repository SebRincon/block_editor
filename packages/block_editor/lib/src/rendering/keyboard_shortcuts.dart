library;

import 'package:flutter/services.dart';
import 'package:block_editor/block_editor.dart';
import 'package:flutter/widgets.dart';

/// Carries the state of the four modifier keys at the moment a key event fires.
///
/// [ModifierKeys] is constructed by the caller before invoking
/// [KeyboardShortcutHandler.handle], decoupling the handler from
/// [HardwareKeyboard.instance] and making it testable without the Flutter
/// binding.
class ModifierKeys extends EditorModifierKeys {
  /// Creates a [ModifierKeys] snapshot.
  ///
  /// All parameters default to false, representing no modifiers held.
  const ModifierKeys({
    super.cmd,
    super.meta = false,
    super.control = false,
    super.shift = false,
    super.alt = false,
  });

  /// Reads the current modifier state from [HardwareKeyboard.instance].
  ///
  /// This factory requires the Flutter [ServicesBinding] to be initialised.
  /// Use the default constructor in tests to avoid the binding dependency.
  factory ModifierKeys.fromHardware() {
    final meta = HardwareKeyboard.instance.isMetaPressed;
    final control = HardwareKeyboard.instance.isControlPressed;
    return ModifierKeys(
      meta: meta,
      control: control,
      shift: HardwareKeyboard.instance.isShiftPressed,
      alt: HardwareKeyboard.instance.isAltPressed,
    );
  }
}

/// Centralises keyboard shortcut matching and dispatch for the block editor.
///
/// [KeyboardShortcutHandler] adapts hardware key events to the editor command
/// layer. [BlockEditorWidget] holds a single instance and forwards every
/// [KeyDownEvent] and [KeyRepeatEvent] to [handle] together with a [ModifierKeys]
/// snapshot read from [HardwareKeyboard.instance] at the call site.
///
/// Modifier state is injected rather than read inside [handle], so every
/// shortcut path is testable without initialising the Flutter binding.
class KeyboardShortcutHandler {
  /// Creates a [KeyboardShortcutHandler] bound to [controller] and [ops].
  ///
  /// [controller] is used for operations that do not pass through
  /// [EditorEditingOperations] — [BlockController.undo], [BlockController.redo],
  /// [BlockController.selectAll], and [BlockController.clearSelection].
  ///
  /// [ops] handles every character-level and selection operation.
  const KeyboardShortcutHandler({
    required this.controller,
    required this.ops,
    this.keymap = EditorKeymap.standard,
    this.commandRegistry = EditorCommandRegistry.standardRegistry,
    this.onPostCommand,
    this.readOnly = false,
  });

  /// The document and selection owner.
  final BlockController controller;

  /// The editing operations delegate.
  final EditorEditingOperations ops;

  /// Resolves key/modifier pairs to command ids.
  final EditorKeymap keymap;

  /// Executes resolved command ids.
  final EditorCommandRegistry commandRegistry;

  /// Called after a command reports that it handled a key event.
  final VoidCallback? onPostCommand;

  /// Whether commands should execute in read-only mode.
  final bool readOnly;

  /// Dispatches [event] to the appropriate operation and returns a
  /// [KeyEventResult] indicating whether the event was consumed.
  ///
  /// [modifiers] must reflect the hardware modifier state at the instant the
  /// event fired. Callers in production read this via [ModifierKeys.fromHardware].
  /// Test callers construct [ModifierKeys] directly.
  ///
  /// Only [KeyDownEvent] and [KeyRepeatEvent] are handled. All other event
  /// types return [KeyEventResult.ignored] immediately.
  KeyEventResult handle(KeyEvent event, ModifierKeys modifiers) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final commandId = keymap.resolve(
      event.logicalKey,
      modifiers,
      character: event.character,
    );
    if (commandId == null) return KeyEventResult.ignored;

    final result = commandRegistry.execute(
      commandId,
      EditorCommandContext(
        controller: controller,
        operations: ops,
        character: event.character,
        readOnly: readOnly,
      ),
    );
    if (!result.handled) return KeyEventResult.ignored;
    if (result.shouldRunPostCommand) onPostCommand?.call();
    return KeyEventResult.handled;
  }
}
