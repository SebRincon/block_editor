import 'package:block_editor/block_editor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BlockMarkdownCodec', () {
    test('decodes common markdown blocks', () {
      final document = BlockMarkdownCodec.decode('''
# Title

## Section

- [x] done
- item
1. ordered
> quoted

```dart
void main() {}
```
''');

      final blocks = document.blocks;
      expect(blocks.map((block) => block.type), [
        BlockTypes.heading1,
        BlockTypes.heading2,
        BlockTypes.todo,
        BlockTypes.bulletList,
        BlockTypes.numberedList,
        BlockTypes.quote,
        BlockTypes.code,
      ]);
      expect(blocks[0].delta?.plainText, 'Title');
      expect(blocks[2].attributes['checked'], isTrue);
      expect(blocks[6].attributes['language'], 'dart');
      expect(blocks[6].delta?.plainText, 'void main() {}');
    });

    test('preserves supported inline formatting on round trip', () {
      final markdown =
          'A **bold** and *italic* and `code` and [link](https://x.test)';

      final document = BlockMarkdownCodec.decode(markdown);
      final paragraph = document.blocks.single;

      expect(paragraph.type, BlockTypes.paragraph);
      expect(BlockMarkdownCodec.encode(document), markdown);
    });

    test('encodes block documents as markdown', () {
      final document = BlockDocument([
        BlockNode(
          type: BlockTypes.heading1,
          delta: TextDelta.fromPlainText('Title'),
        ),
        BlockNode(
          type: BlockTypes.todo,
          attributes: {'checked': false},
          delta: TextDelta.fromPlainText('task'),
        ),
      ]);

      expect(BlockMarkdownCodec.encode(document), '# Title\n\n- [ ] task');
    });

    test('decodes and encodes GitHub-style pipe tables', () {
      const markdown = '''
| Model | License |
|-------|---------|
| Small | Apache-2.0 |
| Large | CC-BY-NC-4.0 |
''';

      final document = BlockMarkdownCodec.decode(markdown);
      final table = document.blocks.single;

      expect(table.type, BlockTypes.table);
      expect(table.attributes['headers'], ['Model', 'License']);
      expect(table.attributes['rows'], [
        ['Small', 'Apache-2.0'],
        ['Large', 'CC-BY-NC-4.0'],
      ]);
      expect(
        BlockMarkdownCodec.encode(document),
        '''
| Model | License |
| --- | --- |
| Small | Apache-2.0 |
| Large | CC-BY-NC-4.0 |
'''
            .trimRight(),
      );
    });

    test('preserves table column alignment markers', () {
      const markdown = '''
| Left | Center | Right |
|:-----|:------:|------:|
| A | B | C |
''';

      final document = BlockMarkdownCodec.decode(markdown);
      final table = document.blocks.single;

      expect(table.attributes['alignments'], ['left', 'center', 'right']);
      expect(BlockMarkdownCodec.encode(document), '''
| Left | Center | Right |
| :--- | :---: | ---: |
| A | B | C |''');
    });
  });
}
