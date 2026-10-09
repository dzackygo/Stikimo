import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:stikimo/features/image_import/data/image_selection_source.dart';
import 'package:stikimo/features/image_import/domain/import_failure.dart';

void main() {
  late _FakeImagePicker picker;
  late AndroidImageSelectionSource source;

  setUp(() {
    picker = _FakeImagePicker();
    source = AndroidImageSelectionSource(picker: picker);
  });

  test(
    'selects_gallery_photo_without_resizing_or_requesting_metadata',
    () async {
      picker.selected = XFile('/synthetic/photo.png');

      final file = await source.pick();

      expect(file!.path, '/synthetic/photo.png');
      expect(picker.source, ImageSource.gallery);
      expect(picker.maxWidth, isNull);
      expect(picker.maxHeight, isNull);
      expect(picker.imageQuality, isNull);
      expect(picker.requestFullMetadata, isFalse);
    },
  );

  test('cancelled_picker_returns_null', () async {
    expect(await source.pick(), isNull);
  });

  test('retrieves_one_lost_photo_after_activity_restart', () async {
    picker.lostData = LostDataResponse(
      files: [XFile('/synthetic/recovered.png')],
      type: RetrieveType.image,
    );

    final recovered = await source.recover();

    expect(recovered!.path, '/synthetic/recovered.png');
    expect(picker.recoveryCalls, 1);
    expect(picker.pickCalls, 0);
  });

  test('empty_lost_data_returns_null', () async {
    expect(await source.recover(), isNull);
    expect(picker.recoveryCalls, 1);
  });

  test(
    'lost_data_platform_failure_is_preserved_for_safe_service_mapping',
    () async {
      final exception = PlatformException(code: 'retrieve_error');
      picker.lostData = LostDataResponse(exception: exception);

      await expectLater(source.recover(), throwsA(same(exception)));
    },
  );

  for (final entry in <String, LostDataResponse>{
    'video': LostDataResponse(
      files: [XFile('/synthetic/video.mp4')],
      type: RetrieveType.video,
    ),
    'multiple_photos': LostDataResponse(
      files: [XFile('/synthetic/one.png'), XFile('/synthetic/two.png')],
      type: RetrieveType.image,
    ),
    'missing_files': LostDataResponse(type: RetrieveType.image),
    'empty_files': LostDataResponse(files: [], type: RetrieveType.image),
  }.entries) {
    test('rejects_recovery_${entry.key}', () async {
      picker.lostData = entry.value;

      await expectLater(
        source.recover(),
        throwsA(
          isA<ImportFailure>().having(
            (failure) => failure.message,
            'message',
            'Foto sebelumnya tidak dapat dipulihkan. Pilih ulang foto.',
          ),
        ),
      );
    });
  }
}

class _FakeImagePicker extends ImagePicker {
  XFile? selected;
  LostDataResponse lostData = LostDataResponse.empty();
  ImageSource? source;
  double? maxWidth;
  double? maxHeight;
  int? imageQuality;
  bool? requestFullMetadata;
  int pickCalls = 0;
  int recoveryCalls = 0;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    pickCalls++;
    this.source = source;
    this.maxWidth = maxWidth;
    this.maxHeight = maxHeight;
    this.imageQuality = imageQuality;
    this.requestFullMetadata = requestFullMetadata;
    return selected;
  }

  @override
  Future<LostDataResponse> retrieveLostData() async {
    recoveryCalls++;
    return lostData;
  }
}
