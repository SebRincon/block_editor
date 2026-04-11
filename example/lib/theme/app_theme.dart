import 'package:flutter/material.dart';

/// Provides the complete light and dark [ThemeData] for the block_editor
/// example application.
///
/// Both themes are built entirely from scratch. No seed colors, no Material 3
/// dynamic color, no stock component defaults. Every component theme is
/// explicitly overridden so the application reads as its own design system
/// rather than a Material app with a custom color.
abstract final class AppTheme {
  static const Color _accent = Color(0xFF3B82F6);
  static const Color _accentDark = Color(0xFF60A5FA);

  static const Color _lightBackground = Color(0xFFF9F9F9);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceVariant = Color(0xFFF2F2F2);
  static const Color _lightBorder = Color(0xFFE4E4E7);
  static const Color _lightText = Color(0xFF111111);
  static const Color _lightTextMuted = Color(0xFF71717A);

  static const Color _darkBackground = Color(0xFF111111);
  static const Color _darkSurface = Color(0xFF1C1C1C);
  static const Color _darkSurfaceVariant = Color(0xFF262626);
  static const Color _darkBorder = Color(0xFF2E2E2E);
  static const Color _darkText = Color(0xFFF4F4F5);
  static const Color _darkTextMuted = Color(0xFF71717A);

  static const _radius = BorderRadius.all(Radius.circular(12));
  static const _radiusSmall = BorderRadius.all(Radius.circular(8));

  /// The light theme.
  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: _lightBackground,
    surface: _lightSurface,
    surfaceVariant: _lightSurfaceVariant,
    border: _lightBorder,
    text: _lightText,
    textMuted: _lightTextMuted,
    accent: _accent,
  );

  /// The dark theme.
  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: _darkBackground,
    surface: _darkSurface,
    surfaceVariant: _darkSurfaceVariant,
    border: _darkBorder,
    text: _darkText,
    textMuted: _darkTextMuted,
    accent: _accentDark,
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color surfaceVariant,
    required Color border,
    required Color text,
    required Color textMuted,
    required Color accent,
  }) {
    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: Colors.white,
      secondary: accent,
      onSecondary: Colors.white,
      error: const Color(0xFFEF4444),
      onError: Colors.white,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: surfaceVariant,
      outline: border,
    );

    return ThemeData(
      useMaterial3: false,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: surface,
      dividerColor: border,
      fontFamily: 'Inter',
      textTheme: _textTheme(text, textMuted),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 15,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textMuted, size: 20),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: _radius,
          side: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _radius),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: text,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: const RoundedRectangleBorder(borderRadius: _radius),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.1,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: const RoundedRectangleBorder(borderRadius: _radiusSmall),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: TextStyle(color: textMuted, fontSize: 14),
        labelStyle: TextStyle(color: textMuted, fontSize: 14),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: _radius,
          side: BorderSide(color: border),
        ),
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        contentTextStyle: TextStyle(
          color: textMuted,
          fontSize: 14,
          height: 1.6,
        ),
      ),
      listTileTheme: ListTileThemeData(
        shape: const RoundedRectangleBorder(borderRadius: _radiusSmall),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        iconColor: textMuted,
        textColor: text,
        titleTextStyle: TextStyle(
          color: text,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      iconTheme: IconThemeData(color: textMuted, size: 20),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: brightness == Brightness.dark
              ? const Color(0xFF2E2E2E)
              : const Color(0xFF111111),
          borderRadius: _radiusSmall,
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        waitDuration: const Duration(milliseconds: 600),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStateProperty.all(border),
        radius: const Radius.circular(4),
        thickness: WidgetStateProperty.all(4),
      ),
      extensions: [
        AppColors(
          background: background,
          surface: surface,
          surfaceVariant: surfaceVariant,
          border: border,
          text: text,
          textMuted: textMuted,
          accent: accent,
        ),
      ],
    );
  }

  static TextTheme _textTheme(Color text, Color muted) {
    return TextTheme(
      displayLarge: TextStyle(
        color: text,
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.5,
        height: 1.1,
      ),
      displayMedium: TextStyle(
        color: text,
        fontSize: 36,
        fontWeight: FontWeight.w700,
        letterSpacing: -1.0,
        height: 1.15,
      ),
      headlineLarge: TextStyle(
        color: text,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
        height: 1.2,
      ),
      headlineMedium: TextStyle(
        color: text,
        fontSize: 22,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.5,
        height: 1.25,
      ),
      headlineSmall: TextStyle(
        color: text,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.3,
      ),
      titleLarge: TextStyle(
        color: text,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        height: 1.4,
      ),
      titleMedium: TextStyle(
        color: text,
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        height: 1.4,
      ),
      titleSmall: TextStyle(
        color: text,
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0,
        height: 1.4,
      ),
      bodyLarge: TextStyle(
        color: text,
        fontSize: 15,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodyMedium: TextStyle(
        color: text,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
      ),
      bodySmall: TextStyle(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.5,
      ),
      labelLarge: TextStyle(
        color: text,
        fontSize: 14,
        fontWeight: FontWeight.w500,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        color: muted,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.2,
      ),
      labelSmall: TextStyle(
        color: muted,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        letterSpacing: 0.3,
      ),
    );
  }
}

/// A [ThemeExtension] that makes the full palette available anywhere in the
/// widget tree without digging through [ColorScheme].
///
/// Read via `Theme.of(context).extension<AppColors>()!`.
final class AppColors extends ThemeExtension<AppColors> {
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

  final Color background;
  final Color surface;
  final Color surfaceVariant;
  final Color border;
  final Color text;
  final Color textMuted;
  final Color accent;

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? surfaceVariant,
    Color? border,
    Color? text,
    Color? textMuted,
    Color? accent,
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
      background: Color.lerp(background, other.background, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      surfaceVariant: Color.lerp(surfaceVariant, other.surfaceVariant, t)!,
      border: Color.lerp(border, other.border, t)!,
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
    );
  }
}
