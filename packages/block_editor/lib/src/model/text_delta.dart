library;

import 'package:meta/meta.dart';

import 'delta_op.dart';
import 'inline_attributes.dart';

@immutable
final class TextDelta {
  TextDelta(List<DeltaOp> ops) : ops = _normalize(ops);

  TextDelta.empty() : ops = const [];

  TextDelta.fromPlainText(String text)
    : ops = text.isEmpty ? const [] : [TextOp(text)];

  factory TextDelta.fromJson(List<dynamic> json) {
    final ops = json
        .map((e) => DeltaOp.fromJson(e as Map<String, dynamic>))
        .toList();
    return TextDelta(_normalize(ops));
  }

  final List<DeltaOp> ops;

  String get plainText {
    final buffer = StringBuffer();
    for (final op in ops) {
      if (op is TextOp) buffer.write(op.text);
    }
    return buffer.toString();
  }

  bool get isEmpty => ops.isEmpty;
  bool get isNotEmpty => ops.isNotEmpty;

  TextDelta append(DeltaOp op) => TextDelta(_normalize([...ops, op]));

  TextDelta concat(TextDelta other) =>
      TextDelta(_normalize([...ops, ...other.ops]));

  TextDelta applyAttributes(int start, int end, InlineAttributes attributes) {
    assert(start >= 0 && end >= start, 'Invalid range [$start, $end)');
    final result = <DeltaOp>[];
    var cursor = 0;

    for (final op in ops) {
      if (op is! TextOp) {
        result.add(op);
        continue;
      }
      final opStart = cursor;
      final opEnd = cursor + op.text.length;
      cursor = opEnd;

      if (opEnd <= start || opStart >= end) {
        result.add(op);
        continue;
      }

      final before = op.text.substring(
        0,
        (start - opStart).clamp(0, op.text.length),
      );
      final inside = op.text.substring(
        (start - opStart).clamp(0, op.text.length),
        (end - opStart).clamp(0, op.text.length),
      );
      final after = op.text.substring((end - opStart).clamp(0, op.text.length));

      if (before.isNotEmpty) {
        result.add(TextOp(before, attributes: op.attributes));
      }
      if (inside.isNotEmpty) {
        result.add(
          TextOp(
            inside,
            attributes: op.attributes.copyWith(
              bold: attributes.bold ?? op.attributes.bold,
              italic: attributes.italic ?? op.attributes.italic,
              underline: attributes.underline ?? op.attributes.underline,
              strikethrough:
                  attributes.strikethrough ?? op.attributes.strikethrough,
              inlineCode: attributes.inlineCode ?? op.attributes.inlineCode,
              link: attributes.link ?? op.attributes.link,
              color: attributes.color ?? op.attributes.color,
              backgroundColor:
                  attributes.backgroundColor ?? op.attributes.backgroundColor,
            ),
          ),
        );
      }
      if (after.isNotEmpty) {
        result.add(TextOp(after, attributes: op.attributes));
      }
    }

    return TextDelta(_normalize(result));
  }

  TextDelta slice(int start, int end) {
    assert(start >= 0 && end >= start, 'Invalid range [$start, $end)');
    final result = <DeltaOp>[];
    var cursor = 0;

    for (final op in ops) {
      if (op is! TextOp) {
        cursor++;
        continue;
      }
      final opStart = cursor;
      final opEnd = cursor + op.text.length;
      cursor = opEnd;

      if (opEnd <= start || opStart >= end) continue;

      final sliceStart = (start - opStart).clamp(0, op.text.length);
      final sliceEnd = (end - opStart).clamp(0, op.text.length);
      result.add(
        TextOp(
          op.text.substring(sliceStart, sliceEnd),
          attributes: op.attributes,
        ),
      );
    }

    return TextDelta(_normalize(result));
  }

  List<Map<String, dynamic>> toJson() => ops.map((op) => op.toJson()).toList();

  static List<DeltaOp> _normalize(List<DeltaOp> ops) {
    final result = <DeltaOp>[];
    for (final op in ops) {
      if (op is TextOp && op.text.isEmpty) continue;
      if (result.isNotEmpty && result.last is TextOp && op is TextOp) {
        final prev = result.last as TextOp;
        if (prev.attributes == op.attributes) {
          result[result.length - 1] = TextOp(
            prev.text + op.text,
            attributes: prev.attributes,
          );
          continue;
        }
      }
      result.add(op);
    }
    return List.unmodifiable(result);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! TextDelta || other.ops.length != ops.length) return false;
    for (var i = 0; i < ops.length; i++) {
      if (ops[i] != other.ops[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(ops);

  @override
  String toString() => 'TextDelta(${ops.length} ops: "$plainText")';
}
