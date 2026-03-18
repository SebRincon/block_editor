import 'package:block_editor/block_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(),
    child: Directionality(textDirection: TextDirection.ltr, child: child),
  );
}

Finder findCursorPaint() {
  return find.byWidgetPredicate(
    (widget) =>
        widget is CustomPaint && widget.foregroundPainter is CursorPainter,
  );
}

void main() {
  group('BlockCursor — visibility', () {
    testWidgets('no cursor painter when selection is NoSelection', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BlockCursor(
            blockId: 'b1',
            delta: TextDelta.fromPlainText('hello'),
            selection: EditorSelection.none,
          ),
        ),
      );
      expect(findCursorPaint(), findsNothing);
    });

    testWidgets('no cursor painter when selection is ExpandedSelection', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BlockCursor(
            blockId: 'b1',
            delta: TextDelta.fromPlainText('hello'),
            selection: const ExpandedSelection(
              anchor: SelectionPoint(blockId: 'b1', offset: 0),
              focus: SelectionPoint(blockId: 'b1', offset: 5),
            ),
          ),
        ),
      );
      expect(findCursorPaint(), findsNothing);
    });

    testWidgets(
      'no cursor painter when CollapsedSelection is for different block',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            BlockCursor(
              blockId: 'b1',
              delta: TextDelta.fromPlainText('hello'),
              selection: const CollapsedSelection(
                SelectionPoint(blockId: 'b2', offset: 0),
              ),
            ),
          ),
        );
        expect(findCursorPaint(), findsNothing);
      },
    );

    testWidgets(
      'cursor painter present when CollapsedSelection matches blockId',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            BlockCursor(
              blockId: 'b1',
              delta: TextDelta.fromPlainText('hello'),
              selection: const CollapsedSelection(
                SelectionPoint(blockId: 'b1', offset: 2),
              ),
            ),
          ),
        );
        expect(findCursorPaint(), findsOneWidget);
      },
    );

    testWidgets('no cursor painter when offset is -1', (tester) async {
      await tester.pumpWidget(
        wrap(
          BlockCursor(
            blockId: 'b1',
            delta: TextDelta.fromPlainText('hello'),
            selection: const CollapsedSelection(
              SelectionPoint(blockId: 'b1', offset: -1),
            ),
          ),
        ),
      );
      expect(findCursorPaint(), findsNothing);
    });
  });

  group('BlockCursor — external animation', () {
    testWidgets('accepts external animation without error', (tester) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 600),
      );
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        wrap(
          BlockCursor(
            blockId: 'b1',
            delta: TextDelta.fromPlainText('hello'),
            selection: const CollapsedSelection(
              SelectionPoint(blockId: 'b1', offset: 2),
            ),
            animation: controller,
          ),
        ),
      );
      expect(findCursorPaint(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('cursor painter has full opacity when animation value is 1.0', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 600),
      );
      addTearDown(controller.dispose);
      controller.value = 1.0;

      await tester.pumpWidget(
        wrap(
          BlockCursor(
            blockId: 'b1',
            delta: TextDelta.fromPlainText('hello'),
            selection: const CollapsedSelection(
              SelectionPoint(blockId: 'b1', offset: 2),
            ),
            animation: controller,
            cursorColor: const Color(0xFF000000),
          ),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(findCursorPaint());
      final painter = customPaint.foregroundPainter! as CursorPainter;
      expect(painter.cursorColor.a, 1.0);
    });

    testWidgets('cursor painter has zero opacity when animation value is 0.0', (
      tester,
    ) async {
      final controller = AnimationController(
        vsync: tester,
        duration: const Duration(milliseconds: 600),
      );
      addTearDown(controller.dispose);
      controller.value = 0.0;

      await tester.pumpWidget(
        wrap(
          BlockCursor(
            blockId: 'b1',
            delta: TextDelta.fromPlainText('hello'),
            selection: const CollapsedSelection(
              SelectionPoint(blockId: 'b1', offset: 2),
            ),
            animation: controller,
            cursorColor: const Color(0xFF000000),
          ),
        ),
      );

      final customPaint = tester.widget<CustomPaint>(findCursorPaint());
      final painter = customPaint.foregroundPainter! as CursorPainter;
      expect(painter.cursorColor.a, 0.0);
    });
  });

  group('BlockCursor — default animation', () {
    testWidgets('renders without error with default animation', (tester) async {
      await tester.pumpWidget(
        wrap(
          BlockCursor(
            blockId: 'b1',
            delta: TextDelta.fromPlainText('hello'),
            selection: const CollapsedSelection(
              SelectionPoint(blockId: 'b1', offset: 2),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('custom blinkDuration is accepted without error', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          BlockCursor(
            blockId: 'b1',
            delta: TextDelta.fromPlainText('hello'),
            selection: const CollapsedSelection(
              SelectionPoint(blockId: 'b1', offset: 2),
            ),
            blinkDuration: const Duration(milliseconds: 800),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('BlockCursor — empty delta', () {
    testWidgets('renders without error on empty delta', (tester) async {
      await tester.pumpWidget(
        wrap(
          BlockCursor(
            blockId: 'b1',
            delta: TextDelta.fromPlainText(''),
            selection: const CollapsedSelection(
              SelectionPoint(blockId: 'b1', offset: 0),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });
}
