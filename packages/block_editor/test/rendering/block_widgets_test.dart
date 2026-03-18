import 'package:block_editor/block_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) {
  return Directionality(textDirection: TextDirection.ltr, child: child);
}

void main() {
  final helloDelta = TextDelta.fromPlainText('hello');

  group('ParagraphBlock', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(ParagraphBlock(blockId: 'b1', delta: helloDelta, onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          ParagraphBlock(
            blockId: 'b1',
            delta: helloDelta,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(ParagraphBlock));
      expect(received, isA<TapEvent>());
      expect((received as TapEvent).blockId, 'b1');
    });
  });

  group('H1Block', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(H1Block(blockId: 'b1', delta: helloDelta, onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          H1Block(
            blockId: 'b1',
            delta: helloDelta,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(H1Block));
      expect(received, isA<TapEvent>());
    });
  });

  group('H2Block', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(H2Block(blockId: 'b1', delta: helloDelta, onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          H2Block(
            blockId: 'b1',
            delta: helloDelta,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(H2Block));
      expect(received, isA<TapEvent>());
    });
  });

  group('H3Block', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(H3Block(blockId: 'b1', delta: helloDelta, onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          H3Block(
            blockId: 'b1',
            delta: helloDelta,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(H3Block));
      expect(received, isA<TapEvent>());
    });
  });

  group('BulletListBlock', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(
          BulletListBlock(
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
          BulletListBlock(
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
          BulletListBlock(
            blockId: 'b1',
            delta: helloDelta,
            attributes: const {'indent': 2},
            onEvent: (_) {},
          ),
        ),
      );
      final padding = tester.widget<Padding>(find.byType(Padding).first);
      expect(padding.padding, const EdgeInsets.only(left: 48.0));
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            width: 400,
            height: 50,
            child: BulletListBlock(
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

  group('NumberedListBlock', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(
          NumberedListBlock(
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
          NumberedListBlock(
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
            child: NumberedListBlock(
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

  group('TodoBlock', () {
    testWidgets('renders unchecked without error', (tester) async {
      await tester.pumpWidget(
        wrap(
          TodoBlock(
            blockId: 'b1',
            delta: helloDelta,
            checked: false,
            onEvent: (_) {},
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders checked without error', (tester) async {
      await tester.pumpWidget(
        wrap(
          TodoBlock(
            blockId: 'b1',
            delta: helloDelta,
            checked: true,
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
          TodoBlock(
            blockId: 'b1',
            delta: helloDelta,
            checked: false,
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
          TodoBlock(
            blockId: 'b1',
            delta: helloDelta,
            checked: true,
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
          TodoBlock(
            blockId: 'b1',
            delta: helloDelta,
            checked: false,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.text('hello', findRichText: true));
      expect(received, isA<TapEvent>());
    });

    testWidgets('checked state renders strikethrough on text', (tester) async {
      await tester.pumpWidget(
        wrap(
          TodoBlock(
            blockId: 'b1',
            delta: helloDelta,
            checked: true,
            onEvent: (_) {},
          ),
        ),
      );
      final text = tester.widget<Text>(find.byType(Text).first);
      expect(text.textSpan!.style!.decoration, TextDecoration.lineThrough);
    });
  });

  group('QuoteBlock', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(QuoteBlock(blockId: 'b1', delta: helloDelta, onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('emits TapEvent on tap', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          QuoteBlock(
            blockId: 'b1',
            delta: helloDelta,
            onEvent: (e) => received = e,
          ),
        ),
      );
      await tester.tap(find.byType(QuoteBlock));
      expect(received, isA<TapEvent>());
    });
  });

  group('DividerBlock', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        wrap(DividerBlock(blockId: 'b1', onEvent: (_) {})),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders a Divider widget', (tester) async {
      await tester.pumpWidget(
        wrap(DividerBlock(blockId: 'b1', onEvent: (_) {})),
      );
      expect(find.byType(Divider), findsOneWidget);
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
  });
}
