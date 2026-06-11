import 'package:block_editor/block_editor.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

Future<void> hoverBlockContent(WidgetTester tester) async {
  await tester.sendEventToBinding(
    PointerHoverEvent(
      position: tester.getCenter(find.text('block content')),
      kind: PointerDeviceKind.mouse,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 120));
}

void main() {
  group('BlockDragHandle', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        wrap(
          BlockDragHandle(
            index: 0,
            blockId: 'b1',
            onEvent: (_) {},
            feedbackWidget: const SizedBox(),
            child: const Text('block content'),
          ),
        ),
      );
      expect(find.text('block content'), findsOneWidget);
    });

    testWidgets('renders without drag handle in readOnly mode', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: wrap(
            BlockDragHandle(
              index: 0,
              blockId: 'b1',
              onEvent: (_) {},
              feedbackWidget: const SizedBox(),
              readOnly: true,
              child: const Text('block content'),
            ),
          ),
        ),
      );
      expect(find.byType(Draggable<int>), findsNothing);
      expect(find.text('block content'), findsOneWidget);
    });

    testWidgets('renders without drag handle when width is below 600', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(375, 812)),
          child: wrap(
            BlockDragHandle(
              index: 0,
              blockId: 'b1',
              onEvent: (_) {},
              feedbackWidget: const SizedBox(),
              child: const Text('block content'),
            ),
          ),
        ),
      );
      expect(find.byType(Draggable<int>), findsNothing);
      expect(find.text('block content'), findsOneWidget);
    });

    testWidgets('renders Draggable when width is above 600 and not readOnly', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: wrap(
            BlockDragHandle(
              index: 0,
              blockId: 'b1',
              onEvent: (_) {},
              feedbackWidget: const SizedBox(),
              child: const Text('block content'),
            ),
          ),
        ),
      );
      expect(find.byType(Draggable<int>), findsOneWidget);
    });

    testWidgets('renders Draggable when not readOnly', (tester) async {
      await tester.pumpWidget(
        wrap(
          BlockDragHandle(
            index: 0,
            blockId: 'b1',
            onEvent: (_) {},
            feedbackWidget: const SizedBox(),
            child: const Text('block content'),
          ),
        ),
      );
      expect(find.byType(Draggable<int>), findsOneWidget);
    });

    testWidgets('plus control is hidden by default', (tester) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: wrap(
            BlockDragHandle(
              index: 0,
              blockId: 'b1',
              onEvent: (_) {},
              feedbackWidget: const SizedBox(),
              onAddBlockRequested: () {},
              child: const SizedBox(
                width: 400,
                height: 40,
                child: Text('block content'),
              ),
            ),
          ),
        ),
      );

      await hoverBlockContent(tester);
      expect(find.byTooltip('Add block below'), findsNothing);
    });

    testWidgets('plus control requests a block below when enabled', (
      tester,
    ) async {
      var requested = false;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: wrap(
            BlockDragHandle(
              index: 0,
              blockId: 'b1',
              onEvent: (_) {},
              feedbackWidget: const SizedBox(),
              onAddBlockRequested: () => requested = true,
              showAddBlockButton: true,
              child: const SizedBox(
                width: 400,
                height: 40,
                child: Text('block content'),
              ),
            ),
          ),
        ),
      );

      await hoverBlockContent(tester);
      expect(find.byTooltip('Add block below'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      expect(requested, isTrue);
    });

    testWidgets('grip control requests the action menu', (tester) async {
      String? requestedBlockId;
      Offset? requestedPosition;
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(800, 600)),
          child: wrap(
            BlockDragHandle(
              index: 0,
              blockId: 'b1',
              onEvent: (_) {},
              feedbackWidget: const SizedBox(),
              onActionMenuRequested: (blockId, position) {
                requestedBlockId = blockId;
                requestedPosition = position;
              },
              child: const SizedBox(
                width: 400,
                height: 40,
                child: Text('block content'),
              ),
            ),
          ),
        ),
      );

      await hoverBlockContent(tester);
      expect(find.byTooltip('Drag or open block menu'), findsNothing);
      await tester.tap(find.byIcon(Icons.drag_indicator));
      expect(requestedBlockId, 'b1');
      expect(requestedPosition, isNotNull);
    });
  });

  group('BlockDropTarget', () {
    testWidgets('renders child widget', (tester) async {
      await tester.pumpWidget(
        wrap(
          BlockDropTarget(
            index: 0,
            blockId: 'b1',
            onEvent: (_) {},
            totalBlocks: 3,
            blockIdResolver: (_) => 'b1',
            child: const Text('block content'),
          ),
        ),
      );
      expect(find.text('block content'), findsOneWidget);
    });

    testWidgets('emits BlockReorderedEvent on drop', (tester) async {
      BlockEvent? received;
      await tester.pumpWidget(
        wrap(
          SizedBox(
            height: 400,
            child: Column(
              children: [
                const Draggable<int>(
                  data: 0,
                  feedback: SizedBox(width: 100, height: 40),
                  child: SizedBox(
                    width: 400,
                    height: 40,
                    child: Text('drag me'),
                  ),
                ),
                BlockDropTarget(
                  index: 1,
                  blockId: 'b2',
                  onEvent: (e) => received = e,
                  totalBlocks: 3,
                  blockIdResolver: (i) => i == 0 ? 'b1' : null,
                  child: const SizedBox(
                    width: 400,
                    height: 40,
                    child: Text('drop here'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('drag me')),
      );
      await tester.pump();
      await gesture.moveTo(tester.getCenter(find.text('drop here')));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(received, isA<BlockReorderedEvent>());
      expect((received as BlockReorderedEvent).blockId, 'b1');
    });
  });

  group('BlockGhost', () {
    testWidgets('renders without error', (tester) async {
      final node = BlockNode(
        id: 'b1',
        type: BlockTypes.paragraph,
        delta: TextDelta.fromPlainText('ghost content'),
      );
      await tester.pumpWidget(wrap(BlockGhost(node: node, width: 700)));
      expect(tester.takeException(), isNull);
    });

    testWidgets('shrink-wraps content-sized blocks', (tester) async {
      final node = BlockNode(
        id: 'b1',
        type: BlockTypes.heading2,
        delta: TextDelta.fromPlainText('Short title'),
      );
      await tester.pumpWidget(
        wrap(Center(child: BlockGhost(node: node, width: 700))),
      );

      final size = tester.getSize(
        find.byKey(const ValueKey('block-editor-block-ghost-shell')),
      );
      expect(size.width, lessThan(700));
      expect(size.width, greaterThanOrEqualTo(120));
    });
  });

  group('BlockReorderedEvent', () {
    test('carries blockId and newIndex', () {
      const e = BlockReorderedEvent(blockId: 'b1', newIndex: 2);
      expect(e.blockId, 'b1');
      expect(e.newIndex, 2);
    });
  });
}
