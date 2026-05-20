import 'package:flutter/material.dart' as material;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import 'shell/shell_scaffold.dart';
import 'theme/app_theme.dart';

/// The root widget of the block_editor example application.
///
/// Owns the theme-mode notifier and wires the example through the same
/// `ShadcnApp` setup used by `mock_ui`. The theme toggle is forwarded to
/// [ShellScaffold] which surfaces it in the editor top bar.
class App extends material.StatefulWidget {
  /// Creates an [App].
  const App({super.key});

  @override
  material.State<App> createState() => _AppState();
}

class _AppState extends material.State<App> {
  shadcn.ThemeMode _themeMode = shadcn.ThemeMode.dark;

  material.ThemeMode get _materialThemeMode {
    return switch (_themeMode) {
      shadcn.ThemeMode.light => material.ThemeMode.light,
      shadcn.ThemeMode.dark => material.ThemeMode.dark,
      shadcn.ThemeMode.system => material.ThemeMode.system,
    };
  }

  void _toggleTheme() {
    setState(() {
      _themeMode = _themeMode == shadcn.ThemeMode.light
          ? shadcn.ThemeMode.dark
          : shadcn.ThemeMode.light;
    });
  }

  @override
  material.Widget build(material.BuildContext context) {
    return shadcn.ShadcnApp(
      title: 'block_editor demo',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: AppTheme.shadcnLight,
      darkTheme: AppTheme.shadcnDark,
      materialTheme: AppTheme.materialFor(_materialThemeMode),
      home: ShellScaffold(
        themeMode: _materialThemeMode,
        onToggleTheme: _toggleTheme,
      ),
    );
  }
}
