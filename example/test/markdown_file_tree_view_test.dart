import 'dart:io';

import 'package:block_editor_example/theme/app_theme.dart';
import 'package:block_editor_example/workspace/markdown_file_tree_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

Widget _wrap(Widget child) {
  return shadcn.ShadcnApp(
    theme: AppTheme.shadcnLight,
    darkTheme: AppTheme.shadcnDark,
    themeMode: shadcn.ThemeMode.dark,
    materialTheme: AppTheme.dark,
    home: Scaffold(body: SizedBox(width: 360, height: 520, child: child)),
  );
}

void main() {
  group('MarkdownFileTreeView', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('block_editor_tree_');
    });

    tearDown(() async {
      if (await temp.exists()) await temp.delete(recursive: true);
    });

    testWidgets('loads markdown files and ignores generated folders', (
      tester,
    ) async {
      final root = Directory(p.join(temp.path, 'workspace'))..createSync();
      File(p.join(root.path, 'README.md')).writeAsStringSync('# Readme');
      File(p.join(root.path, 'notes.txt')).writeAsStringSync('not markdown');
      Directory(p.join(root.path, 'build')).createSync();
      File(
        p.join(root.path, 'build', 'generated.md'),
      ).writeAsStringSync('# Ignore');

      String? openedPath;
      await tester.pumpWidget(
        _wrap(
          MarkdownFileTreeView(
            rootPaths: <String>[root.path],
            onOpenFileRequested: (path) => openedPath = path,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('README.md'), findsOneWidget);
      expect(find.text('notes.txt'), findsNothing);
      expect(find.text('generated.md'), findsNothing);

      await tester.tap(find.text('README.md'));
      await tester.pump();
      expect(openedPath, p.join(root.path, 'README.md'));
    });

    testWidgets('reveals and selects the active markdown file', (tester) async {
      final root = Directory(p.join(temp.path, 'workspace'))..createSync();
      final docs = Directory(p.join(root.path, 'docs'))..createSync();
      final file = File(p.join(docs.path, 'guide.md'))
        ..writeAsStringSync('# Guide');

      await tester.pumpWidget(
        _wrap(
          MarkdownFileTreeView(
            rootPaths: <String>[root.path],
            activeFilePath: file.path,
            activeFileRevealRequestId: 1,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      expect(find.text('docs'), findsOneWidget);
      expect(find.text('guide.md'), findsOneWidget);
    });
  });
}
