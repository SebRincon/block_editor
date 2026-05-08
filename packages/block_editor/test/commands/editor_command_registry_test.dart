import 'package:block_editor/block_editor.dart';
import 'package:flutter_test/flutter_test.dart';

BlockNode _paragraph(String id, String text) => BlockNode(
  id: id,
  type: BlockTypes.paragraph,
  delta: TextDelta([TextOp(text)]),
);

EditorCommandContext _context(
  BlockController controller, {
  String? character,
  bool readOnly = false,
}) {
  return EditorCommandContext(
    controller: controller,
    operations: EditorEditingOperations(controller),
    character: character,
    readOnly: readOnly,
  );
}

void main() {
  group('EditorCommandRegistry', () {
    test('executes registered commands by id', () {
      final controller = BlockController(
        document: BlockDocument([_paragraph('a', '')]),
      )..collapseSelection('a', 0);
      final registry = EditorCommandRegistry.standard();

      final result = registry.execute(
        EditorCommandIds.insertCharacter,
        _context(controller, character: 'x'),
      );

      expect(result.handled, true);
      expect(controller.document.findById('a')!.delta!.plainText, 'x');
    });

    test('returns ignored for unknown command ids', () {
      final controller = BlockController(
        document: BlockDocument([_paragraph('a', '')]),
      );
      final registry = EditorCommandRegistry.standard();

      final result = registry.execute('missing.command', _context(controller));

      expect(result.handled, false);
    });

    test('respects read-only command metadata', () {
      final controller = BlockController(
        document: BlockDocument([_paragraph('a', '')]),
      )..collapseSelection('a', 0);
      final registry = EditorCommandRegistry.standard();

      final insert = registry.execute(
        EditorCommandIds.insertCharacter,
        _context(controller, character: 'x', readOnly: true),
      );
      final clearSelection = registry.execute(
        EditorCommandIds.clearSelection,
        _context(controller, readOnly: true),
      );

      expect(insert.handled, false);
      expect(clearSelection.handled, true);
      expect(controller.document.findById('a')!.delta!.plainText, isEmpty);
      expect(controller.selection, isA<NoSelection>());
    });
  });
}
