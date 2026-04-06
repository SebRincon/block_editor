import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The bottom navigation bar shown on narrow screens (below 768px wide).
///
/// Built entirely from scratch — no [BottomNavigationBar] widget. Three items
/// are laid out in a [Row], each responding to tap and highlighting the active
/// destination with the accent color.
class NavBottomBar extends StatelessWidget {
  /// Creates a [NavBottomBar].
  const NavBottomBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.border)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              _BottomNavItem(
                icon: Icons.edit_outlined,
                label: 'Editor',
                selected: selectedIndex == 0,
                onTap: () => onDestinationSelected(0),
              ),
              _BottomNavItem(
                icon: Icons.grid_view_outlined,
                label: 'Demo',
                selected: selectedIndex == 1,
                onTap: () => onDestinationSelected(1),
              ),
              _BottomNavItem(
                icon: Icons.extension_outlined,
                label: 'Custom',
                selected: selectedIndex == 2,
                onTap: () => onDestinationSelected(2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final fg = selected ? colors.accent : colors.textMuted;

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              decoration: BoxDecoration(
                color: selected
                    ? colors.accent.withValues(alpha: 0.10)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 20, color: fg),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 150),
              style: TextStyle(
                color: fg,
                fontSize: 11,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}
