import 'package:block_editor/block_editor.dart';
import 'package:flutter/gestures.dart';
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
  await hoverTableCell(tester, text);
  await tester.tap(_tableCellFinder(text));
  await tester.pump();
  await tester.pump();
}

Future<void> hoverTableCell(WidgetTester tester, String text) async {
  final finder = _tableCellFinder(text);
  await tester.sendEventToBinding(
    PointerHoverEvent(
      position: tester.getCenter(finder),
      kind: PointerDeviceKind.mouse,
    ),
  );
  await tester.pump();
  await tester.pump();
}

Finder _tableCellFinder(String text) {
  final field = find.widgetWithText(TextField, text);
  if (field.evaluate().isNotEmpty) return field;

  final renderable = text.replaceAll(
    RegExp(r'<br\s*/?>', caseSensitive: false),
    '\n',
  );
  final plain = BlockMarkdownCodec.parseInline(renderable).plainText;
  final richText = find.byWidgetPredicate(
    (widget) => widget is RichText && widget.text.toPlainText() == plain,
  );
  if (richText.evaluate().isNotEmpty) return richText;

  return find.text(plain, findRichText: true);
}

Finder _tableCellSurfaceFinder(String tableId) {
  return find.byWidgetPredicate((widget) {
    final key = widget.key;
    return key is ValueKey<String> &&
        key.value.startsWith('block-editor-table-cell-$tableId-');
  });
}

Future<void> hoverBlockText(WidgetTester tester, String text) async {
  await tester.sendEventToBinding(
    PointerHoverEvent(
      position: tester.getCenter(find.text(text, findRichText: true)),
      kind: PointerDeviceKind.mouse,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
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

      await activateTableCell(tester, 'Draft');
      await tester.enterText(find.widgetWithText(TextField, 'Draft'), 'Done');
      await tester.pump();

      expect(tableController.document.blocks.single.attributes['rows'], [
        ['Done', 'Open'],
      ]);
    });

    testWidgets('decoded markdown tables render inline styles in cells', (
      tester,
    ) async {
      final tableController = BlockController(
        document: BlockMarkdownCodec.decode('''
| Syntax | Rendered |
| --- | --- |
| Bold | **bold text** |
| Italic | *italic text* |
| Highlight | ==highlighted text== |
| Code | `inline code` |
| Link | [Docs](https://example.com) |
| Wiki | [[Target page|alias]] |
'''),
      );
      addTearDown(tableController.dispose);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: tableController)),
      );

      expect(find.text('bold text', findRichText: true), findsOneWidget);
      expect(find.text('italic text', findRichText: true), findsOneWidget);
      expect(find.text('highlighted text', findRichText: true), findsOneWidget);
      expect(find.text('inline code', findRichText: true), findsOneWidget);
      expect(find.text('Docs', findRichText: true), findsOneWidget);
      expect(find.text('alias', findRichText: true), findsOneWidget);
      expect(find.text('**bold text**', findRichText: true), findsNothing);
      expect(
        find.text('==highlighted text==', findRichText: true),
        findsNothing,
      );
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

      await activateTableCell(tester, 'Draft');
      await tester.enterText(find.widgetWithText(TextField, 'Draft'), 'Done');
      await tester.pump();

      expect(tableController.document.blocks.first.delta?.plainText, 'Intro');
      expect(tableController.document.blocks.last.attributes['rows'], [
        ['Done', 'Open'],
      ]);
    });

    testWidgets('code block edits update the block delta', (tester) async {
      final codeController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'code1',
            type: BlockTypes.code,
            attributes: {'language': 'dart'},
            delta: TextDelta.fromPlainText('void main() {}'),
          ),
        ]),
      );
      addTearDown(codeController.dispose);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: codeController)),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'void main() {}'),
        'void main() {\n  print("hi");\n}',
      );
      await tester.pump();

      expect(
        codeController.document.findById('code1')?.delta?.plainText,
        'void main() {\n  print("hi");\n}',
      );
    });

    testWidgets('code block editor opts out of ambient filled inputs', (
      tester,
    ) async {
      final codeController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'code1',
            type: BlockTypes.code,
            attributes: {'language': 'dart'},
            delta: TextDelta.fromPlainText('void main() {}'),
          ),
        ]),
      );
      addTearDown(codeController.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.red,
            ),
          ),
          home: Scaffold(body: BlockEditorWidget(controller: codeController)),
        ),
      );

      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'void main() {}'),
      );
      expect(textField.decoration?.filled, isFalse);
      expect(textField.decoration?.fillColor, Colors.transparent);
    });

    testWidgets('raw Markdown block edits update the block delta', (
      tester,
    ) async {
      final rawController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'raw1',
            type: BlockTypes.rawMarkdown,
            delta: TextDelta.fromPlainText('<div>raw</div>'),
          ),
        ]),
      );
      addTearDown(rawController.dispose);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: rawController)),
      );

      await tester.enterText(
        find.widgetWithText(TextField, '<div>raw</div>'),
        '<section>\nraw\n</section>',
      );
      await tester.pump();

      expect(
        rawController.document.findById('raw1')?.delta?.plainText,
        '<section>\nraw\n</section>',
      );
    });

    testWidgets('math block edits update the block delta', (tester) async {
      final mathController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'math1',
            type: BlockTypes.math,
            delta: TextDelta.fromPlainText('E = mc^2'),
          ),
        ]),
      );
      addTearDown(mathController.dispose);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: mathController)),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'E = mc^2'),
        r'\int_0^1 x dx',
      );
      await tester.pump();

      expect(
        mathController.document.findById('math1')?.delta?.plainText,
        r'\int_0^1 x dx',
      );
    });

    testWidgets('Mermaid block edits update the block delta', (tester) async {
      final mermaidController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'diagram1',
            type: BlockTypes.mermaid,
            delta: TextDelta.fromPlainText('graph TD\nA --> B'),
          ),
        ]),
      );
      addTearDown(mermaidController.dispose);
      await tester.pumpWidget(
        wrap(BlockEditorWidget(controller: mermaidController)),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'graph TD\nA --> B'),
        'sequenceDiagram\nA->>B: hello',
      );
      await tester.pump();

      expect(
        mermaidController.document.findById('diagram1')?.delta?.plainText,
        'sequenceDiagram\nA->>B: hello',
      );
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
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(4));
      await tester.tap(find.byTooltip('Add row below'));
      await tester.pump();
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(6));
      expect(tableController.document.blocks.single.attributes['rows'], [
        ['1', '2'],
        ['', ''],
      ]);

      await tester.tap(find.byTooltip('Add column right'));
      await tester.pump();
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(9));
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
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(6));
      await tester.tap(find.byTooltip('Delete row 2'));
      await tester.pump();
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(4));
      expect(tableController.document.blocks.single.attributes['rows'], [
        ['1', '2'],
      ]);

      await activateTableCell(tester, '2');
      await tester.tap(find.byTooltip('Add column right'));
      await tester.pump();
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(6));
      await tester.tap(find.byTooltip('Delete column 3'));
      await tester.pump();
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(4));
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
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(6));
      expect(tableController.document.blocks.single.attributes['rows'], [
        ['1', '2', '3'],
      ]);

      await activateTableCell(tester, '2');
      await tester.tap(find.byTooltip('Delete column 2'));
      await tester.pump();
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(4));
      expect(tableController.document.blocks.single.attributes['headers'], [
        'A',
        'C',
      ]);
      expect(tableController.document.blocks.single.attributes['rows'], [
        ['1', '3'],
      ]);
    });

    testWidgets('table alignment controls update column alignments', (
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

      await hoverTableCell(tester, 'A');
      await tester.tap(find.byTooltip('Align center'));
      await tester.pump();

      expect(tableController.document.blocks.single.attributes['alignments'], [
        'center',
        '',
      ]);

      await hoverTableCell(tester, 'A');
      await tester.tap(find.byTooltip('Align center'));
      await tester.pump();

      expect(tableController.document.blocks.single.attributes['alignments'], [
        '',
        '',
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

    testWidgets('block plus control is not shown by default', (tester) async {
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));

      await hoverBlockText(tester, 'First');

      expect(find.byTooltip('Add block below'), findsNothing);
      expect(controller.document.blocks.length, 3);
    });

    testWidgets('block action menu select marks a whole block selected', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(BlockEditorWidget(controller: controller)));

      await hoverBlockText(tester, 'First');
      expect(find.byTooltip('Drag or open block menu'), findsNothing);
      await tester.tap(find.byIcon(Icons.drag_indicator).first);
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

    testWidgets('Tab and Shift+Tab indent task list blocks', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final listController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'task1',
            type: BlockTypes.todo,
            attributes: const {'checked': false},
            delta: TextDelta.fromPlainText('child task'),
          ),
        ]),
      );
      addTearDown(listController.dispose);
      listController.collapseSelection('task1', 0);
      await tester.pumpWidget(
        wrap(
          BlockEditorWidget(controller: listController, focusNode: focusNode),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        listController.document.findById('task1')!.attributes['indent'],
        1,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(
        listController.document.findById('task1')!.attributes['indent'],
        0,
      );
    });

    testWidgets('Tab indents selected list blocks as a group', (tester) async {
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final listController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'task1',
            type: BlockTypes.todo,
            attributes: const {'checked': false},
            delta: TextDelta.fromPlainText('first task'),
          ),
          BlockNode(
            id: 'task2',
            type: BlockTypes.bulletList,
            delta: TextDelta.fromPlainText('second task'),
          ),
          paragraph(id: 'p1', text: 'not a list'),
        ]),
      );
      addTearDown(listController.dispose);
      listController.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'task1', offset: 0),
          focus: SelectionPoint(blockId: 'task2', offset: 11),
        ),
      );
      await tester.pumpWidget(
        wrap(
          BlockEditorWidget(controller: listController, focusNode: focusNode),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      expect(
        listController.document.findById('task1')!.attributes['indent'],
        1,
      );
      expect(
        listController.document.findById('task2')!.attributes['indent'],
        1,
      );
      expect(
        listController.document.findById('p1')!.attributes['indent'],
        isNull,
      );

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();

      expect(
        listController.document.findById('task1')!.attributes['indent'],
        isNull,
      );
      expect(
        listController.document.findById('task2')!.attributes['indent'],
        isNull,
      );
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
      expect(sel.point.offset, 10);
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
      expect(sel.point.offset, 5);
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
      expect(sel.focus.offset, 5);
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

    testWidgets('Meta+C copies fully selected blocks as markdown', (
      tester,
    ) async {
      mockClipboard(tester);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final markdownController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'h1',
            type: BlockTypes.heading1,
            delta: TextDelta.fromPlainText('Title'),
          ),
          BlockNode(
            id: 'todo1',
            type: BlockTypes.todo,
            attributes: const {'checked': true, 'indent': 1},
            delta: TextDelta.fromPlainText('Done'),
          ),
        ]),
      );
      addTearDown(markdownController.dispose);
      markdownController.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'h1', offset: 0),
          focus: SelectionPoint(blockId: 'todo1', offset: 4),
        ),
      );
      await tester.pumpWidget(
        wrap(
          BlockEditorWidget(
            controller: markdownController,
            focusNode: focusNode,
          ),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.idle();

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      expect(data?.text, '# Title\n\n  - [x] Done');
    });

    testWidgets('Meta+C copies fully selected tables as markdown', (
      tester,
    ) async {
      mockClipboard(tester);
      final focusNode = FocusNode();
      addTearDown(focusNode.dispose);
      final tableController = BlockController(
        document: BlockDocument([
          BlockNode(
            id: 'table1',
            type: BlockTypes.table,
            attributes: const {
              'headers': ['Name', 'Status'],
              'rows': [
                ['CodeForge', '**ready**'],
              ],
              'alignments': ['left', 'center'],
            },
          ),
        ]),
      );
      addTearDown(tableController.dispose);
      tableController.updateSelection(
        const ExpandedSelection(
          anchor: SelectionPoint(blockId: 'table1', offset: 0),
          focus: SelectionPoint(blockId: 'table1', offset: 0),
        ),
      );
      await tester.pumpWidget(
        wrap(
          BlockEditorWidget(controller: tableController, focusNode: focusNode),
        ),
      );
      focusNode.requestFocus();
      await tester.pump();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.idle();

      final data = await Clipboard.getData(Clipboard.kTextPlain);
      expect(data?.text, '''
| Name | Status |
| :--- | :---: |
| CodeForge | **ready** |''');
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

    testWidgets('nested numbered list items count within their indent', (
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
            attributes: const {'indent': 1},
            delta: TextDelta.fromPlainText('child one'),
          ),
          BlockNode(
            id: 'n3',
            type: BlockTypes.numberedList,
            attributes: const {'indent': 1},
            delta: TextDelta.fromPlainText('child two'),
          ),
          BlockNode(
            id: 'n4',
            type: BlockTypes.numberedList,
            delta: TextDelta.fromPlainText('two'),
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
      expect(widgets.map((widget) => widget.number), [1, 1, 2, 2]);
    });
  });
}
