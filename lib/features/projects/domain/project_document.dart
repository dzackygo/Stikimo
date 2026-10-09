import 'project_asset.dart';
import 'project_layer.dart';
import 'project_validation.dart';

export 'project_asset.dart';
export 'project_layer.dart';
export 'project_failure.dart';

/// Format JSON v1. Urutan [layers] adalah urutan gambar dari bawah ke atas.
/// Batas melindungi memori: 64 layer, 256 aset, 2048 stroke, 100000 poin total.
class ProjectDocument {
  ProjectDocument({
    required this.id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    this.version = 1,
    this.canvasWidth = 512,
    this.canvasHeight = 512,
    required this.sourceAssetId,
    required List<ProjectAsset> assets,
    required List<ProjectLayer> layers,
  }) : name = normalizeProjectName(name),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc(),
       assets = List.unmodifiable(assets),
       layers = List.unmodifiable(layers) {
    validateProjectId(id);
    validateProjectId(sourceAssetId);
    validateProjectDate(this.createdAt);
    validateProjectDate(this.updatedAt);
    if (version != 1 ||
        canvasWidth < 1 ||
        canvasWidth > 8192 ||
        canvasHeight < 1 ||
        canvasHeight > 8192 ||
        this.updatedAt.isBefore(this.createdAt) ||
        assets.isEmpty ||
        assets.length > maxAssets ||
        layers.length > maxLayers) {
      invalidProject();
    }
    final byId = <String, ProjectAsset>{};
    for (final asset in assets) {
      if (byId.containsKey(asset.id)) invalidProject();
      byId[asset.id] = asset;
    }
    if (byId[sourceAssetId]?.role != AssetRole.original) invalidProject();
    final layerIds = <String>{};
    var strokes = 0;
    var points = 0;
    for (final layer in layers) {
      if (!layerIds.add(layer.id)) invalidProject();
      final content = layer.content;
      if (content is ImageLayerContent) {
        final working = byId[content.workingAssetId];
        if (working == null ||
            (working.role != AssetRole.working &&
                working.role != AssetRole.derived)) {
          invalidProject();
        }
        if (content.maskAssetId != null) {
          final mask = byId[content.maskAssetId];
          if (mask == null ||
              mask.role != AssetRole.mask ||
              mask.width != working.width ||
              mask.height != working.height) {
            invalidProject();
          }
        }
      } else if (content is DrawingLayerContent) {
        strokes += content.strokes.length;
        for (final stroke in content.strokes) {
          points += stroke.points.length;
        }
      }
    }
    if (strokes > maxStrokes || points > maxPoints) invalidProject();
  }

  static const maxEncodedBytes = 8 * 1024 * 1024;
  static const maxLayers = 64;
  static const maxAssets = 256;
  static const maxStrokes = 2048;
  static const maxPoints = 100000;

  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int version;
  final int canvasWidth;
  final int canvasHeight;
  final String sourceAssetId;
  final List<ProjectAsset> assets;
  final List<ProjectLayer> layers;

  factory ProjectDocument.fromJson(Map<String, dynamic> json) {
    jsonFields(json, {
      'id',
      'name',
      'createdAt',
      'updatedAt',
      'version',
      'canvasWidth',
      'canvasHeight',
      'sourceAssetId',
      'assets',
      'layers',
    });
    return ProjectDocument(
      id: jsonString(json['id']),
      name: jsonString(json['name']),
      createdAt: jsonDate(json['createdAt']),
      updatedAt: jsonDate(json['updatedAt']),
      version: jsonInt(json['version']),
      canvasWidth: jsonInt(json['canvasWidth']),
      canvasHeight: jsonInt(json['canvasHeight']),
      sourceAssetId: jsonString(json['sourceAssetId']),
      assets: jsonList(
        json['assets'],
        maxAssets,
      ).map((asset) => ProjectAsset.fromJson(jsonObject(asset))).toList(),
      layers: jsonList(
        json['layers'],
        maxLayers,
      ).map((layer) => ProjectLayer.fromJson(jsonObject(layer))).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
    'updatedAt': updatedAt.toIso8601String(),
    'canvasWidth': canvasWidth,
    'canvasHeight': canvasHeight,
    'sourceAssetId': sourceAssetId,
    'assets': assets.map((asset) => asset.toJson()).toList(),
    'layers': layers.map((layer) => layer.toJson()).toList(),
  };

  ProjectDocument copyWith({
    String? id,
    String? name,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? version,
    int? canvasWidth,
    int? canvasHeight,
    String? sourceAssetId,
    List<ProjectAsset>? assets,
    List<ProjectLayer>? layers,
  }) => ProjectDocument(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    version: version ?? this.version,
    canvasWidth: canvasWidth ?? this.canvasWidth,
    canvasHeight: canvasHeight ?? this.canvasHeight,
    sourceAssetId: sourceAssetId ?? this.sourceAssetId,
    assets: assets ?? this.assets,
    layers: layers ?? this.layers,
  );
}

class SavedProject {
  SavedProject({required this.document, required this.revisionId}) {
    validateProjectId(revisionId);
  }
  final ProjectDocument document;
  final String revisionId;
}

class ProjectSummary {
  ProjectSummary({
    required this.id,
    required String name,
    required DateTime createdAt,
    required DateTime updatedAt,
    required this.revisionId,
  }) : name = normalizeProjectName(name),
       createdAt = createdAt.toUtc(),
       updatedAt = updatedAt.toUtc() {
    validateProjectId(id);
    validateProjectId(revisionId);
    validateProjectDate(this.createdAt);
    validateProjectDate(this.updatedAt);
    if (this.updatedAt.isBefore(this.createdAt)) invalidProject();
  }
  final String id;
  final String name;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String revisionId;
}
