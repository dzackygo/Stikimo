import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:stikimo/features/projects/domain/project_document.dart';

const projectId = '10000000-0000-4000-8000-000000000001';
const originalId = '20000000-0000-4000-8000-000000000001';
const workingId = '20000000-0000-4000-8000-000000000002';
const maskId = '20000000-0000-4000-8000-000000000003';

Map<String, dynamic> documentJson() => {
  'version': 1,
  'id': projectId,
  'name': 'Kucing lokal',
  'createdAt': '2026-10-09T01:00:00.000Z',
  'updatedAt': '2026-10-09T02:00:00.000Z',
  'canvasWidth': 512,
  'canvasHeight': 512,
  'sourceAssetId': originalId,
  'assets': [
    {
      'id': originalId,
      'role': 'original',
      'byteLength': 120,
      'width': null,
      'height': null,
    },
    {
      'id': workingId,
      'role': 'working',
      'byteLength': 140,
      'width': 40,
      'height': 20,
    },
    {'id': maskId, 'role': 'mask', 'byteLength': 80, 'width': 40, 'height': 20},
  ],
  'layers': [
    {
      'id': '30000000-0000-4000-8000-000000000001',
      'type': 'image',
      'centerX': -0.1,
      'centerY': 0.4,
      'width': 0.8,
      'height': 0.4,
      'rotation': 0.25,
      'isVisible': true,
      'isLocked': true,
      'content': {
        'workingAssetId': workingId,
        'maskAssetId': maskId,
        'crop': {'x': 0.1, 'y': 0.2, 'width': 0.8, 'height': 0.7},
        'flipX': true,
        'flipY': false,
        'backgroundRemoval': {
          'algorithmVersion': 1,
          'colorArgb': 4278255360,
          'tolerance': 0.2,
          'softness': 0.1,
          'edgeConnectedOnly': true,
        },
      },
    },
    {
      'id': '30000000-0000-4000-8000-000000000002',
      'type': 'text',
      'centerX': 0.3,
      'centerY': 0.7,
      'width': 0.6,
      'height': 0.2,
      'rotation': -0.4,
      'isVisible': false,
      'isLocked': false,
      'content': {
        'text': 'Halo 🐈',
        'fontFamily': 'sans-serif',
        'fontSize': 0.08,
        'colorArgb': 4294967295,
        'alignment': 'center',
        'outlineColorArgb': 4278190080,
        'outlineWidth': 0.005,
      },
    },
    {
      'id': '30000000-0000-4000-8000-000000000003',
      'type': 'drawing',
      'centerX': 0.5,
      'centerY': 0.5,
      'width': 1.0,
      'height': 1.0,
      'rotation': 0.0,
      'isVisible': true,
      'isLocked': false,
      'content': {
        'strokes': [
          {
            'points': [
              {'x': 0.1, 'y': 0.2},
              {'x': 0.8, 'y': 0.9},
            ],
            'colorArgb': 4281558681,
            'width': 0.02,
            'opacity': 0.75,
            'tool': 'brush',
          },
          {
            'points': [
              {'x': 0.4, 'y': 0.5},
            ],
            'colorArgb': 0,
            'width': 0.04,
            'opacity': 1.0,
            'tool': 'eraser',
          },
        ],
      },
    },
  ],
};

List<dynamic> layers(Map<String, dynamic> json) =>
    json['layers'] as List<dynamic>;
Map<String, dynamic> firstLayer(Map<String, dynamic> json) =>
    layers(json).first as Map<String, dynamic>;
Map<String, dynamic> imageContent(Map<String, dynamic> json) =>
    firstLayer(json)['content'] as Map<String, dynamic>;

void main() {
  test(
    'roundtrip_preserves_all_layer_types_order_source_mask_and_parameters',
    () {
      final expected = documentJson();
      final project = ProjectDocument.fromJson(expected);
      final restored = ProjectDocument.fromJson(
        jsonDecode(jsonEncode(project.toJson())) as Map<String, dynamic>,
      );

      expect(restored.toJson(), expected);
      expect(restored.layers.map((layer) => layer.content.type), [
        'image',
        'text',
        'drawing',
      ]);
      final image = restored.layers.first.content as ImageLayerContent;
      expect(image.workingAssetId, workingId);
      expect(image.maskAssetId, maskId);
      expect(image.backgroundRemoval!.tolerance, 0.2);
      expect(restored.sourceAssetId, originalId);
      expect(restored.layers.first.centerX, -0.1);
      expect(restored.layers[1].content, isA<TextLayerContent>());
      expect(
        (restored.layers.last.content as DrawingLayerContent).strokes.last.tool,
        DrawingTool.eraser,
      );
    },
  );

  test(
    'copy_with_changes_name_and_layers_without_mutating_previous_snapshot',
    () {
      final original = ProjectDocument.fromJson(documentJson());
      final updated = original.copyWith(
        name: '  Nama baru  ',
        layers: original.layers.reversed.toList(),
        updatedAt: DateTime.utc(2026, 10, 10),
      );
      expect(updated.name, 'Nama baru');
      expect(updated.layers.first.content, isA<DrawingLayerContent>());
      expect(original.name, 'Kucing lokal');
      expect(original.layers.first.content, isA<ImageLayerContent>());
      expect(updated.assets, original.assets);
      expect(() => updated.layers.clear(), throwsUnsupportedError);
      expect(() => updated.assets.clear(), throwsUnsupportedError);
    },
  );

  test('normalizes_timezone_and_preserves_microseconds', () {
    final json = documentJson()
      ..['createdAt'] = '2026-10-09T08:00:00.123456+07:00';
    final document = ProjectDocument.fromJson(json);
    expect(document.createdAt.isUtc, isTrue);
    expect(document.createdAt.toIso8601String(), '2026-10-09T01:00:00.123456Z');
  });

  test('asset_write_copies_and_protects_input_bytes', () {
    final bytes = Uint8List.fromList([1, 2, 3]);
    final write = ProjectAssetWrite(
      id: maskId,
      role: AssetRole.mask,
      bytes: bytes,
      width: 1,
      height: 1,
    );
    bytes[0] = 9;
    expect(write.bytes, [1, 2, 3]);
    expect(write.asset.byteLength, 3);
    expect(() => write.bytes[0] = 7, throwsUnsupportedError);
  });

  test('layer_copy_with_preserves_payload_and_changes_transform', () {
    final layer = ProjectDocument.fromJson(documentJson()).layers.first;
    final changed = layer.copyWith(
      centerX: 0.2,
      rotation: -1,
      isVisible: false,
    );
    expect(changed.content.toJson(), layer.content.toJson());
    expect(changed.centerX, 0.2);
    expect(changed.rotation, -1);
    expect(changed.isVisible, isFalse);
    expect(layer.centerX, -0.1);
  });

  final invalid = <String, void Function(Map<String, dynamic>)>{
    'unsupported_version': (json) => json['version'] = 2,
    'fractional_version': (json) => json['version'] = 1.1,
    'missing_version': (json) => json.remove('version'),
    'traversal_project_id': (json) => json['id'] = '../outside',
    'absolute_asset_id': (json) => json['sourceAssetId'] = '/private/file',
    'blank_name': (json) => json['name'] = ' \n ',
    'long_name': (json) => json['name'] = 'a' * 81,
    'wrong_name_type': (json) => json['name'] = 42,
    'invalid_date': (json) => json['createdAt'] = 'yesterday',
    'overflow_calendar_date': (json) =>
        json['createdAt'] = '2026-02-31T01:00:00Z',
    'overflow_clock_time': (json) => json['createdAt'] = '2026-10-08T25:00:00Z',
    'date_without_timezone': (json) =>
        json['createdAt'] = '2026-10-09T01:00:00',
    'updated_before_created': (json) =>
        json['updatedAt'] = '2020-01-01T00:00:00Z',
    'invalid_canvas': (json) => json['canvasWidth'] = 0,
    'oversized_canvas': (json) => json['canvasHeight'] = 8193,
    'unknown_layer': (json) => firstLayer(json)['type'] = 'plugin',
    'missing_layer_field': (json) => firstLayer(json).remove('rotation'),
    'duplicate_layer_id': (json) =>
        (layers(json)[1] as Map)['id'] = firstLayer(json)['id'],
    'duplicate_asset_id': (json) =>
        (json['assets'] as List).add((json['assets'] as List).first),
    'missing_source': (json) =>
        json['sourceAssetId'] = '40000000-0000-4000-8000-000000000001',
    'wrong_source_role': (json) => json['sourceAssetId'] = workingId,
    'missing_working': (json) => imageContent(json)['workingAssetId'] =
        '40000000-0000-4000-8000-000000000001',
    'wrong_working_role': (json) =>
        imageContent(json)['workingAssetId'] = originalId,
    'wrong_mask_role': (json) => imageContent(json)['maskAssetId'] = workingId,
    'mask_dimension_mismatch': (json) =>
        ((json['assets'] as List)[2] as Map)['width'] = 20,
    'infinite_coordinate': (json) =>
        firstLayer(json)['centerX'] = double.infinity,
    'nan_rotation': (json) => firstLayer(json)['rotation'] = double.nan,
    'zero_layer_width': (json) => firstLayer(json)['width'] = 0,
    'far_outside_layer': (json) => firstLayer(json)['centerY'] = 100,
    'invalid_bool': (json) => firstLayer(json)['isVisible'] = 'true',
    'invalid_crop': (json) =>
        (imageContent(json)['crop'] as Map)['width'] = 1.0,
    'invalid_tolerance': (json) =>
        (imageContent(json)['backgroundRemoval'] as Map)['tolerance'] = 1.01,
    'unsupported_algorithm': (json) =>
        (imageContent(json)['backgroundRemoval'] as Map)['algorithmVersion'] =
            99,
    'negative_color': (json) =>
        (imageContent(json)['backgroundRemoval'] as Map)['colorArgb'] = -1,
    'arbitrary_font_path': (json) =>
        ((layers(json)[1] as Map)['content'] as Map)['fontFamily'] =
            '../font.ttf',
    'invalid_alignment': (json) =>
        ((layers(json)[1] as Map)['content'] as Map)['alignment'] = 'justify',
    'invalid_tool': (json) =>
        ((((layers(json)[2] as Map)['content'] as Map)['strokes'] as List).first
                as Map)['tool'] =
            'plugin',
    'empty_stroke': (json) =>
        ((((layers(json)[2] as Map)['content'] as Map)['strokes'] as List).first
                as Map)['points'] =
            <dynamic>[],
    'partial_asset_dimensions': (json) =>
        ((json['assets'] as List)[1] as Map).remove('height'),
    'unknown_asset_role': (json) =>
        ((json['assets'] as List)[1] as Map)['role'] = 'external',
    'zero_asset_bytes': (json) =>
        ((json['assets'] as List)[1] as Map)['byteLength'] = 0,
    'unexpected_field': (json) =>
        firstLayer(json)['externalPath'] = '/private/photo',
  };
  for (final entry in invalid.entries) {
    test('rejects_${entry.key}_with_safe_domain_failure', () {
      final json = documentJson();
      entry.value(json);
      expect(
        () => ProjectDocument.fromJson(json),
        throwsA(isA<ProjectFailure>()),
      );
    });
  }

  test('rejects_layer_count_above_documented_limit', () {
    final json = documentJson();
    json['layers'] = List.generate(
      ProjectDocument.maxLayers + 1,
      (_) => firstLayer(documentJson()),
    );
    expect(
      () => ProjectDocument.fromJson(json),
      throwsA(isA<ProjectFailure>()),
    );
  });

  test('retains_cleared_optional_mask_and_parameters_after_copy', () {
    final content =
        ProjectDocument.fromJson(documentJson()).layers.first.content
            as ImageLayerContent;
    final changed = content.copyWith(
      clearMask: true,
      clearBackgroundRemoval: true,
    );
    expect(changed.maskAssetId, isNull);
    expect(changed.backgroundRemoval, isNull);
    expect(content.maskAssetId, maskId);
  });

  test('rejects_total_points_over_limit_across_valid_individual_strokes', () {
    final original = ProjectDocument.fromJson(documentJson());
    final stroke = DrawingStroke(
      points: List.filled(
        DrawingStroke.maxPoints,
        DrawingPoint(x: 0.2, y: 0.3),
      ),
      colorArgb: 0xff112233,
      width: 0.01,
    );
    final drawing = original.layers.last.copyWith(
      content: DrawingLayerContent(strokes: List.filled(11, stroke)),
    );
    expect(
      () => original.copyWith(layers: [drawing]),
      throwsA(isA<ProjectFailure>()),
    );
  });

  test('rejects_total_strokes_over_limit_across_valid_individual_layers', () {
    final original = ProjectDocument.fromJson(documentJson());
    final stroke = DrawingStroke(
      points: [DrawingPoint(x: 0.2, y: 0.3)],
      colorArgb: 0xff112233,
      width: 0.01,
    );
    final first = original.layers.last.copyWith(
      content: DrawingLayerContent(strokes: List.filled(1025, stroke)),
    );
    final second = first.copyWith(id: '30000000-0000-4000-8000-000000000004');
    expect(
      () => original.copyWith(layers: [first, second]),
      throwsA(isA<ProjectFailure>()),
    );
  });

  test('drawing_snapshots_copy_all_input_lists', () {
    final points = [DrawingPoint(x: 0.2, y: 0.3)];
    final stroke = DrawingStroke(
      points: points,
      colorArgb: 0xff112233,
      width: 0.01,
    );
    final strokes = [stroke];
    final content = DrawingLayerContent(strokes: strokes);
    points.clear();
    strokes.clear();
    expect(content.strokes.single.points.single.x, 0.2);
    expect(() => content.strokes.clear(), throwsUnsupportedError);
    expect(() => stroke.points.clear(), throwsUnsupportedError);
  });
}
