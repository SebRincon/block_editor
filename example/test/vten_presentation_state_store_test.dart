import 'dart:io';

import 'package:block_editor/block_editor.dart';
import 'package:block_editor_example/storage/vten_presentation_state_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores presentation state under .vten per document id', () async {
    final root = await Directory.systemTemp.createTemp(
      'block_editor_vten_presentation_state_',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final store = VtenPresentationStateStore(rootDirectory: root);
    final document = BlockDocument([
      BlockNode(
        type: BlockTypes.heading2,
        attributes: const {'textAlign': 'center'},
        delta: TextDelta.fromPlainText('Stored alignment'),
      ),
    ]);
    final state = MarkdownPresentationState.capture(
      document,
      documentId: 'docs/plan.md',
    );

    await store.save('docs/plan.md', state);

    final file = await store.presentationFile('docs/plan.md');
    expect(
      file.path,
      contains(
        '${Platform.pathSeparator}presentation${Platform.pathSeparator}',
      ),
    );
    expect(await file.exists(), isTrue);

    final loaded = await store.load('docs/plan.md');
    final restored = loaded?.applyTo(
      BlockDocument([
        BlockNode(
          type: BlockTypes.heading2,
          delta: TextDelta.fromPlainText('Stored alignment'),
        ),
      ]),
    );

    expect(loaded?.documentId, 'docs/plan.md');
    expect(restored?.blocks.single.attributes['textAlign'], 'center');
  });

  test('deletes stale presentation file when state becomes empty', () async {
    final root = await Directory.systemTemp.createTemp(
      'block_editor_vten_empty_presentation_state_',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final store = VtenPresentationStateStore(rootDirectory: root);
    final document = BlockDocument([
      BlockNode(
        type: BlockTypes.heading2,
        attributes: const {'textAlign': 'center'},
        delta: TextDelta.fromPlainText('Stored alignment'),
      ),
    ]);
    await store.save(
      'docs/plan.md',
      MarkdownPresentationState.capture(document),
    );

    final file = await store.presentationFile('docs/plan.md');
    expect(await file.exists(), isTrue);

    await store.save(
      'docs/plan.md',
      MarkdownPresentationState.capture(
        BlockDocument([
          BlockNode(
            type: BlockTypes.heading2,
            delta: TextDelta.fromPlainText('Stored alignment'),
          ),
        ]),
      ),
    );

    expect(await file.exists(), isFalse);
  });
}
