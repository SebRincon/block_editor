import 'package:block_editor/block_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Directionality(textDirection: TextDirection.ltr, child: child),
    ),
  );
}

Future<void> activateTableCell(WidgetTester tester, String text) async {
  await hoverTableCell(tester, text);
  await tester.tap(find.widgetWithText(TextField, text));
  await tester.pump();
  await tester.pump();
}

Future<void> hoverTableCell(WidgetTester tester, String text) async {
  final finder = find.widgetWithText(TextField, text);
  await tester.sendEventToBinding(
    PointerHoverEvent(
      position: tester.getCenter(finder),
      kind: PointerDeviceKind.mouse,
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<void> hoverOutsideEditor(WidgetTester tester) async {
  await tester.sendEventToBinding(
    const PointerHoverEvent(
      position: Offset(790, 590),
      kind: PointerDeviceKind.mouse,
    ),
  );
  await tester.pump();
}

void main() {
  final helloDelta = TextDelta.fromPlainText('hello');

  group('ParagraphWidget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(
          ParagraphWidget(blockId: 'b1', delta: helloDelta, onEvent: (_) {}),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          ParagraphWidget(
            blockId: 'b1',
            delta: helloDelta,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(ParagraphWidget));
      expect(received, isA<TapEvent>());
      expect((received as TapEvent).blockId, 'b1');
    });
  });

  group('H1Widget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(H1Widget(blockId: 'b1', delta: helloDelta, onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          H1Widget(
            blockId: 'b1',
            delta: helloDelta,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(H1Widget));
      expect(received, isA<TapEvent>());
    });
  });

  group('H2Widget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(H2Widget(blockId: 'b1', delta: helloDelta, onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          H2Widget(
            blockId: 'b1',
            delta: helloDelta,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(H2Widget));
      expect(received, isA<TapEvent>());
    });
  });

  group('H3Widget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(H3Widget(blockId: 'b1', delta: helloDelta, onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          H3Widget(
            blockId: 'b1',
            delta: helloDelta,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(H3Widget));
      expect(received, isA<TapEvent>());
    });
  });

  group('BulletListWidget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(
          BulletListWidget(
            blockId: 'b1',
            delta: helloDelta,
            attributes: const {},
            onEvent: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders bullet marker', (tester) async {
      await tester.pumpWidget(
        wrap(
          BulletListWidget(
            blockId: 'b1',
            delta: helloDelta,
            attributes: const {},
            onEvent: (_) {},
          ),
        ),
      );
      expect(find.text('•'), findsOneWidget);
    });

    testWidgets('applies indent padding', (tester) async {
      await tester.pumpWidget(
        wrap(
          BulletListWidget(
            blockId: 'b1',
            delta: helloDelta,
            attributes: const {'indent': 2},
            onEvent: (_) {},
          ),
        ),
      );
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, const EdgeInsetsDirectional.only(start: 56.0));
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 400,
            height: 50,
            child: BulletListWidget(
              blockId: 'b1',
              delta: helloDelta,
              attributes: const {},
              onEvent: (e) => received = e,
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(200, 10));
      expect(received, isA<TapEvent>());
    });
  });

  group('NumberedListWidget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(
          NumberedListWidget(
            blockId: 'b1',
            delta: helloDelta,
            attributes: const {},
            number: 1,
            onEvent: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders number marker', (tester) async {
      await tester.pumpWidget(
        wrap(
          NumberedListWidget(
            blockId: 'b1',
            delta: helloDelta,
            attributes: const {},
            number: 3,
            onEvent: (_) {},
          ),
        ),
      );
      expect(find.text('3.'), findsOneWidget);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 400,
            height: 50,
            child: NumberedListWidget(
              blockId: 'b1',
              delta: helloDelta,
              attributes: const {},
              number: 1,
              onEvent: (e) => received = e,
            ),
          ),
        ),
      );
      await tester.tapAt(const Offset(200, 10));
      expect(received, isA<TapEvent>());
    });
  });

  group('TodoWidget', () {
    testWidgets('renders unchecked without error', (tester) async {
      await tester.pumpWidget(
        wrap(
          TodoWidget(
            blockId: 'b1',
            delta: helloDelta,
            checked: false,
            attributes: const {},
            onEvent: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders checked without error', (tester) async {
      await tester.pumpWidget(
        wrap(
          TodoWidget(
            blockId: 'b1',
            delta: helloDelta,
            checked: true,
            attributes: const {},
            onEvent: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('tapping checkbox emits CheckboxToggledEvent with true', (
      tester,
    ) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          TodoWidget(
            blockId: 'b1',
            delta: helloDelta,
            checked: false,
            attributes: const {},
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(Container).first);
      expect(received, isA<CheckboxToggledEvent>());
      expect((received as CheckboxToggledEvent).checked, isTrue);
    });

    testWidgets('tapping checkbox emits CheckboxToggledEvent with false', (
      tester,
    ) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          TodoWidget(
            blockId: 'b1',
            delta: helloDelta,
            checked: true,
            attributes: const {},
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(Container).first);
      expect((received as CheckboxToggledEvent).checked, isFalse);
    });

    testWidgets('tapping text area emits TapEvent', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          TodoWidget(
            blockId: 'b1',
            delta: helloDelta,
            checked: false,
            attributes: const {},
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.text('hello', findRichText: true));
      expect(received, isA<TapEvent>());
    });

    testWidgets('applies indent padding', (tester) async {
      await tester.pumpWidget(
        wrap(
          TodoWidget(
            blockId: 'b1',
            delta: helloDelta,
            checked: false,
            attributes: const {'indent': 2},
            onEvent: (_) {},
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, const EdgeInsetsDirectional.only(start: 56.0));
    });

    testWidgets('checked state renders strikethrough on text', (tester) async {
      await tester.pumpWidget(
        wrap(
          TodoWidget(
            blockId: 'b1',
            delta: helloDelta,
            checked: true,
            attributes: const {},
            onEvent: (_) {},
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text).first);
      expect(text.textSpan!.style!.decoration, TextDecoration.lineThrough);
    });
  });

  group('QuoteWidget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(QuoteWidget(blockId: 'b1', delta: helloDelta, onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          QuoteWidget(
            blockId: 'b1',
            delta: helloDelta,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(QuoteWidget));
      expect(received, isA<TapEvent>());
    });
  });

  group('DividerWidget', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(DividerWidget(blockId: 'b1', onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a Divider widget', (tester) async {
      await tester.pumpWidget(
        wrap(DividerWidget(blockId: 'b1', onEvent: (_) {})),
      );
      expect(find.byType(Divider), findsOneWidget);
    });
  });

  group('TableWidget', () {
    testWidgets('renders header and body cells', (tester) async {
      await tester.pumpWidget(
        wrap(
          TableWidget(
            blockId: 'table1',
            headers: const ['Model', 'License'],
            rows: const [
              ['Small', 'Apache-2.0'],
              ['Large', 'CC-BY-NC-4.0'],
            ],
            alignments: const [],
            onEvent: (_) {},
          ),
        ),
      );

      expect(find.text('Model', findRichText: true), findsOneWidget);
      expect(find.text('Apache-2.0', findRichText: true), findsOneWidget);
    });

    testWidgets('renders inline markdown in inactive editable cells', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          TableWidget(
            blockId: 'table1',
            headers: const ['Name'],
            rows: const [
              ['**Bold** and *soft*'],
            ],
            alignments: const [],
            onEvent: (_) {},
          ),
        ),
      );

      expect(find.text('Bold and soft', findRichText: true), findsOneWidget);
      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, '**Bold** and *soft*'),
      );
      expect(textField.maxLines, isNull);
    });

    testWidgets('shrink-wraps narrow tables instead of filling the row', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 500,
            child: TableWidget(
              blockId: 'table1',
              headers: const ['A', 'B'],
              rows: const [
                ['1', '2'],
              ],
              alignments: const [],
              onEvent: (_) {},
            ),
          ),
        ),
      );

      final tableSize = tester.getSize(find.byType(Table));
      expect(tableSize.width, lessThan(500));
    });

    testWidgets('positions table action controls outside the table border', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 500,
            child: TableWidget(
              blockId: 'table1',
              headers: const ['A', 'B'],
              rows: const [
                ['1', '2'],
                ['3', '4'],
              ],
              alignments: const [],
              onEvent: (_) {},
            ),
          ),
        ),
      );

      await activateTableCell(tester, '3');
      final tableRect = tester.getRect(find.byType(Table));
      final rowControlRect = tester.getRect(find.byTooltip('Add row below'));
      expect(rowControlRect.left, greaterThan(tableRect.right));

      await activateTableCell(tester, 'B');
      final columnControlRect = tester.getRect(
        find.byTooltip('Add column right'),
      );
      expect(columnControlRect.bottom, lessThan(tableRect.top));
    });

    testWidgets('hides table action controls outside table hover', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 500,
            child: TableWidget(
              blockId: 'table1',
              headers: const ['A', 'B'],
              rows: const [
                ['1', '2'],
              ],
              alignments: const [],
              onEvent: (_) {},
            ),
          ),
        ),
      );

      expect(find.byTooltip('Add column right'), findsNothing);
      expect(find.byTooltip('Add row below'), findsNothing);

      await hoverTableCell(tester, '1');
      expect(find.byTooltip('Add column right'), findsOneWidget);
      expect(find.byTooltip('Add row below'), findsOneWidget);

      await hoverOutsideEditor(tester);
      expect(find.byTooltip('Add column right'), findsNothing);
      expect(find.byTooltip('Add row below'), findsNothing);
    });

    testWidgets('emits TableCellChangedEvent when a cell is edited', (
      tester,
    ) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 500,
            child: TableWidget(
              blockId: 'table1',
              headers: const ['A', 'B'],
              rows: const [
                ['1', '2'],
              ],
              alignments: const [],
              onEvent: (event) => received = event,
            ),
          ),
        ),
      );
      await tester.enterText(find.widgetWithText(TextField, '1'), 'updated');
      await tester.pump();

      expect(received, isA<TableCellChangedEvent>());
      final event = received as TableCellChangedEvent;
      expect(event.blockId, 'table1');
      expect(event.header, isFalse);
      expect(event.rowIndex, 0);
      expect(event.columnIndex, 0);
      expect(event.text, 'updated');
    });

    testWidgets('emits table action events on pointer down', (tester) async {
      final events = <BlockEvent>[];
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 500,
            child: TableWidget(
              blockId: 'table1',
              headers: const ['A', 'B'],
              rows: const [
                ['1', '2'],
                ['3', '4'],
              ],
              alignments: const [],
              onEvent: events.add,
            ),
          ),
        ),
      );

      await activateTableCell(tester, '3');
      final addRowGesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Add row below')),
      );
      expect(events.single, isA<TableRowInsertedEvent>());
      expect((events.single as TableRowInsertedEvent).index, 2);
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(8));
      await addRowGesture.up();
      events.clear();

      final deleteRowGesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Delete row 3')),
      );
      expect(events.single, isA<TableRowDeletedEvent>());
      expect((events.single as TableRowDeletedEvent).index, 2);
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(6));
      await deleteRowGesture.up();
      events.clear();

      await activateTableCell(tester, '2');
      final deleteColumnGesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Delete column 2')),
      );
      expect(events.single, isA<TableColumnDeletedEvent>());
      expect((events.single as TableColumnDeletedEvent).index, 1);
      await tester.pump();
      expect(find.byType(TextField), findsNWidgets(3));
      await deleteColumnGesture.up();
    });

    testWidgets('emits TapEvent on tap in read-only mode', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            readOnly: true,
            child: SizedBox(
              width: 500,
              child: TableWidget(
                blockId: 'table1',
                headers: const ['A', 'B'],
                rows: const [
                  ['1', '2'],
                ],
                alignments: const [],
                onEvent: (event) => received = event,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DecoratedBox).last);
      expect(received, isA<TapEvent>());
      expect((received as TapEvent).blockId, 'table1');
    });
  });

  group('BlockEvent', () {
    test('TapEvent carries blockId and offset', () {
      const e = TapEvent(blockId: 'b1', offset: 5);
      expect(e.blockId, 'b1');
      expect(e.offset, 5);
    });

    test('CheckboxToggledEvent carries blockId and checked', () {
      const e = CheckboxToggledEvent(blockId: 'b1', checked: true);
      expect(e.blockId, 'b1');
      expect(e.checked, isTrue);
    });

    test('CodeBlockChangedEvent carries blockId and text', () {
      const e = CodeBlockChangedEvent(blockId: 'code1', text: 'print(1);');
      expect(e.blockId, 'code1');
      expect(e.text, 'print(1);');
    });

    test('MathBlockChangedEvent carries blockId and text', () {
      const e = MathBlockChangedEvent(blockId: 'math1', text: 'E = mc^2');
      expect(e.blockId, 'math1');
      expect(e.text, 'E = mc^2');
    });

    test('MermaidBlockChangedEvent carries blockId and text', () {
      const e = MermaidBlockChangedEvent(blockId: 'diagram1', text: 'graph TD');
      expect(e.blockId, 'diagram1');
      expect(e.text, 'graph TD');
    });

    test('TableColumnAlignmentChangedEvent carries blockId and alignment', () {
      const e = TableColumnAlignmentChangedEvent(
        blockId: 'table1',
        columnIndex: 1,
        alignment: 'right',
      );
      expect(e.blockId, 'table1');
      expect(e.columnIndex, 1);
      expect(e.alignment, 'right');
    });

    test('RawMarkdownChangedEvent carries blockId and text', () {
      const e = RawMarkdownChangedEvent(
        blockId: 'raw1',
        text: '<div>raw</div>',
      );
      expect(e.blockId, 'raw1');
      expect(e.text, '<div>raw</div>');
    });
  });
}
