import 'dart:io';

import 'package:block_editor/block_editor.dart';
import 'package:block_editor_example/storage/vten_reader_preferences_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('stores reader preferences under .vten', () async {
    final root = await Directory.systemTemp.createTemp(
      'block_editor_vten_reader_preferences_',
    );
    addTearDown(() async {
      if (await root.exists()) {
        await root.delete(recursive: true);
      }
    });

    final store = VtenReaderPreferencesStore(rootDirectory: root);
    await store.save(
      const VtenReaderPreferences(
        density: MarkdownDocumentDensity.compact,
        contentAlignment: MarkdownDocumentContentAlignment.leading,
      ),
    );

    final file = File(
      '${root.path}/.vten/block_editor/reader_preferences.json',
    );
    expect(await file.exists(), isTrue);

    final loaded = await store.load();
    expect(loaded?.density, MarkdownDocumentDensity.compact);
    expect(loaded?.contentAlignment, MarkdownDocumentContentAlignment.leading);
  });
}
