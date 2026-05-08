import 'package:block_editor/block_editor.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EditorKeymap', () {
    test('resolves primary modifier commands', () {
      final keymap = EditorKeymap.standard;

      expect(
        keymap.resolve(
          LogicalKeyboardKey.keyA,
          const EditorModifierKeys(cmd: true),
        ),
        EditorCommandIds.selectAll,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.keyZ,
          const EditorModifierKeys(cmd: true),
        ),
        EditorCommandIds.undo,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.keyZ,
          const EditorModifierKeys(cmd: true, shift: true),
        ),
        EditorCommandIds.redo,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.keyY,
          const EditorModifierKeys(cmd: true),
        ),
        EditorCommandIds.redo,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.keyY,
          const EditorModifierKeys(cmd: true, shift: true),
        ),
        isNull,
      );
    });

    test('resolves newline and tab variants', () {
      final keymap = EditorKeymap.standard;

      expect(
        keymap.resolve(LogicalKeyboardKey.enter, const EditorModifierKeys()),
        EditorCommandIds.insertNewline,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.enter,
          const EditorModifierKeys(shift: true),
        ),
        EditorCommandIds.insertNewline,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.numpadEnter,
          const EditorModifierKeys(),
        ),
        EditorCommandIds.insertNewline,
      );
      expect(
        keymap.resolve(LogicalKeyboardKey.tab, const EditorModifierKeys()),
        EditorCommandIds.indent,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.tab,
          const EditorModifierKeys(shift: true),
        ),
        EditorCommandIds.dedent,
      );
    });

    test('resolves movement variants before character fallback', () {
      final keymap = EditorKeymap.standard;

      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowRight,
          const EditorModifierKeys(shift: true, alt: true),
        ),
        EditorCommandIds.extendSelectionWordRight,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowRight,
          const EditorModifierKeys(alt: true),
        ),
        EditorCommandIds.moveWordRight,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowRight,
          const EditorModifierKeys(shift: true),
        ),
        EditorCommandIds.extendSelectionRight,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowRight,
          const EditorModifierKeys(),
        ),
        EditorCommandIds.moveCharRight,
      );
    });

    test('resolves platform-specific modified arrows', () {
      final keymap = EditorKeymap.standard;

      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowLeft,
          const EditorModifierKeys(meta: true),
        ),
        EditorCommandIds.moveToLineStart,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowRight,
          const EditorModifierKeys(meta: true, shift: true),
        ),
        EditorCommandIds.extendSelectionToLineEnd,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowUp,
          const EditorModifierKeys(meta: true),
        ),
        EditorCommandIds.moveToDocumentStart,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowDown,
          const EditorModifierKeys(meta: true, shift: true),
        ),
        EditorCommandIds.extendSelectionToDocumentEnd,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowRight,
          const EditorModifierKeys(control: true),
        ),
        EditorCommandIds.moveWordRight,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowLeft,
          const EditorModifierKeys(control: true, shift: true),
        ),
        EditorCommandIds.extendSelectionWordLeft,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.arrowRight,
          const EditorModifierKeys(meta: true, control: true),
        ),
        isNull,
      );
    });

    test('uses printable character fallback only without cmd or alt', () {
      final keymap = EditorKeymap.standard;

      expect(
        keymap.resolve(
          LogicalKeyboardKey.keyH,
          const EditorModifierKeys(),
          character: 'h',
        ),
        EditorCommandIds.insertCharacter,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.keyH,
          const EditorModifierKeys(shift: true),
          character: 'H',
        ),
        EditorCommandIds.insertCharacter,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.keyH,
          const EditorModifierKeys(cmd: true),
          character: 'h',
        ),
        isNull,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.keyH,
          const EditorModifierKeys(alt: true),
          character: 'h',
        ),
        isNull,
      );
      expect(
        keymap.resolve(
          LogicalKeyboardKey.keyA,
          const EditorModifierKeys(),
          character: '\x01',
        ),
        isNull,
      );
    });
  });
}
