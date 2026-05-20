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
    required this.listIndentWidth,
    required this.listMarkerWidth,
    required this.bulletListMarkerVerticalOffset,
    required this.numberedListMarkerVerticalOffset,
    required this.todoMarkerVerticalOffset,
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
  final double listIndentWidth;
  final double listMarkerWidth;
  final double bulletListMarkerVerticalOffset;
  final double numberedListMarkerVerticalOffset;
  final double todoMarkerVerticalOffset;
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
    final inherited = MarkdownDocumentTheme.maybeOf(context);
    if (inherited != null) return inherited;

    return MarkdownDocumentThemeData.defaults(context);
  }

  /// Resolves the default Markdown document tokens from the shared editor theme.
  factory MarkdownDocumentThemeData.defaults(material.BuildContext context) {
    final editor = BlockEditorThemeData.fromContext(context);
    final inherited = material.DefaultTextStyle.of(context).style;
    final foreground = editor.foreground;
    final mutedForeground = editor.mutedForeground;
    final bodyFamily = inherited.fontFamily;
    final codeFamily = 'JetBrainsMono';
    final tableHeaderSurface = material.Color.alphaBlend(
      foreground.withValues(alpha: 0.035),
      editor.background,
    );
    final codeSurface = material.Color.alphaBlend(
      foreground.withValues(alpha: 0.045),
      editor.background,
    );
    final activeCellSurface = material.Color.alphaBlend(
      foreground.withValues(alpha: 0.055),
      editor.background,
    );
    final footnoteSurface = material.Color.alphaBlend(
      foreground.withValues(alpha: 0.065),
      editor.background,
    );

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
      listIndentWidth: 28,
      listMarkerWidth: 28,
      bulletListMarkerVerticalOffset: -1.5,
      numberedListMarkerVerticalOffset: -2.0,
      todoMarkerVerticalOffset: 2,
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
      footnoteBackground: footnoteSurface,
      tableBorder: editor.border.withValues(alpha: 0.76),
      tableHeaderBackground: tableHeaderSurface,
      tableCellStyle: paragraph.copyWith(fontSize: 14.5, height: 1.42),
      tableHeaderStyle: paragraph.copyWith(
        fontSize: 13.5,
        height: 1.35,
        fontWeight: material.FontWeight.w700,
        color: foreground,
      ),
      tableActiveCellBackground: activeCellSurface,
      codeBlockBackground: codeSurface,
      codeBlockBorder: editor.border.withValues(alpha: 0.78),
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

  /// Returns a copy with selected Markdown document tokens replaced.
  MarkdownDocumentThemeData copyWith({
    double? maxContentWidth,
    material.EdgeInsets? pagePadding,
    material.TextStyle? paragraphStyle,
    material.TextStyle? heading1Style,
    material.TextStyle? heading2Style,
    material.TextStyle? heading3Style,
    material.TextStyle? heading4Style,
    material.TextStyle? heading5Style,
    material.TextStyle? heading6Style,
    material.TextStyle? listMarkerStyle,
    double? listIndentWidth,
    double? listMarkerWidth,
    double? bulletListMarkerVerticalOffset,
    double? numberedListMarkerVerticalOffset,
    double? todoMarkerVerticalOffset,
    material.TextStyle? quoteStyle,
    material.Color? quoteBorder,
    material.TextStyle? inlineCodeStyle,
    material.Color? inlineCodeBackground,
    material.Color? inlineCodeForeground,
    material.Color? linkColor,
    material.Color? wikiLinkColor,
    material.Color? wikiLinkBackground,
    material.Color? embedBackground,
    material.Color? highlightBackground,
    material.Color? highlightForeground,
    material.Color? footnoteColor,
    material.Color? footnoteBackground,
    material.Color? tableBorder,
    material.Color? tableHeaderBackground,
    material.TextStyle? tableCellStyle,
    material.TextStyle? tableHeaderStyle,
    material.Color? tableActiveCellBackground,
    material.Color? codeBlockBackground,
    material.Color? codeBlockBorder,
    material.Color? codeBlockForeground,
    material.Color? codeBlockMutedForeground,
    material.TextStyle? calloutTextStyle,
    material.TextStyle? calloutTitleStyle,
    MarkdownCalloutTone? infoCallout,
    MarkdownCalloutTone? warningCallout,
    MarkdownCalloutTone? errorCallout,
    MarkdownCalloutTone? successCallout,
    MarkdownCalloutTone? neutralCallout,
  }) {
    return MarkdownDocumentThemeData(
      maxContentWidth: maxContentWidth ?? this.maxContentWidth,
      pagePadding: pagePadding ?? this.pagePadding,
      paragraphStyle: paragraphStyle ?? this.paragraphStyle,
      heading1Style: heading1Style ?? this.heading1Style,
      heading2Style: heading2Style ?? this.heading2Style,
      heading3Style: heading3Style ?? this.heading3Style,
      heading4Style: heading4Style ?? this.heading4Style,
      heading5Style: heading5Style ?? this.heading5Style,
      heading6Style: heading6Style ?? this.heading6Style,
      listMarkerStyle: listMarkerStyle ?? this.listMarkerStyle,
      listIndentWidth: listIndentWidth ?? this.listIndentWidth,
      listMarkerWidth: listMarkerWidth ?? this.listMarkerWidth,
      bulletListMarkerVerticalOffset:
          bulletListMarkerVerticalOffset ?? this.bulletListMarkerVerticalOffset,
      numberedListMarkerVerticalOffset:
          numberedListMarkerVerticalOffset ??
          this.numberedListMarkerVerticalOffset,
      todoMarkerVerticalOffset:
          todoMarkerVerticalOffset ?? this.todoMarkerVerticalOffset,
      quoteStyle: quoteStyle ?? this.quoteStyle,
      quoteBorder: quoteBorder ?? this.quoteBorder,
      inlineCodeStyle: inlineCodeStyle ?? this.inlineCodeStyle,
      inlineCodeBackground: inlineCodeBackground ?? this.inlineCodeBackground,
      inlineCodeForeground: inlineCodeForeground ?? this.inlineCodeForeground,
      linkColor: linkColor ?? this.linkColor,
      wikiLinkColor: wikiLinkColor ?? this.wikiLinkColor,
      wikiLinkBackground: wikiLinkBackground ?? this.wikiLinkBackground,
      embedBackground: embedBackground ?? this.embedBackground,
      highlightBackground: highlightBackground ?? this.highlightBackground,
      highlightForeground: highlightForeground ?? this.highlightForeground,
      footnoteColor: footnoteColor ?? this.footnoteColor,
      footnoteBackground: footnoteBackground ?? this.footnoteBackground,
      tableBorder: tableBorder ?? this.tableBorder,
      tableHeaderBackground:
          tableHeaderBackground ?? this.tableHeaderBackground,
      tableCellStyle: tableCellStyle ?? this.tableCellStyle,
      tableHeaderStyle: tableHeaderStyle ?? this.tableHeaderStyle,
      tableActiveCellBackground:
          tableActiveCellBackground ?? this.tableActiveCellBackground,
      codeBlockBackground: codeBlockBackground ?? this.codeBlockBackground,
      codeBlockBorder: codeBlockBorder ?? this.codeBlockBorder,
      codeBlockForeground: codeBlockForeground ?? this.codeBlockForeground,
      codeBlockMutedForeground:
          codeBlockMutedForeground ?? this.codeBlockMutedForeground,
      calloutTextStyle: calloutTextStyle ?? this.calloutTextStyle,
      calloutTitleStyle: calloutTitleStyle ?? this.calloutTitleStyle,
      infoCallout: infoCallout ?? this.infoCallout,
      warningCallout: warningCallout ?? this.warningCallout,
      errorCallout: errorCallout ?? this.errorCallout,
      successCallout: successCallout ?? this.successCallout,
      neutralCallout: neutralCallout ?? this.neutralCallout,
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

/// Overrides Markdown document rendering tokens for a subtree.
class MarkdownDocumentTheme extends material.InheritedWidget {
  /// Creates a Markdown document theme override.
  const MarkdownDocumentTheme({
    super.key,
    required this.data,
    required super.child,
  });

  /// The Markdown document tokens exposed to descendant block widgets.
  final MarkdownDocumentThemeData data;

  /// Returns the nearest Markdown document theme override, if any.
  static MarkdownDocumentThemeData? maybeOf(material.BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<MarkdownDocumentTheme>()
        ?.data;
  }

  /// Returns the nearest Markdown document theme or derived defaults.
  static MarkdownDocumentThemeData of(material.BuildContext context) {
    return MarkdownDocumentThemeData.fromContext(context);
  }

  @override
  bool updateShouldNotify(MarkdownDocumentTheme oldWidget) {
    return data != oldWidget.data;
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
