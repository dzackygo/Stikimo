part of 'layer_content.dart';

enum DrawingTool { brush, eraser }

class DrawingLayerContent extends LayerContent {
  DrawingLayerContent({required List<DrawingStroke> strokes})
    : strokes = List.unmodifiable(strokes) {
    if (strokes.length > maxStrokes) invalidProject();
  }

  static const maxStrokes = 2048;
  final List<DrawingStroke> strokes;
  @override
  String get type => 'drawing';

  factory DrawingLayerContent.fromJson(Map<String, dynamic> json) {
    jsonFields(json, {'strokes'});
    return DrawingLayerContent(
      strokes: jsonList(
        json['strokes'],
        maxStrokes,
      ).map((stroke) => DrawingStroke.fromJson(jsonObject(stroke))).toList(),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'strokes': strokes.map((stroke) => stroke.toJson()).toList(),
  };
  DrawingLayerContent copyWith({List<DrawingStroke>? strokes}) =>
      DrawingLayerContent(strokes: strokes ?? this.strokes);
}

/// Lebar brush relatif lebar bidang layer; opacity 0–1. Tidak menyimpan bitmap per event.
class DrawingStroke {
  DrawingStroke({
    required List<DrawingPoint> points,
    required this.colorArgb,
    required this.width,
    this.opacity = 1,
    this.tool = DrawingTool.brush,
  }) : points = List.unmodifiable(points) {
    if (points.isEmpty || points.length > maxPoints) invalidProject();
    validateColor(colorArgb);
    validateNumber(width, 0, 1, positive: true);
    validateNumber(opacity, 0, 1);
  }

  static const maxPoints = 10000;
  final List<DrawingPoint> points;
  final int colorArgb;
  final double width;
  final double opacity;
  final DrawingTool tool;

  factory DrawingStroke.fromJson(Map<String, dynamic> json) {
    jsonFields(json, {'points', 'colorArgb', 'width', 'opacity', 'tool'});
    return DrawingStroke(
      points: jsonList(
        json['points'],
        maxPoints,
      ).map((point) => DrawingPoint.fromJson(jsonObject(point))).toList(),
      colorArgb: jsonInt(json['colorArgb']),
      width: jsonDouble(json['width']),
      opacity: jsonDouble(json['opacity']),
      tool: jsonEnum(json['tool'], DrawingTool.values),
    );
  }
  Map<String, dynamic> toJson() => {
    'points': points.map((point) => point.toJson()).toList(),
    'colorArgb': colorArgb,
    'width': width,
    'opacity': opacity,
    'tool': tool.name,
  };
  DrawingStroke copyWith({
    List<DrawingPoint>? points,
    int? colorArgb,
    double? width,
    double? opacity,
    DrawingTool? tool,
  }) => DrawingStroke(
    points: points ?? this.points,
    colorArgb: colorArgb ?? this.colorArgb,
    width: width ?? this.width,
    opacity: opacity ?? this.opacity,
    tool: tool ?? this.tool,
  );
}
