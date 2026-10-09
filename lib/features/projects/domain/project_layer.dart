import 'layer_content.dart';
import 'project_validation.dart';

export 'layer_content.dart';
export 'project_geometry.dart';

/// Posisi/ukuran relatif canvas; lebar/tinggi menyimpan scale, rotasi dalam radian.
/// Layer boleh melewati canvas: pusat dibatasi ±8, ukuran maksimal 16 canvas.
class ProjectLayer {
  ProjectLayer({
    required this.id,
    required this.content,
    this.centerX = 0.5,
    this.centerY = 0.5,
    this.width = 1,
    this.height = 1,
    this.rotation = 0,
    this.isVisible = true,
    this.isLocked = false,
  }) {
    validateProjectId(id);
    validateNumber(centerX, -8, 8);
    validateNumber(centerY, -8, 8);
    validateNumber(width, 0, 16, positive: true);
    validateNumber(height, 0, 16, positive: true);
    validateNumber(rotation, -10000, 10000);
  }

  final String id;
  final LayerContent content;
  final double centerX;
  final double centerY;
  final double width;
  final double height;
  final double rotation;
  final bool isVisible;
  final bool isLocked;
  String get type => content.type;

  factory ProjectLayer.fromJson(Map<String, dynamic> json) {
    jsonFields(json, {
      'id',
      'type',
      'centerX',
      'centerY',
      'width',
      'height',
      'rotation',
      'isVisible',
      'isLocked',
      'content',
    });
    return ProjectLayer(
      id: jsonString(json['id']),
      content: LayerContent.fromJson(
        jsonString(json['type']),
        jsonObject(json['content']),
      ),
      centerX: jsonDouble(json['centerX']),
      centerY: jsonDouble(json['centerY']),
      width: jsonDouble(json['width']),
      height: jsonDouble(json['height']),
      rotation: jsonDouble(json['rotation']),
      isVisible: jsonBool(json['isVisible']),
      isLocked: jsonBool(json['isLocked']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'centerX': centerX,
    'centerY': centerY,
    'width': width,
    'height': height,
    'rotation': rotation,
    'isVisible': isVisible,
    'isLocked': isLocked,
    'content': content.toJson(),
  };

  ProjectLayer copyWith({
    String? id,
    LayerContent? content,
    double? centerX,
    double? centerY,
    double? width,
    double? height,
    double? rotation,
    bool? isVisible,
    bool? isLocked,
  }) => ProjectLayer(
    id: id ?? this.id,
    content: content ?? this.content,
    centerX: centerX ?? this.centerX,
    centerY: centerY ?? this.centerY,
    width: width ?? this.width,
    height: height ?? this.height,
    rotation: rotation ?? this.rotation,
    isVisible: isVisible ?? this.isVisible,
    isLocked: isLocked ?? this.isLocked,
  );
}
