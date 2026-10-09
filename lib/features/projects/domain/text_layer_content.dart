part of 'layer_content.dart';

enum TextAlignment { left, center, right }

/// Ukuran font dan outline relatif lebar canvas. Font hanya keluarga sistem.
class TextLayerContent extends LayerContent {
  TextLayerContent({
    required this.text,
    this.fontFamily = 'sans-serif',
    this.fontSize = 0.08,
    this.colorArgb = 0xffffffff,
    this.alignment = TextAlignment.center,
    this.outlineColorArgb,
    this.outlineWidth = 0,
  }) {
    if (text.runes.length > 2000 || !fontFamilies.contains(fontFamily)) {
      invalidProject();
    }
    validateNumber(fontSize, 0, 2, positive: true);
    validateColor(colorArgb);
    validateNumber(outlineWidth, 0, 0.25);
    if (outlineColorArgb != null) validateColor(outlineColorArgb!);
    if (outlineWidth > 0 && outlineColorArgb == null) invalidProject();
  }

  static const fontFamilies = {'sans-serif', 'serif', 'monospace'};
  final String text;
  final String fontFamily;
  final double fontSize;
  final int colorArgb;
  final TextAlignment alignment;
  final int? outlineColorArgb;
  final double outlineWidth;
  @override
  String get type => 'text';

  factory TextLayerContent.fromJson(Map<String, dynamic> json) {
    jsonFields(json, {
      'text',
      'fontFamily',
      'fontSize',
      'colorArgb',
      'alignment',
      'outlineColorArgb',
      'outlineWidth',
    });
    return TextLayerContent(
      text: jsonString(json['text']),
      fontFamily: jsonString(json['fontFamily']),
      fontSize: jsonDouble(json['fontSize']),
      colorArgb: jsonInt(json['colorArgb']),
      alignment: jsonEnum(json['alignment'], TextAlignment.values),
      outlineColorArgb: json['outlineColorArgb'] == null
          ? null
          : jsonInt(json['outlineColorArgb']),
      outlineWidth: jsonDouble(json['outlineWidth']),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'text': text,
    'fontFamily': fontFamily,
    'fontSize': fontSize,
    'colorArgb': colorArgb,
    'alignment': alignment.name,
    'outlineColorArgb': outlineColorArgb,
    'outlineWidth': outlineWidth,
  };

  TextLayerContent copyWith({
    String? text,
    String? fontFamily,
    double? fontSize,
    int? colorArgb,
    TextAlignment? alignment,
    int? outlineColorArgb,
    double? outlineWidth,
    bool clearOutline = false,
  }) => TextLayerContent(
    text: text ?? this.text,
    fontFamily: fontFamily ?? this.fontFamily,
    fontSize: fontSize ?? this.fontSize,
    colorArgb: colorArgb ?? this.colorArgb,
    alignment: alignment ?? this.alignment,
    outlineColorArgb: clearOutline
        ? null
        : outlineColorArgb ?? this.outlineColorArgb,
    outlineWidth: clearOutline ? 0 : outlineWidth ?? this.outlineWidth,
  );
}
