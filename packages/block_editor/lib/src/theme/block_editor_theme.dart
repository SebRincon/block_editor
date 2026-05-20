library;

import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

const _selectionBlue = material.Color(0x663B82F6);
const _cursorBlue = material.Color(0xFF3B82F6);

/// Shared theme tokens used by block_editor surfaces.
///
/// The editor prefers the nearest shadcn_flutter [shadcn.Theme]. A Material
/// fallback is kept so package-level tests and non-shadcn embedders still
/// render without needing a full app shell.
final class BlockEditorThemeData {
  const BlockEditorThemeData({
    required this.background,
    required this.foreground,
    required this.muted,
    required this.mutedForeground,
    required this.border,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.ring,
    required this.selection,
    required this.cursor,
    required this.inlineCodeBackground,
    required this.variable,
    required this.tag,
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.paragraphStyle,
    required this.heading1Style,
    required this.heading2Style,
    required this.heading3Style,
    required this.smallStyle,
    required this.xSmallStyle,
    required this.inlineCodeStyle,
    required this.mutedStyle,
  });

  final material.Color background;
  final material.Color foreground;
  final material.Color muted;
  final material.Color mutedForeground;
  final material.Color border;
  final material.Color popover;
  final material.Color popoverForeground;
  final material.Color primary;
  final material.Color primaryForeground;
  final material.Color accent;
  final material.Color accentForeground;
  final material.Color destructive;
  final material.Color ring;
  final material.Color selection;
  final material.Color cursor;
  final material.Color inlineCodeBackground;
  final material.Color variable;
  final material.Color tag;
  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final material.TextStyle paragraphStyle;
  final material.TextStyle heading1Style;
  final material.TextStyle heading2Style;
  final material.TextStyle heading3Style;
  final material.TextStyle smallStyle;
  final material.TextStyle xSmallStyle;
  final material.TextStyle inlineCodeStyle;
  final material.TextStyle mutedStyle;

  factory BlockEditorThemeData.fromContext(material.BuildContext context) {
    try {
      final theme = shadcn.Theme.of(context);
      final colors = theme.colorScheme;
      final typography = theme.typography;
      return BlockEditorThemeData(
        background: colors.background,
        foreground: colors.foreground,
        muted: colors.muted,
        mutedForeground: colors.mutedForeground,
        border: colors.border,
        popover: colors.popover,
        popoverForeground: colors.popoverForeground,
        primary: colors.primary,
        primaryForeground: colors.primaryForeground,
        accent: colors.accent,
        accentForeground: colors.accentForeground,
        destructive: colors.destructive,
        ring: colors.ring,
        selection: _selectionBlue,
        cursor: _cursorBlue,
        inlineCodeBackground: colors.muted,
        variable: colors.primary,
        tag: colors.ring,
        radiusXs: theme.radiusXs,
        radiusSm: theme.radiusSm,
        radiusMd: theme.radiusMd,
        radiusLg: theme.radiusLg,
        paragraphStyle: typography.p.copyWith(color: colors.foreground),
        heading1Style: typography.h1.copyWith(color: colors.foreground),
        heading2Style: typography.h2.copyWith(color: colors.foreground),
        heading3Style: typography.h3.copyWith(color: colors.foreground),
        smallStyle: typography.small.copyWith(color: colors.foreground),
        xSmallStyle: typography.xSmall.copyWith(color: colors.mutedForeground),
        inlineCodeStyle: typography.inlineCode.copyWith(
          color: colors.foreground,
          backgroundColor: colors.muted,
        ),
        mutedStyle: typography.textMuted.copyWith(
          color: colors.mutedForeground,
        ),
      );
    } catch (_) {
      return _fromMaterial(context);
    }
  }

  static BlockEditorThemeData _fromMaterial(material.BuildContext context) {
    final inheritedTheme = context
        .findAncestorWidgetOfExactType<material.Theme>();
    if (inheritedTheme == null) return _legacyFallback();

    final theme = material.Theme.of(context);
    final colors = theme.colorScheme;
    final text = theme.textTheme;
    final foreground = colors.onSurface;
    final mutedForeground = colors.onSurfaceVariant;
    final muted = colors.surfaceContainerHighest;
    final primary = colors.primary;

    return BlockEditorThemeData(
      background: colors.surface,
      foreground: foreground,
      muted: muted,
      mutedForeground: mutedForeground,
      border: colors.outlineVariant,
      popover: colors.surface,
      popoverForeground: foreground,
      primary: primary,
      primaryForeground: colors.onPrimary,
      accent: colors.secondaryContainer,
      accentForeground: colors.onSecondaryContainer,
      destructive: colors.error,
      ring: primary,
      selection: _selectionBlue,
      cursor: _cursorBlue,
      inlineCodeBackground: muted,
      variable: primary,
      tag: colors.tertiary,
      radiusXs: 2,
      radiusSm: 4,
      radiusMd: 8,
      radiusLg: 12,
      paragraphStyle: (text.bodyMedium ?? const material.TextStyle()).copyWith(
        fontSize: 16,
        color: foreground,
      ),
      heading1Style: (text.headlineMedium ?? const material.TextStyle())
          .copyWith(fontSize: 32, fontWeight: material.FontWeight.w700),
      heading2Style: (text.headlineSmall ?? const material.TextStyle())
          .copyWith(fontSize: 26, fontWeight: material.FontWeight.w700),
      heading3Style: (text.titleLarge ?? const material.TextStyle()).copyWith(
        fontSize: 22,
        fontWeight: material.FontWeight.w700,
      ),
      smallStyle: (text.bodySmall ?? const material.TextStyle()).copyWith(
        fontSize: 14,
        color: foreground,
      ),
      xSmallStyle: (text.labelSmall ?? const material.TextStyle()).copyWith(
        fontSize: 12,
        color: mutedForeground,
      ),
      inlineCodeStyle: (text.bodySmall ?? const material.TextStyle()).copyWith(
        fontSize: 14,
        fontFamily: 'monospace',
        fontWeight: material.FontWeight.w600,
        color: foreground,
        backgroundColor: muted,
      ),
      mutedStyle: (text.bodySmall ?? const material.TextStyle()).copyWith(
        fontSize: 14,
        color: mutedForeground,
      ),
    );
  }

  static BlockEditorThemeData _legacyFallback() {
    const foreground = material.Color(0xFF222222);
    const mutedForeground = material.Color(0xFF888888);
    const primary = material.Color(0xFF0070F3);
    const inlineCodeBackground = material.Color(0xFFEEEEEE);

    return const BlockEditorThemeData(
      background: material.Color(0xFFFFFFFF),
      foreground: foreground,
      muted: material.Color(0xFFF5F5F5),
      mutedForeground: mutedForeground,
      border: material.Color(0xFFE0E0E0),
      popover: material.Color(0xFFFFFFFF),
      popoverForeground: foreground,
      primary: primary,
      primaryForeground: material.Color(0xFFFFFFFF),
      accent: material.Color(0xFFF5F5F5),
      accentForeground: foreground,
      destructive: material.Color(0xFFD32F2F),
      ring: primary,
      selection: _selectionBlue,
      cursor: _cursorBlue,
      inlineCodeBackground: inlineCodeBackground,
      variable: material.Color(0xFF8B5CF6),
      tag: material.Color(0xFF0EA5E9),
      radiusXs: 2,
      radiusSm: 4,
      radiusMd: 8,
      radiusLg: 12,
      paragraphStyle: material.TextStyle(fontSize: 16, color: foreground),
      heading1Style: material.TextStyle(
        fontSize: 32,
        fontWeight: material.FontWeight.bold,
        color: foreground,
      ),
      heading2Style: material.TextStyle(
        fontSize: 26,
        fontWeight: material.FontWeight.bold,
        color: foreground,
      ),
      heading3Style: material.TextStyle(
        fontSize: 22,
        fontWeight: material.FontWeight.bold,
        color: foreground,
      ),
      smallStyle: material.TextStyle(fontSize: 14, color: foreground),
      xSmallStyle: material.TextStyle(fontSize: 12, color: mutedForeground),
      inlineCodeStyle: material.TextStyle(
        fontSize: 14,
        fontFamily: 'monospace',
        fontWeight: material.FontWeight.w600,
        color: foreground,
        backgroundColor: inlineCodeBackground,
      ),
      mutedStyle: material.TextStyle(fontSize: 14, color: mutedForeground),
    );
  }
}
