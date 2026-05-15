library;

import 'package:flutter/material.dart';
import 'package:block_editor/block_editor.dart';

/// [BlockPlugin] for [BlockTypes.paragraph].
final class ParagraphBlock extends BlockPlugin {
  /// Creates a [ParagraphBlock].
  ParagraphBlock();

  @override
  String get blockType => BlockTypes.paragraph;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => ParagraphWidget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Text',
    group: 'Basic',
    icon: const Icon(Icons.notes),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.heading1].
final class H1Block extends BlockPlugin {
  /// Creates an [H1Block].
  H1Block();

  @override
  String get blockType => BlockTypes.heading1;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => H1Widget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Heading 1',
    group: 'Basic',
    description: 'h1, #, large section title',
    icon: const Icon(Icons.title),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.heading2].
final class H2Block extends BlockPlugin {
  /// Creates an [H2Block].
  H2Block();

  @override
  String get blockType => BlockTypes.heading2;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => H2Widget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Heading 2',
    group: 'Basic',
    description: 'h2, ##, section title',
    icon: const Icon(Icons.text_fields),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.heading3].
final class H3Block extends BlockPlugin {
  /// Creates an [H3Block].
  H3Block();

  @override
  String get blockType => BlockTypes.heading3;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => H3Widget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Heading 3',
    group: 'Basic',
    description: 'h3, ###, subsection title',
    icon: const Icon(Icons.short_text),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.heading4].
final class H4Block extends BlockPlugin {
  /// Creates an [H4Block].
  H4Block();

  @override
  String get blockType => BlockTypes.heading4;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => H4Widget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Heading 4',
    group: 'Basic',
    description: 'h4, ####, detail heading',
    icon: const Icon(Icons.subject),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.heading5].
final class H5Block extends BlockPlugin {
  /// Creates an [H5Block].
  H5Block();

  @override
  String get blockType => BlockTypes.heading5;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => H5Widget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Heading 5',
    group: 'Basic',
    description: 'h5, #####, minor heading',
    icon: const Icon(Icons.notes),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.heading6].
final class H6Block extends BlockPlugin {
  /// Creates an [H6Block].
  H6Block();

  @override
  String get blockType => BlockTypes.heading6;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => H6Widget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Heading 6',
    group: 'Basic',
    description: 'h6, ######, tiny heading',
    icon: const Icon(Icons.short_text),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.bulletList].
final class BulletListBlock extends BlockPlugin {
  /// Creates a [BulletListBlock].
  BulletListBlock();

  @override
  String get blockType => BlockTypes.bulletList;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => BulletListWidget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    attributes: node.attributes,
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Bullet List',
    group: 'Basic',
    description: '-, *, unordered list',
    icon: const Icon(Icons.format_list_bulleted),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.numberedList].
final class NumberedListBlock extends BlockPlugin {
  /// Creates a [NumberedListBlock].
  NumberedListBlock();

  @override
  String get blockType => BlockTypes.numberedList;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => NumberedListWidget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    attributes: node.attributes,
    number: node.attributes['number'] as int? ?? 1,
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Numbered List',
    group: 'Basic',
    description: '1., ordered list',
    icon: const Icon(Icons.format_list_numbered),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.todo].
final class TodoBlock extends BlockPlugin {
  /// Creates a [TodoBlock].
  TodoBlock();

  @override
  String get blockType => BlockTypes.todo;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => TodoWidget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    checked: node.attributes['checked'] as bool? ?? false,
    attributes: node.attributes,
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'To-do',
    group: 'Basic',
    description: 'checkbox, task, []',
    icon: const Icon(Icons.check_box_outlined),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.quote].
final class QuoteBlock extends BlockPlugin {
  /// Creates a [QuoteBlock].
  QuoteBlock();

  @override
  String get blockType => BlockTypes.quote;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => QuoteWidget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    selection: selection,
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Quote',
    group: 'Basic',
    icon: const Icon(Icons.format_quote),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.divider].
final class DividerBlock extends BlockPlugin {
  /// Creates a [DividerBlock].
  DividerBlock();

  @override
  String get blockType => BlockTypes.divider;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => DividerWidget(blockId: node.id, onEvent: onEvent);

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Divider',
    group: 'Basic',
    icon: const Icon(Icons.horizontal_rule),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Basic';
}

/// [BlockPlugin] for [BlockTypes.table].
final class TableBlock extends BlockPlugin {
  /// Creates a [TableBlock].
  TableBlock();

  @override
  String get blockType => BlockTypes.table;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => TableWidget(
    blockId: node.id,
    headers: _stringList(node.attributes['headers']),
    rows: _rowsList(node.attributes['rows']),
    alignments: _stringList(node.attributes['alignments']),
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Table',
    group: 'Advanced',
    icon: const Icon(Icons.table_chart_outlined),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Advanced';
}

/// [BlockPlugin] for [BlockTypes.math].
final class MathBlock extends BlockPlugin {
  /// Creates a [MathBlock].
  MathBlock();

  @override
  String get blockType => BlockTypes.math;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => MathBlockWidget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Math',
    group: 'Embeds',
    description: r'Equation block, LaTeX, $$',
    icon: const Icon(Icons.functions),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Embeds';
}

/// [BlockPlugin] for [BlockTypes.mermaid].
final class MermaidBlock extends BlockPlugin {
  /// Creates a [MermaidBlock].
  MermaidBlock();

  @override
  String get blockType => BlockTypes.mermaid;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => MermaidBlockWidget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Mermaid',
    group: 'Embeds',
    description: 'Diagram block, flowchart, sequence',
    icon: const Icon(Icons.account_tree_outlined),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Embeds';
}

/// [BlockPlugin] for [BlockTypes.rawMarkdown].
final class RawMarkdownBlock extends BlockPlugin {
  /// Creates a [RawMarkdownBlock].
  RawMarkdownBlock();

  @override
  String get blockType => BlockTypes.rawMarkdown;

  @override
  Widget build(
    BlockNode node,
    EditorSelection selection,
    void Function(BlockEvent) onEvent,
  ) => RawMarkdownWidget(
    blockId: node.id,
    delta: node.delta ?? TextDelta.empty(),
    onEvent: onEvent,
  );

  @override
  Map<String, dynamic> serialize(BlockNode node) => node.toJson();

  @override
  BlockNode deserialize(Map<String, dynamic> json) => BlockNode.fromJson(json);

  @override
  SlashCommandConfig slashCommandItem() => SlashCommandConfig(
    label: 'Raw Markdown',
    group: 'Advanced',
    description: 'HTML, comments, unsupported source',
    icon: const Icon(Icons.integration_instructions_outlined),
    onSelected: () {},
  );

  @override
  String slashCommandGroup() => 'Advanced';
}

List<String> _stringList(Object? value) {
  if (value is! Iterable<Object?>) return const [];
  return value.map((item) => item?.toString() ?? '').toList();
}

List<List<String>> _rowsList(Object? value) {
  if (value is! Iterable<Object?>) return const [];
  return value
      .whereType<Iterable<Object?>>()
      .map((row) => row.map((item) => item?.toString() ?? '').toList())
      .toList();
}
