import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:shadcn_flutter/shadcn_flutter.dart' as shadcn;

import '../theme/app_theme.dart';
import 'markdown_workspace_controller.dart';

@immutable
final class MarkdownFileTreeEntry {
  const MarkdownFileTreeEntry({
    required this.rootPath,
    required this.path,
    required this.name,
    required this.isDirectory,
    this.isRoot = false,
  });

  final String rootPath;
  final String path;
  final String name;
  final bool isDirectory;
  final bool isRoot;
}

/// Lazy file tree for selecting real Markdown files in the demo app.
class MarkdownFileTreeView extends StatefulWidget {
  const MarkdownFileTreeView({
    super.key,
    required this.rootPaths,
    this.activeFilePath,
    this.activeFileRevealRequestId,
    this.isVisible = true,
    this.onOpenFileRequested,
    this.onFileSystemPathsChanged,
    this.onUnloadRoot,
  });

  final List<String> rootPaths;
  final String? activeFilePath;
  final int? activeFileRevealRequestId;
  final bool isVisible;
  final ValueChanged<String>? onOpenFileRequested;
  final ValueChanged<Set<String>>? onFileSystemPathsChanged;
  final ValueChanged<String>? onUnloadRoot;

  @override
  State<MarkdownFileTreeView> createState() => _MarkdownFileTreeViewState();
}

class _MarkdownFileTreeViewState extends State<MarkdownFileTreeView> {
  late List<shadcn.TreeNode<MarkdownFileTreeEntry>> _nodes;

  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _itemKeys = <String, GlobalKey>{};
  final Set<String> _loadedDirectoryChildren = <String>{};
  final Set<String> _loadingDirectoryChildren = <String>{};
  final Map<String, StreamSubscription<FileSystemEvent>> _watchersByRootPath =
      <String, StreamSubscription<FileSystemEvent>>{};
  final Set<String> _pendingDirectoryRefreshes = <String>{};
  final Set<String> _pendingChangedPaths = <String>{};
  final ValueNotifier<String?> _hoveredPathNotifier = ValueNotifier<String?>(
    null,
  );

  Timer? _watchDebounceTimer;
  bool _isFlushingDirectoryRefreshes = false;
  int? _lastRevealRequestId;
  String? _lastRevealFilePath;

  @override
  void initState() {
    super.initState();
    _nodes = _buildWorkspaceNodes(widget.rootPaths);
    _applyActiveFileSelection(widget.activeFilePath, notify: false);
    _syncWorkspaceWatchers();
    _scheduleInitialRootLoads();
    if (widget.activeFilePath != null &&
        (widget.activeFileRevealRequestId ?? 0) > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _revealAndCenter(widget.activeFilePath!);
        _lastRevealRequestId = widget.activeFileRevealRequestId;
        _lastRevealFilePath = widget.activeFilePath;
      });
    }
  }

  @override
  void didUpdateWidget(covariant MarkdownFileTreeView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rootsChanged = !listEquals(oldWidget.rootPaths, widget.rootPaths);
    final activeFileChanged = oldWidget.activeFilePath != widget.activeFilePath;
    final revealIdChanged =
        oldWidget.activeFileRevealRequestId != widget.activeFileRevealRequestId;
    final becameVisible = !oldWidget.isVisible && widget.isVisible;

    if (rootsChanged) {
      final expandedByPath = <String, bool>{};
      final selectedByPath = <String, bool>{};
      _collectNodeState(
        nodes: _nodes,
        expandedByPath: expandedByPath,
        selectedByPath: selectedByPath,
      );

      final next = _buildWorkspaceNodes(widget.rootPaths);
      _nodes = _applyNodeState(
        nodes: next,
        expandedByPath: expandedByPath,
        selectedByPath: selectedByPath,
      );
      _loadedDirectoryChildren.clear();
      _loadingDirectoryChildren.clear();
      _itemKeys.clear();
      _syncWorkspaceWatchers();
      _scheduleInitialRootLoads();
    }

    if (activeFileChanged) {
      _applyActiveFileSelection(widget.activeFilePath);
    }

    final revealId = widget.activeFileRevealRequestId;
    final shouldReveal =
        widget.isVisible &&
        (revealId ?? 0) > 0 &&
        widget.activeFilePath != null &&
        (revealIdChanged || activeFileChanged || becameVisible) &&
        (_lastRevealRequestId != revealId ||
            _lastRevealFilePath != widget.activeFilePath);

    if (shouldReveal) {
      _revealAndCenter(widget.activeFilePath!);
      _lastRevealRequestId = revealId;
      _lastRevealFilePath = widget.activeFilePath;
    }
  }

  @override
  void dispose() {
    _watchDebounceTimer?.cancel();
    for (final watcher in _watchersByRootPath.values) {
      unawaited(watcher.cancel());
    }
    _watchersByRootPath.clear();
    _scrollController.dispose();
    _hoveredPathNotifier.dispose();
    super.dispose();
  }

  void _scheduleInitialRootLoads() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      for (final root in widget.rootPaths) {
        final rootEntry = _findEntryByPath(root);
        if (rootEntry != null) {
          unawaited(_ensureChildrenLoaded(rootEntry));
        }
      }
    });
  }

  void _syncWorkspaceWatchers() {
    final nextRoots = widget.rootPaths
        .map(p.normalize)
        .where((root) => root.trim().isNotEmpty)
        .toSet();

    final staleRoots = _watchersByRootPath.keys
        .where((root) => !nextRoots.contains(root))
        .toList(growable: false);
    for (final staleRoot in staleRoots) {
      final watcher = _watchersByRootPath.remove(staleRoot);
      if (watcher != null) unawaited(watcher.cancel());
    }

    for (final root in nextRoots) {
      if (_watchersByRootPath.containsKey(root)) continue;
      final directory = Directory(root);
      if (!directory.existsSync()) continue;
      try {
        _watchersByRootPath[root] = directory
            .watch(recursive: true)
            .listen(
              (event) => _onWorkspaceFsEvent(root, event),
              onError: (_) {},
            );
      } catch (_) {
        // Network mounts and some sandboxed launches do not allow recursive
        // watches. The manual refresh control still works in those cases.
      }
    }
  }

  void _onWorkspaceFsEvent(String rootPath, FileSystemEvent event) {
    if (_shouldIgnoreWatchPath(rootPath, event.path)) return;
    final refreshDirs = _refreshDirectoriesForEvent(rootPath, event);
    if (refreshDirs.isEmpty) return;

    _pendingDirectoryRefreshes.addAll(refreshDirs);
    _pendingChangedPaths.add(p.normalize(event.path));
    if (event is FileSystemMoveEvent && event.destination != null) {
      _pendingChangedPaths.add(p.normalize(event.destination!));
    }

    _watchDebounceTimer?.cancel();
    _watchDebounceTimer = Timer(const Duration(milliseconds: 140), () {
      unawaited(_flushPendingDirectoryRefreshes());
    });
  }

  bool _shouldIgnoreWatchPath(String rootPath, String eventPath) {
    final normalized = p.normalize(eventPath);
    if (!(p.equals(rootPath, normalized) || p.isWithin(rootPath, normalized))) {
      return true;
    }

    final relative = p.relative(normalized, from: rootPath);
    final parts = p.split(relative);
    if (parts.any(_isIgnoredDirectoryName)) return true;

    final name = p.basename(normalized);
    return name == '.DS_Store' ||
        name == 'index.lock' ||
        name.endsWith('.lock') ||
        name.endsWith('~') ||
        name.endsWith('.swp') ||
        name.endsWith('.swx') ||
        name.startsWith('.#') ||
        name.startsWith('.watchman-cookie');
  }

  Set<String> _refreshDirectoriesForEvent(
    String rootPath,
    FileSystemEvent event,
  ) {
    final dirs = <String>{};

    void addPath(String? value) {
      if (value == null || value.trim().isEmpty) return;
      final normalized = p.normalize(value);
      if (!(p.equals(rootPath, normalized) ||
          p.isWithin(rootPath, normalized))) {
        return;
      }

      final type = FileSystemEntity.typeSync(normalized, followLinks: false);
      if (type == FileSystemEntityType.directory) {
        dirs.add(normalized);
      } else {
        dirs.add(p.normalize(p.dirname(normalized)));
      }
    }

    addPath(event.path);
    if (event is FileSystemMoveEvent) addPath(event.destination);
    if (dirs.isEmpty) dirs.add(p.normalize(rootPath));
    return dirs;
  }

  Future<void> _flushPendingDirectoryRefreshes() async {
    if (_isFlushingDirectoryRefreshes) return;
    _isFlushingDirectoryRefreshes = true;
    try {
      while (_pendingDirectoryRefreshes.isNotEmpty) {
        final pending = _pendingDirectoryRefreshes.toList(growable: false)
          ..sort((a, b) => a.length.compareTo(b.length));
        final changedPaths = Set<String>.from(_pendingChangedPaths);
        _pendingDirectoryRefreshes.clear();
        _pendingChangedPaths.clear();

        if (changedPaths.isNotEmpty) {
          widget.onFileSystemPathsChanged?.call(changedPaths);
        }

        for (final dirPath in pending) {
          if (!mounted) return;
          await _refreshDirectoryNodeByPath(dirPath);
        }
      }
    } finally {
      _isFlushingDirectoryRefreshes = false;
    }
  }

  Future<void> _refreshDirectoryNodeByPath(String dirPath) async {
    final normalized = p.normalize(dirPath);
    final rootPath = _findRootForPath(normalized);
    if (rootPath == null) return;

    var candidate = normalized;
    while (true) {
      final entry = _findEntryByPath(candidate);
      if (entry != null && entry.isDirectory) {
        await _refreshDirectoryNode(entry);
        return;
      }

      if (p.equals(candidate, rootPath)) break;
      final parent = p.normalize(p.dirname(candidate));
      if (parent == candidate) break;
      candidate = parent;
    }

    final rootEntry = _findEntryByPath(rootPath);
    if (rootEntry != null && rootEntry.isDirectory) {
      await _refreshDirectoryNode(rootEntry);
    }
  }

  Future<void> _refreshDirectoryNode(MarkdownFileTreeEntry entry) async {
    final normalizedDirPath = p.normalize(entry.path);
    final children = await _scanDirectoryChildren(entry);
    if (!mounted) return;

    final mergedChildren = _mergeChildrenWithExistingState(
      directoryPath: entry.path,
      nextChildren: children,
    );

    setState(() {
      _loadedDirectoryChildren.add(normalizedDirPath);
      _loadingDirectoryChildren.remove(normalizedDirPath);
      _nodes = shadcn.TreeView.replaceNodes(_nodes, (node) {
        if (node is! shadcn.TreeItem<MarkdownFileTreeEntry>) return null;
        if (node.data.path != entry.path) return null;
        return shadcn.TreeItem<MarkdownFileTreeEntry>(
          data: node.data,
          expanded: node.expanded,
          selected: node.selected,
          children: mergedChildren,
        );
      });
    });
  }

  List<shadcn.TreeNode<MarkdownFileTreeEntry>> _mergeChildrenWithExistingState({
    required String directoryPath,
    required List<shadcn.TreeNode<MarkdownFileTreeEntry>> nextChildren,
  }) {
    final existing = _findTreeItemByPath(directoryPath);
    if (existing == null) return nextChildren;

    final expandedByPath = <String, bool>{};
    final selectedByPath = <String, bool>{};
    _collectNodeState(
      nodes: existing.children,
      expandedByPath: expandedByPath,
      selectedByPath: selectedByPath,
    );

    return _applyNodeState(
      nodes: nextChildren,
      expandedByPath: expandedByPath,
      selectedByPath: selectedByPath,
    );
  }

  shadcn.TreeItem<MarkdownFileTreeEntry>? _findTreeItemByPath(String path) {
    shadcn.TreeItem<MarkdownFileTreeEntry>? result;

    void walk(List<shadcn.TreeNode<MarkdownFileTreeEntry>> nodes) {
      for (final node in nodes) {
        if (result != null) return;
        if (node is shadcn.TreeRoot<MarkdownFileTreeEntry>) {
          walk(node.children);
          continue;
        }
        if (node is shadcn.TreeItem<MarkdownFileTreeEntry>) {
          if (p.equals(node.data.path, path)) {
            result = node;
            return;
          }
          walk(node.children);
        }
      }
    }

    walk(_nodes);
    return result;
  }

  String? _findRootForPath(String path) {
    String? best;
    final normalizedPath = p.normalize(path);
    for (final root in widget.rootPaths) {
      final normalizedRoot = p.normalize(root);
      if (p.equals(normalizedRoot, normalizedPath) ||
          p.isWithin(normalizedRoot, normalizedPath)) {
        if (best == null || normalizedRoot.length > best.length) {
          best = normalizedRoot;
        }
      }
    }
    return best;
  }

  Future<void> _ensureChildrenLoaded(MarkdownFileTreeEntry entry) async {
    if (!entry.isDirectory) return;
    final dirPath = p.normalize(entry.path);
    if (_loadingDirectoryChildren.contains(dirPath)) return;
    if (_loadedDirectoryChildren.contains(dirPath)) return;

    _loadingDirectoryChildren.add(dirPath);
    setState(() {});
    try {
      final children = await _scanDirectoryChildren(entry);
      if (!mounted) return;
      setState(() {
        _loadedDirectoryChildren.add(dirPath);
        _loadingDirectoryChildren.remove(dirPath);
        _nodes = shadcn.TreeView.replaceNodes(_nodes, (node) {
          if (node is! shadcn.TreeItem<MarkdownFileTreeEntry>) return null;
          if (node.data.path != entry.path) return null;
          if (node.children.isNotEmpty) return null;
          return shadcn.TreeItem<MarkdownFileTreeEntry>(
            data: node.data,
            expanded: node.expanded,
            selected: node.selected,
            children: children,
          );
        });
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loadedDirectoryChildren.add(dirPath);
        _loadingDirectoryChildren.remove(dirPath);
      });
    }
  }

  Future<List<shadcn.TreeNode<MarkdownFileTreeEntry>>> _scanDirectoryChildren(
    MarkdownFileTreeEntry entry,
  ) async {
    final root = entry.rootPath;
    final dir = Directory(entry.path);
    if (!dir.existsSync()) return const [];

    final directories = <MarkdownFileTreeEntry>[];
    final files = <MarkdownFileTreeEntry>[];

    final entities = dir.listSync(recursive: false, followLinks: false);
    for (final entity in entities) {
      final type = FileSystemEntity.typeSync(entity.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) continue;
      final isDirectory = type == FileSystemEntityType.directory;
      final name = p.basename(entity.path);
      if (isDirectory && _isIgnoredDirectoryName(name)) continue;
      if (!isDirectory && !isMarkdownFileName(name)) continue;

      final child = MarkdownFileTreeEntry(
        rootPath: root,
        path: p.normalize(entity.path),
        name: name,
        isDirectory: isDirectory,
      );
      if (isDirectory) {
        directories.add(child);
      } else {
        files.add(child);
      }
    }

    directories.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );
    files.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return <shadcn.TreeNode<MarkdownFileTreeEntry>>[
      for (final directory in directories)
        shadcn.TreeItem<MarkdownFileTreeEntry>(
          data: directory,
          expanded: false,
          children: const [],
        ),
      for (final file in files)
        shadcn.TreeItem<MarkdownFileTreeEntry>(data: file),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final textTheme = Theme.of(context).textTheme;

    if (widget.rootPaths.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            'Choose a folder to load Markdown files.',
            textAlign: TextAlign.center,
            style: textTheme.bodySmall?.copyWith(color: colors.textMuted),
          ),
        ),
      );
    }

    final tree = shadcn.TreeView<MarkdownFileTreeEntry>(
      nodes: _nodes,
      controller: _scrollController,
      recursiveSelection: false,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      onSelectionChanged: _onSelectionChanged,
      builder: (context, node) {
        final entry = node.data;
        final isLoading = _loadingDirectoryChildren.contains(
          p.normalize(entry.path),
        );
        final itemKey = _itemKeys.putIfAbsent(entry.path, () => GlobalKey());

        final onExpand = entry.isDirectory
            ? (expanded) {
                if (expanded &&
                    node.children.isEmpty &&
                    !_loadedDirectoryChildren.contains(
                      p.normalize(entry.path),
                    )) {
                  unawaited(_ensureChildrenLoaded(entry));
                }
                setState(() {
                  _nodes = shadcn.TreeView.replaceNodes(_nodes, (n) {
                    if (n is! shadcn.TreeItem<MarkdownFileTreeEntry>) {
                      return null;
                    }
                    if (n.data.path != entry.path) return null;
                    if (n.expanded == expanded) return null;
                    return n.updateState(expanded: expanded);
                  });
                });
              }
            : null;

        final onOpenFile = (!entry.isDirectory)
            ? () => widget.onOpenFileRequested?.call(entry.path)
            : null;
        final labelStyle = _treeLabelStyle(
          context,
          directory: entry.isDirectory,
        );
        final trailing = entry.isRoot && widget.onUnloadRoot != null
            ? shadcn.GhostButton(
                density: shadcn.ButtonDensity.iconDense,
                shape: shadcn.ButtonShape.circle,
                onPressed: () => widget.onUnloadRoot!(entry.path),
                child: const shadcn.Icon(shadcn.LucideIcons.x, size: 12.5),
              )
            : (entry.isDirectory && isLoading)
            ? const SizedBox(
                width: 30,
                height: 2,
                child: LinearProgressIndicator(),
              )
            : null;

        final treeItemView = shadcn.TreeItemView(
          leading: null,
          onPressed: entry.isDirectory
              ? () => onExpand?.call(!node.expanded)
              : onOpenFile,
          onDoublePressed: onOpenFile,
          onExpand: onExpand,
          expandable: entry.isDirectory,
          trailing: trailing,
          child: Row(
            children: [
              _MarkdownTreeIcon(
                entry: entry,
                expanded: entry.isDirectory && node.expanded,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  entry.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
            ],
          ),
        );

        return KeyedSubtree(
          key: itemKey,
          child: MouseRegion(
            cursor: entry.isDirectory
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
            onEnter: (_) {
              if (_hoveredPathNotifier.value == entry.path) return;
              _hoveredPathNotifier.value = entry.path;
            },
            onExit: (_) {
              if (_hoveredPathNotifier.value != entry.path) return;
              _hoveredPathNotifier.value = null;
            },
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onSecondaryTapDown: (_) {
                if (!node.selected) {
                  final next = shadcn.TreeView.replaceNodes(_nodes, (n) {
                    if (n is! shadcn.TreeItem<MarkdownFileTreeEntry>) {
                      return null;
                    }
                    final shouldSelect = identical(n, node);
                    if (n.selected == shouldSelect) return null;
                    return n.updateState(selected: shouldSelect);
                  });
                  setState(() => _nodes = next);
                }
              },
              child: shadcn.ContextMenu(
                items: _buildContextMenuItems(entry, onOpen: onOpenFile),
                child: treeItemView,
              ),
            ),
          ),
        );
      },
    );

    return ValueListenableBuilder<String?>(
      valueListenable: _hoveredPathNotifier,
      builder: (context, hoveredPath, child) {
        return shadcn.ContextMenu(
          enabled: hoveredPath == null,
          items: _backgroundMenuItems(),
          child: child!,
        );
      },
      child: tree,
    );
  }

  void _onSelectionChanged(
    List<shadcn.TreeNode<MarkdownFileTreeEntry>> selectedNodes,
    bool multiSelect,
    bool selected,
  ) {
    final selectedPaths = selectedNodes
        .whereType<shadcn.TreeItem<MarkdownFileTreeEntry>>()
        .map((node) => node.data.path)
        .toSet();

    setState(() {
      if (multiSelect) {
        _nodes = shadcn.TreeView.replaceNodes(_nodes, (node) {
          if (node is! shadcn.TreeItem<MarkdownFileTreeEntry>) return null;
          if (!selectedPaths.contains(node.data.path)) return null;
          if (node.selected == selected) return null;
          return node.updateState(selected: selected);
        });
        return;
      }

      _nodes = shadcn.TreeView.replaceNodes(_nodes, (node) {
        if (node is! shadcn.TreeItem<MarkdownFileTreeEntry>) return null;
        final shouldSelect = selectedPaths.contains(node.data.path);
        if (node.selected == shouldSelect) return null;
        return node.updateState(selected: shouldSelect);
      });
    });
  }

  List<shadcn.MenuItem> _buildContextMenuItems(
    MarkdownFileTreeEntry entry, {
    required VoidCallback? onOpen,
  }) {
    return <shadcn.MenuItem>[
      if (!entry.isDirectory)
        shadcn.MenuButton(
          onPressed: onOpen == null
              ? null
              : (popoverContext) {
                  shadcn.closeOverlay(popoverContext);
                  onOpen();
                },
          enabled: onOpen != null,
          trailing: const shadcn.MenuShortcut(
            activator: SingleActivator(LogicalKeyboardKey.enter),
          ),
          child: const Text('Open Markdown'),
        ),
      if (entry.isDirectory)
        shadcn.MenuButton(
          onPressed: (popoverContext) {
            shadcn.closeOverlay(popoverContext);
            unawaited(_refreshDirectoryNode(entry));
            widget.onFileSystemPathsChanged?.call(<String>{entry.path});
          },
          child: const Text('Refresh'),
        ),
      shadcn.MenuButton(
        onPressed: (popoverContext) async {
          shadcn.closeOverlay(popoverContext);
          await Clipboard.setData(ClipboardData(text: entry.path));
        },
        child: const Text('Copy Path'),
      ),
      shadcn.MenuButton(
        onPressed: (popoverContext) async {
          shadcn.closeOverlay(popoverContext);
          final relative = p.relative(entry.path, from: entry.rootPath);
          await Clipboard.setData(ClipboardData(text: relative));
        },
        child: const Text('Copy Relative Path'),
      ),
      if (entry.isRoot && widget.onUnloadRoot != null) ...[
        const shadcn.MenuDivider(),
        shadcn.MenuButton(
          onPressed: (popoverContext) {
            shadcn.closeOverlay(popoverContext);
            widget.onUnloadRoot!(entry.path);
          },
          child: const Text('Unload Folder'),
        ),
      ],
    ];
  }

  List<shadcn.MenuItem> _backgroundMenuItems() {
    if (widget.rootPaths.isEmpty) return const <shadcn.MenuItem>[];
    return <shadcn.MenuItem>[
      for (final root in widget.rootPaths)
        shadcn.MenuButton(
          onPressed: (popoverContext) {
            shadcn.closeOverlay(popoverContext);
            final entry = _findEntryByPath(root);
            if (entry != null) {
              unawaited(_refreshDirectoryNode(entry));
            }
            widget.onFileSystemPathsChanged?.call(<String>{root});
          },
          child: Text(
            widget.rootPaths.length == 1
                ? 'Refresh'
                : 'Refresh ${p.basename(root)}',
          ),
        ),
    ];
  }

  void _applyActiveFileSelection(String? filePath, {bool notify = true}) {
    final selectedPath = filePath?.trim().isEmpty == true ? null : filePath;
    final next = shadcn.TreeView.replaceNodes(_nodes, (node) {
      if (node is! shadcn.TreeItem<MarkdownFileTreeEntry>) return null;
      if (node.data.isDirectory) return null;
      final shouldSelect =
          selectedPath != null && p.equals(node.data.path, selectedPath);
      if (node.selected == shouldSelect) return null;
      return node.updateState(selected: shouldSelect);
    });
    if (!identical(next, _nodes)) {
      if (notify && mounted) {
        setState(() => _nodes = next);
      } else {
        _nodes = next;
      }
    }
  }

  void _revealAndCenter(String filePath) {
    final root = _findRootForPath(filePath);
    if (root == null) return;
    unawaited(_revealAndCenterAsync(root, filePath));
  }

  Future<void> _revealAndCenterAsync(String root, String filePath) async {
    final ancestorPaths = _orderedAncestorDirsForFile(
      rootPath: root,
      filePath: filePath,
    );

    for (final dirPath in ancestorPaths) {
      if (!mounted) return;
      final entry = _findEntryByPath(dirPath);
      final normalized = p.normalize(dirPath);
      if (entry != null &&
          !_loadedDirectoryChildren.contains(normalized) &&
          !_loadingDirectoryChildren.contains(normalized)) {
        await _ensureChildrenLoaded(entry);
      } else if (_loadingDirectoryChildren.contains(normalized)) {
        while (_loadingDirectoryChildren.contains(normalized) && mounted) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
        }
      }

      if (!mounted) return;
      setState(() {
        _nodes = shadcn.TreeView.replaceNodes(_nodes, (node) {
          if (node is! shadcn.TreeItem<MarkdownFileTreeEntry>) return null;
          if (!p.equals(node.data.path, dirPath)) return null;
          if (node.expanded) return null;
          return node.updateState(expanded: true);
        });
      });
    }

    if (!mounted) return;
    _applyActiveFileSelection(filePath);
    _scheduleEnsureVisible(filePath);
  }

  MarkdownFileTreeEntry? _findEntryByPath(String path) {
    MarkdownFileTreeEntry? result;
    void walk(List<shadcn.TreeNode<MarkdownFileTreeEntry>> nodes) {
      for (final node in nodes) {
        if (result != null) return;
        if (node is shadcn.TreeItem<MarkdownFileTreeEntry>) {
          if (p.equals(node.data.path, path)) {
            result = node.data;
            return;
          }
          walk(node.children);
        } else if (node is shadcn.TreeRoot<MarkdownFileTreeEntry>) {
          walk(node.children);
        }
      }
    }

    walk(_nodes);
    return result;
  }

  void _scheduleEnsureVisible(String filePath, {int attempt = 0}) {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || !widget.isVisible) return;
      final key = _itemKeys[filePath];
      final ctx = key?.currentContext;
      if (ctx != null) {
        await Scrollable.ensureVisible(
          ctx,
          alignment: 0.5,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        );
        return;
      }
      if (attempt >= 5) return;
      _scheduleEnsureVisible(filePath, attempt: attempt + 1);
    });
  }

  List<String> _orderedAncestorDirsForFile({
    required String rootPath,
    required String filePath,
  }) {
    final out = <String>[rootPath];
    String rel;
    try {
      rel = p.relative(filePath, from: rootPath);
    } catch (_) {
      return out;
    }
    if (rel.startsWith('..')) return out;
    final parts = p.split(rel);
    if (parts.length <= 1) return out;
    var current = rootPath;
    for (var i = 0; i < parts.length - 1; i++) {
      current = p.join(current, parts[i]);
      out.add(current);
    }
    return out;
  }
}

class _MarkdownTreeIcon extends StatelessWidget {
  const _MarkdownTreeIcon({required this.entry, required this.expanded});

  final MarkdownFileTreeEntry entry;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final icon = entry.isDirectory
        ? expanded
              ? shadcn.LucideIcons.folderOpen
              : shadcn.LucideIcons.folder
        : shadcn.LucideIcons.fileText;
    final color = entry.isDirectory ? colors.textMuted : colors.accent;
    return SizedBox.square(
      dimension: _TreeMetrics.iconSize,
      child: shadcn.Icon(icon, size: _TreeMetrics.iconSize, color: color),
    );
  }
}

TextStyle _treeLabelStyle(BuildContext context, {required bool directory}) {
  final colors = Theme.of(context).extension<AppColors>()!;
  return Theme.of(context).textTheme.bodySmall!.copyWith(
    fontSize: _TreeMetrics.labelFontSize,
    height: 1.2,
    color: colors.text,
    fontWeight: directory ? FontWeight.w500 : FontWeight.normal,
  );
}

void _collectNodeState({
  required List<shadcn.TreeNode<MarkdownFileTreeEntry>> nodes,
  required Map<String, bool> expandedByPath,
  required Map<String, bool> selectedByPath,
}) {
  for (final node in nodes) {
    if (node is shadcn.TreeRoot<MarkdownFileTreeEntry>) {
      _collectNodeState(
        nodes: node.children,
        expandedByPath: expandedByPath,
        selectedByPath: selectedByPath,
      );
      continue;
    }
    if (node is shadcn.TreeItem<MarkdownFileTreeEntry>) {
      expandedByPath[node.data.path] = node.expanded;
      selectedByPath[node.data.path] = node.selected;
      _collectNodeState(
        nodes: node.children,
        expandedByPath: expandedByPath,
        selectedByPath: selectedByPath,
      );
    }
  }
}

List<shadcn.TreeNode<MarkdownFileTreeEntry>> _applyNodeState({
  required List<shadcn.TreeNode<MarkdownFileTreeEntry>> nodes,
  required Map<String, bool> expandedByPath,
  required Map<String, bool> selectedByPath,
}) {
  return shadcn.TreeView.replaceNodes(nodes, (node) {
    if (node is! shadcn.TreeItem<MarkdownFileTreeEntry>) return null;
    final expanded = expandedByPath[node.data.path];
    final selected = selectedByPath[node.data.path];
    if (expanded == null && selected == null) return null;
    return node.updateState(
      expanded: expanded ?? node.expanded,
      selected: selected ?? node.selected,
    );
  });
}

List<shadcn.TreeNode<MarkdownFileTreeEntry>> _buildWorkspaceNodes(
  List<String> rootPaths,
) {
  if (rootPaths.isEmpty) {
    return <shadcn.TreeNode<MarkdownFileTreeEntry>>[
      shadcn.TreeRoot<MarkdownFileTreeEntry>(children: const []),
    ];
  }

  final roots = rootPaths
      .where((root) => root.trim().isNotEmpty)
      .map(p.normalize)
      .toList(growable: false);
  roots.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  return <shadcn.TreeNode<MarkdownFileTreeEntry>>[
    shadcn.TreeRoot<MarkdownFileTreeEntry>(
      children: <shadcn.TreeNode<MarkdownFileTreeEntry>>[
        for (final rootPath in roots)
          shadcn.TreeItem<MarkdownFileTreeEntry>(
            data: MarkdownFileTreeEntry(
              rootPath: rootPath,
              path: rootPath,
              name: p.basename(rootPath).isEmpty
                  ? rootPath
                  : p.basename(rootPath),
              isDirectory: true,
              isRoot: true,
            ),
            expanded: true,
            children: const [],
          ),
      ],
    ),
  ];
}

bool _isIgnoredDirectoryName(String name) {
  return switch (name) {
    '.git' ||
    '.dart_tool' ||
    '.vten' ||
    '.idea' ||
    '.gradle' ||
    'build' ||
    'node_modules' ||
    'Pods' ||
    'DerivedData' => true,
    _ => false,
  };
}

final class _TreeMetrics {
  const _TreeMetrics._();

  static const iconSize = 14.0;
  static const labelFontSize = 13.0;
}
