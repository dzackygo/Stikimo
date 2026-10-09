import 'project_validation.dart';

/// Crop relatif ke working image sebelum transformasi layer, dalam rentang 0–1.
class NormalizedRect {
  NormalizedRect({this.x = 0, this.y = 0, this.width = 1, this.height = 1}) {
    validateNumber(x, 0, 1);
    validateNumber(y, 0, 1);
    validateNumber(width, 0, 1, positive: true);
    validateNumber(height, 0, 1, positive: true);
    if (x + width > 1.000000000001 || y + height > 1.000000000001) {
      invalidProject();
    }
  }

  final double x;
  final double y;
  final double width;
  final double height;

  factory NormalizedRect.fromJson(Map<String, dynamic> json) {
    jsonFields(json, {'x', 'y', 'width', 'height'});
    return NormalizedRect(
      x: jsonDouble(json['x']),
      y: jsonDouble(json['y']),
      width: jsonDouble(json['width']),
      height: jsonDouble(json['height']),
    );
  }
  Map<String, dynamic> toJson() => {
    'x': x,
    'y': y,
    'width': width,
    'height': height,
  };
  NormalizedRect copyWith({
    double? x,
    double? y,
    double? width,
    double? height,
  }) => NormalizedRect(
    x: x ?? this.x,
    y: y ?? this.y,
    width: width ?? this.width,
    height: height ?? this.height,
  );
}

/// Poin relatif terhadap bidang layer (0–1); transformasi layer diterapkan saat render.
class DrawingPoint {
  DrawingPoint({required this.x, required this.y}) {
    validateNumber(x, 0, 1);
    validateNumber(y, 0, 1);
  }

  final double x;
  final double y;
  factory DrawingPoint.fromJson(Map<String, dynamic> json) {
    jsonFields(json, {'x', 'y'});
    return DrawingPoint(x: jsonDouble(json['x']), y: jsonDouble(json['y']));
  }
  Map<String, dynamic> toJson() => {'x': x, 'y': y};
}
