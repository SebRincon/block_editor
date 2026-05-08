library;

import 'package:flutter/services.dart';
import 'package:meta/meta.dart';

/// Carries command-key modifier state in a rendering-independent form.
@immutable
class EditorModifierKeys {
  /// Creates an [EditorModifierKeys] snapshot.
  const EditorModifierKeys({
    bool? cmd,
    this.meta = false,
    this.control = false,
    this.shift = false,
    this.alt = false,
  }) : cmd = cmd ?? (meta || control);

  /// True when the editor primary modifier is pressed.
  final bool cmd;

  /// True when the platform Meta/Command modifier is pressed.
  final bool meta;

  /// True when the Control modifier is pressed.
  final bool control;

  /// True when Shift is pressed.
  final bool shift;

  /// True when Alt/Option is pressed.
  final bool alt;
}

/// A single key binding from a logical key and modifier set to a command id.
@immutable
final class EditorKeyBinding {
  /// Creates an [EditorKeyBinding].
  const EditorKeyBinding({
    required this.key,
    required this.commandId,
    this.cmd = false,
    this.meta,
    this.control,
    this.shift = false,
    this.alt = false,
  });

  /// The logical key that triggers the command.
  final LogicalKeyboardKey key;

  /// Required primary modifier state, or null to accept either state.
  final bool? cmd;

  /// Required Meta/Command modifier state, or null to accept either state.
  final bool? meta;

  /// Required Control modifier state, or null to accept either state.
  final bool? control;

  /// Required shift modifier state, or null to accept either state.
  final bool? shift;

  /// Required alt modifier state, or null to accept either state.
  final bool? alt;

  /// The command id to execute when this binding matches.
  final String commandId;

  /// Whether this binding matches [key] and [modifiers].
  bool matches(LogicalKeyboardKey key, EditorModifierKeys modifiers) {
    return this.key == key &&
        _matches(cmd, modifiers.cmd) &&
        _matches(meta, modifiers.meta) &&
        _matches(control, modifiers.control) &&
        _matches(shift, modifiers.shift) &&
        _matches(alt, modifiers.alt);
  }

  bool _matches(bool? expected, bool actual) =>
      expected == null || expected == actual;
}
