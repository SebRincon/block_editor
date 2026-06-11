import 'dart:io';

import 'package:block_editor_example/workspace/markdown_workspace_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

class _FakeDirectoryPicker implements MarkdownDirectoryPicker {
  const _FakeDirectoryPicker(this.path);

  final String? path;

  @override
  Future<String?> pickDirectory({String? initialDirectory}) async => path;
}

void main() {
  group('MarkdownWorkspaceController', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('block_editor_workspace_');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    test('picks a workspace and opens markdown files', () async {
      final root = Directory(p.join(temp.path, 'docs'))..createSync();
      final file = File(p.join(root.path, 'plan.md'))
        ..writeAsStringSync('# Plan\n\nInitial text.\n');
      final controller = MarkdownWorkspaceController(
        picker: _FakeDirectoryPicker(root.path),
        store: MarkdownWorkspaceStateStore(rootDirectory: temp),
      );
      addTearDown(controller.dispose);

      await controller.pickWorkspace();
      expect(controller.state.rootPath, root.path);
      expect(controller.state.recentRoots, <String>[root.path]);

      await controller.openMarkdownFile(file.path);
      expect(controller.state.activeFilePath, file.path);
      expect(controller.state.activeMarkdown, contains('# Plan'));
      expect(controller.state.activeRelativePath, 'plan.md');
      expect(controller.state.documentRevision, 1);
    });

    test(
      'saves markdown without bumping the loaded document revision',
      () async {
        final file = File(p.join(temp.path, 'doc.md'))
          ..writeAsStringSync('# Before\n');
        final controller = MarkdownWorkspaceController(
          store: MarkdownWorkspaceStateStore(rootDirectory: temp),
        );
        addTearDown(controller.dispose);

        await controller.openWorkspace(temp.path);
        await controller.openMarkdownFile(file.path);
        final revision = controller.state.documentRevision;

        controller.markActiveDirty();
        expect(controller.state.isDirty, isTrue);

        await controller.saveActiveMarkdown('# After\n');
        expect(file.readAsStringSync(), '# After\n');
        expect(controller.state.isDirty, isFalse);
        expect(controller.state.documentRevision, revision);
      },
    );

    test(
      'restores the last workspace and active file from .vten state',
      () async {
        final root = Directory(p.join(temp.path, 'workspace'))..createSync();
        final file = File(p.join(root.path, 'notes.markdown'))
          ..writeAsStringSync('## Notes\n');
        final store = MarkdownWorkspaceStateStore(rootDirectory: temp);
        final first = MarkdownWorkspaceController(store: store);
        addTearDown(first.dispose);

        await first.openWorkspace(root.path);
        await first.openMarkdownFile(file.path);

        final second = MarkdownWorkspaceController(store: store);
        addTearDown(second.dispose);
        await second.loadLastWorkspace();

        expect(second.state.rootPath, root.path);
        expect(second.state.activeFilePath, file.path);
        expect(second.state.activeMarkdown, '## Notes\n');
        expect(second.state.recentRoots, <String>[root.path]);
      },
    );
  });
}
