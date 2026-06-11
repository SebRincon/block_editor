import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;

import '../storage/vten_storage_paths.dart';

/// Persisted workspace shell state for the markdown editor demo.
final class MarkdownWorkspaceSnapshot {
  const MarkdownWorkspaceSnapshot({
    this.rootPath,
    this.activeFilePath,
    this.recentRoots = const <String>[],
  });

  final String? rootPath;
  final String? activeFilePath;
  final List<String> recentRoots;

  factory MarkdownWorkspaceSnapshot.fromJson(Map<String, Object?> json) {
    final recent = json['recentRoots'];
    return MarkdownWorkspaceSnapshot(
      rootPath: _cleanPath(json['rootPath']),
      activeFilePath: _cleanPath(json['activeFilePath']),
      recentRoots: recent is List
          ? recent.whereType<String>().map(p.normalize).toList(growable: false)
          : const <String>[],
    );
  }

  Map<String, Object?> toJson() {
    return <String, Object?>{
      'schemaVersion': 1,
      'rootPath': rootPath,
      'activeFilePath': activeFilePath,
      'recentRoots': recentRoots,
    };
  }

  static String? _cleanPath(Object? value) {
    final path = value?.toString().trim();
    if (path == null || path.isEmpty) return null;
    return p.normalize(path);
  }
}

/// Stores demo workspace state under `.vten`.
final class MarkdownWorkspaceStateStore {
  MarkdownWorkspaceStateStore({Directory? rootDirectory})
    : _rootDirectory = rootDirectory;

  final Directory? _rootDirectory;

  Future<MarkdownWorkspaceSnapshot?> load() async {
    try {
      final file = await _stateFile();
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      return MarkdownWorkspaceSnapshot.fromJson(decoded);
    } on FileSystemException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<void> save(MarkdownWorkspaceSnapshot snapshot) async {
    try {
      final file = await _stateFile();
      await file.parent.create(recursive: true);
      const encoder = JsonEncoder.withIndent('  ');
      await file.writeAsString('${encoder.convert(snapshot.toJson())}\n');
    } on FileSystemException {
      // Recent-workspace state is convenience-only; the picker remains usable.
    }
  }

  Future<File> _stateFile() async {
    final root =
        _rootDirectory ?? await VtenStoragePaths.resolveBlockEditorRoot();
    return File(
      VtenStoragePaths.joinAll([
        root.path,
        '.vten',
        'block_editor',
        'workspace_state.json',
      ]),
    );
  }
}

/// Directory picker abstraction so tests do not need the platform plugin.
abstract interface class MarkdownDirectoryPicker {
  Future<String?> pickDirectory({String? initialDirectory});
}

/// File-picker backed workspace directory picker.
final class FilePickerMarkdownDirectoryPicker
    implements MarkdownDirectoryPicker {
  const FilePickerMarkdownDirectoryPicker();

  @override
  Future<String?> pickDirectory({String? initialDirectory}) {
    return FilePicker.platform.getDirectoryPath(
      dialogTitle: 'Open Markdown Workspace',
      initialDirectory: initialDirectory,
    );
  }
}

/// Runtime state for the markdown workspace demo.
final class MarkdownWorkspaceState {
  const MarkdownWorkspaceState({
    this.rootPath,
    this.recentRoots = const <String>[],
    this.activeFilePath,
    this.activeMarkdown,
    this.documentRevision = 0,
    this.isLoading = false,
    this.isSaving = false,
    this.isDirty = false,
    this.error,
  });

  final String? rootPath;
  final List<String> recentRoots;
  final String? activeFilePath;
  final String? activeMarkdown;
  final int documentRevision;
  final bool isLoading;
  final bool isSaving;
  final bool isDirty;
  final String? error;

  bool get hasWorkspace => rootPath != null && rootPath!.trim().isNotEmpty;

  bool get hasActiveFile =>
      activeFilePath != null && activeFilePath!.trim().isNotEmpty;

  String? get activeFileName =>
      activeFilePath == null ? null : p.basename(activeFilePath!);

  String? get activeRelativePath {
    final root = rootPath;
    final file = activeFilePath;
    if (root == null || file == null) return file;
    if (!(p.equals(root, file) || p.isWithin(root, file))) return file;
    return p.relative(file, from: root);
  }

  MarkdownWorkspaceState copyWith({
    Object? rootPath = _unset,
    List<String>? recentRoots,
    Object? activeFilePath = _unset,
    Object? activeMarkdown = _unset,
    int? documentRevision,
    bool? isLoading,
    bool? isSaving,
    bool? isDirty,
    Object? error = _unset,
  }) {
    return MarkdownWorkspaceState(
      rootPath: identical(rootPath, _unset)
          ? this.rootPath
          : rootPath as String?,
      recentRoots: recentRoots ?? this.recentRoots,
      activeFilePath: identical(activeFilePath, _unset)
          ? this.activeFilePath
          : activeFilePath as String?,
      activeMarkdown: identical(activeMarkdown, _unset)
          ? this.activeMarkdown
          : activeMarkdown as String?,
      documentRevision: documentRevision ?? this.documentRevision,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      isDirty: isDirty ?? this.isDirty,
      error: identical(error, _unset) ? this.error : error as String?,
    );
  }

  static const Object _unset = Object();
}

/// Owns workspace selection, markdown file loading, and disk writes.
final class MarkdownWorkspaceController extends ChangeNotifier {
  MarkdownWorkspaceController({
    MarkdownDirectoryPicker? picker,
    MarkdownWorkspaceStateStore? store,
  }) : _picker = picker ?? const FilePickerMarkdownDirectoryPicker(),
       _store = store ?? MarkdownWorkspaceStateStore();

  static const _maxRecentRoots = 10;

  final MarkdownDirectoryPicker _picker;
  final MarkdownWorkspaceStateStore _store;

  MarkdownWorkspaceState _state = const MarkdownWorkspaceState();
  bool _loadedInitialState = false;

  MarkdownWorkspaceState get state => _state;

  Future<void> loadLastWorkspace() async {
    if (_loadedInitialState) return;
    _loadedInitialState = true;

    final snapshot = await _store.load();
    if (snapshot == null) return;
    final recent = _normalizeRecentRoots(snapshot.recentRoots);
    _setState(_state.copyWith(recentRoots: recent));

    final root = snapshot.rootPath;
    if (root == null || root.isEmpty) return;
    await openWorkspace(root, persist: false, clearActiveFile: false);

    final activeFile = snapshot.activeFilePath;
    if (activeFile != null && isMarkdownPath(activeFile)) {
      final file = File(activeFile);
      if (await file.exists()) {
        await openMarkdownFile(activeFile, persistWorkspace: false);
      }
    }
  }

  Future<void> pickWorkspace() async {
    final initialDirectory = await _pickerInitialDirectory();
    _setState(_state.copyWith(isLoading: true, error: null));

    try {
      final selectedPath = await _pickDirectoryWithFallback(
        initialDirectory: initialDirectory,
      );
      if (selectedPath == null || selectedPath.trim().isEmpty) {
        _setState(_state.copyWith(isLoading: false, error: null));
        return;
      }
      await openWorkspace(selectedPath);
    } on PlatformException catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          error: error.message ?? error.toString(),
        ),
      );
    } on Object catch (error) {
      _setState(_state.copyWith(isLoading: false, error: error.toString()));
    }
  }

  Future<void> openWorkspace(
    String path, {
    bool persist = true,
    bool clearActiveFile = true,
  }) async {
    final normalized = p.normalize(path.trim());
    if (normalized.isEmpty) return;

    _setState(_state.copyWith(isLoading: true, error: null));

    final directory = Directory(normalized);
    if (!await directory.exists()) {
      _setState(
        _state.copyWith(
          isLoading: false,
          error: 'Folder not found: $normalized',
        ),
      );
      return;
    }

    final recentRoots = _withRecentRoot(normalized, _state.recentRoots);
    _setState(
      _state.copyWith(
        rootPath: normalized,
        recentRoots: recentRoots,
        activeFilePath: clearActiveFile ? null : _state.activeFilePath,
        activeMarkdown: clearActiveFile ? null : _state.activeMarkdown,
        isLoading: false,
        isDirty: false,
        error: null,
      ),
    );

    if (persist) await _persistSnapshot();
  }

  Future<void> openMarkdownFile(
    String filePath, {
    bool persistWorkspace = true,
  }) async {
    final normalized = p.normalize(filePath.trim());
    if (!isMarkdownPath(normalized)) {
      _setState(
        _state.copyWith(
          error: 'Not a Markdown file: ${p.basename(normalized)}',
        ),
      );
      return;
    }

    final file = File(normalized);
    _setState(_state.copyWith(isLoading: true, error: null));

    try {
      if (!await file.exists()) {
        _setState(
          _state.copyWith(
            isLoading: false,
            error: 'File not found: $normalized',
          ),
        );
        return;
      }

      final markdown = await file.readAsString();
      final root = _rootForFile(normalized);
      final recentRoots = root == null
          ? _state.recentRoots
          : _withRecentRoot(root, _state.recentRoots);
      _setState(
        _state.copyWith(
          rootPath: root ?? _state.rootPath,
          recentRoots: recentRoots,
          activeFilePath: normalized,
          activeMarkdown: markdown,
          documentRevision: _state.documentRevision + 1,
          isLoading: false,
          isSaving: false,
          isDirty: false,
          error: null,
        ),
      );

      if (persistWorkspace) await _persistSnapshot();
    } on FileSystemException catch (error) {
      _setState(
        _state.copyWith(
          isLoading: false,
          error: error.message.isEmpty ? error.toString() : error.message,
        ),
      );
    }
  }

  void markActiveDirty() {
    if (!_state.hasActiveFile || _state.isDirty) return;
    _setState(_state.copyWith(isDirty: true));
  }

  Future<void> saveActiveMarkdown(String markdown) async {
    final filePath = _state.activeFilePath;
    if (filePath == null || filePath.trim().isEmpty) return;

    _setState(_state.copyWith(isSaving: true, error: null));
    try {
      final file = File(filePath);
      await file.parent.create(recursive: true);
      await file.writeAsString(markdown);
      _setState(
        _state.copyWith(
          activeMarkdown: markdown,
          isSaving: false,
          isDirty: false,
          error: null,
        ),
      );
      await _persistSnapshot();
    } on FileSystemException catch (error) {
      _setState(
        _state.copyWith(
          isSaving: false,
          error: error.message.isEmpty ? error.toString() : error.message,
        ),
      );
    }
  }

  Future<void> clearWorkspace() async {
    _setState(
      _state.copyWith(
        rootPath: null,
        activeFilePath: null,
        activeMarkdown: null,
        documentRevision: _state.documentRevision + 1,
        isLoading: false,
        isSaving: false,
        isDirty: false,
        error: null,
      ),
    );
    await _persistSnapshot();
  }

  Future<String?> _pickerInitialDirectory() async {
    final rootPath = _state.rootPath?.trim();
    if (rootPath == null || rootPath.isEmpty) return null;
    final normalized = p.normalize(rootPath);
    if (await Directory(normalized).exists()) return normalized;
    return null;
  }

  Future<String?> _pickDirectoryWithFallback({
    required String? initialDirectory,
  }) async {
    try {
      return await _picker.pickDirectory(initialDirectory: initialDirectory);
    } on PlatformException {
      if (initialDirectory == null) rethrow;
      return _picker.pickDirectory();
    }
  }

  String? _rootForFile(String filePath) {
    final root = _state.rootPath;
    if (root != null &&
        (p.equals(root, filePath) || p.isWithin(root, filePath))) {
      return root;
    }
    return p.dirname(filePath);
  }

  List<String> _withRecentRoot(String rootPath, List<String> currentRoots) {
    final normalizedRoot = p.normalize(rootPath);
    return _normalizeRecentRoots([
      normalizedRoot,
      ...currentRoots.where((path) => p.normalize(path) != normalizedRoot),
    ]);
  }

  List<String> _normalizeRecentRoots(List<String> roots) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final root in roots) {
      final path = p.normalize(root.trim());
      if (path.isEmpty || !seen.add(path)) continue;
      normalized.add(path);
      if (normalized.length >= _maxRecentRoots) break;
    }
    return normalized;
  }

  Future<void> _persistSnapshot() {
    return _store.save(
      MarkdownWorkspaceSnapshot(
        rootPath: _state.rootPath,
        activeFilePath: _state.activeFilePath,
        recentRoots: _state.recentRoots,
      ),
    );
  }

  void _setState(MarkdownWorkspaceState next) {
    _state = next;
    notifyListeners();
  }

  /// Returns true for Markdown files the demo can open as block documents.
  static bool isMarkdownPath(String filePath) => isMarkdownFileName(filePath);
}

/// Returns true for Markdown file names supported by the demo.
bool isMarkdownFileName(String filePath) {
  final extension = p.extension(filePath).toLowerCase();
  return extension == '.md' ||
      extension == '.markdown' ||
      extension == '.mdown';
}
