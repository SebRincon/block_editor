import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import '../theme/app_theme.dart';
import 'markdown_file_tree_view.dart';
import 'markdown_workspace_controller.dart';

/// Sidebar pane for choosing a workspace folder and opening Markdown files.
class MarkdownWorkspacePane extends StatelessWidget {
  const MarkdownWorkspacePane({
    super.key,
    required this.state,
    required this.revealRequestId,
    required this.onPickWorkspace,
    required this.onRefreshWorkspace,
    required this.onClearWorkspace,
    required this.onOpenFile,
    this.onFileSystemPathsChanged,
  });

  final MarkdownWorkspaceState state;
  final int revealRequestId;
  final VoidCallback onPickWorkspace;
  final VoidCallback onRefreshWorkspace;
  final VoidCallback onClearWorkspace;
  final ValueChanged<String> onOpenFile;
  final ValueChanged<Set<String>>? onFileSystemPathsChanged;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final rootPath = state.rootPath;
    final rootPaths = rootPath == null ? const <String>[] : <String>[rootPath];

    return Container(
      color: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WorkspaceHeader(
            rootPath: rootPath,
            isLoading: state.isLoading,
            onPickWorkspace: onPickWorkspace,
            onRefreshWorkspace: onRefreshWorkspace,
            onClearWorkspace: onClearWorkspace,
          ),
          if (state.error != null)
            _WorkspaceError(message: state.error!)
          else if (state.hasActiveFile)
            _ActiveFileStrip(state: state),
          Expanded(
            child: MarkdownFileTreeView(
              rootPaths: rootPaths,
              activeFilePath: state.activeFilePath,
              activeFileRevealRequestId: revealRequestId,
              onOpenFileRequested: onOpenFile,
              onFileSystemPathsChanged: onFileSystemPathsChanged,
              onUnloadRoot: (_) => onClearWorkspace(),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceHeader extends StatelessWidget {
  const _WorkspaceHeader({
    required this.rootPath,
    required this.isLoading,
    required this.onPickWorkspace,
    required this.onRefreshWorkspace,
    required this.onClearWorkspace,
  });

  final String? rootPath;
  final bool isLoading;
  final VoidCallback onPickWorkspace;
  final VoidCallback onRefreshWorkspace;
  final VoidCallback onClearWorkspace;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final title = rootPath == null ? 'No folder' : p.basename(rootPath!);

    return Container(
      height: 44,
      padding: const EdgeInsets.only(left: 12, right: 6),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'MARKDOWN',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colors.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.text,
                    fontSize: 12.5,
                    height: 1.15,
                  ),
                ),
              ],
            ),
          ),
          _PaneIconButton(
            icon: Icons.create_new_folder_outlined,
            tooltip: 'Open Markdown folder',
            onTap: onPickWorkspace,
          ),
          const SizedBox(width: 4),
          _PaneIconButton(
            icon: Icons.refresh,
            tooltip: 'Refresh file tree',
            onTap: rootPath == null ? null : onRefreshWorkspace,
          ),
          const SizedBox(width: 4),
          _PaneIconButton(
            icon: Icons.close,
            tooltip: 'Close folder',
            onTap: rootPath == null ? null : onClearWorkspace,
          ),
          if (isLoading) ...[
            const SizedBox(width: 8),
            const SizedBox(
              width: 32,
              height: 2,
              child: LinearProgressIndicator(),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActiveFileStrip extends StatelessWidget {
  const _ActiveFileStrip({required this.state});

  final MarkdownWorkspaceState state;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final relative = state.activeRelativePath ?? state.activeFileName ?? '';
    final status = state.isSaving
        ? 'saving'
        : state.isDirty
        ? 'unsaved'
        : 'saved';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colors.background,
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Row(
        children: [
          Icon(Icons.description_outlined, size: 14, color: colors.accent),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              relative,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colors.text,
                fontSize: 12.5,
                height: 1.2,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            status,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: state.isDirty ? colors.accent : colors.textMuted,
              fontSize: 11,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkspaceError extends StatelessWidget {
  const _WorkspaceError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFEF4444).withValues(alpha: 0.08),
        border: Border(bottom: BorderSide(color: colors.border)),
      ),
      child: Text(
        message,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: const Color(0xFFF87171),
          fontSize: 12,
          height: 1.3,
        ),
      ),
    );
  }
}

class _PaneIconButton extends StatefulWidget {
  const _PaneIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  State<_PaneIconButton> createState() => _PaneIconButtonState();
}

class _PaneIconButtonState extends State<_PaneIconButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final enabled = widget.onTap != null;
    final fg = !enabled
        ? colors.textMuted.withValues(alpha: 0.45)
        : _hovered
        ? colors.text
        : colors.textMuted;
    final bg = enabled && _hovered ? colors.surfaceVariant : Colors.transparent;

    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(6),
            ),
            alignment: Alignment.center,
            child: Icon(widget.icon, size: 15, color: fg),
          ),
        ),
      ),
    );
  }
}
