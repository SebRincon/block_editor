import 'dart:convert';

import 'package:block_editor/block_editor.dart';
import 'package:test/test.dart';

void main() {
  group('MarkdownPresentationState', () {
    test(
      'captures and reapplies block text alignment after Markdown reload',
      () {
        const markdown = '''
# Title

| Area | Status |
| --- | --- |
| Tables | ready |
''';
        final decoded = BlockMarkdownCodec.decode(markdown);
        final styled = BlockDocument([
          decoded.blocks[0].copyWith(
            attributes: {
              ...decoded.blocks[0].attributes,
              'textAlign': 'center',
            },
          ),
          decoded.blocks[1].copyWith(
            attributes: {...decoded.blocks[1].attributes, 'textAlign': 'right'},
          ),
        ]);

        final state = MarkdownPresentationState.capture(styled);
        final reloaded = BlockMarkdownCodec.decode(
          BlockMarkdownCodec.encode(styled),
        );
        final restored = state.applyTo(reloaded);

        expect(restored.blocks[0].attributes['textAlign'], 'center');
        expect(restored.blocks[1].attributes['textAlign'], 'right');
      },
    );

    test('uses occurrence index for repeated matching blocks', () {
      const markdown = '''
## Repeat

## Repeat
''';
      final decoded = BlockMarkdownCodec.decode(markdown);
      final styled = BlockDocument([
        decoded.blocks[0].copyWith(attributes: {'textAlign': 'center'}),
        decoded.blocks[1].copyWith(attributes: {'textAlign': 'right'}),
      ]);

      final state = MarkdownPresentationState.capture(styled);
      final restored = state.applyTo(BlockMarkdownCodec.decode(markdown));

      expect(restored.blocks[0].attributes['textAlign'], 'center');
      expect(restored.blocks[1].attributes['textAlign'], 'right');
    });

    test(
      'uses source spans before occurrence index for reordered duplicates',
      () {
        const markdown = '''
## Repeat

## Repeat
''';
        final decoded = BlockMarkdownCodec.decode(markdown);
        final styled = BlockDocument([
          decoded.blocks[0].copyWith(
            attributes: {
              ...decoded.blocks[0].attributes,
              'textAlign': 'center',
            },
          ),
          decoded.blocks[1].copyWith(
            attributes: {...decoded.blocks[1].attributes, 'textAlign': 'right'},
          ),
        ]);

        final state = MarkdownPresentationState.capture(styled);
        final moved = BlockDocument([decoded.blocks[1], decoded.blocks[0]]);
        final restored = state.applyTo(moved);

        expect(restored.blocks[0].attributes['textAlign'], 'right');
        expect(restored.blocks[1].attributes['textAlign'], 'center');
      },
    );

    test(
      'captures and reapplies table dimensions as string-key attributes',
      () {
        const markdown = '''
| A | B |
| --- | --- |
| 1 | 2 |
''';
        final decoded = BlockMarkdownCodec.decode(markdown);
        final styled = BlockDocument([
          decoded.blocks.single.copyWith(
            attributes: {
              ...decoded.blocks.single.attributes,
              'tableColumnWidths': {'0': 224.0, 1: 180.5},
              'tableRowHeights': {0: 72.0},
            },
          ),
        ]);

        final state = MarkdownPresentationState.capture(styled);
        final restored = state.applyTo(BlockMarkdownCodec.decode(markdown));
        final attrs = restored.blocks.single.attributes;

        expect(attrs['tableColumnWidths'], {'0': 224.0, '1': 180.5});
        expect(attrs['tableRowHeights'], {'0': 72.0});
      },
    );

    test('ignores stale presentation entries after block content changes', () {
      const markdown = '# Old title';
      final decoded = BlockMarkdownCodec.decode(markdown);
      final styled = BlockDocument([
        decoded.blocks.single.copyWith(attributes: {'textAlign': 'center'}),
      ]);

      final state = MarkdownPresentationState.capture(styled);
      final changed = BlockMarkdownCodec.decode('# New title');
      final restored = state.applyTo(changed);

      expect(restored.blocks.single.attributes['textAlign'], isNull);
    });

    test('round trips through JSON', () {
      final document = BlockDocument([
        BlockNode(
          type: BlockTypes.heading2,
          attributes: const {'textAlign': 'center'},
          delta: TextDelta.fromPlainText('Persist me'),
        ),
      ]);

      final state = MarkdownPresentationState.capture(
        document,
        documentId: 'docs/example.md',
      );
      final decoded = MarkdownPresentationState.fromJson(
        (jsonDecode(jsonEncode(state.toJson())) as Map).cast<String, Object?>(),
      );
      final restored = decoded.applyTo(
        BlockDocument([
          BlockNode(
            type: BlockTypes.heading2,
            delta: TextDelta.fromPlainText('Persist me'),
          ),
        ]),
      );

      expect(decoded.documentId, 'docs/example.md');
      expect(restored.blocks.single.attributes['textAlign'], 'center');
    });
  });
}
