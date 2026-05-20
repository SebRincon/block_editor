library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Handles source-editor keyboard navigation that Flutter's platform text
/// shortcuts do not always deliver consistently inside nested editor surfaces.
KeyEventResult handleEmbeddedTextEditingShortcut(
  TextEditingController controller,
  KeyEvent event,
) {
  if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
    return KeyEventResult.ignored;
  }

  final hardware = HardwareKeyboard.instance;
  final key = event.logicalKey;
  final isMac = defaultTargetPlatform == TargetPlatform.macOS;
  final primaryPressed =
      hardware.isMetaPressed || (!isMac && hardware.isControlPressed);
  final wordPressed =
      hardware.isAltPressed || (!isMac && hardware.isControlPressed);
  final shiftPressed = hardware.isShiftPressed;
  final altPressed = hardware.isAltPressed;

  if (primaryPressed && !altPressed && key == LogicalKeyboardKey.keyA) {
    _selectRange(controller, 0, controller.text.length);
    return KeyEventResult.handled;
  }

  if (primaryPressed && !altPressed) {
    if (hardware.isMetaPressed && key == LogicalKeyboardKey.arrowLeft) {
      _moveTo(
        controller,
        _lineStart(controller.text, _extent(controller)),
        expand: shiftPressed,
      );
      return KeyEventResult.handled;
    }
    if (hardware.isMetaPressed && key == LogicalKeyboardKey.arrowRight) {
      _moveTo(
        controller,
        _lineEnd(controller.text, _extent(controller)),
        expand: shiftPressed,
      );
      return KeyEventResult.handled;
    }
    if ((hardware.isMetaPressed && key == LogicalKeyboardKey.arrowUp) ||
        key == LogicalKeyboardKey.home) {
      _moveTo(controller, 0, expand: shiftPressed);
      return KeyEventResult.handled;
    }
    if ((hardware.isMetaPressed && key == LogicalKeyboardKey.arrowDown) ||
        key == LogicalKeyboardKey.end) {
      _moveTo(controller, controller.text.length, expand: shiftPressed);
      return KeyEventResult.handled;
    }
  }

  if (wordPressed &&
      !primaryPressed &&
      (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.arrowRight)) {
    final current = _extent(controller);
    final target = key == LogicalKeyboardKey.arrowLeft
        ? _previousWordBoundary(controller.text, current)
        : _nextWordBoundary(controller.text, current);
    _moveTo(controller, target, expand: shiftPressed);
    return KeyEventResult.handled;
  }

  if (!primaryPressed && !altPressed) {
    if (key == LogicalKeyboardKey.home) {
      _moveTo(
        controller,
        _lineStart(controller.text, _extent(controller)),
        expand: shiftPressed,
      );
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.end) {
      _moveTo(
        controller,
        _lineEnd(controller.text, _extent(controller)),
        expand: shiftPressed,
      );
      return KeyEventResult.handled;
    }
    if (shiftPressed && key == LogicalKeyboardKey.arrowLeft) {
      _moveTo(controller, _extent(controller) - 1, expand: true);
      return KeyEventResult.handled;
    }
    if (shiftPressed && key == LogicalKeyboardKey.arrowRight) {
      _moveTo(controller, _extent(controller) + 1, expand: true);
      return KeyEventResult.handled;
    }
    if (shiftPressed && key == LogicalKeyboardKey.arrowUp) {
      _moveTo(
        controller,
        _lineAbove(controller.text, _extent(controller)),
        expand: true,
      );
      return KeyEventResult.handled;
    }
    if (shiftPressed && key == LogicalKeyboardKey.arrowDown) {
      _moveTo(
        controller,
        _lineBelow(controller.text, _extent(controller)),
        expand: true,
      );
      return KeyEventResult.handled;
    }
  }

  return KeyEventResult.ignored;
}

int _extent(TextEditingController controller) {
  final selection = controller.selection;
  if (!selection.isValid) return controller.text.length;
  return selection.extentOffset.clamp(0, controller.text.length);
}

int _base(TextEditingController controller) {
  final selection = controller.selection;
  if (!selection.isValid) return _extent(controller);
  return selection.baseOffset.clamp(0, controller.text.length);
}

void _moveTo(
  TextEditingController controller,
  int target, {
  required bool expand,
}) {
  final text = controller.text;
  final offset = target.clamp(0, text.length);
  final selection = expand
      ? TextSelection(baseOffset: _base(controller), extentOffset: offset)
      : TextSelection.collapsed(offset: offset);
  controller.value = controller.value.copyWith(
    selection: selection,
    composing: TextRange.empty,
  );
}

void _selectRange(TextEditingController controller, int start, int end) {
  controller.value = controller.value.copyWith(
    selection: TextSelection(
      baseOffset: start.clamp(0, controller.text.length),
      extentOffset: end.clamp(0, controller.text.length),
    ),
    composing: TextRange.empty,
  );
}

int _lineStart(String text, int offset) {
  if (offset <= 0) return 0;
  return text.lastIndexOf('\n', offset - 1) + 1;
}

int _lineEnd(String text, int offset) {
  final index = text.indexOf('\n', offset.clamp(0, text.length));
  return index == -1 ? text.length : index;
}

int _lineAbove(String text, int offset) {
  final currentStart = _lineStart(text, offset);
  if (currentStart == 0) return 0;
  final previousEnd = currentStart - 1;
  final previousStart = _lineStart(text, previousEnd);
  final column = offset - currentStart;
  return (previousStart + column).clamp(previousStart, previousEnd);
}

int _lineBelow(String text, int offset) {
  final currentStart = _lineStart(text, offset);
  final currentEnd = _lineEnd(text, offset);
  if (currentEnd >= text.length) return text.length;
  final nextStart = currentEnd + 1;
  final nextEnd = _lineEnd(text, nextStart);
  final column = offset - currentStart;
  return (nextStart + column).clamp(nextStart, nextEnd);
}

int _previousWordBoundary(String text, int offset) {
  var i = offset.clamp(0, text.length);
  while (i > 0 && _isWhitespace(text.codeUnitAt(i - 1))) {
    i--;
  }
  if (i == 0) return 0;
  final word = _isWordCodeUnit(text.codeUnitAt(i - 1));
  while (i > 0) {
    final codeUnit = text.codeUnitAt(i - 1);
    if (_isWhitespace(codeUnit)) break;
    if (_isWordCodeUnit(codeUnit) != word) break;
    i--;
  }
  return i;
}

int _nextWordBoundary(String text, int offset) {
  var i = offset.clamp(0, text.length);
  while (i < text.length && _isWhitespace(text.codeUnitAt(i))) {
    i++;
  }
  if (i >= text.length) return text.length;
  final word = _isWordCodeUnit(text.codeUnitAt(i));
  while (i < text.length) {
    final codeUnit = text.codeUnitAt(i);
    if (_isWhitespace(codeUnit)) break;
    if (_isWordCodeUnit(codeUnit) != word) break;
    i++;
  }
  return i;
}

bool _isWhitespace(int codeUnit) {
  return codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D;
}

bool _isWordCodeUnit(int codeUnit) {
  return (codeUnit >= 0x30 && codeUnit <= 0x39) ||
      (codeUnit >= 0x41 && codeUnit <= 0x5A) ||
      (codeUnit >= 0x61 && codeUnit <= 0x7A) ||
      codeUnit == 0x5F;
}
