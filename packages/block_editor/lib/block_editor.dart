/// A Notion-inspired, block-based rich text editor built entirely from
/// scratch in Flutter/Dart.
///
/// Phase 1 exports cover the pure-Dart document model and core engine.
/// Phase 2 adds the [EditorSelection] model for cross-block selection.
/// No Flutter imports are present in this layer.
library;

import 'package:block_editor/block_editor.dart';

export 'src/model/inline_attributes.dart';
export 'src/model/delta_op.dart';
export 'src/model/text_delta.dart';
export 'src/model/block_node.dart';
export 'src/model/block_document.dart';
export 'src/controller/block_controller.dart';
export 'src/model/block_types.dart';
export 'src/model/editor_selection.dart';
export 'src/rendering/rich_text_renderer.dart';
export 'src/rendering/block_event.dart';
export 'src/rendering/block_widgets.dart';
export 'src/rendering/block_renderer.dart';
export 'src/rendering/block_cursor.dart';
export 'src/rendering/block_selection_overlay.dart';
export 'src/rendering/block_editor_widget.dart';
export 'src/editing/editor_editing_operations.dart';
export 'src/rendering/block_drag_handle.dart';
