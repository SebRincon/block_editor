import 'package:block_editor/block_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

BlockNode paragraph({String? id, String text = ''}) => BlockNode(
  id: id,
  type: BlockTypes.paragraph,
  delta: TextDelta.fromPlainText(text),
);

Widget wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Future<void> activateTableCell(WidgetTester tester, String text) async {
  await tester.tap(find.widgetWithText(TextField, text));
  await tester.pump();
  await tester.pump();
}

void mockClipboard(WidgetTester tester, {String? initialText}) {
  var clipboardText = initialText;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          final data = call.arguments as Map<dynamic, dynamic>;
          clipboardText = data['text'] as String?;
          return null;
        case 'Clipboard.getData':
          return <String, dynamic>{'text': clipboardText};
      }
      return null;
    },
  );
  addTearDown(() {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    );
  });
}

Widget wrapWithAhem(Widget child) {
  return MaterialApp(
    theme: ThemeData(
      textTheme: const TextTheme(
        bodyMedium: TextStyle(fontFamily: 'Ahem', fontSize: 16),
      ),
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  late BlockController controller;

  setUp(() {
    controller = BlockController(
      document: BlockDocument([
        paragraph(id: 'b1', text: 'First'),
        paragraph(id: 'b2', text: 'Second'),
        paragraph(id: 'b3', text: 'Third'),
      ]),
    );
  });

  tearDown(() => controller.dispose());

  group('BlockEditorWidget — rendering', () {
    testWidgets('renders all blocks', (tester) async {
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));
      expect(find.byType(BlockRenderer), findsNWidgets(3));
    });

    testWidgets('renders without error on empty document', (tester) async {
      final empty = BlockController(document: const BlockDocument([]));
      addTearDown(empty.dispose);
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: empty)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('rebuilds when document changes', (tester) async {
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));
      controller.append(paragraph(id: 'b4', text: 'Fourth'));
      await tester.pump();
      expect(find.byType(BlockRenderer), findsNWidgets(4));
    });
  });

  group('BlockEditorWidget — readOnly', () {
    testWidgets('readOnly mode renders all blocks', (tester) async {
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, readOnly: true)),
      );
      expect(find.byType(BlockRenderer), findsNWidgets(3));
    });

    testWidgets('readOnly mode suppresses selection on tap', (tester) async {
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, readOnly: true)),
      );
      await tester.tap(find.text('First', findRichText: true));
      await tester.pump();
      expect(controller.selection, isA<NoSelection>());
    });
  });

  group('BlockEditorWidget — event dispatch', () {
    testWidgets('tap sets CollapsedSelection on controller', (tester) async {
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));
      await tester.tap(find.text('First', findRichText: true));
      await tester.pump();
      expect(controller.selection, isA<CollapsedSelection>());
      expect((controller.selection as CollapsedSelection).point.blockId, 'b1');
    });

    testWidgets('checkbox toggle updates checked attribute', (tester) async {
      final todoController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 't1',
            type: BlockTypes.todo,
            attributes: {'checked': false},
            delta: TextDelta.fromPlainText('task'),
          ),
        ]),
      );
      addTearDown(todoController.dispose);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: todoController)),
      );
      await tester.tap(find.byType(Container).first);
      await tester.pump();
      expect(
        todoController.document.blocks.first.attributes['checked'],
        isTrue,
      );
    });

    testWidgets('table cell edits update table attributes', (tester) async {
      final tableController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'table1',
            type: BlockTypes.table,
            attributes: {
              'headers': const ['Name', 'Status'],
              'rows': const [
                ['Draft', 'Open'],
              ],
            },
          ),
        ]),
      );
      addTearDown(tableController.dispose);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: tableController)),
      );

      await tester.enterText(find.widgetWithText(TextField, 'Draft'), 'Done');
      await tester.pump();

      expect(tableController.document.blocks.single.attributes['rows'], [
        ['Done', 'Open'],
      ]);
    });

    testWidgets('focused table cells own the active text input client', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final tableController = BlockController(
        document: BlockDocument([
          paragraph(id: 'p1', text: 'Intro'),
          BlockNode(
            id: 'table1',
            type: BlockTypes.table,
            attributes: {
              'headers': const ['Name', 'Status'],
              'rows': const [
                ['Draft', 'Open'],
              ],
            },
          ),
        ]),
      );
      addTearDown(tableController.dispose);
      tableController.collapseSelection('p1', 0);
      await tester.pumpWidget(
        wrap(
          BlockEditorWidget(controller: tableController, focusNode: focusNode),
        ),
      );

      focusNode.requestFocus();
      await tester.pump();
      expect(tester.testTextInput.hasAnyClients, isTrue);

      await tester.tap(find.widgetWithText(TextField, 'Draft'));
      await tester.pump();
      tester.testTextInput.enterText('Done');
      await tester.pump();

      expect(tableController.document.blocks.first.delta?.plainText, 'Intro');
      expect(tableController.document.blocks.last.attributes['rows'], [
        ['Done', 'Open'],
      ]);
    });

    testWidgets('table action buttons append rows and columns', (tester) async {
      final tableController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'table1',
            type: BlockTypes.table,
            attributes: {
              'headers': const ['A', 'B'],
              'rows': const [
                ['1', '2'],
              ],
            },
          ),
        ]),
      );
      addTearDown(tableController.dispose);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: tableController)),
      );

      await activateTableCell(tester, '2');
      expect(find.byType(TextField), findsNWidgets(4));
      await tester.tap(find.byTooltip('Add row below'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(6));
      expect(tableController.document.blocks.single.attributes['rows'], [
        ['1', '2'],
        ['', ''],
      ]);

      await tester.tap(find.byTooltip('Add column right'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(9));
      expect(tableController.document.blocks.single.attributes['headers'], [
        'A',
        'B',
        'Column 3',
      ]);
      expect(tableController.document.blocks.single.attributes['rows'], [
        ['1', '2', ''],
        ['', '', ''],
      ]);
    });

    testWidgets('new empty table rows and columns delete immediately', (
      tester,
    ) async {
      final tableController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'table1',
            type: BlockTypes.table,
            attributes: {
              'headers': const ['A', 'B'],
              'rows': const [
                ['1', '2'],
              ],
            },
          ),
        ]),
      );
      addTearDown(tableController.dispose);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: tableController)),
      );

      await activateTableCell(tester, '2');
      await tester.tap(find.byTooltip('Add row below'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(6));
      await tester.tap(find.byTooltip('Delete row 2'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(4));
      expect(tableController.document.blocks.single.attributes['rows'], [
        ['1', '2'],
      ]);

      await activateTableCell(tester, '2');
      await tester.tap(find.byTooltip('Add column right'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(6));
      await tester.tap(find.byTooltip('Delete column 3'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(4));
      expect(tableController.document.blocks.single.attributes['headers'], [
        'A',
        'B',
      ]);
      expect(tableController.document.blocks.single.attributes['rows'], [
        ['1', '2'],
      ]);
    });

    testWidgets(
      'table action buttons mutate on pointer down with a focused cell',
      (tester) async {
        final tableController = BlockController(
          document: BlockDocument([
            BlockNode(
              id: 'table1',
              type: BlockTypes.table,
              attributes: {
                'headers': const ['A', 'B'],
                'rows': const [
                  ['1', '2'],
                ],
              },
            ),
          ]),
        );
        addTearDown(tableController.dispose);
        await tester.pumpWidget(
          wrap(BlockEditorWidget(controller: tableController)),
        );

        await activateTableCell(tester, '1');

        final gesture = await tester.startGesture(
          tester.getCenter(find.byTooltip('Add row below')),
        );
        expect(tableController.document.blocks.single.attributes['rows'], [
          ['1', '2'],
          ['', ''],
        ]);
        await tester.pump();
        await gesture.up();
      },
    );

    testWidgets('table row and column delete controls update attributes', (
      tester,
    ) async {
      final tableController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'table1',
            type: BlockTypes.table,
            attributes: {
              'headers': const ['A', 'B', 'C'],
              'rows': const [
                ['1', '2', '3'],
                ['4', '5', '6'],
              ],
            },
          ),
        ]),
      );
      addTearDown(tableController.dispose);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: tableController)),
      );

      await activateTableCell(tester, '4');
      await tester.tap(find.byTooltip('Delete row 2'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(6));
      expect(tableController.document.blocks.single.attributes['rows'], [
        ['1', '2', '3'],
      ]);

      await activateTableCell(tester, '2');
      await tester.tap(find.byTooltip('Delete column 2'));
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(4));
      expect(tableController.document.blocks.single.attributes['headers'], [
        'A',
        'C',
      ]);
      expect(tableController.document.blocks.single.attributes['rows'], [
        ['1', '3'],
      ]);
    });

    testWidgets('dragging across text creates ExpandedSelection', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));

      final textRect = tester.getRect(find.byType(RichTextRenderer).first);
      final gesture = await tester.startGesture(
        textRect.centerLeft + const Offset(2, 0),
      );
      await gesture.moveBy(const Offset(80, 0));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      final selection = controller.selection;
      expect(selection, isA<ExpandedSelection>());
      final expanded = selection as ExpandedSelection;
      expect(expanded.anchor.blockId, 'b1');
      expect(expanded.focus.blockId, 'b1');
      expect(expanded.focus.offset, greaterThan(expanded.anchor.offset));
    });

    testWidgets('block plus control inserts an empty paragraph below', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));

      await tester.tap(find.byTooltip('Add block below').first);
      await tester.pump();

      expect(controller.document.blocks.length, 4);
      expect(controller.document.blocks[1].type, BlockTypes.paragraph);
      expect(controller.document.blocks[1].delta?.plainText, '');
      final selection = controller.selection as CollapsedSelection;
      expect(selection.point.blockId, controller.document.blocks[1].id);
      expect(selection.point.offset, 0);
    });

    testWidgets('block action menu select marks a whole block selected', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));

      await tester.tap(find.byTooltip('Drag or open block menu').first);
      await tester.pump();
      await tester.tap(find.text('Select block'));
      await tester.pump();

      final selection = controller.selection as ExpandedSelection;
      expect(selection.anchor.blockId, 'b1');
      expect(selection.anchor.offset, 0);
      expect(selection.focus.blockId, 'b1');
      expect(selection.focus.offset, 5);
    });
  });

  group('BlockEditorWidget — keyboard shortcuts', () {
    testWidgets('plain arrow keys move the cursor through Focus.onKeyEvent', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      controller.collapseSelection('b1', 1);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();

      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 2);
    });

    testWidgets('Shift+Arrow extends selection through Focus.onKeyEvent', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      controller.collapseSelection('b1', 1);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      final sel = controller.selection as ExpandedSelection;
      expect(sel.anchor.blockId, 'b1');
      expect(sel.anchor.offset, 1);
      expect(sel.focus.blockId, 'b1');
      expect(sel.focus.offset, 2);
    });

    testWidgets('Meta+ArrowRight moves to line end', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      controller.collapseSelection('b1', 1);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 5);
    });

    testWidgets('Meta+ArrowRight moves to visual line end inside a wrap', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final wrappedController = BlockController(
        document: BlockDocument([
          paragraph(id: 'b1', text: 'abcdefghijklmnopqrst'),
        ]),
      );
      addTearDown(wrappedController.dispose);
      wrappedController.collapseSelection('b1', 7);
      await tester.pumpWidget(
        wrapWithAhem(
          SizedBox(
            width: 80,
            height: 200,
            child: BlockEditorWidget(
              controller: wrappedController,
              focusNode: focusNode,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      final sel = wrappedController.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 8);
    });

    testWidgets('Meta+ArrowLeft moves to visual line start inside a wrap', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final wrappedController = BlockController(
        document: BlockDocument([
          paragraph(id: 'b1', text: 'abcdefghijklmnopqrst'),
        ]),
      );
      addTearDown(wrappedController.dispose);
      wrappedController.collapseSelection('b1', 7);
      await tester.pumpWidget(
        wrapWithAhem(
          SizedBox(
            width: 80,
            height: 200,
            child: BlockEditorWidget(
              controller: wrappedController,
              focusNode: focusNode,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      final sel = wrappedController.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 4);
    });

    testWidgets('Shift+Meta+ArrowLeft extends to visual line start', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final wrappedController = BlockController(
        document: BlockDocument([
          paragraph(id: 'b1', text: 'abcdefghijklmnopqrst'),
        ]),
      );
      addTearDown(wrappedController.dispose);
      wrappedController.collapseSelection('b1', 7);
      await tester.pumpWidget(
        wrapWithAhem(
          SizedBox(
            width: 80,
            height: 200,
            child: BlockEditorWidget(
              controller: wrappedController,
              focusNode: focusNode,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      final sel = wrappedController.selection as ExpandedSelection;
      expect(sel.anchor.blockId, 'b1');
      expect(sel.anchor.offset, 7);
      expect(sel.focus.blockId, 'b1');
      expect(sel.focus.offset, 4);
    });

    testWidgets('Control+ArrowRight moves by word', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      controller.collapseSelection('b1', 0);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 5);
    });

    testWidgets('Meta+Control+Arrow remains reserved for the host', (
      tester,
    ) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      controller.collapseSelection('b1', 1);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 1);
    });

    testWidgets('Ctrl+A triggers selectAll', (tester) async {
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));
      await tester.tap(find.text('First', findRichText: true));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(controller.selection, isA<ExpandedSelection>());
    });

    testWidgets('Ctrl+Z triggers undo', (tester) async {
      controller.append(paragraph(id: 'b4', text: 'Fourth'));
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));
      await tester.tap(find.text('First', findRichText: true));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(controller.document.blocks.length, 3);
    });

    testWidgets('Meta+C copies expanded selection to the clipboard', (
      tester,
    ) async {
      mockClipboard(tester);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      controller.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'b1', offset: 1),
          focus: SelectionPoint(blockId: 'b1', offset: 4),
        ),
      );
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.idle();

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      expect(data?.text, 'irs');
    });

    testWidgets('Meta+V pastes clipboard text at the cursor', (tester) async {
      mockClipboard(tester, initialText: ' pasted');
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      controller.collapseSelection('b1', 5);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.idle();
      await tester.pump();

      expect(
        controller.document.findById('b1')?.delta?.plainText,
        'First pasted',
      );
      final sel = controller.selection as CollapsedSelection;
      expect(sel.point.blockId, 'b1');
      expect(sel.point.offset, 12);
    });

    testWidgets('Meta+X cuts expanded selection immediately', (tester) async {
      mockClipboard(tester);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      controller.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'b1', offset: 0),
          focus: SelectionPoint(blockId: 'b1', offset: 5),
        ),
      );
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, focusNode: focusNode)),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyX);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.idle();

      expect(controller.document.findById('b1')?.delta?.plainText, '');
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      expect(data?.text, 'First');
    });

    testWidgets('Escape clears selection', (tester) async {
      controller.collapseSelection('b1', 0);
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));
      await tester.tap(find.text('First', findRichText: true));
      await tester.pump();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.escape);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.selection, isA<NoSelection>());
    });

    testWidgets('keyboard shortcuts are ignored in readOnly mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: controller, readOnly: true)),
      );
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(controller.selection, isA<NoSelection>());
    });
  });

  group('BlockEditorWidget — numbered list ordinal', () {
    testWidgets('consecutive numbered list items get sequential ordinals', (
      tester,
    ) async {
      final numberedController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'n1',
            type: BlockTypes.numberedList,
            delta: TextDelta.fromPlainText('one'),
          ),
          BlockNode(
            id: 'n2',
            type: BlockTypes.numberedList,
            delta: TextDelta.fromPlainText('two'),
          ),
          BlockNode(
            id: 'n3',
            type: BlockTypes.numberedList,
            delta: TextDelta.fromPlainText('three'),
          ),
        ]),
      );
      addTearDown(numberedController.dispose);
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 400,
            height: 600,
            child: BlockEditorWidget(controller: numberedController),
          ),
        ),
      );
      final widgets = tester
          .widgetList<NumberedListWidget>(find.byType(NumberedListWidget))
          .toList();
      expect(widgets[0].number, 1);
      expect(widgets[1].number, 2);
      expect(widgets[2].number, 3);
    });

    testWidgets('non-numbered block resets counter', (tester) async {
      final mixedController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'n1',
            type: BlockTypes.numberedList,
            delta: TextDelta.fromPlainText('one'),
          ),
          paragraph(id: 'p1', text: 'break'),
          BlockNode(
            id: 'n2',
            type: BlockTypes.numberedList,
            delta: TextDelta.fromPlainText('restart'),
          ),
        ]),
      );
      addTearDown(mixedController.dispose);
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 400,
            height: 600,
            child: BlockEditorWidget(controller: mixedController),
          ),
        ),
      );
      final widgets = tester
          .widgetList<NumberedListWidget>(find.byType(NumberedListWidget))
          .toList();
      expect(widgets[0].number, 1);
      expect(widgets[1].number, 1);
    });
  });
}
