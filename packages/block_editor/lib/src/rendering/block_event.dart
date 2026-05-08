library;

import 'dart:ui' show TextAffinity;

import 'package:block_editor/block_editor.dart';

/// The base class for all events emitted by block widgets.
///
/// Every block widget communicates user interactions upward by emitting a
/// [BlockEvent] subtype through its callback. [BlockEditorWidget] is the
/// single dispatch point that translates [BlockEvent] instances into
/// [BlockController] mutations. No block widget ever imports
/// [BlockController] directly.
sealed class BlockEvent {
  const BlockEvent({required this.blockId});

  /// The id of the block that produced this event.
  final String blockId;
}

/// Emitted when the user taps inside a text block.
///
/// [offset] is the character offset within the block's [TextDelta] nearest
/// to the tap position. A value of -1 indicates the tap position could not
/// be resolved to a character offset.
final class TapEvent extends BlockEvent {
  /// Creates a [TapEvent] for the block identified by [blockId] at [offset].
  const TapEvent({
    required super.blockId,
    required this.offset,
    this.affinity = TextAffinity.downstream,
  });

  /// The character offset nearest to the tap position.
  final int offset;

  /// Which visual side of a soft-wrap boundary the tap resolved to.
  final TextAffinity affinity;
}

/// Emitted when the user taps the checkbox of a [TodoBlock].
///
/// [checked] is the new value after the toggle — true if the todo is now
/// checked, false if it is now unchecked.
final class CheckboxToggledEvent extends BlockEvent {
  /// Creates a [CheckboxToggledEvent] for the block identified by [blockId].
  const CheckboxToggledEvent({required super.blockId, required this.checked});

  /// The new checked state after the toggle.
  final bool checked;
}

/// Emitted when an editable Markdown table cell changes.
final class TableCellChangedEvent extends BlockEvent {
  /// Creates a [TableCellChangedEvent] for the table identified by [blockId].
  const TableCellChangedEvent({
    required super.blockId,
    required this.header,
    required this.rowIndex,
    required this.columnIndex,
    required this.text,
  });

  /// Whether the edited cell belongs to the table header row.
  final bool header;

  /// The body row index, or -1 when [header] is true.
  final int rowIndex;

  /// The edited column index.
  final int columnIndex;

  /// The new raw Markdown text for the cell.
  final String text;
}

/// Emitted when the user requests a new Markdown table row.
final class TableRowInsertedEvent extends BlockEvent {
  /// Creates a [TableRowInsertedEvent] for the table identified by [blockId].
  const TableRowInsertedEvent({required super.blockId, required this.index});

  /// The body row insertion index.
  final int index;
}

/// Emitted when the user requests a new Markdown table column.
final class TableColumnInsertedEvent extends BlockEvent {
  /// Creates a [TableColumnInsertedEvent] for the table identified by [blockId].
  const TableColumnInsertedEvent({required super.blockId, required this.index});

  /// The column insertion index.
  final int index;
}

/// Emitted when the user requests a Markdown table row deletion.
final class TableRowDeletedEvent extends BlockEvent {
  /// Creates a [TableRowDeletedEvent] for the table identified by [blockId].
  const TableRowDeletedEvent({required super.blockId, required this.index});

  /// The body row deletion index.
  final int index;
}

/// Emitted when the user requests a Markdown table column deletion.
final class TableColumnDeletedEvent extends BlockEvent {
  /// Creates a [TableColumnDeletedEvent] for the table identified by [blockId].
  const TableColumnDeletedEvent({required super.blockId, required this.index});

  /// The column deletion index.
  final int index;
}

/// Emitted when the user drags a block to a new position.
///
/// [newIndex] is the target index in the root block list after the move.
final class BlockReorderedEvent extends BlockEvent {
  /// Creates a [BlockReorderedEvent] for the block identified by [blockId].
  const BlockReorderedEvent({required super.blockId, required this.newIndex});

  /// The target index in the root block list.
  final int newIndex;
}

/// Wraps an opaque interaction payload from a third-party block plugin.
///
/// [CustomBlockEvent] is the sole extensibility point in the [BlockEvent]
/// hierarchy. A plugin author constructs a [CustomBlockEvent] inside their
/// [BlockPlugin.build] implementation and passes it to the onEvent callback
/// they receive. [BlockEditorWidget] dispatches it to the consumer-supplied
/// [BlockEditorWidget.onCustomEvent] handler without touching [BlockController].
final class CustomBlockEvent extends BlockEvent {
  /// Creates a [CustomBlockEvent] for the block identified by [blockId].
  ///
  /// [eventType] is a developer-defined string that distinguishes between
  /// different interaction kinds within the same plugin.
  ///
  /// [payload] is any Dart value the plugin author wishes to transport to
  /// the host app. The editor treats it as fully opaque.
  const CustomBlockEvent({
    required super.blockId,
    required this.eventType,
    this.payload,
  });

  /// A developer-defined string identifying the kind of interaction.
  final String eventType;

  /// An opaque value carrying interaction data to the host app.
  ///
  /// May be null when the event type alone conveys sufficient information.
  final Object? payload;
}
