import 'package:block_editor/block_editor.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders a plan-sized Markdown document surface', (tester) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final controller = BlockController(
      document: BlockMarkdownCodec.decode(_planSizedMarkdown),
    );
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2563EB)),
        ),
        home: Scaffold(
          body: SizedBox(
            width: 900,
            height: 1200,
            child: BlockEditorWidget(
              controller: controller,
              readOnly: true,
              padding: const EdgeInsets.fromLTRB(48, 36, 48, 64),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));

    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(BlockEditorWidget),
      matchesGoldenFile('goldens/plan_document_surface.png'),
    );
  });
}

const _planSizedMarkdown = '''
---
title: Markdown editor phase plan
status: in-review
---

# Markdown Editor Phase Plan

> [!note] Scope
> This document exercises the same kind of dense planning file that CodeForge opens in block mode.

## Goals

- Preserve source fidelity when the WYSIWYG layer cannot render a block.
- Keep table controls outside the text cells.
- Support nested work lists that stay aligned.
  - Child bullet with **bold** and ==highlighted== text.
  - [ ] Child task that can indent under a parent task.
- [x] Verified block copy uses Markdown.

## Table

| Area | Owner | Status |
|:-----|:-----:|------:|
| Tables | Editor | **ready** |
| Shortcuts | Editor | in progress |
| Preview blocks | Markdown | planned |

## Diagram

```mermaid
graph TD
  Open[Open markdown] --> Decode[Decode blocks]
  Decode --> Edit[Edit in block mode]
  Edit --> Save[Save markdown]
```

## Equation

\$\$
score = fidelity * usability
\$\$

## Raw Source

<aside class="source-preserved">
This HTML should stay editable even before it has rich UI.
</aside>

## Code

```dart
void main() {
  print('markdown stays markdown');
}
```
''';
