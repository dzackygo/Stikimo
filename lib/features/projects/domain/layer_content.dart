import 'project_geometry.dart';
import 'project_validation.dart';

part 'image_layer_content.dart';
part 'text_layer_content.dart';
part 'drawing_layer_content.dart';

/// Payload bertipe menjamin field/asset reference tersimpan tanpa map bebas.
sealed class LayerContent {
  const LayerContent();
  String get type;
  Map<String, dynamic> toJson();

  static LayerContent fromJson(String type, Map<String, dynamic> json) =>
      switch (type) {
        'image' => ImageLayerContent.fromJson(json),
        'text' => TextLayerContent.fromJson(json),
        'drawing' => DrawingLayerContent.fromJson(json),
        _ => invalidProject(),
      };
}
