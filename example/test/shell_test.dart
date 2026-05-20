import 'package:block_editor/block_editor.dart';
import 'package:block_editor_example/app.dart';
import 'package:block_editor_example/plugins/callout_with_author_block.dart';
import 'package:block_editor_example/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

void main() {
  setUpAll(() {
    BlockRegistry.instance.register(CalloutWithAuthorBlock());
  });

  group('ShellScaffold navigation', () {
    testWidgets('renders on wide screen with sidebar visible', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const App());
      await tester.pump();

      expect(find.text('block_editor'), findsOneWidget);
      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Demo Blocks'), findsOneWidget);
      expect(find.text('Custom Block'), findsOneWidget);
      expect(find.text('Playground'), findsOneWidget);
    });

    testWidgets('renders on narrow screen with bottom bar visible', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const App());
      await tester.pump();

      expect(find.text('Editor'), findsOneWidget);
      expect(find.text('Demo'), findsOneWidget);
      expect(find.text('Custom'), findsOneWidget);
      expect(find.text('Tune'), findsOneWidget);
    });

    testWidgets('navigates to Demo Blocks section', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const App());
      await tester.pump();

      await tester.tap(find.text('Demo Blocks'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Demo Blocks'), findsWidgets);
    });

    testWidgets('navigates to Custom Block section', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const App());
      await tester.pump();

      await tester.tap(find.text('Custom Block'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Custom Block Demo'), findsOneWidget);
    });

    testWidgets('navigates to Rendering Playground section', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const App());
      await tester.pump();

      await tester.tap(find.text('Playground'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Rendering Playground'), findsOneWidget);
    });

    testWidgets('navigates back to Editor section', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const App());
      await tester.pump();

      await tester.tap(find.text('Demo Blocks'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Editor'));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Getting started'), findsOneWidget);
    });

    testWidgets('uses mock_ui shadcn setup and toggles theme mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(const App());
      await tester.pump();

      final shadcn.ShadcnApp appBefore = tester.widget(
        find.byType(shadcn.ShadcnApp),
      );
      expect(appBefore.themeMode, shadcn.ThemeMode.dark);
      expect(
        appBefore.darkTheme?.colorScheme.primary,
        AppTheme.vsCodeDarkColorScheme.primary,
      );
      expect(appBefore.darkTheme?.radius, 0.5);

      await tester.tap(find.byTooltip('Switch to light mode'));
      await tester.pump(const Duration(milliseconds: 500));

      final shadcn.ShadcnApp appAfter = tester.widget(
        find.byType(shadcn.ShadcnApp),
      );
      expect(appAfter.themeMode, shadcn.ThemeMode.light);
    });
  });
}
