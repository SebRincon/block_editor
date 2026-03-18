library;

import 'package:meta/meta.dart';

import 'inline_attributes.dart';

@immutable
sealed class DeltaOp {
  const DeltaOp();

  factory DeltaOp.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    return switch (type) {
      'text' => TextOp.fromJson(json),
      _ => throw FormatException('Unknown DeltaOp type: $type', json),
    };
  }

  Map<String, dynamic> toJson();
}

@immutable
final class TextOp extends DeltaOp {
  const TextOp(this.text, {InlineAttributes? attributes})
    : attributes = attributes ?? const InlineAttributes();

  factory TextOp.fromJson(Map<String, dynamic> json) {
    return TextOp(
      json['text'] as String,
      attributes: json['attributes'] != null
          ? InlineAttributes.fromJson(
              json['attributes'] as Map<String, dynamic>,
            )
          : null,
    );
  }

  final String text;
  final InlineAttributes attributes;

  TextOp copyWith({String? text, InlineAttributes? attributes}) {
    return TextOp(text ?? this.text, attributes: attributes ?? this.attributes);
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'type': 'text',
      'text': text,
      if (!attributes.isEmpty) 'attributes': attributes.toJson(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TextOp &&
        other.text == text &&
        other.attributes == attributes;
  }

  @override
  int get hashCode => Object.hash(text, attributes);

  @override
  String toString() => 'TextOp("$text", $attributes)';
}
