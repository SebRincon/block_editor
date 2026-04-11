import 'package:block_editor/block_editor.dart';
import 'package:block_editor_example/plugins/callout_with_author_block.dart';
import 'package:block_editor_example/sections/custom_block_demo_section.dart';
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

  group('CustomBlockDemoSection', () {
    testWidgets('mounts without error', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CustomBlockDemoSection(
            themeMode: ThemeMode.light,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CustomBlockDemoSection), findsOneWidget);
    });

    testWidgets('shows the section header', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CustomBlockDemoSection(
            themeMode: ThemeMode.light,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Custom Block Demo'), findsOneWidget);
    });

    testWidgets('renders a BlockEditorWidget in read-only mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CustomBlockDemoSection(
            themeMode: ThemeMode.light,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pump();

      final editor = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      expect(editor.readOnly, isTrue);
    });

    testWidgets('custom block type is registered in BlockRegistry', (
      tester,
    ) async {
      final plugin = BlockRegistry.instance.resolve(calloutWithAuthorBlockType);
      expect(plugin, isNotNull);
      expect(plugin, isA<CalloutWithAuthorBlock>());
    });

    testWidgets('custom block plugin produces a renderable widget', (
      tester,
    ) async {
      final plugin = BlockRegistry.instance.resolve(calloutWithAuthorBlockType);
      expect(plugin, isNotNull);

      final node = BlockNode(
        type: calloutWithAuthorBlockType,
        attributes: {
          'variant': 'info',
          'author': 'Test Author',
          'timestamp': DateTime.now().toIso8601String(),
        },
        delta: TextDelta.fromPlainText('Test content'),
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: plugin!.build(node, EditorSelection.none, (_) {}),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Test Author'), findsOneWidget);
      expect(find.text('just now'), findsOneWidget);
    });

    testWidgets('demo document contains custom block type nodes', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          CustomBlockDemoSection(
            themeMode: ThemeMode.light,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pump();

      final editor = tester.widget<BlockEditorWidget>(
        find.byType(BlockEditorWidget),
      );
      final types = editor.controller.document
          .flatten()
          .map((b) => b.type)
          .toList();

      expect(types, contains(calloutWithAuthorBlockType));
      expect(
        types.where((t) => t == calloutWithAuthorBlockType).length,
        equals(2),
      );
    });

    testWidgets('code panel is visible', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        _wrap(
          CustomBlockDemoSection(
            themeMode: ThemeMode.light,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Registration'), findsOneWidget);
      expect(find.text('Live render'), findsOneWidget);
    });

    testWidgets('renders without throwing on dark theme', (tester) async {
      await tester.pumpWidget(
        _wrap(
          CustomBlockDemoSection(
            themeMode: ThemeMode.dark,
            onToggleTheme: () {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(CustomBlockDemoSection), findsOneWidget);
    });

    testWidgets(
      'CalloutWithAuthorBlock serializes and deserializes correctly',
      (tester) async {
        final plugin = CalloutWithAuthorBlock();
        final node = BlockNode(
          type: calloutWithAuthorBlockType,
          attributes: const {
            'variant': 'warning',
            'author': 'Stanly Silas',
            'timestamp': '2025-01-01T00:00:00.000',
          },
          delta: TextDelta.fromPlainText('Round-trip content'),
        );

        final serialized = plugin.serialize(node);
        final deserialized = plugin.deserialize(serialized);

        expect(deserialized.type, equals(calloutWithAuthorBlockType));
        expect(deserialized.attributes['author'], equals('Stanly Silas'));
        expect(deserialized.attributes['variant'], equals('warning'));
        expect(deserialized.delta?.plainText, equals('Round-trip content'));
      },
    );
  });
}
