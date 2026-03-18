import 'package:block_editor/block_editor.dart';
import 'package:test/test.dart';

BlockNode paragraph({String? id, String text = ''}) => BlockNode(
  id: id,
  type: BlockTypes.paragraph,
  delta: TextDelta.fromPlainText(text),
);

BlockNode bulletItem({String? id, String text = '', int indent = 0}) =>
    BlockNode(
      id: id,
      type: BlockTypes.bulletList,
      attributes: {'indent': indent},
      delta: TextDelta.fromPlainText(text),
    );

BlockNode numberedItem({String? id, String text = ''}) => BlockNode(
  id: id,
  type: BlockTypes.numberedList,
  delta: TextDelta.fromPlainText(text),
);

BlockNode todoItem({String? id, String text = '', bool checked = false}) =>
    BlockNode(
      id: id,
      type: BlockTypes.todo,
      attributes: {'checked': checked},
      delta: TextDelta.fromPlainText(text),
    );

void main() {
  late BlockController controller;
  late EditorEditingOperations ops;

  setUp(() {
    controller = BlockController(
      document: BlockDocument([
        paragraph(id: 'b1', text: 'hello world'),
        paragraph(id: 'b2', text: 'second'),
        paragraph(id: 'b3', text: 'third'),
      ]),
    );
    ops = EditorEditingOperations(controller);
  });

  tearDown(() => controller.dispose());

  group('insertCharacter', () {
    test('inserts character at cursor offset', () {
      controller.collapseSelection('b1', 5);
      ops.insertCharacter('!');
      expect(
        controller.document.findById('b1')!.delta!.plainText,
        'hello! world',
      );
    });

    test('advances cursor by character length', () {
      controller.collapseSelection('b1', 5);
      ops.insertCharacter('!');
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.offset, 6);
    });

    test('inserts at offset 0', () {
      controller.collapseSelection('b1', 0);
      ops.insertCharacter('X');
      expect(
        controller.document.findById('b1')!.delta!.plainText,
        'Xhello world',
      );
    });

    test('inserts at end of text', () {
      controller.collapseSelection('b1', 11);
      ops.insertCharacter('.');
      expect(
        controller.document.findById('b1')!.delta!.plainText,
        'hello world.',
      );
    });

    test('does nothing when selection is not collapsed', () {
      controller.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'b1', offset: 0),
          focus: SelectionPoint(blockId: 'b1', offset: 5),
        ),
      );
      ops.insertCharacter('X');
      expect(
        controller.document.findById('b1')!.delta!.plainText,
        'hello world',
      );
    });

    test('does nothing when character is empty', () {
      controller.collapseSelection('b1', 5);
      ops.insertCharacter('');
      expect(
        controller.document.findById('b1')!.delta!.plainText,
        'hello world',
      );
    });
  });

  group('backspace', () {
    test('deletes character before cursor', () {
      controller.collapseSelection('b1', 5);
      ops.backspace();
      expect(
        controller.document.findById('b1')!.delta!.plainText,
        'hell world',
      );
    });

    test('moves cursor back one position', () {
      controller.collapseSelection('b1', 5);
      ops.backspace();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.offset, 4);
    });

    test('merges with previous block at offset 0', () {
      controller.collapseSelection('b2', 0);
      ops.backspace();
      expect(
        controller.document.findById('b1')!.delta!.plainText,
        'hello worldsecond',
      );
      expect(controller.document.findById('b2'), isNull);
    });

    test('places cursor at join point after merge', () {
      controller.collapseSelection('b2', 0);
      ops.backspace();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 11);
    });

    test('does nothing at offset 0 of first block', () {
      controller.collapseSelection('b1', 0);
      ops.backspace();
      expect(controller.document.blocks.length, 3);
    });

    test('deletes selected range when selection is expanded', () {
      controller.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'b1', offset: 0),
          focus: SelectionPoint(blockId: 'b1', offset: 5),
        ),
      );
      ops.backspace();
      expect(controller.document.findById('b1')!.delta!.plainText, ' world');
    });
  });

  group('delete', () {
    test('deletes character at cursor', () {
      controller.collapseSelection('b1', 5);
      ops.delete();
      expect(
        controller.document.findById('b1')!.delta!.plainText,
        'helloworld',
      );
    });

    test('cursor stays at same offset after delete', () {
      controller.collapseSelection('b1', 5);
      ops.delete();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.offset, 5);
    });

    test('merges next block at end of block', () {
      controller.collapseSelection('b1', 11);
      ops.delete();
      expect(
        controller.document.findById('b1')!.delta!.plainText,
        'hello worldsecond',
      );
      expect(controller.document.findById('b2'), isNull);
    });

    test('does nothing at end of last block', () {
      controller.collapseSelection('b3', 5);
      ops.delete();
      expect(controller.document.blocks.length, 3);
    });
  });

  group('insertNewline', () {
    test('splits block at cursor offset', () {
      controller.collapseSelection('b1', 5);
      ops.insertNewline();
      expect(controller.document.blocks.length, 4);
      expect(controller.document.blocks[0].delta!.plainText, 'hello');
      expect(controller.document.blocks[1].delta!.plainText, ' world');
    });

    test('new block has same type as split block', () {
      controller.collapseSelection('b1', 5);
      ops.insertNewline();
      expect(controller.document.blocks[1].type, BlockTypes.paragraph);
    });

    test('cursor moves to start of new block', () {
      controller.collapseSelection('b1', 5);
      ops.insertNewline();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, controller.document.blocks[1].id);
      expect(sel.point.offset, 0);
    });

    test('empty bullet list transforms to paragraph', () {
      final c = BlockController(
        document: BlockDocument([bulletItem(id: 'li1', text: '')]),
      );
      addTearDown(c.dispose);
      final o = EditorEditingOperations(c);
      c.collapseSelection('li1', 0);
      o.insertNewline();
      expect(c.document.blocks.first.type, BlockTypes.paragraph);
      expect(c.document.blocks.length, 1);
    });

    test('empty numbered list transforms to paragraph', () {
      final c = BlockController(
        document: BlockDocument([numberedItem(id: 'n1', text: '')]),
      );
      addTearDown(c.dispose);
      final o = EditorEditingOperations(c);
      c.collapseSelection('n1', 0);
      o.insertNewline();
      expect(c.document.blocks.first.type, BlockTypes.paragraph);
    });

    test('empty todo transforms to paragraph', () {
      final c = BlockController(
        document: BlockDocument([todoItem(id: 't1', text: '')]),
      );
      addTearDown(c.dispose);
      final o = EditorEditingOperations(c);
      c.collapseSelection('t1', 0);
      o.insertNewline();
      expect(c.document.blocks.first.type, BlockTypes.paragraph);
    });

    test('non-empty list item splits normally', () {
      final c = BlockController(
        document: BlockDocument([bulletItem(id: 'li1', text: 'item')]),
      );
      addTearDown(c.dispose);
      final o = EditorEditingOperations(c);
      c.collapseSelection('li1', 4);
      o.insertNewline();
      expect(c.document.blocks.length, 2);
      expect(c.document.blocks[1].type, BlockTypes.bulletList);
    });
  });

  group('indent / dedent', () {
    test('indent increments indent attribute', () {
      final c = BlockController(
        document: BlockDocument([bulletItem(id: 'li1', indent: 0)]),
      );
      addTearDown(c.dispose);
      final o = EditorEditingOperations(c);
      c.collapseSelection('li1', 0);
      o.indent();
      expect(c.document.blocks.first.attributes['indent'], 1);
    });

    test('dedent decrements indent attribute', () {
      final c = BlockController(
        document: BlockDocument([bulletItem(id: 'li1', indent: 2)]),
      );
      addTearDown(c.dispose);
      final o = EditorEditingOperations(c);
      c.collapseSelection('li1', 0);
      o.dedent();
      expect(c.document.blocks.first.attributes['indent'], 1);
    });

    test('indent clamps at 8', () {
      final c = BlockController(
        document: BlockDocument([bulletItem(id: 'li1', indent: 8)]),
      );
      addTearDown(c.dispose);
      final o = EditorEditingOperations(c);
      c.collapseSelection('li1', 0);
      o.indent();
      expect(c.document.blocks.first.attributes['indent'], 8);
    });

    test('dedent clamps at 0', () {
      final c = BlockController(
        document: BlockDocument([bulletItem(id: 'li1', indent: 0)]),
      );
      addTearDown(c.dispose);
      final o = EditorEditingOperations(c);
      c.collapseSelection('li1', 0);
      o.dedent();
      expect(c.document.blocks.first.attributes['indent'], 0);
    });

    test('indent does nothing for paragraph', () {
      controller.collapseSelection('b1', 0);
      ops.indent();
      expect(controller.document.findById('b1')!.attributes['indent'], isNull);
    });
  });

  group('inline formatting', () {
    test('applyBold applies bold to expanded selection', () {
      controller.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'b1', offset: 0),
          focus: SelectionPoint(blockId: 'b1', offset: 5),
        ),
      );
      ops.applyBold();
      final ops2 = controller.document.findById('b1')!.delta!.ops;
      expect((ops2.first as TextOp).attributes.bold, isTrue);
    });

    test('applyItalic does nothing for collapsed selection', () {
      controller.collapseSelection('b1', 3);
      ops.applyItalic();
      final op = controller.document.findById('b1')!.delta!.ops.first as TextOp;
      expect(op.attributes.italic, isNull);
    });

    test('applyUnderline applies underline to expanded selection', () {
      controller.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'b1', offset: 0),
          focus: SelectionPoint(blockId: 'b1', offset: 5),
        ),
      );
      ops.applyUnderline();
      final op = controller.document.findById('b1')!.delta!.ops.first as TextOp;
      expect(op.attributes.underline, isTrue);
    });
  });

  group('navigation', () {
    test('moveToLineStart collapses to offset 0', () {
      controller.collapseSelection('b1', 7);
      ops.moveToLineStart();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.offset, 0);
    });

    test('moveToLineEnd collapses to last offset', () {
      controller.collapseSelection('b1', 0);
      ops.moveToLineEnd();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.offset, 11);
    });

    test('moveToDocumentStart moves to first block offset 0', () {
      controller.collapseSelection('b3', 3);
      ops.moveToDocumentStart();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 0);
    });

    test('moveToDocumentEnd moves to last block last offset', () {
      controller.collapseSelection('b1', 0);
      ops.moveToDocumentEnd();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b3');
      expect(sel.point.offset, 5);
    });

    test('moveWordRight advances to next word boundary', () {
      controller.collapseSelection('b1', 0);
      ops.moveWordRight();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.offset, 5);
    });

    test('moveWordLeft retreats to previous word boundary', () {
      controller.collapseSelection('b1', 11);
      ops.moveWordLeft();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.offset, 6);
    });

    test('moveWordRight at end of block moves to next block', () {
      controller.collapseSelection('b1', 11);
      ops.moveWordRight();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b2');
      expect(sel.point.offset, 0);
    });

    test('moveWordLeft at start of block moves to end of previous block', () {
      controller.collapseSelection('b2', 0);
      ops.moveWordLeft();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 11);
    });
  });

  group('cross-block delete', () {
    test('backspace on expanded cross-block selection merges blocks', () {
      controller.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'b1', offset: 6),
          focus: SelectionPoint(blockId: 'b2', offset: 3),
        ),
      );
      ops.backspace();
      expect(controller.document.blocks.length, 2);
      expect(controller.document.findById('b1')!.delta!.plainText, 'hello ond');
    });

    test('cursor lands at start offset after cross-block delete', () {
      controller.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'b1', offset: 6),
          focus: SelectionPoint(blockId: 'b2', offset: 3),
        ),
      );
      ops.backspace();
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 6);
    });
  });
}
