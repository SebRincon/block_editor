import 'package:block_editor/block_editor.dart';
import 'package:block_editor_example/sections/rendering_playground_section.dart';
import 'package:block_editor_example/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

Widget _wrap(Widget child) {
  return shadcn.ShadcnApp(
    theme: AppTheme.shadcnLight,
    darkTheme: AppTheme.shadcnDark,
    themeMode: shadcn.ThemeMode.dark,
    materialTheme: AppTheme.dark,
    home: Scaffold(body: child),
  );
}

void _setWideView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  group('RenderingPlaygroundSection', () {
    testWidgets('mounts with controls, preview, and source pane', (
      tester,
    ) async {
      _setWideView(tester);
      await tester.pumpWidget(
        _wrap(
          RenderingPlaygroundSection(
            themeMode: ThemeMode.dark,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Rendering Playground'), findsOneWidget);
      expect(find.text('Number marker Y'), findsOneWidget);
      expect(find.byType(BlockEditorWidget), findsOneWidget);
      expect(find.widgetWithText(TextField, 'Markdown source'), findsOneWidget);
    });

    testWidgets('applies default playground Markdown theme overrides', (
      tester,
    ) async {
      _setWideView(tester);
      await tester.pumpWidget(
        _wrap(
          RenderingPlaygroundSection(
            themeMode: ThemeMode.dark,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pump();

      final theme = tester.widget<MarkdownDocumentTheme>(
        find.byType(MarkdownDocumentTheme),
      );
      expect(theme.data.maxContentWidth, 1248);
      expect(theme.data.bulletListMarkerVerticalOffset, -1.5);
      expect(theme.data.numberedListMarkerVerticalOffset, -2.0);
      expect(theme.data.listIndentWidth, 28);
    });

    testWidgets('default fixture covers broad Markdown and block variants', (
      tester,
    ) async {
      _setWideView(tester);
      await tester.pumpWidget(
        _wrap(
          RenderingPlaygroundSection(
            themeMode: ThemeMode.dark,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pump();

      final editor = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      final blocks = editor.controller.document.flatten().toList();
      final types = blocks.map((block) => block.type).toSet();

      expect(
        types,
        containsAll(<String>[
          BlockTypes.heading1,
          BlockTypes.heading2,
          BlockTypes.heading3,
          BlockTypes.heading4,
          BlockTypes.heading5,
          BlockTypes.heading6,
          BlockTypes.paragraph,
          BlockTypes.bulletList,
          BlockTypes.numberedList,
          BlockTypes.todo,
          BlockTypes.quote,
          BlockTypes.callout,
          BlockTypes.table,
          BlockTypes.code,
          BlockTypes.math,
          BlockTypes.mermaid,
          BlockTypes.rawMarkdown,
          BlockTypes.image,
          BlockTypes.link,
          BlockTypes.video,
          BlockTypes.youtube,
          BlockTypes.file,
          BlockTypes.divider,
        ]),
      );
      expect(
        blocks.where((block) => block.type == BlockTypes.table).length,
        greaterThanOrEqualTo(4),
      );
      expect(
        blocks.where((block) => block.type == BlockTypes.code).length,
        greaterThanOrEqualTo(5),
      );
      expect(
        blocks.where((block) => block.type == BlockTypes.callout).length,
        greaterThanOrEqualTo(6),
      );
    });

    testWidgets('source edits reparse the preview document', (tester) async {
      _setWideView(tester);
      await tester.pumpWidget(
        _wrap(
          RenderingPlaygroundSection(
            themeMode: ThemeMode.dark,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pump();

      await tester.enterText(
        find.widgetWithText(TextField, 'Markdown source'),
        '# Reparsed\n\n1. Updated item',
      );
      await tester.pump();

      final editor = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      expect(editor.controller.document.blocks.first.type, BlockTypes.heading1);
      expect(
        editor.controller.document.blocks[1].type,
        BlockTypes.numberedList,
      );
    });
  });
}
