import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The top bar for the editor section.
///
/// Contains the document title [TextField], a read-only mode indicator badge,
/// and five action buttons — export JSON, export Markdown, toggle read-only,
/// clear document, and toggle theme. Each button is an icon-only control on
/// narrow layouts and gains a text label on wide layouts.
class EditorTopBar extends StatelessWidget {
  /// Creates an [EditorTopBar].
  const EditorTopBar({
    super.key,
    required this.titleController,
    required this.readOnly,
    required this.compactReader,
    required this.centerContent,
    required this.themeMode,
    this.workspaceFileLabel,
    this.workspaceDirty = false,
    this.workspaceSaving = false,
    this.onPickWorkspace,
    this.onSaveMarkdown,
    required this.onExportJson,
    required this.onExportMarkdown,
    required this.onToggleReadOnly,
    required this.onToggleCompactReader,
    required this.onToggleCenterContent,
    required this.onClear,
    required this.onToggleTheme,
  });

  final TextEditingController titleController;
  final bool readOnly;
  final bool compactReader;
  final bool centerContent;
  final ThemeMode themeMode;
  final String? workspaceFileLabel;
  final bool workspaceDirty;
  final bool workspaceSaving;
  final VoidCallback? onPickWorkspace;
  final VoidCallback? onSaveMarkdown;
  final VoidCallback onExportJson;
  final VoidCallback onExportMarkdown;
  final VoidCallback onToggleReadOnly;
  final VoidCallback onToggleCompactReader;
  final VoidCallback onToggleCenterContent;
  final VoidCallback onClear;
  final VoidCallback onToggleTheme;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final isWide = MediaQuery.of(context).size.width >= 1120;

    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: _TitleField(
              controller: titleController,
              colors: colors,
              readOnly: readOnly,
            ),
          ),
          if (workspaceFileLabel != null) ...[
            const SizedBox(width: 10),
            _WorkspaceFileBadge(
              label: workspaceFileLabel!,
              dirty: workspaceDirty,
              saving: workspaceSaving,
              colors: colors,
            ),
          ],
          const SizedBox(width: 12),
          if (readOnly) ...[
            _ReadOnlyBadge(colors: colors),
            const SizedBox(width: 12),
          ],
          _ActionRow(
            isWide: isWide,
            readOnly: readOnly,
            compactReader: compactReader,
            centerContent: centerContent,
            themeMode: themeMode,
            workspaceDirty: workspaceDirty,
            workspaceSaving: workspaceSaving,
            onPickWorkspace: onPickWorkspace,
            onSaveMarkdown: onSaveMarkdown,
            onExportJson: onExportJson,
            onExportMarkdown: onExportMarkdown,
            onToggleReadOnly: onToggleReadOnly,
            onToggleCompactReader: onToggleCompactReader,
            onToggleCenterContent: onToggleCenterContent,
            onClear: onClear,
            onToggleTheme: onToggleTheme,
            colors: colors,
          ),
        ],
      ),
    );
  }
}

class _TitleField extends StatelessWidget {
  const _TitleField({
    required this.controller,
    required this.colors,
    required this.readOnly,
  });

  final TextEditingController controller;
  final AppColors colors;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      style: TextStyle(
        color: colors.text,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      decoration: InputDecoration(
        hintText: 'Untitled document',
        hintStyle: TextStyle(
          color: colors.textMuted,
          fontSize: 15,
          fontWeight: FontWeight.w400,
        ),
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        filled: false,
        contentPadding: const EdgeInsets.symmetric(vertical: 4),
        isDense: true,
      ),
    );
  }
}

class _WorkspaceFileBadge extends StatelessWidget {
  const _WorkspaceFileBadge({
    required this.label,
    required this.dirty,
    required this.saving,
    required this.colors,
  });

  final String label;
  final bool dirty;
  final bool saving;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final status = saving
        ? 'saving'
        : dirty
        ? 'unsaved'
        : 'saved';
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 260),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: colors.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined, size: 13, color: colors.accent),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.textMuted,
                  fontSize: 11.5,
                  height: 1.1,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              status,
              style: TextStyle(
                color: dirty ? colors.accent : colors.textMuted,
                fontSize: 11,
                height: 1.1,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadOnlyBadge extends StatelessWidget {
  const _ReadOnlyBadge({required this.colors});
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: colors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline, size: 12, color: colors.textMuted),
          const SizedBox(width: 4),
          Text(
            'Read only',
            style: TextStyle(
              color: colors.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.isWide,
    required this.readOnly,
    required this.compactReader,
    required this.centerContent,
    required this.themeMode,
    required this.workspaceDirty,
    required this.workspaceSaving,
    required this.onPickWorkspace,
    required this.onSaveMarkdown,
    required this.onExportJson,
    required this.onExportMarkdown,
    required this.onToggleReadOnly,
    required this.onToggleCompactReader,
    required this.onToggleCenterContent,
    required this.onClear,
    required this.onToggleTheme,
    required this.colors,
  });

  final bool isWide;
  final bool readOnly;
  final bool compactReader;
  final bool centerContent;
  final ThemeMode themeMode;
  final bool workspaceDirty;
  final bool workspaceSaving;
  final VoidCallback? onPickWorkspace;
  final VoidCallback? onSaveMarkdown;
  final VoidCallback onExportJson;
  final VoidCallback onExportMarkdown;
  final VoidCallback onToggleReadOnly;
  final VoidCallback onToggleCompactReader;
  final VoidCallback onToggleCenterContent;
  final VoidCallback onClear;
  final VoidCallback onToggleTheme;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final isDark = themeMode == ThemeMode.dark;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (onPickWorkspace != null) ...[
          _TopBarButton(
            icon: Icons.folder_open_outlined,
            label: 'Folder',
            tooltip: 'Open Markdown folder',
            showLabel: isWide,
            onTap: onPickWorkspace!,
            colors: colors,
          ),
          const SizedBox(width: 6),
        ],
        if (onSaveMarkdown != null) ...[
          _TopBarButton(
            icon: workspaceSaving ? Icons.sync : Icons.save_outlined,
            label: workspaceSaving ? 'Saving' : 'Save',
            tooltip: workspaceSaving
                ? 'Saving Markdown'
                : workspaceDirty
                ? 'Save Markdown now'
                : 'Markdown saved',
            showLabel: isWide,
            onTap: onSaveMarkdown!,
            colors: colors,
            active: workspaceDirty || workspaceSaving,
          ),
          const SizedBox(width: 6),
        ],
        _TopBarButton(
          icon: Icons.data_object,
          label: 'JSON',
          tooltip: 'Export JSON',
          showLabel: isWide,
          onTap: onExportJson,
          colors: colors,
        ),
        const SizedBox(width: 6),
        _TopBarButton(
          icon: Icons.text_snippet_outlined,
          label: 'MD',
          tooltip: 'Export Markdown',
          showLabel: isWide,
          onTap: onExportMarkdown,
          colors: colors,
        ),
        const SizedBox(width: 6),
        _TopBarButton(
          icon: compactReader
              ? Icons.density_small_outlined
              : Icons.density_medium_outlined,
          label: 'Compact',
          tooltip: compactReader
              ? 'Switch to comfortable reader'
              : 'Switch to compact reader',
          showLabel: isWide,
          onTap: onToggleCompactReader,
          colors: colors,
          active: compactReader,
        ),
        const SizedBox(width: 6),
        _TopBarButton(
          icon: centerContent
              ? Icons.format_align_center
              : Icons.format_align_left,
          label: centerContent ? 'Center' : 'Left',
          tooltip: centerContent ? 'Align content left' : 'Center content',
          showLabel: isWide,
          onTap: onToggleCenterContent,
          colors: colors,
          active: centerContent,
        ),
        const SizedBox(width: 6),
        _TopBarButton(
          icon: readOnly ? Icons.edit_outlined : Icons.lock_outline,
          label: readOnly ? 'Edit' : 'Lock',
          tooltip: readOnly ? 'Switch to editing' : 'Switch to read-only',
          showLabel: isWide,
          onTap: onToggleReadOnly,
          colors: colors,
          active: readOnly,
        ),
        const SizedBox(width: 6),
        _TopBarButton(
          icon: Icons.delete_outline,
          label: 'Clear',
          tooltip: 'Clear document',
          showLabel: isWide,
          onTap: onClear,
          colors: colors,
          destructive: true,
        ),
        const SizedBox(width: 6),
        _TopBarButton(
          icon: isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          label: isDark ? 'Light' : 'Dark',
          tooltip: isDark ? 'Switch to light mode' : 'Switch to dark mode',
          showLabel: isWide,
          onTap: onToggleTheme,
          colors: colors,
        ),
      ],
    );
  }
}

class _TopBarButton extends StatefulWidget {
  const _TopBarButton({
    required this.icon,
    required this.label,
    required this.tooltip,
    required this.showLabel,
    required this.onTap,
    required this.colors,
    this.active = false,
    this.destructive = false,
  });

  final IconData icon;
  final String label;
  final String tooltip;
  final bool showLabel;
  final VoidCallback onTap;
  final AppColors colors;
  final bool active;
  final bool destructive;

  @override
  State<_TopBarButton> createState() => _TopBarButtonState();
}

class _TopBarButtonState extends State<_TopBarButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final Color fg;
    final Color bg;
    final Color border;

    if (widget.destructive) {
      fg = _hovered ? const Color(0xFFEF4444) : widget.colors.textMuted;
      bg = _hovered
          ? const Color(0xFFEF4444).withValues(alpha: 0.08)
          : Colors.transparent;
      border = _hovered ? const Color(0xFFEF4444) : widget.colors.border;
    } else if (widget.active) {
      fg = widget.colors.accent;
      bg = widget.colors.accent.withValues(alpha: 0.08);
      border = widget.colors.accent.withValues(alpha: 0.4);
    } else {
      fg = _hovered ? widget.colors.text : widget.colors.textMuted;
      bg = _hovered
          ? widget.colors.surfaceVariant
          : widget.colors.surface.withValues(alpha: 0.0);
      border = widget.colors.border;
    }

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            curve: Curves.easeOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: widget.showLabel ? 10 : 8,
              vertical: 7,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(widget.icon, size: 16, color: fg),
                if (widget.showLabel) ...[
                  const SizedBox(width: 5),
                  Text(
                    widget.label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
