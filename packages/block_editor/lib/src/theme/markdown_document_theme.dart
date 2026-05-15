library;

import 'package:flutter/material.dart' as material;

import 'block_editor_theme.dart';

/// Document-specific styling tokens for Markdown editing and preview surfaces.
///
/// These tokens are derived from the shared shadcn-backed
/// [BlockEditorThemeData] so Markdown documents feel like part of the app while
/// still using a calmer, readable note layout instead of code-editor styling.
final class MarkdownDocumentThemeData {
  const MarkdownDocumentThemeData({
    required this.maxContentWidth,
    required this.pagePadding,
    required this.paragraphStyle,
    required this.heading1Style,
    required this.heading2Style,
    required this.heading3Style,
    required this.heading4Style,
    required this.heading5Style,
    required this.heading6Style,
    required this.listMarkerStyle,
    required this.quoteStyle,
    required this.quoteBorder,
    required this.inlineCodeStyle,
    required this.inlineCodeBackground,
    required this.inlineCodeForeground,
    required this.linkColor,
    required this.wikiLinkColor,
    required this.wikiLinkBackground,
    required this.embedBackground,
    required this.highlightBackground,
    required this.highlightForeground,
    required this.footnoteColor,
    required this.footnoteBackground,
    required this.tableBorder,
    required this.tableHeaderBackground,
    required this.tableCellStyle,
    required this.tableHeaderStyle,
    required this.tableActiveCellBackground,
    required this.codeBlockBackground,
    required this.codeBlockBorder,
    required this.codeBlockForeground,
    required this.codeBlockMutedForeground,
    required this.calloutTextStyle,
    required this.calloutTitleStyle,
    required this.infoCallout,
    required this.warningCallout,
    required this.errorCallout,
    required this.successCallout,
    required this.neutralCallout,
  });

  final double maxContentWidth;
  final material.EdgeInsets pagePadding;
  final material.TextStyle paragraphStyle;
  final material.TextStyle heading1Style;
  final material.TextStyle heading2Style;
  final material.TextStyle heading3Style;
  final material.TextStyle heading4Style;
  final material.TextStyle heading5Style;
  final material.TextStyle heading6Style;
  final material.TextStyle listMarkerStyle;
  final material.TextStyle quoteStyle;
  final material.Color quoteBorder;
  final material.TextStyle inlineCodeStyle;
  final material.Color inlineCodeBackground;
  final material.Color inlineCodeForeground;
  final material.Color linkColor;
  final material.Color wikiLinkColor;
  final material.Color wikiLinkBackground;
  final material.Color embedBackground;
  final material.Color highlightBackground;
  final material.Color highlightForeground;
  final material.Color footnoteColor;
  final material.Color footnoteBackground;
  final material.Color tableBorder;
  final material.Color tableHeaderBackground;
  final material.TextStyle tableCellStyle;
  final material.TextStyle tableHeaderStyle;
  final material.Color tableActiveCellBackground;
  final material.Color codeBlockBackground;
  final material.Color codeBlockBorder;
  final material.Color codeBlockForeground;
  final material.Color codeBlockMutedForeground;
  final material.TextStyle calloutTextStyle;
  final material.TextStyle calloutTitleStyle;
  final MarkdownCalloutTone infoCallout;
  final MarkdownCalloutTone warningCallout;
  final MarkdownCalloutTone errorCallout;
  final MarkdownCalloutTone successCallout;
  final MarkdownCalloutTone neutralCallout;

  factory MarkdownDocumentThemeData.fromContext(material.BuildContext context) {
    final editor = BlockEditorThemeData.fromContext(context);
    final inherited = material.DefaultTextStyle.of(context).style;
    final foreground = editor.foreground;
    final mutedForeground = editor.mutedForeground;
    final bodyFamily = inherited.fontFamily;
    final codeFamily = 'JetBrainsMono';

    final paragraph = inherited.merge(
      editor.paragraphStyle.copyWith(
        fontFamily: bodyFamily,
        fontSize: 16,
        height: 1.58,
        letterSpacing: 0,
        color: foreground,
      ),
    );
    final codeStyle = editor.inlineCodeStyle.copyWith(
      fontFamily: codeFamily,
      fontFamilyFallback: const ['MesloLGS NF', 'monospace'],
      fontSize: 13.5,
      height: 1.45,
      letterSpacing: 0,
      color: foreground,
      backgroundColor: editor.muted.withValues(alpha: 0.76),
    );

    final info = editor.primary;
    const warning = material.Color(0xFFF59E0B);
    const success = material.Color(0xFF16A34A);

    return MarkdownDocumentThemeData(
      maxContentWidth: 1248,
      pagePadding: const material.EdgeInsets.symmetric(
        horizontal: 32,
        vertical: 28,
      ),
      paragraphStyle: paragraph,
      heading1Style: paragraph.copyWith(
        fontSize: 31,
        height: 1.14,
        fontWeight: material.FontWeight.w700,
        letterSpacing: 0,
      ),
      heading2Style: paragraph.copyWith(
        fontSize: 25,
        height: 1.18,
        fontWeight: material.FontWeight.w700,
        letterSpacing: 0,
      ),
      heading3Style: paragraph.copyWith(
        fontSize: 20,
        height: 1.25,
        fontWeight: material.FontWeight.w600,
        letterSpacing: 0,
      ),
      heading4Style: paragraph.copyWith(
        fontSize: 18,
        height: 1.28,
        fontWeight: material.FontWeight.w600,
        letterSpacing: 0,
      ),
      heading5Style: paragraph.copyWith(
        fontSize: 16,
        height: 1.34,
        fontWeight: material.FontWeight.w600,
        letterSpacing: 0,
      ),
      heading6Style: paragraph.copyWith(
        fontSize: 14.5,
        height: 1.35,
        fontWeight: material.FontWeight.w700,
        letterSpacing: 0,
        color: mutedForeground,
      ),
      listMarkerStyle: paragraph.copyWith(color: mutedForeground),
      quoteStyle: paragraph.copyWith(
        color: mutedForeground,
        fontStyle: material.FontStyle.italic,
      ),
      quoteBorder: editor.border.withValues(alpha: 0.92),
      inlineCodeStyle: codeStyle,
      inlineCodeBackground: editor.muted.withValues(alpha: 0.78),
      inlineCodeForeground: foreground,
      linkColor: editor.primary,
      wikiLinkColor: editor.primary,
      wikiLinkBackground: editor.primary.withValues(alpha: 0.08),
      embedBackground: editor.primary.withValues(alpha: 0.12),
      highlightBackground: warning.withValues(alpha: 0.22),
      highlightForeground: foreground,
      footnoteColor: mutedForeground,
      footnoteBackground: editor.muted.withValues(alpha: 0.70),
      tableBorder: editor.border.withValues(alpha: 0.82),
      tableHeaderBackground: editor.muted.withValues(alpha: 0.48),
      tableCellStyle: paragraph.copyWith(fontSize: 14.5, height: 1.42),
      tableHeaderStyle: paragraph.copyWith(
        fontSize: 13.5,
        height: 1.35,
        fontWeight: material.FontWeight.w700,
        color: foreground,
      ),
      tableActiveCellBackground: editor.accent.withValues(alpha: 0.10),
      codeBlockBackground: editor.muted.withValues(alpha: 0.40),
      codeBlockBorder: editor.border.withValues(alpha: 0.86),
      codeBlockForeground: foreground,
      codeBlockMutedForeground: mutedForeground,
      calloutTextStyle: paragraph.copyWith(fontSize: 15.5, height: 1.5),
      calloutTitleStyle: paragraph.copyWith(
        fontSize: 14.5,
        height: 1.35,
        fontWeight: material.FontWeight.w700,
      ),
      infoCallout: _tone(info, editor.background),
      warningCallout: _tone(warning, editor.background),
      errorCallout: _tone(editor.destructive, editor.background),
      successCallout: _tone(success, editor.background),
      neutralCallout: _tone(mutedForeground, editor.background),
    );
  }

  MarkdownCalloutTone calloutTone(String variant) {
    switch (variant.trim().toLowerCase()) {
      case 'warning':
      case 'warn':
      case 'caution':
      case 'attention':
        return warningCallout;
      case 'error':
      case 'danger':
      case 'failure':
      case 'fail':
      case 'missing':
      case 'bug':
        return errorCallout;
      case 'success':
      case 'check':
      case 'done':
      case 'question':
      case 'help':
      case 'faq':
        return successCallout;
      case 'note':
      case 'abstract':
      case 'summary':
      case 'tldr':
      case 'info':
      case 'todo':
      case 'tip':
      case 'hint':
      case 'important':
        return infoCallout;
      default:
        return neutralCallout;
    }
  }

  static MarkdownCalloutTone _tone(
    material.Color accent,
    material.Color surface,
  ) {
    return MarkdownCalloutTone(
      accent: accent,
      background: material.Color.alphaBlend(
        accent.withValues(alpha: 0.10),
        surface,
      ),
      border: accent.withValues(alpha: 0.58),
      iconBackground: accent.withValues(alpha: 0.14),
    );
  }
}

final class MarkdownCalloutTone {
  const MarkdownCalloutTone({
    required this.accent,
    required this.background,
    required this.border,
    required this.iconBackground,
  });

  final material.Color accent;
  final material.Color background;
  final material.Color border;
  final material.Color iconBackground;
}
