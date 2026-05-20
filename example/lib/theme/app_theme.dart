import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

/// Shared example-app theme wiring.
///
/// The default dark theme mirrors `mock_ui`:
///
/// - `ShadcnApp`
/// - `CustomColorSchemes.vsCodeDark()`
/// - `radius: 0.5`
/// - `Typography.geist()`
///
/// The Material [ThemeData] values are adapters for the example app's legacy
/// Material widgets. The editor package itself reads the shadcn theme first.
abstract final class AppTheme {
  static const shadcn.Typography _typography = shadcn.Typography.geist();

  /// The exact shadcn dark theme used by `mock_ui`.
  static final shadcn.ThemeData shadcnDark = shadcn.ThemeData(
    colorScheme: vsCodeDarkColorScheme,
    radius: 0.5,
    typography: _typography,
  );

  /// A light companion theme for local contrast checks.
  ///
  /// The playground starts in [material.ThemeMode.dark] so the first-run
  /// experience matches `mock_ui`.
  static final shadcn.ThemeData shadcnLight = shadcn.ThemeData(
    colorScheme: shadcn.ColorSchemes.lightDefaultColor,
    radius: 0.5,
    typography: _typography,
  );

  /// Material adapter for light-mode tests and local contrast checks.
  static material.ThemeData get light =>
      _materialFromShadcn(shadcn.ColorSchemes.lightDefaultColor);

  /// Material adapter for the `mock_ui` VS Code dark shadcn theme.
  static material.ThemeData get dark =>
      _materialFromShadcn(vsCodeDarkColorScheme);

  /// Returns the Material adapter that matches a shadcn theme mode.
  static material.ThemeData materialFor(material.ThemeMode mode) {
    return mode == material.ThemeMode.light ? light : dark;
  }

  /// Visual Studio Code default dark color scheme copied from `mock_ui`.
  static const shadcn.ColorScheme vsCodeDarkColorScheme = shadcn.ColorScheme(
    brightness: material.Brightness.dark,
    background: material.Color(0xFF1E1E1E),
    foreground: material.Color(0xFFCCCCCC),
    card: material.Color(0xFF252526),
    cardForeground: material.Color(0xFFCCCCCC),
    popover: material.Color(0xFF252526),
    popoverForeground: material.Color(0xFFCCCCCC),
    primary: material.Color(0xFF007ACC),
    primaryForeground: material.Color(0xFFFFFFFF),
    secondary: material.Color(0xFF37373D),
    secondaryForeground: material.Color(0xFFCCCCCC),
    muted: material.Color(0xFF2D2D2D),
    mutedForeground: material.Color(0xFF808080),
    accent: material.Color(0xFF37373D),
    accentForeground: material.Color(0xFFCCCCCC),
    destructive: material.Color(0xFFF44747),
    destructiveForeground: material.Color(0xFFFFFFFF),
    border: material.Color(0xFF303031),
    input: material.Color(0xFF3C3C3C),
    ring: material.Color(0xFF0E639C),
    chart1: material.Color(0xFF569CD6),
    chart2: material.Color(0xFF9CDCFE),
    chart3: material.Color(0xFFB5CEA8),
    chart4: material.Color(0xFFCE9178),
    chart5: material.Color(0xFFDCDCAA),
    sidebar: material.Color(0xFF252526),
    sidebarForeground: material.Color(0xFFCCCCCC),
    sidebarPrimary: material.Color(0xFF007ACC),
    sidebarPrimaryForeground: material.Color(0xFFFFFFFF),
    sidebarAccent: material.Color(0xFF37373D),
    sidebarAccentForeground: material.Color(0xFFCCCCCC),
    sidebarBorder: material.Color(0xFF303031),
    sidebarRing: material.Color(0xFF0E639C),
  );

  static material.ThemeData _materialFromShadcn(shadcn.ColorScheme colors) {
    final materialScheme =
        material.ColorScheme.fromSeed(
          seedColor: colors.primary,
          brightness: colors.brightness,
          surface: colors.background,
          primary: colors.primary,
          secondary: colors.secondary,
          error: colors.destructive,
        ).copyWith(
          onSurface: colors.foreground,
          surface: colors.background,
          surfaceContainerHighest: colors.muted,
          outline: colors.border,
          outlineVariant: colors.border,
          onSurfaceVariant: colors.mutedForeground,
          secondaryContainer: colors.accent,
          onSecondaryContainer: colors.accentForeground,
        );

    final appColors = AppColors.fromShadcn(colors);
    final textTheme = _textTheme(colors);
    final radius = material.BorderRadius.circular(6);
    final smallRadius = material.BorderRadius.circular(4);

    return material.ThemeData.from(colorScheme: materialScheme).copyWith(
      brightness: colors.brightness,
      scaffoldBackgroundColor: colors.background,
      canvasColor: colors.card,
      dividerColor: colors.border,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      appBarTheme: material.AppBarTheme(
        backgroundColor: colors.card,
        foregroundColor: colors.foreground,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: _typography.textSmall.copyWith(
          color: colors.foreground,
          fontWeight: material.FontWeight.w600,
        ),
        iconTheme: material.IconThemeData(
          color: colors.mutedForeground,
          size: 20,
        ),
      ),
      cardTheme: material.CardThemeData(
        color: colors.card,
        elevation: 0,
        margin: material.EdgeInsets.zero,
        shape: material.RoundedRectangleBorder(
          borderRadius: radius,
          side: material.BorderSide(color: colors.border),
        ),
      ),
      elevatedButtonTheme: material.ElevatedButtonThemeData(
        style: material.ElevatedButton.styleFrom(
          backgroundColor: colors.primary,
          foregroundColor: colors.primaryForeground,
          elevation: 0,
          shadowColor: material.Colors.transparent,
          padding: const material.EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          shape: material.RoundedRectangleBorder(borderRadius: radius),
          textStyle: _typography.textSmall.copyWith(
            fontWeight: material.FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: material.OutlinedButtonThemeData(
        style: material.OutlinedButton.styleFrom(
          foregroundColor: colors.foreground,
          side: material.BorderSide(color: colors.border),
          padding: const material.EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 10,
          ),
          shape: material.RoundedRectangleBorder(borderRadius: radius),
          textStyle: _typography.textSmall.copyWith(
            fontWeight: material.FontWeight.w500,
          ),
        ),
      ),
      textButtonTheme: material.TextButtonThemeData(
        style: material.TextButton.styleFrom(
          foregroundColor: colors.primary,
          padding: const material.EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          shape: material.RoundedRectangleBorder(borderRadius: smallRadius),
          textStyle: _typography.textSmall.copyWith(
            fontWeight: material.FontWeight.w500,
          ),
        ),
      ),
      inputDecorationTheme: material.InputDecorationTheme(
        filled: true,
        fillColor: colors.input,
        contentPadding: const material.EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: material.OutlineInputBorder(
          borderRadius: radius,
          borderSide: material.BorderSide(color: colors.border),
        ),
        enabledBorder: material.OutlineInputBorder(
          borderRadius: radius,
          borderSide: material.BorderSide(color: colors.border),
        ),
        focusedBorder: material.OutlineInputBorder(
          borderRadius: radius,
          borderSide: material.BorderSide(color: colors.ring, width: 1.5),
        ),
        hintStyle: _typography.textSmall.copyWith(
          color: colors.mutedForeground,
        ),
        labelStyle: _typography.textSmall.copyWith(
          color: colors.mutedForeground,
        ),
      ),
      dialogTheme: material.DialogThemeData(
        backgroundColor: colors.popover,
        elevation: 0,
        shape: material.RoundedRectangleBorder(
          borderRadius: radius,
          side: material.BorderSide(color: colors.border),
        ),
        titleTextStyle: _typography.textLarge.copyWith(
          color: colors.popoverForeground,
        ),
        contentTextStyle: _typography.textSmall.copyWith(
          color: colors.mutedForeground,
          height: 1.5,
        ),
      ),
      iconTheme: material.IconThemeData(
        color: colors.mutedForeground,
        size: 20,
      ),
      dividerTheme: material.DividerThemeData(
        color: colors.border,
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: material.TooltipThemeData(
        decoration: material.BoxDecoration(
          color: colors.popover,
          border: material.Border.all(color: colors.border),
          borderRadius: smallRadius,
        ),
        textStyle: _typography.xSmall.copyWith(color: colors.popoverForeground),
        waitDuration: const Duration(milliseconds: 600),
      ),
      scrollbarTheme: material.ScrollbarThemeData(
        thumbColor: material.WidgetStateProperty.all(colors.border),
        radius: const material.Radius.circular(3),
        thickness: material.WidgetStateProperty.all(4),
      ),
      extensions: [appColors],
    );
  }

  static material.TextTheme _textTheme(shadcn.ColorScheme colors) {
    material.TextStyle withColor(
      material.TextStyle style,
      material.Color color,
    ) {
      return style.copyWith(color: color);
    }

    return material.TextTheme(
      displayLarge: withColor(_typography.h1, colors.foreground),
      displayMedium: withColor(_typography.h2, colors.foreground),
      headlineLarge: withColor(_typography.h3, colors.foreground),
      headlineMedium: withColor(_typography.h4, colors.foreground),
      headlineSmall: withColor(_typography.textLarge, colors.foreground),
      titleLarge: withColor(_typography.large, colors.foreground),
      titleMedium: withColor(_typography.base, colors.foreground),
      titleSmall: withColor(_typography.small, colors.foreground),
      bodyLarge: withColor(_typography.p, colors.foreground),
      bodyMedium: withColor(_typography.textSmall, colors.foreground),
      bodySmall: withColor(_typography.xSmall, colors.mutedForeground),
      labelLarge: withColor(_typography.textSmall, colors.foreground),
      labelMedium: withColor(_typography.xSmall, colors.mutedForeground),
      labelSmall: withColor(_typography.xSmall, colors.mutedForeground),
    );
  }
}

/// Material-side palette adapter for example widgets that have not been moved
/// to shadcn components yet.
final class AppColors extends material.ThemeExtension<AppColors> {
  /// Creates an [AppColors] extension.
  const AppColors({
    required this.background,
    required this.surface,
    required this.surfaceVariant,
    required this.border,
    required this.text,
    required this.textMuted,
    required this.accent,
  });

  factory AppColors.fromShadcn(shadcn.ColorScheme colors) {
    return AppColors(
      background: colors.background,
      surface: colors.card,
      surfaceVariant: colors.secondary,
      border: colors.border,
      text: colors.foreground,
      textMuted: colors.mutedForeground,
      accent: colors.primary,
    );
  }

  final material.Color background;
  final material.Color surface;
  final material.Color surfaceVariant;
  final material.Color border;
  final material.Color text;
  final material.Color textMuted;
  final material.Color accent;

  @override
  AppColors copyWith({
    material.Color? background,
    material.Color? surface,
    material.Color? surfaceVariant,
    material.Color? border,
    material.Color? text,
    material.Color? textMuted,
    material.Color? accent,
  }) {
    return AppColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      border: border ?? this.border,
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      accent: accent ?? this.accent,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    return AppColors(
      background: material.Color.lerp(background, other.background, t)!,
      surface: material.Color.lerp(surface, other.surface, t)!,
      surfaceVariant: material.Color.lerp(
        surfaceVariant,
        other.surfaceVariant,
        t,
      )!,
      border: material.Color.lerp(border, other.border, t)!,
      text: material.Color.lerp(text, other.text, t)!,
      textMuted: material.Color.lerp(textMuted, other.textMuted, t)!,
      accent: material.Color.lerp(accent, other.accent, t)!,
    );
  }
}
