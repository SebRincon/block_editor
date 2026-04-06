import 'package:block_editor/block_editor.dart';
import 'package:block_editor_example/plugins/callout_with_author_block.dart';
import 'package:block_editor_example/sections/demo_blocks_section.dart';
import 'package:block_editor_example/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: AppTheme.light,
    darkTheme: AppTheme.dark,
    home: Scaffold(body: child),
  );
}

void main() {
  setUpAll(() {
    BlockRegistry.instance.register(CalloutWithAuthorBlock());
  });

  group('DemoBlocksSection', () {
    testWidgets('mounts without error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DemoBlocksSection(themeMode: ThemeMode.light, onToggleTheme: () {}),
        ),
      );
      await tester.pump();

      expect(find.byType(DemoBlocksSection), findsOneWidget);
    });

    testWidgets('renders a BlockEditorWidget in read-only mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DemoBlocksSection(themeMode: ThemeMode.light, onToggleTheme: () {}),
        ),
      );
      await tester.pump();

      final editor = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      expect(editor.readOnly, isTrue);
    });

    testWidgets('shows the section header', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DemoBlocksSection(themeMode: ThemeMode.light, onToggleTheme: () {}),
        ),
      );
      await tester.pump();

      expect(find.text('Demo Blocks'), findsOneWidget);
      expect(
        find.text('Every built-in block type — read only'),
        findsOneWidget,
      );
    });

    testWidgets('variables map is passed to BlockEditorWidget', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DemoBlocksSection(themeMode: ThemeMode.light, onToggleTheme: () {}),
        ),
      );
      await tester.pump();

      final editor = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      expect(editor.variables['authorName'], equals('Stanly Silas'));
      expect(editor.variables['packageName'], equals('block_editor'));
    });

    testWidgets('demo document contains all sixteen block types', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          DemoBlocksSection(themeMode: ThemeMode.light, onToggleTheme: () {}),
        ),
      );
      await tester.pump();

      expect(find.byType(BlockEditorWidget), findsOneWidget);

      final editor = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      final types = editor.controller.document
          .flatten()
          .map((b) => b.type)
          .toSet();

      expect(types, contains(BlockTypes.paragraph));
      expect(types, contains(BlockTypes.heading1));
      expect(types, contains(BlockTypes.heading2));
      expect(types, contains(BlockTypes.heading3));
      expect(types, contains(BlockTypes.bulletList));
      expect(types, contains(BlockTypes.numberedList));
      expect(types, contains(BlockTypes.todo));
      expect(types, contains(BlockTypes.quote));
      expect(types, contains(BlockTypes.callout));
      expect(types, contains(BlockTypes.code));
      expect(types, contains(BlockTypes.divider));
      expect(types, contains(BlockTypes.image));
      expect(types, contains(BlockTypes.video));
      expect(types, contains(BlockTypes.youtube));
      expect(types, contains(BlockTypes.file));
      expect(types, contains(BlockTypes.link));
    });

    testWidgets('renders without throwing on dark theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          DemoBlocksSection(themeMode: ThemeMode.dark, onToggleTheme: () {}),
        ),
      );
      await tester.pump();

      expect(find.byType(DemoBlocksSection), findsOneWidget);
    });
  });
}
