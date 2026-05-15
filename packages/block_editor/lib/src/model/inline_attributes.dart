library;

import 'package:meta/meta.dart';

@immutable
final class InlineAttributes {
  const InlineAttributes({
    this.bold,
    this.italic,
    this.underline,
    this.strikethrough,
    this.inlineCode,
    this.highlight,
    this.link,
    this.wikiLink,
    this.embed,
    this.footnote,
    this.color,
    this.backgroundColor,
  });

  factory InlineAttributes.fromJson(Map<String, dynamic> json) {
    return InlineAttributes(
      bold: json['bold'] as bool?,
      italic: json['italic'] as bool?,
      underline: json['underline'] as bool?,
      strikethrough: json['strikethrough'] as bool?,
      inlineCode: json['inlineCode'] as bool?,
      highlight: json['highlight'] as bool?,
      link: json['link'] as String?,
      wikiLink: json['wikiLink'] as String?,
      embed: json['embed'] as bool?,
      footnote: json['footnote'] as String?,
      color: json['color'] as String?,
      backgroundColor: json['backgroundColor'] as String?,
    );
  }

  final bool? bold;
  final bool? italic;
  final bool? underline;
  final bool? strikethrough;
  final bool? inlineCode;
  final bool? highlight;
  final String? link;
  final String? wikiLink;
  final bool? embed;
  final String? footnote;
  final String? color;
  final String? backgroundColor;

  bool get isEmpty =>
      bold == null &&
      italic == null &&
      underline == null &&
      strikethrough == null &&
      inlineCode == null &&
      highlight == null &&
      link == null &&
      wikiLink == null &&
      embed == null &&
      footnote == null &&
      color == null &&
      backgroundColor == null;

  Map<String, dynamic> toJson() {
    return {
      if (bold != null) 'bold': bold,
      if (italic != null) 'italic': italic,
      if (underline != null) 'underline': underline,
      if (strikethrough != null) 'strikethrough': strikethrough,
      if (inlineCode != null) 'inlineCode': inlineCode,
      if (highlight != null) 'highlight': highlight,
      if (link != null) 'link': link,
      if (wikiLink != null) 'wikiLink': wikiLink,
      if (embed != null) 'embed': embed,
      if (footnote != null) 'footnote': footnote,
      if (color != null) 'color': color,
      if (backgroundColor != null) 'backgroundColor': backgroundColor,
    };
  }

  InlineAttributes copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    bool? inlineCode,
    bool? highlight,
    String? link,
    String? wikiLink,
    bool? embed,
    String? footnote,
    String? color,
    String? backgroundColor,
  }) {
    return InlineAttributes(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      inlineCode: inlineCode ?? this.inlineCode,
      highlight: highlight ?? this.highlight,
      link: link ?? this.link,
      wikiLink: wikiLink ?? this.wikiLink,
      embed: embed ?? this.embed,
      footnote: footnote ?? this.footnote,
      color: color ?? this.color,
      backgroundColor: backgroundColor ?? this.backgroundColor,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is InlineAttributes &&
        other.bold == bold &&
        other.italic == italic &&
        other.underline == underline &&
        other.strikethrough == strikethrough &&
        other.inlineCode == inlineCode &&
        other.highlight == highlight &&
        other.link == link &&
        other.wikiLink == wikiLink &&
        other.embed == embed &&
        other.footnote == footnote &&
        other.color == color &&
        other.backgroundColor == backgroundColor;
  }

  @override
  int get hashCode => Object.hash(
    bold,
    italic,
    underline,
    strikethrough,
    inlineCode,
    highlight,
    link,
    wikiLink,
    embed,
    footnote,
    color,
    backgroundColor,
  );

  @override
  String toString() => 'InlineAttributes(${toJson()})';
}
