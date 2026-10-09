part of 'layer_content.dart';

class ImageLayerContent extends LayerContent {
  ImageLayerContent({
    required this.workingAssetId,
    this.maskAssetId,
    NormalizedRect? crop,
    this.flipX = false,
    this.flipY = false,
    this.backgroundRemoval,
  }) : crop = crop ?? NormalizedRect() {
    validateProjectId(workingAssetId);
    if (maskAssetId != null) validateProjectId(maskAssetId!);
  }

  final String workingAssetId;
  final String? maskAssetId;
  final NormalizedRect crop;
  final bool flipX;
  final bool flipY;
  final BackgroundRemovalParameters? backgroundRemoval;
  @override
  String get type => 'image';

  factory ImageLayerContent.fromJson(Map<String, dynamic> json) {
    jsonFields(json, {
      'workingAssetId',
      'maskAssetId',
      'crop',
      'flipX',
      'flipY',
      'backgroundRemoval',
    });
    return ImageLayerContent(
      workingAssetId: jsonString(json['workingAssetId']),
      maskAssetId: json['maskAssetId'] == null
          ? null
          : jsonString(json['maskAssetId']),
      crop: NormalizedRect.fromJson(jsonObject(json['crop'])),
      flipX: jsonBool(json['flipX']),
      flipY: jsonBool(json['flipY']),
      backgroundRemoval: json['backgroundRemoval'] == null
          ? null
          : BackgroundRemovalParameters.fromJson(
              jsonObject(json['backgroundRemoval']),
            ),
    );
  }
  @override
  Map<String, dynamic> toJson() => {
    'workingAssetId': workingAssetId,
    'maskAssetId': maskAssetId,
    'crop': crop.toJson(),
    'flipX': flipX,
    'flipY': flipY,
    'backgroundRemoval': backgroundRemoval?.toJson(),
  };

  ImageLayerContent copyWith({
    String? workingAssetId,
    String? maskAssetId,
    NormalizedRect? crop,
    bool? flipX,
    bool? flipY,
    BackgroundRemovalParameters? backgroundRemoval,
    bool clearMask = false,
    bool clearBackgroundRemoval = false,
  }) => ImageLayerContent(
    workingAssetId: workingAssetId ?? this.workingAssetId,
    maskAssetId: clearMask ? null : maskAssetId ?? this.maskAssetId,
    crop: crop ?? this.crop,
    flipX: flipX ?? this.flipX,
    flipY: flipY ?? this.flipY,
    backgroundRemoval: clearBackgroundRemoval
        ? null
        : backgroundRemoval ?? this.backgroundRemoval,
  );
}

/// Paramater color-key v1. Tolerance/softness dinormalisasi dalam rentang 0–1.
class BackgroundRemovalParameters {
  BackgroundRemovalParameters({
    this.algorithmVersion = 1,
    required this.colorArgb,
    required this.tolerance,
    this.softness = 0,
    this.edgeConnectedOnly = true,
  }) {
    if (algorithmVersion != 1) invalidProject();
    validateColor(colorArgb);
    validateNumber(tolerance, 0, 1);
    validateNumber(softness, 0, 1);
  }

  final int algorithmVersion;
  final int colorArgb;
  final double tolerance;
  final double softness;
  final bool edgeConnectedOnly;

  factory BackgroundRemovalParameters.fromJson(Map<String, dynamic> json) {
    jsonFields(json, {
      'algorithmVersion',
      'colorArgb',
      'tolerance',
      'softness',
      'edgeConnectedOnly',
    });
    return BackgroundRemovalParameters(
      algorithmVersion: jsonInt(json['algorithmVersion']),
      colorArgb: jsonInt(json['colorArgb']),
      tolerance: jsonDouble(json['tolerance']),
      softness: jsonDouble(json['softness']),
      edgeConnectedOnly: jsonBool(json['edgeConnectedOnly']),
    );
  }
  Map<String, dynamic> toJson() => {
    'algorithmVersion': algorithmVersion,
    'colorArgb': colorArgb,
    'tolerance': tolerance,
    'softness': softness,
    'edgeConnectedOnly': edgeConnectedOnly,
  };
  BackgroundRemovalParameters copyWith({
    int? colorArgb,
    double? tolerance,
    double? softness,
    bool? edgeConnectedOnly,
  }) => BackgroundRemovalParameters(
    algorithmVersion: algorithmVersion,
    colorArgb: colorArgb ?? this.colorArgb,
    tolerance: tolerance ?? this.tolerance,
    softness: softness ?? this.softness,
    edgeConnectedOnly: edgeConnectedOnly ?? this.edgeConnectedOnly,
  );
}
