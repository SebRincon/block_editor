import 'package:flutter/material.dart';

import '../sections/custom_block_demo_section.dart';
import '../sections/demo_blocks_section.dart';
import '../sections/editor_section.dart';
import '../sections/rendering_playground_section.dart';
import '../theme/app_theme.dart';
import 'nav_bottom_bar.dart';
import 'nav_sidebar.dart';

/// The top-level layout scaffold for the block_editor example application.
///
/// On wide screens (≥ 768px) renders a fixed [NavSidebar] beside the active
/// section. On narrow screens renders the active section full-width with a
/// [NavBottomBar] below. The breakpoint switch is driven by [LayoutBuilder].
///
/// Section transitions animate with a cross-fade at 200ms using
/// [AnimatedSwitcher].
class ShellScaffold extends StatefulWidget {
  /// Creates a [ShellScaffold].
  const ShellScaffold({
    super.key,
    required this.themeMode,
    required this.onToggleTheme,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;

  @override
  State<ShellScaffold> createState() => _ShellScaffoldState();
}

class _ShellScaffoldState extends State<ShellScaffold> {
  int _selectedIndex = 0;

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
  }

  Widget _buildSection() {
    return switch (_selectedIndex) {
      0 => EditorSection(
        key: const ValueKey('editor'),
        themeMode: widget.themeMode,
        onToggleTheme: widget.onToggleTheme,
      ),
      1 => DemoBlocksSection(
        key: const ValueKey('demo'),
        themeMode: widget.themeMode,
        onToggleTheme: widget.onToggleTheme,
      ),
      2 => CustomBlockDemoSection(
        key: const ValueKey('custom'),
        themeMode: widget.themeMode,
        onToggleTheme: widget.onToggleTheme,
      ),
      3 => RenderingPlaygroundSection(
        key: const ValueKey('playground'),
        themeMode: widget.themeMode,
        onToggleTheme: widget.onToggleTheme,
      ),
      _ => EditorSection(
        key: ValueKey('editor'),
        themeMode: widget.themeMode,
        onToggleTheme: widget.onToggleTheme,
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 768;

        if (isWide) {
          return Scaffold(
            backgroundColor: colors.background,
            body: Row(
              children: [
                NavSidebar(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                ),
                VerticalDivider(width: 1, thickness: 1, color: colors.border),
                Expanded(
                  child: _SectionHost(
                    themeMode: widget.themeMode,
                    onToggleTheme: widget.onToggleTheme,
                    child: _buildSection(),
                  ),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          backgroundColor: colors.background,
          body: _SectionHost(
            themeMode: widget.themeMode,
            onToggleTheme: widget.onToggleTheme,
            child: _buildSection(),
          ),
          bottomNavigationBar: NavBottomBar(
            selectedIndex: _selectedIndex,
            onDestinationSelected: _onDestinationSelected,
          ),
        );
      },
    );
  }
}

class _SectionHost extends StatelessWidget {
  const _SectionHost({
    required this.themeMode,
    required this.onToggleTheme,
    required this.child,
  });

  final ThemeMode themeMode;
  final VoidCallback onToggleTheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      transitionBuilder: (child, animation) =>
          FadeTransition(opacity: animation, child: child),
      child: child,
    );
  }
}
