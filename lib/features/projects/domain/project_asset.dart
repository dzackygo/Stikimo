import 'dart:typed_data';

import 'project_validation.dart';

enum AssetRole { original, working, mask, derived }

/// ID aset bersifat lokal terhadap proyek; path ditentukan repository.
class ProjectAsset {
  ProjectAsset({
    required this.id,
    required this.role,
    required this.byteLength,
    this.width,
    this.height,
  }) {
    validateProjectId(id);
    if (byteLength < 1 || byteLength > maxByteLength) invalidProject();
    if ((width == null) != (height == null)) invalidProject();
    if (width != null &&
        (width! < 1 || width! > 8192 || height! < 1 || height! > 8192)) {
      invalidProject();
    }
    if ((role == AssetRole.working ||
            role == AssetRole.mask ||
            role == AssetRole.derived) &&
        width == null) {
      invalidProject();
    }
  }

  static const maxByteLength = 32 * 1024 * 1024;
  final String id;
  final AssetRole role;
  final int byteLength;
  final int? width;
  final int? height;

  factory ProjectAsset.fromJson(Map<String, dynamic> json) {
    jsonFields(json, {'id', 'role', 'byteLength', 'width', 'height'});
    return ProjectAsset(
      id: jsonString(json['id']),
      role: jsonEnum(json['role'], AssetRole.values),
      byteLength: jsonInt(json['byteLength']),
      width: json['width'] == null ? null : jsonInt(json['width']),
      height: json['height'] == null ? null : jsonInt(json['height']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'role': role.name,
    'byteLength': byteLength,
    'width': width,
    'height': height,
  };

  ProjectAsset copyWith({
    String? id,
    AssetRole? role,
    int? byteLength,
    int? width,
    int? height,
  }) => ProjectAsset(
    id: id ?? this.id,
    role: role ?? this.role,
    byteLength: byteLength ?? this.byteLength,
    width: width ?? this.width,
    height: height ?? this.height,
  );
}

/// Byte aset baru; repository menolak penimpaan ID yang sudah tersimpan.
class ProjectAssetWrite {
  ProjectAssetWrite({
    required this.id,
    required this.role,
    required Uint8List bytes,
    this.width,
    this.height,
  }) : asset = ProjectAsset(
         id: id,
         role: role,
         byteLength: bytes.length,
         width: width,
         height: height,
       ),
       bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  final String id;
  final AssetRole role;
  final Uint8List bytes;
  final int? width;
  final int? height;
  final ProjectAsset asset;
}
