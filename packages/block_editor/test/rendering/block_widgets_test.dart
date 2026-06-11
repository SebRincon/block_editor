import 'package:block_editor/block_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

Future<void> hoverOutsideEditor(WidgetTester tester) async {
  await tester.sendEventToBinding(
    const PointerHoverEvent(
      position: Offset(790, 590),
      kind: PointerDeviceKind.mouse,
    ),
  );
  await tester.pump();
}

Future<void> sendMetaShortcut(
  WidgetTester tester,
  LogicalKeyboardKey key,
) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  await tester.sendKeyEvent(key);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  await tester.pump();
}

Future<void> sendPlainKey(WidgetTester tester, LogicalKeyboardKey key) async {
  await tester.sendKeyDownEvent(key);
  await tester.sendKeyUpEvent(key);
  await tester.pump();
  await tester.pump();
}

Future<void> sendShiftTab(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyDownEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.tab);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
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

TextField focusedTextField(WidgetTester tester) {
  return tester
      .widgetList<TextField>(find.byType(TextField))
      .singleWhere((field) => field.focusNode?.hasFocus ?? false);
}

Finder _tableResizeHandleFinder(MouseCursor cursor) {
  return find.byWidgetPredicate(
    (widget) => widget is MouseRegion && widget.cursor == cursor,
  );
}

Iterable<TextSpan> flattenTextSpan(TextSpan span) sync* {
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) yield* flattenTextSpan(child);
  }
}

TextSpan richTextSpanWithPlainText(WidgetTester tester, String plainText) {
  for (final widget in tester.widgetList<RichText>(find.byType(RichText))) {
    final span = widget.text;
    if (span is TextSpan && span.toPlainText() == plainText) {
      return span;
    }
  }
  throw TestFailure('No RichText span found for "$plainText".');
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

    testWidgets('renders a drawn bullet marker', (tester) async {
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
      expect(
        find.byKey(const ValueKey('block-editor-bullet-marker-filledCircle')),
        findsOneWidget,
      );
    });

    testWidgets('nested bullets use inverted drawn markers', (tester) async {
      await tester.pumpWidget(
        wrap(
          Column(
            children: [
              BulletListWidget(
                blockId: 'b1',
                delta: helloDelta,
                attributes: const {'indent': 1},
                onEvent: (_) {},
              ),
              BulletListWidget(
                blockId: 'b2',
                delta: helloDelta,
                attributes: const {'indent': 2},
                onEvent: (_) {},
              ),
            ],
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('block-editor-bullet-marker-invertedCircle')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('block-editor-bullet-marker-invertedSquare')),
        findsOneWidget,
      );
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

    testWidgets('uses Markdown theme list metrics and marker offset', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          Builder(
            builder: (context) {
              final theme = MarkdownDocumentThemeData.defaults(context);
              return MarkdownDocumentTheme(
                data: theme.copyWith(
                  listIndentWidth: 36,
                  listMarkerWidth: 40,
                  numberedListMarkerVerticalOffset: -4,
                ),
                child: NumberedListWidget(
                  blockId: 'b1',
                  delta: helloDelta,
                  attributes: const {'indent': 2},
                  number: 7,
                  onEvent: (_) {},
                ),
              );
            },
          ),
        ),
      );

      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, const EdgeInsetsDirectional.only(start: 72.0));

      final markerBox = tester.widget<SizedBox>(
        find
            .ancestor(of: find.text('7.'), matching: find.byType(SizedBox))
            .first,
      );
      expect(markerBox.width, 44);

      final markerTransform = tester.widget<Transform>(
        find
            .ancestor(of: find.text('7.'), matching: find.byType(Transform))
            .first,
      );
      expect(markerTransform.transform.storage[13], -4);
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

  group('MermaidBlockWidget', () {
    Finder mermaidPainter() {
      return find.byWidgetPredicate(
        (widget) =>
            widget is CustomPaint &&
            widget.painter.runtimeType.toString().contains(
              'MermaidDiagramPainter',
            ),
      );
    }

    testWidgets('renders flowcharts as a painted diagram preview', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 640,
            child: MermaidBlockWidget(
              blockId: 'diagram1',
              delta: TextDelta.fromPlainText(
                'graph TD\n'
                'Editor[Editable editor] --> Blocks[Block document]\n'
                'Blocks --> Markdown[Markdown export]',
              ),
              onEvent: (_) {},
            ),
          ),
        ),
      );

      expect(mermaidPainter(), findsOneWidget);
    });

    testWidgets('renders sequence diagrams as a painted diagram preview', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 640,
            child: MermaidBlockWidget(
              blockId: 'diagram1',
              delta: TextDelta.fromPlainText(
                'sequenceDiagram\n'
                'participant User\n'
                'participant Editor\n'
                'User->>Editor: edit blocks',
              ),
              onEvent: (_) {},
            ),
          ),
        ),
      );

      expect(mermaidPainter(), findsOneWidget);
    });

    testWidgets('renders focused split editor preview on wide layouts', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 900,
            child: MermaidBlockWidget(
              blockId: 'diagram1',
              delta: TextDelta.fromPlainText(
                'graph TD\n'
                'Editor[Editable editor] --> Blocks[Block document]\n'
                'Blocks --> Markdown[Markdown export]',
              ),
              onEvent: (_) {},
            ),
          ),
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(MermaidBlockWidget)));
      await tester.pump();
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.byType(TextField), findsOneWidget);
      expect(mermaidPainter(), findsOneWidget);
    });

    testWidgets('keeps split editor and preview panels at the same height', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 900,
            child: MermaidBlockWidget(
              blockId: 'diagram1',
              delta: TextDelta.fromPlainText(
                'graph TD\n'
                'A[Plan] --> B[Build]\n'
                'B --> C[Test]\n'
                'C --> D[Ship]',
              ),
              onEvent: (_) {},
            ),
          ),
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(MermaidBlockWidget)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));

      final editorSize = tester.getSize(
        find.byKey(const ValueKey('block-editor-source-editor-diagram1')),
      );
      final previewSize = tester.getSize(
        find.byKey(const ValueKey('block-editor-source-preview-diagram1')),
      );

      expect(editorSize.height, previewSize.height);
      expect(previewSize.height, greaterThan(260));
    });

    testWidgets('highlights Mermaid source tokens while editing', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 900,
            child: MermaidBlockWidget(
              blockId: 'diagram1',
              delta: TextDelta.fromPlainText(
                'graph TD\nA[Start] --> B{Choice}',
              ),
              onEvent: (_) {},
            ),
          ),
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(MermaidBlockWidget)));
      await tester.pump();
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      final span = field.controller!.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        style: const TextStyle(color: Colors.white),
        withComposing: false,
      );

      final spans = flattenTextSpan(span).toList();
      expect(
        spans.any(
          (child) => child.text == 'graph' && child.style?.color != null,
        ),
        isTrue,
      );
      expect(
        spans.any((child) => child.text == '-->' && child.style?.color != null),
        isTrue,
      );
    });

    testWidgets('uses host-provided source highlighter while editing', (
      tester,
    ) async {
      BlockSourceHighlightRequest? receivedRequest;
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            sourceEditingConfig: BlockSourceEditingConfig(
              highlighter: (request) {
                receivedRequest = request;
                return TextSpan(
                  text: request.source,
                  style: request.baseStyle.copyWith(color: Colors.pink),
                );
              },
            ),
            child: SizedBox(
              width: 900,
              child: MermaidBlockWidget(
                blockId: 'diagram1',
                delta: TextDelta.fromPlainText('graph TD\nA --> B'),
                onEvent: (_) {},
              ),
            ),
          ),
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(MermaidBlockWidget)));
      await tester.pump();
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      final span = field.controller!.buildTextSpan(
        context: tester.element(find.byType(TextField)),
        style: const TextStyle(color: Colors.white),
        withComposing: false,
      );

      expect(receivedRequest?.blockId, 'diagram1');
      expect(receivedRequest?.language, 'mermaid');
      expect(receivedRequest?.source, 'graph TD\nA --> B');
      expect(span.style?.color, Colors.pink);
    });

    testWidgets('embedded Mermaid editor handles macOS line shortcuts', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 900,
            child: MermaidBlockWidget(
              blockId: 'diagram1',
              delta: TextDelta.fromPlainText(
                'graph TD\nA[Start] --> B{Choice}',
              ),
              onEvent: (_) {},
            ),
          ),
        ),
      );

      await tester.tapAt(tester.getCenter(find.byType(MermaidBlockWidget)));
      await tester.pump();
      await tester.pump();

      final field = tester.widget<TextField>(find.byType(TextField));
      final controller = field.controller!;
      controller.selection = const TextSelection.collapsed(offset: 17);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(controller.selection.extentOffset, 9);
      expect(controller.selection.isCollapsed, isTrue);

      controller.selection = const TextSelection.collapsed(offset: 17);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
      await tester.pump();

      expect(controller.selection.baseOffset, 17);
      expect(controller.selection.extentOffset, 9);
    });

    testWidgets('source editor opts out of ambient filled inputs', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.red,
            ),
          ),
          home: Scaffold(
            body: MermaidBlockWidget(
              blockId: 'diagram1',
              delta: TextDelta.fromPlainText('graph TD\nA --> B'),
              onEvent: (_) {},
            ),
          ),
        ),
      );

      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.decoration?.filled, isFalse);
      expect(textField.decoration?.fillColor, Colors.transparent);
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

      expect(find.text('Model', findRichText: true), findsAtLeastNWidgets(1));
      expect(
        find.text('Apache-2.0', findRichText: true),
        findsAtLeastNWidgets(1),
      );
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
      final richSpan = richTextSpanWithPlainText(tester, 'Bold and soft');
      final styledChildren = flattenTextSpan(richSpan).toList();
      expect(
        styledChildren.any(
          (span) =>
              span.text == 'Bold' && span.style?.fontWeight == FontWeight.bold,
        ),
        isTrue,
      );
      expect(
        styledChildren.any(
          (span) =>
              span.text == 'soft' && span.style?.fontStyle == FontStyle.italic,
        ),
        isTrue,
      );
      expect(
        find.widgetWithText(TextField, '**Bold** and *soft*'),
        findsNothing,
      );

      await activateTableCell(tester, '**Bold** and *soft*');
      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, '**Bold** and *soft*'),
      );
      expect(textField.maxLines, isNull);
    });

    testWidgets('renders all inactive table cells through inline markdown', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          TableWidget(
            blockId: 'table1',
            headers: const ['Link', 'Highlight', 'Wiki', 'Code'],
            rows: const [
              [
                '[Docs](https://example.com)',
                '==Marked== text',
                '[[Daily note|Daily]]',
                '`inline` code',
              ],
            ],
            alignments: const [],
            onEvent: (_) {},
          ),
        ),
      );

      expect(find.text('Docs', findRichText: true), findsOneWidget);
      expect(find.text('Marked text', findRichText: true), findsOneWidget);
      expect(find.text('Daily', findRichText: true), findsOneWidget);
      expect(find.text('inline code', findRichText: true), findsOneWidget);
    });

    testWidgets('cell text selection theme uses editor blue', (tester) async {
      await tester.pumpWidget(
        wrap(
          TableWidget(
            blockId: 'table1',
            headers: const ['A'],
            rows: const [
              ['1'],
            ],
            alignments: const [],
            onEvent: (_) {},
          ),
        ),
      );

      await activateTableCell(tester, '1');
      final fieldContext = tester.element(find.widgetWithText(TextField, '1'));
      final selectionTheme = TextSelectionTheme.of(fieldContext);
      expect(selectionTheme.selectionColor, const Color(0x663B82F6));
      expect(selectionTheme.cursorColor, const Color(0xFF3B82F6));
    });

    testWidgets('active cell surface uses a neutral hover color', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          TableWidget(
            blockId: 'table1',
            headers: const ['A'],
            rows: const [
              ['1'],
            ],
            alignments: const [],
            onEvent: (_) {},
          ),
        ),
      );

      const cellKey = ValueKey('block-editor-table-cell-table1-row-0-0');
      var surface = tester.widget<DecoratedBox>(find.byKey(cellKey));
      expect((surface.decoration as BoxDecoration).color, Colors.transparent);

      await hoverTableCell(tester, '1');
      surface = tester.widget<DecoratedBox>(find.byKey(cellKey));
      final hoveredColor = (surface.decoration as BoxDecoration).color;
      expect(hoveredColor, isNot(Colors.transparent));
      expect(hoveredColor, isNot(const Color(0x663B82F6)));
    });

    testWidgets('cell surface does not use scoped text selection color', (
      tester,
    ) async {
      const scopedSelection = Color(0xAA1122EE);
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            selectionColor: scopedSelection,
            child: TableWidget(
              blockId: 'table1',
              headers: const ['A'],
              rows: const [
                ['1'],
              ],
              alignments: const [],
              onEvent: (_) {},
            ),
          ),
        ),
      );

      await hoverTableCell(tester, '1');
      const cellKey = ValueKey('block-editor-table-cell-table1-row-0-0');
      var surface = tester.widget<DecoratedBox>(find.byKey(cellKey));
      expect(
        (surface.decoration as BoxDecoration).color,
        isNot(scopedSelection),
      );

      await activateTableCell(tester, '1');
      final fieldContext = tester.element(find.widgetWithText(TextField, '1'));
      final selectionTheme = TextSelectionTheme.of(fieldContext);
      expect(selectionTheme.selectionColor, scopedSelection);

      surface = tester.widget<DecoratedBox>(find.byKey(cellKey));
      expect(
        (surface.decoration as BoxDecoration).color,
        isNot(scopedSelection),
      );
    });

    testWidgets('focused cell source keeps inline markdown styling', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          TableWidget(
            blockId: 'table1',
            headers: const ['Name'],
            rows: const [
              ['**Bold** and ==marked=='],
            ],
            alignments: const [],
            onEvent: (_) {},
          ),
        ),
      );

      await activateTableCell(tester, '**Bold** and ==marked==');

      final fieldFinder = find.widgetWithText(
        TextField,
        '**Bold** and ==marked==',
      );
      final field = tester.widget<TextField>(fieldFinder);
      final span = field.controller!.buildTextSpan(
        context: tester.element(fieldFinder),
        style: const TextStyle(color: Colors.white),
        withComposing: false,
      );
      final styledChildren = flattenTextSpan(span).toList();

      expect(
        styledChildren.any(
          (child) =>
              child.text == 'Bold' &&
              child.style?.fontWeight == FontWeight.bold,
        ),
        isTrue,
      );
      expect(
        styledChildren.any(
          (child) =>
              child.text == 'marked' && child.style?.backgroundColor != null,
        ),
        isTrue,
      );
      expect(
        styledChildren
            .where((child) => child.text == '**')
            .every((child) => child.style?.color == Colors.transparent),
        isTrue,
      );
      expect(
        styledChildren
            .where((child) => child.text == '==')
            .every((child) => child.style?.color == Colors.transparent),
        isTrue,
      );
      expect(span.toPlainText(), '**Bold** and ==marked==');
    });

    testWidgets(
      'focused table cells keep link and wiki syntax visually hidden',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            TableWidget(
              blockId: 'table1',
              headers: const ['Name'],
              rows: const [
                ['[Docs](https://example.com) and [[Target page|alias]]'],
              ],
              alignments: const [],
              onEvent: (_) {},
            ),
          ),
        );

        await activateTableCell(
          tester,
          '[Docs](https://example.com) and [[Target page|alias]]',
        );

        final fieldFinder = find.widgetWithText(
          TextField,
          '[Docs](https://example.com) and [[Target page|alias]]',
        );
        final field = tester.widget<TextField>(fieldFinder);
        final span = field.controller!.buildTextSpan(
          context: tester.element(fieldFinder),
          style: const TextStyle(color: Colors.white),
          withComposing: false,
        );
        final styledChildren = flattenTextSpan(span).toList();

        expect(
          span.toPlainText(),
          '[Docs](https://example.com) and [[Target page|alias]]',
        );
        expect(
          styledChildren.any(
            (child) =>
                child.text == 'Docs' &&
                child.style?.color != Colors.transparent,
          ),
          isTrue,
        );
        expect(
          styledChildren.any(
            (child) =>
                child.text == 'alias' &&
                child.style?.color != Colors.transparent,
          ),
          isTrue,
        );
        expect(
          styledChildren
              .where(
                (child) =>
                    child.text == '[' ||
                    child.text == '](https://example.com)' ||
                    child.text == '[[' ||
                    child.text == 'Target page|',
              )
              .every((child) => child.style?.color == Colors.transparent),
          isTrue,
        );
      },
    );

    testWidgets('cell editors opt out of ambient filled input themes', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(
              filled: true,
              fillColor: Colors.red,
            ),
          ),
          home: Scaffold(
            body: TableWidget(
              blockId: 'table1',
              headers: const ['A'],
              rows: const [
                ['1'],
              ],
              alignments: const [],
              onEvent: (_) {},
            ),
          ),
        ),
      );

      await activateTableCell(tester, '1');
      final textField = tester.widget<TextField>(
        find.widgetWithText(TextField, '1'),
      );
      expect(textField.decoration?.filled, isFalse);
      expect(textField.decoration?.fillColor, Colors.transparent);
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

    testWidgets('trackpad scroll over resize handles does not resize cells', (
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

      await hoverTableCell(tester, '1');
      final tableFinder = find.byType(Table);
      final initialTableSize = tester.getSize(tableFinder);

      final columnHandle = _tableResizeHandleFinder(
        SystemMouseCursors.resizeColumn,
      ).first;
      final columnGesture = await tester.startGesture(
        tester.getCenter(columnHandle),
        kind: PointerDeviceKind.trackpad,
      );
      await columnGesture.panZoomUpdate(
        tester.getCenter(columnHandle),
        pan: const Offset(120, 0),
      );
      await tester.pump();
      await columnGesture.up();
      await tester.pump();

      expect(tester.getSize(tableFinder).width, initialTableSize.width);

      final rowHandle = _tableResizeHandleFinder(
        SystemMouseCursors.resizeRow,
      ).first;
      final rowGesture = await tester.startGesture(
        tester.getCenter(rowHandle),
        kind: PointerDeviceKind.trackpad,
      );
      await rowGesture.panZoomUpdate(
        tester.getCenter(rowHandle),
        pan: const Offset(0, 120),
      );
      await tester.pump();
      await rowGesture.up();
      await tester.pump();

      expect(tester.getSize(tableFinder).height, initialTableSize.height);
    });

    testWidgets('primary mouse drag over resize handles resizes cells', (
      tester,
    ) async {
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

      await hoverTableCell(tester, '1');
      final tableFinder = find.byType(Table);
      final initialTableSize = tester.getSize(tableFinder);

      final columnHandle = _tableResizeHandleFinder(
        SystemMouseCursors.resizeColumn,
      ).first;
      final columnGesture = await tester.startGesture(
        tester.getCenter(columnHandle),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await columnGesture.moveBy(const Offset(48, 0));
      await tester.pump();
      await columnGesture.up();
      await tester.pump();

      expect(
        tester.getSize(tableFinder).width,
        greaterThan(initialTableSize.width),
      );
      expect(events.last, isA<TableColumnResizedEvent>());
      expect((events.last as TableColumnResizedEvent).columnIndex, 0);
      expect((events.last as TableColumnResizedEvent).width, greaterThan(96));

      final rowHandle = _tableResizeHandleFinder(
        SystemMouseCursors.resizeRow,
      ).first;
      final heightBeforeRowResize = tester.getSize(tableFinder).height;
      final rowGesture = await tester.startGesture(
        tester.getCenter(rowHandle),
        kind: PointerDeviceKind.mouse,
        buttons: kPrimaryMouseButton,
      );
      await rowGesture.moveBy(const Offset(0, 48));
      await tester.pump();
      await rowGesture.up();
      await tester.pump();

      expect(
        tester.getSize(tableFinder).height,
        greaterThan(heightBeforeRowResize),
      );
      expect(events.last, isA<TableRowResizedEvent>());
      expect((events.last as TableRowResizedEvent).rowIndex, 0);
      expect((events.last as TableRowResizedEvent).height, greaterThan(32));
    });

    testWidgets('applies persisted table dimensions from attributes', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 700,
            child: TableWidget(
              blockId: 'table1',
              headers: const ['A', 'B'],
              rows: const [
                ['1', '2'],
              ],
              alignments: const [],
              attributes: const {
                'tableColumnWidths': {'0': 260.0},
                'tableRowHeights': {'0': 88.0},
              },
              onEvent: (_) {},
            ),
          ),
        ),
      );

      final tableSize = tester.getSize(find.byType(Table));
      expect(tableSize.width, greaterThan(350));
      expect(
        tester.getSize(_tableCellSurfaceFinder('table1').at(2)).height,
        greaterThan(85),
      );
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
      await activateTableCell(tester, '1');
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

    testWidgets('cell editors handle Markdown formatting shortcuts', (
      tester,
    ) async {
      final events = <BlockEvent>[];
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 500,
            child: TableWidget(
              blockId: 'table1',
              headers: const ['A'],
              rows: const [
                ['Draft'],
              ],
              alignments: const [],
              onEvent: events.add,
            ),
          ),
        ),
      );

      await activateTableCell(tester, 'Draft');
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Draft'),
      );
      final controller = field.controller!;
      controller.selection = const TextSelection(
        baseOffset: 0,
        extentOffset: 5,
      );

      await sendMetaShortcut(tester, LogicalKeyboardKey.keyB);

      expect(controller.text, '**Draft**');
      expect(controller.selection.baseOffset, 2);
      expect(controller.selection.extentOffset, 7);
      expect(events.last, isA<TableCellChangedEvent>());
      expect((events.last as TableCellChangedEvent).text, '**Draft**');

      controller.selection = const TextSelection(
        baseOffset: 2,
        extentOffset: 7,
      );
      await sendMetaShortcut(tester, LogicalKeyboardKey.keyI);

      expect(controller.text, '***Draft***');
      expect(controller.selection.baseOffset, 3);
      expect(controller.selection.extentOffset, 8);
      expect((events.last as TableCellChangedEvent).text, '***Draft***');

      controller.selection = const TextSelection(
        baseOffset: 3,
        extentOffset: 8,
      );
      await sendMetaShortcut(tester, LogicalKeyboardKey.keyB);

      expect(controller.text, '*Draft*');
      expect(controller.selection.baseOffset, 1);
      expect(controller.selection.extentOffset, 6);
      expect((events.last as TableCellChangedEvent).text, '*Draft*');

      controller.selection = const TextSelection(
        baseOffset: 1,
        extentOffset: 6,
      );
      await sendMetaShortcut(tester, LogicalKeyboardKey.keyI);

      expect(controller.text, 'Draft');
      expect(controller.selection.baseOffset, 0);
      expect(controller.selection.extentOffset, 5);
      expect((events.last as TableCellChangedEvent).text, 'Draft');
    });

    testWidgets('Tab and Shift+Tab move focus across table cells', (
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

      await activateTableCell(tester, '1');
      await sendPlainKey(tester, LogicalKeyboardKey.tab);

      var field = focusedTextField(tester);
      expect(field.controller?.text, '2');
      expect(field.controller?.selection.extentOffset, 0);

      await sendShiftTab(tester);

      field = focusedTextField(tester);
      expect(field.controller?.text, '1');
      expect(field.controller?.selection.extentOffset, 1);
    });

    testWidgets('Tab from the last cell requests a new row', (tester) async {
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
              ],
              alignments: const [],
              onEvent: events.add,
            ),
          ),
        ),
      );

      await activateTableCell(tester, '2');
      await sendPlainKey(tester, LogicalKeyboardKey.tab);

      expect(events.last, isA<TableRowInsertedEvent>());
      expect((events.last as TableRowInsertedEvent).index, 1);
      final field = focusedTextField(tester);
      expect(field.controller?.text, '');
      expect(field.controller?.selection.extentOffset, 0);
    });

    testWidgets('arrow keys move across cell boundaries', (tester) async {
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

      await activateTableCell(tester, '1');
      var field = focusedTextField(tester);
      field.controller?.selection = const TextSelection.collapsed(offset: 1);
      await sendPlainKey(tester, LogicalKeyboardKey.arrowRight);

      field = focusedTextField(tester);
      expect(field.controller?.text, '2');
      expect(field.controller?.selection.extentOffset, 0);

      await sendPlainKey(tester, LogicalKeyboardKey.arrowLeft);

      field = focusedTextField(tester);
      expect(field.controller?.text, '1');
      expect(field.controller?.selection.extentOffset, 1);
    });

    testWidgets('Enter inserts a Markdown table cell line break', (
      tester,
    ) async {
      final events = <BlockEvent>[];
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 500,
            child: TableWidget(
              blockId: 'table1',
              headers: const ['A'],
              rows: const [
                ['1'],
              ],
              alignments: const [],
              onEvent: events.add,
            ),
          ),
        ),
      );

      await activateTableCell(tester, '1');
      final field = focusedTextField(tester);
      field.controller?.selection = const TextSelection.collapsed(offset: 1);
      await sendPlainKey(tester, LogicalKeyboardKey.enter);

      expect(field.controller?.text, '1\n');
      expect(events.last, isA<TableCellChangedEvent>());
      expect((events.last as TableCellChangedEvent).text, '1\n');
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
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(8));
      await addRowGesture.up();
      events.clear();

      final deleteRowGesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Delete row 3')),
      );
      expect(events.single, isA<TableRowDeletedEvent>());
      expect((events.single as TableRowDeletedEvent).index, 2);
      await tester.pump();
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(6));
      await deleteRowGesture.up();
      events.clear();

      await activateTableCell(tester, '2');
      final deleteColumnGesture = await tester.startGesture(
        tester.getCenter(find.byTooltip('Delete column 2')),
      );
      expect(events.single, isA<TableColumnDeletedEvent>());
      expect((events.single as TableColumnDeletedEvent).index, 1);
      await tester.pump();
      expect(_tableCellSurfaceFinder('table1'), findsNWidgets(3));
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

  group('Block alignment rendering', () {
    testWidgets('heading widgets honor centered textAlign attributes', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          H2Widget(
            blockId: 'h2',
            delta: TextDelta.fromPlainText('Centered heading'),
            attributes: const {'textAlign': 'center'},
            onEvent: (_) {},
          ),
        ),
      );

      final renderer = tester.widget<RichTextRenderer>(
        find.byType(RichTextRenderer),
      );
      expect(renderer.textAlign, TextAlign.center);
    });

    testWidgets('table widgets honor centered block textAlign attributes', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 640,
            child: TableWidget(
              blockId: 'table1',
              headers: const ['A', 'B'],
              rows: const [
                ['1', '2'],
              ],
              alignments: const [],
              attributes: const {'textAlign': 'center'},
              onEvent: (_) {},
            ),
          ),
        ),
      );

      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Align &&
              widget.alignment == AlignmentDirectional.topCenter,
        ),
        findsOneWidget,
      );
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

    test('table resize events carry committed dimensions', () {
      const column = TableColumnResizedEvent(
        blockId: 'table1',
        columnIndex: 2,
        width: 240,
      );
      expect(column.blockId, 'table1');
      expect(column.columnIndex, 2);
      expect(column.width, 240);

      const row = TableRowResizedEvent(
        blockId: 'table1',
        rowIndex: 1,
        height: 72,
      );
      expect(row.blockId, 'table1');
      expect(row.rowIndex, 1);
      expect(row.height, 72);
    });

    test('RawMarkdownChangedEvent carries blockId and text', () {
      const e = RawMarkdownChangedEvent(
        blockId: 'raw1',
        text: '<div>raw</div>',
      );
      expect(e.blockId, 'raw1');
      expect(e.text, '<div>raw</div>');
    });

    test('CalloutTitleChangedEvent carries blockId and title', () {
      const e = CalloutTitleChangedEvent(blockId: 'callout1', title: 'Note');
      expect(e.blockId, 'callout1');
      expect(e.title, 'Note');
    });

    test('CalloutVariantChangedEvent carries blockId and variant', () {
      const e = CalloutVariantChangedEvent(
        blockId: 'callout1',
        variant: 'warning',
      );
      expect(e.blockId, 'callout1');
      expect(e.variant, 'warning');
    });
  });
}
