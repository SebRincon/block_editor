import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:block_editor/block_editor.dart';

Widget wrap(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: Directionality(textDirection: TextDirection.ltr, child: child),
    ),
  );
}

BlockNode codeNode({String code = 'print("hello")', String language = 'dart'}) {
  return BlockNode(
    type: BlockTypes.code,
    attributes: {'code': code, 'language': language},
  );
}

Iterable<TextSpan> flattenTextSpan(TextSpan span) sync* {
  yield span;
  for (final child in span.children ?? const <InlineSpan>[]) {
    if (child is TextSpan) yield* flattenTextSpan(child);
  }
}

void main() {
  group('CodeBlock — plugin contract', () {
    test('blockType is code', () {
      expect(CodeBlock().blockType, BlockTypes.code);
    });

    test('serialize round-trips via toJson', () {
      final node = codeNode();
      final json = CodeBlock().serialize(node);
      expect(json['type'], BlockTypes.code);
    });

    test('deserialize produces correct type', () {
      final node = codeNode();
      final json = CodeBlock().serialize(node);
      final restored = CodeBlock().deserialize(json);
      expect(restored.type, BlockTypes.code);
    });

    test('slashCommandItem label is Code', () {
      expect(CodeBlock().slashCommandItem().label, 'Code');
    });

    test('slashCommandGroup is Basic', () {
      expect(CodeBlock().slashCommandGroup(), 'Basic');
    });
  });

  group('CodeBlock — rendering', () {
    testWidgets('renders code content', (tester) async {
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(code: 'var x = 1;'),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );
      expect(find.widgetWithText(TextField, 'var x = 1;'), findsOneWidget);
    });

    testWidgets('renders Markdown-backed delta code content', (tester) async {
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  BlockNode(
                    type: BlockTypes.code,
                    attributes: {'language': 'dart'},
                    delta: TextDelta.fromPlainText('void main() {}'),
                  ),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );
      expect(find.widgetWithText(TextField, 'void main() {}'), findsOneWidget);
    });

    testWidgets('renders grammar-highlighted code while editing', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(code: 'final answer = 42;', language: 'dart'),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );

      final highlightedText = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.textSpan?.toPlainText() == 'final answer = 42;',
        ),
      );
      final spans = flattenTextSpan(highlightedText.textSpan! as TextSpan);

      expect(
        spans.any((span) => span.text == 'final' && span.style?.color != null),
        isTrue,
      );
      expect(
        spans.any((span) => span.text == '42' && span.style?.color != null),
        isTrue,
      );
    });

    testWidgets('uses host-provided source highlighter', (tester) async {
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
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(code: 'final answer = 42;', language: 'dart'),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );

      expect(receivedRequest?.language, 'dart');
      expect(receivedRequest?.source, 'final answer = 42;');

      final highlightedText = tester.widget<Text>(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              widget.textSpan?.toPlainText() == 'final answer = 42;',
        ),
      );
      expect((highlightedText.textSpan! as TextSpan).style?.color, Colors.pink);
    });

    testWidgets('emits CodeBlockChangedEvent when edited', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(code: 'var x = 1;'),
                  EditorSelection.none,
                  (event) => received = event,
                );
              },
            ),
          ),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'var x = 1;'),
        'var x = 2;',
      );
      await tester.pump();

      expect(received, isA<CodeBlockChangedEvent>());
      final event = received as CodeBlockChangedEvent;
      expect(event.text, 'var x = 2;');
    });

    testWidgets('reports embedded text input focus changes', (tester) async {
      final focusStates = <bool>[];
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            onEmbeddedInputFocusChanged: focusStates.add,
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(code: 'var x = 1;'),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );

      await tester.tap(find.widgetWithText(TextField, 'var x = 1;'));
      await tester.pump();

      expect(focusStates, contains(true));
    });

    testWidgets('renders language label when showLanguageSelector is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(language: 'python'),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('python'), findsOneWidget);
    });

    testWidgets('hides language label when showLanguageSelector is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            codeConfig: const CodeBlockConfig(showLanguageSelector: false),
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(language: 'dart'),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('dart'), findsNothing);
    });

    testWidgets('renders line numbers when showLineNumbers is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(code: 'line1\nline2\nline3'),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('hides line numbers when showLineNumbers is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            codeConfig: const CodeBlockConfig(showLineNumbers: false),
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(code: 'line1\nline2'),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('1'), findsNothing);
      expect(find.text('2'), findsNothing);
    });

    testWidgets('emits code_language_change_requested on language label tap', (
      tester,
    ) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(language: 'dart'),
                  EditorSelection.none,
                  (e) => received = e,
                );
              },
            ),
          ),
        ),
      );
      await tester.tap(find.text('dart'));
      expect(received, isA<CustomBlockEvent>());
      final event = received as CustomBlockEvent;
      expect(event.eventType, 'code_language_change_requested');
      expect(event.payload, 'dart');
    });

    testWidgets('renders without error on empty code', (tester) async {
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  codeNode(code: ''),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders default language when absent', (tester) async {
      await tester.pumpWidget(
        wrap(
          BlockEditorScope(
            child: Builder(
              builder: (context) {
                return CodeBlock().build(
                  BlockNode(type: BlockTypes.code),
                  EditorSelection.none,
                  (_) {},
                );
              },
            ),
          ),
        ),
      );
      expect(find.text('plaintext'), findsOneWidget);
    });
  });
}
