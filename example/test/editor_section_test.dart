import 'package:block_editor/block_editor.dart';
import 'package:block_editor_example/app.dart';
import 'package:block_editor_example/plugins/callout_with_author_block.dart';
import 'package:block_editor_example/sections/editor_section.dart';
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

  group('EditorSection', () {
    testWidgets('mounts without error', (tester) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      expect(find.byType(EditorSection), findsOneWidget);
      expect(find.byType(BlockEditorWidget), findsOneWidget);
    });

    testWidgets('title field shows current title', (tester) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      expect(find.text('Getting started'), findsOneWidget);
    });

    testWidgets('read-only toggle switches editor to read-only mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      final editorBefore = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      expect(editorBefore.readOnly, isFalse);

      await tester.tap(find.byTooltip('Switch to read-only'));
      await tester.pump();

      final editorAfter = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      expect(editorAfter.readOnly, isTrue);
    });

    testWidgets('read-only toggle shows lock badge when active', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      expect(find.text('Read only'), findsNothing);

      await tester.tap(find.byTooltip('Switch to read-only'));
      await tester.pump();

      expect(find.text('Read only'), findsOneWidget);
    });

    testWidgets('read-only can be toggled back to editable', (tester) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Switch to read-only'));
      await tester.pump();
      await tester.tap(find.byTooltip('Switch to editing'));
      await tester.pump();

      final editor = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      expect(editor.readOnly, isFalse);
    });

    testWidgets('JSON export button opens modal with non-empty content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Export JSON'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Export JSON'), findsOneWidget);
      expect(find.textContaining('"blocks"'), findsOneWidget);
    });

    testWidgets('Markdown export button opens modal with non-empty content', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Export Markdown'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Export Markdown'), findsOneWidget);
      expect(find.textContaining('#'), findsWidgets);
    });

    testWidgets('clear document shows confirmation dialog', (tester) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Clear document'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Clear document?'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
      expect(find.text('Clear'), findsNWidgets(2));
    });

    testWidgets('clear document cancel dismisses dialog without clearing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      await tester.tap(find.byTooltip('Clear document'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Cancel'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Clear document?'), findsNothing);
      expect(find.byType(BlockEditorWidget), findsOneWidget);
    });

    testWidgets('tag strip shows gettingstarted tag from starter document', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      expect(find.text('#gettingstarted'), findsOneWidget);
    });

    testWidgets('variables map is passed to BlockEditorWidget', (tester) async {
      await tester.pumpWidget(
        _wrap(EditorSection(themeMode: ThemeMode.light, onToggleTheme: () {})),
      );
      await tester.pump();

      final editor = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      expect(editor.variables, isNotEmpty);
      expect(editor.variables['authorName'], equals('Stanly Silas'));
      expect(editor.variables['packageName'], equals('block_editor'));
    });
  });

  group('EditorSection full app integration', () {
    testWidgets('mounts correctly inside App', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const App());
      await tester.pump();

      expect(find.byType(BlockEditorWidget), findsOneWidget);
    });
  });
}
