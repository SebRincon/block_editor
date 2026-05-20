library;

import 'package:flutter/material.dart';
import 'package:re_highlight/languages/bash.dart';
import 'package:re_highlight/languages/c.dart';
import 'package:re_highlight/languages/cpp.dart';
import 'package:re_highlight/languages/csharp.dart';
import 'package:re_highlight/languages/css.dart';
import 'package:re_highlight/languages/dart.dart';
import 'package:re_highlight/languages/diff.dart';
import 'package:re_highlight/languages/dockerfile.dart';
import 'package:re_highlight/languages/go.dart';
import 'package:re_highlight/languages/java.dart';
import 'package:re_highlight/languages/javascript.dart';
import 'package:re_highlight/languages/json.dart';
import 'package:re_highlight/languages/kotlin.dart';
import 'package:re_highlight/languages/markdown.dart';
import 'package:re_highlight/languages/php.dart';
import 'package:re_highlight/languages/plaintext.dart';
import 'package:re_highlight/languages/python.dart';
import 'package:re_highlight/languages/ruby.dart';
import 'package:re_highlight/languages/rust.dart';
import 'package:re_highlight/languages/scss.dart';
import 'package:re_highlight/languages/shell.dart';
import 'package:re_highlight/languages/sql.dart';
import 'package:re_highlight/languages/swift.dart';
import 'package:re_highlight/languages/typescript.dart';
import 'package:re_highlight/languages/xml.dart';
import 'package:re_highlight/languages/yaml.dart';
import 'package:re_highlight/re_highlight.dart';

import '../theme/block_editor_theme.dart';
import '../theme/markdown_document_theme.dart';

final Highlight _sourceHighlighter = Highlight()
  ..registerLanguages({
    'bash': langBash,
    'c': langC,
    'cpp': langCpp,
    'csharp': langCsharp,
    'css': langCss,
    'dart': langDart,
    'diff': langDiff,
    'dockerfile': langDockerfile,
    'go': langGo,
    'java': langJava,
    'javascript': langJavascript,
    'json': langJson,
    'kotlin': langKotlin,
    'markdown': langMarkdown,
    'mermaid': langMermaid,
    'php': langPhp,
    'plaintext': langPlaintext,
    'python': langPython,
    'ruby': langRuby,
    'rust': langRust,
    'scss': langScss,
    'shell': langShell,
    'sql': langSql,
    'swift': langSwift,
    'typescript': langTypescript,
    'xml': langXml,
    'yaml': langYaml,
  });

/// Highlight.js-style grammar for the Mermaid subset the editor previews.
///
/// `re_highlight` does not ship Mermaid, so this mode covers common flowchart
/// and sequence syntax while still using the same token tree renderer as every
/// other source-backed block.
final Mode langMermaid = Mode(
  name: 'Mermaid',
  aliases: const ['mmd'],
  caseInsensitive: true,
  keywords: {
    'keyword': [
      'graph',
      'flowchart',
      'sequenceDiagram',
      'participant',
      'as',
      'subgraph',
      'end',
      'direction',
      'classDef',
      'class',
      'style',
      'linkStyle',
      'stateDiagram-v2',
      'erDiagram',
      'gantt',
      'pie',
      'journey',
      'gitGraph',
      'TD',
      'TB',
      'BT',
      'LR',
      'RL',
      'note',
      'over',
      'activate',
      'deactivate',
      'loop',
      'alt',
      'else',
      'opt',
      'par',
      'and',
      'rect',
      'critical',
      'break',
    ],
  },
  contains: <Mode>[
    Mode(scope: 'comment', begin: r'%%', end: r'$'),
    QUOTE_STRING_MODE,
    Mode(scope: 'string', begin: r'\|', end: r'\|', relevance: 0),
    Mode(scope: 'string', begin: r'\[', end: r'\]', relevance: 0),
    Mode(scope: 'string', begin: r'\(', end: r'\)', relevance: 0),
    Mode(scope: 'string', begin: r'\{', end: r'\}', relevance: 0),
    Mode(
      scope: 'operator',
      match: r'-->|---|==>|-.->|--x|--o|->>|-->>|[-=]+[)>x-]*',
      relevance: 1,
    ),
    Mode(scope: 'number', match: r'\b\d+(?:\.\d+)?\b', relevance: 0),
    Mode(
      scope: 'variable',
      match: r'\b[A-Za-z_][A-Za-z0-9_-]*(?=\s*(?:\[|\(|\{|--|->|:|$))',
      relevance: 0,
    ),
    Mode(scope: 'punctuation', match: r'[:;,]', relevance: 0),
  ],
);

TextSpan buildHighlightedSourceSpan(
  String source, {
  required String language,
  required TextStyle baseStyle,
  required BlockEditorThemeData editorTheme,
  required MarkdownDocumentThemeData markdownTheme,
}) {
  final normalizedLanguage = _normalizeLanguage(language);
  final theme = _sourceHighlightTheme(
    editorTheme: editorTheme,
    markdownTheme: markdownTheme,
    baseStyle: baseStyle,
  );

  try {
    final result = _sourceHighlighter.highlight(
      code: source,
      language: normalizedLanguage,
      ignoreIllegals: true,
    );
    final renderer = TextSpanRenderer(baseStyle, theme);
    result.render(renderer);
    return renderer.span ?? TextSpan(text: source, style: baseStyle);
  } catch (_) {
    return TextSpan(text: source, style: baseStyle);
  }
}

Map<String, TextStyle> _sourceHighlightTheme({
  required BlockEditorThemeData editorTheme,
  required MarkdownDocumentThemeData markdownTheme,
  required TextStyle baseStyle,
}) {
  final muted = markdownTheme.codeBlockMutedForeground;
  final primary = editorTheme.primary;
  const green = Color(0xFF22C55E);
  const cyan = Color(0xFF38BDF8);
  const amber = Color(0xFFF59E0B);
  const orange = Color(0xFFFB923C);
  const rose = Color(0xFFFB7185);
  const violet = Color(0xFFA78BFA);

  return {
    'root': baseStyle,
    'keyword': TextStyle(color: primary, fontWeight: FontWeight.w700),
    'operator': const TextStyle(color: cyan, fontWeight: FontWeight.w700),
    'punctuation': TextStyle(color: muted),
    'comment': TextStyle(color: muted, fontStyle: FontStyle.italic),
    'quote': TextStyle(color: muted, fontStyle: FontStyle.italic),
    'string': const TextStyle(color: green),
    'regexp': const TextStyle(color: green),
    'addition': const TextStyle(color: green),
    'attribute': const TextStyle(color: green),
    'number': const TextStyle(color: amber),
    'literal': const TextStyle(color: cyan),
    'symbol': const TextStyle(color: cyan),
    'bullet': const TextStyle(color: cyan),
    'link': const TextStyle(color: cyan),
    'meta': const TextStyle(color: cyan),
    'built_in': const TextStyle(color: amber),
    'type': const TextStyle(color: orange),
    'variable': const TextStyle(color: orange),
    'template-variable': const TextStyle(color: orange),
    'attr': const TextStyle(color: orange),
    'title': const TextStyle(color: cyan, fontWeight: FontWeight.w700),
    'title.class_': const TextStyle(color: amber, fontWeight: FontWeight.w700),
    'class-title': const TextStyle(color: amber, fontWeight: FontWeight.w700),
    'function': const TextStyle(color: cyan),
    'function-params': const TextStyle(color: green),
    'name': const TextStyle(color: rose),
    'section': const TextStyle(color: rose, fontWeight: FontWeight.w700),
    'selector-tag': const TextStyle(color: rose),
    'deletion': const TextStyle(color: rose),
    'subst': const TextStyle(color: rose),
    'doctag': const TextStyle(color: violet),
    'formula': const TextStyle(color: violet),
    'emphasis': const TextStyle(fontStyle: FontStyle.italic),
    'strong': const TextStyle(fontWeight: FontWeight.bold),
  };
}

String _normalizeLanguage(String language) {
  final normalized = language.trim().toLowerCase();
  return switch (normalized) {
    '' => 'plaintext',
    'plain' => 'plaintext',
    'text' => 'plaintext',
    'js' => 'javascript',
    'jsx' => 'javascript',
    'ts' => 'typescript',
    'tsx' => 'typescript',
    'py' => 'python',
    'rb' => 'ruby',
    'sh' => 'shell',
    'bash' => 'shell',
    'zsh' => 'shell',
    'yml' => 'yaml',
    'md' => 'markdown',
    'mmd' => 'mermaid',
    'html' => 'xml',
    'htm' => 'xml',
    'c++' => 'cpp',
    'cc' => 'cpp',
    'cs' => 'csharp',
    _ => normalized,
  };
}
