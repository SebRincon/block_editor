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

    test('decodes and encodes all Markdown heading levels', () {
      const markdown = '''
# H1

## H2

### H3

#### H4

##### H5

###### H6
''';

      final document = BlockMarkdownCodec.decode(markdown);

      expect(document.blocks.map((block) => block.type), [
        BlockTypes.heading1,
        BlockTypes.heading2,
        BlockTypes.heading3,
        BlockTypes.heading4,
        BlockTypes.heading5,
        BlockTypes.heading6,
      ]);
      expect(BlockMarkdownCodec.encode(document), markdown.trimRight());
    });

    test('preserves YAML frontmatter at the start of the document', () {
      const markdown = '''
---
title: Roadmap
tags:
  - docs
---

# Plan
''';

      final document = BlockMarkdownCodec.decode(markdown);
      final frontmatter = document.blocks.first;

      expect(frontmatter.type, BlockTypes.code);
      expect(frontmatter.attributes['frontmatter'], isTrue);
      expect(frontmatter.attributes['language'], 'yaml');
      expect(frontmatter.delta?.plainText, 'title: Roadmap\ntags:\n  - docs');
      expect(document.blocks.last.type, BlockTypes.heading1);
      expect(BlockMarkdownCodec.encode(document), markdown.trimRight());
    });

    test('preserves raw Markdown HTML blocks', () {
      const markdown = '''
<div class="note">
# Not a heading
</div>
''';

      final document = BlockMarkdownCodec.decode(markdown);
      final block = document.blocks.single;

      expect(block.type, BlockTypes.rawMarkdown);
      expect(block.delta?.plainText, markdown.trimRight());
      expect(BlockMarkdownCodec.encode(document), markdown.trimRight());
    });

    test('decodes and encodes display math blocks', () {
      const markdown = r'''
$$
E = mc^2
$$
''';

      final document = BlockMarkdownCodec.decode(markdown);
      final block = document.blocks.single;

      expect(block.type, BlockTypes.math);
      expect(block.delta?.plainText, 'E = mc^2');
      expect(BlockMarkdownCodec.encode(document), markdown.trimRight());
    });

    test('decodes and encodes Mermaid fenced diagrams', () {
      const markdown = '''
```mermaid
graph TD
  A[Start] --> B[Ship]
```
''';

      final document = BlockMarkdownCodec.decode(markdown);
      final block = document.blocks.single;

      expect(block.type, BlockTypes.mermaid);
      expect(block.delta?.plainText, 'graph TD\n  A[Start] --> B[Ship]');
      expect(BlockMarkdownCodec.encode(document), markdown.trimRight());
    });

    test('preserves raw Markdown footnote and reference definitions', () {
      const markdown = '''
[^details]: First line
  continuation with **markdown**

[label]: https://example.test "Example"
''';

      final document = BlockMarkdownCodec.decode(markdown);

      expect(document.blocks.map((block) => block.type), [
        BlockTypes.rawMarkdown,
        BlockTypes.rawMarkdown,
      ]);
      expect(BlockMarkdownCodec.encode(document), markdown.trimRight());
    });

    test('preserves raw Markdown Obsidian comments and block ids', () {
      const markdown = '''
%%
private note
%%

^section-anchor
''';

      final document = BlockMarkdownCodec.decode(markdown);

      expect(document.blocks.map((block) => block.type), [
        BlockTypes.rawMarkdown,
        BlockTypes.rawMarkdown,
      ]);
      expect(BlockMarkdownCodec.encode(document), markdown.trimRight());
    });

    test('decodes and encodes Obsidian-style inline syntax', () {
      const markdown =
          'Use ==highlight==, [[Daily Note]], [[API|public API]], ![[diagram.png]], [^ref], and #project/docs.';

      final document = BlockMarkdownCodec.decode(markdown);
      final paragraph = document.blocks.single;
      final ops = paragraph.delta!.ops;

      expect(paragraph.type, BlockTypes.paragraph);
      expect(
        ops.whereType<TextOp>().any((op) => op.attributes.highlight == true),
        isTrue,
      );
      expect(
        ops.whereType<TextOp>().any(
          (op) =>
              op.text == 'Daily Note' &&
              op.attributes.wikiLink == 'Daily Note' &&
              op.attributes.embed == null,
        ),
        isTrue,
      );
      expect(
        ops.whereType<TextOp>().any(
          (op) =>
              op.text == 'public API' &&
              op.attributes.wikiLink == 'API' &&
              op.attributes.embed == null,
        ),
        isTrue,
      );
      expect(
        ops.whereType<TextOp>().any(
          (op) =>
              op.text == 'diagram.png' &&
              op.attributes.wikiLink == 'diagram.png' &&
              op.attributes.embed == true,
        ),
        isTrue,
      );
      expect(
        ops.whereType<TextOp>().any(
          (op) => op.text == '[^ref]' && op.attributes.footnote == 'ref',
        ),
        isTrue,
      );
      expect(
        ops.whereType<TagOp>().map((op) => op.tag),
        contains('project/docs'),
      );
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

    test('preserves escaped table pipes inside cells', () {
      const markdown = '''
| Name | Value |
| --- | --- |
| A\\|B | C |
''';

      final document = BlockMarkdownCodec.decode(markdown);
      final table = document.blocks.single;

      expect(table.attributes['rows'], [
        ['A|B', 'C'],
      ]);
      expect(BlockMarkdownCodec.encode(document), '''
| Name | Value |
| --- | --- |
| A\\|B | C |''');
    });

    test('preserves table pipes inside wiki links and inline code spans', () {
      const markdown = '''
| Syntax | Value |
| --- | --- |
| Wiki | [[Target page|alias]] |
| Code | `A | B` |
| Link label | [A | B](https://example.com) |
''';

      final document = BlockMarkdownCodec.decode(markdown);
      final table = document.blocks.single;

      expect(table.attributes['rows'], [
        ['Wiki', '[[Target page|alias]]'],
        ['Code', '`A | B`'],
        ['Link label', '[A | B](https://example.com)'],
      ]);
    });

    test('preserves nested list indentation for bullets and tasks', () {
      const markdown = '''
- root
  - child
  - [ ] child task
    1. ordered child
''';

      final document = BlockMarkdownCodec.decode(markdown);
      final blocks = document.blocks;

      expect(blocks.map((block) => block.type), [
        BlockTypes.bulletList,
        BlockTypes.bulletList,
        BlockTypes.todo,
        BlockTypes.numberedList,
      ]);
      expect(blocks[0].attributes['indent'], isNull);
      expect(blocks[1].attributes['indent'], 1);
      expect(blocks[2].attributes['indent'], 1);
      expect(blocks[3].attributes['indent'], 2);
      expect(BlockMarkdownCodec.encode(document), markdown.trimRight());
    });

    test('decodes and encodes Obsidian-style callouts', () {
      const markdown = '''
> [!warning]- Careful
> This is important.
> Check the details.
''';

      final document = BlockMarkdownCodec.decode(markdown);
      final callout = document.blocks.single;

      expect(callout.type, BlockTypes.callout);
      expect(callout.attributes['variant'], 'warning');
      expect(callout.attributes['title'], 'Careful');
      expect(callout.attributes['expanded'], isFalse);
      expect(
        callout.delta?.plainText,
        'This is important.\nCheck the details.',
      );
      expect(BlockMarkdownCodec.encode(document), markdown.trimRight());
    });
  });
}
