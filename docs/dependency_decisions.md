# Dependency dan kontrak native — TASK-SETUP-02

Verifikasi sumber primer: 9 Oktober 2026. Toolchain aktual: Flutter **3.47.5**, framework `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`; Dart **3.13.4**; JDK **17.0.20.1 Temurin**. SDK lokal dikunci pada tag. `pubspec.lock` dilacak setelah resolver berhasil.

## Pilihan awal

| Package | Versi | SDK minimum dari metadata | Lisensi | Alasan |
|---|---|---|---|---|
| flutter_riverpod | 3.4.3 | Dart 3.12; Flutter 3.0 | MIT | State/DI sesuai arsitektur; tanpa generator |
| image | 4.10.1 | Dart 3.0 | MIT | Decode, transform, alpha, encoder WebP klasik di isolate |
| image_picker | 1.2.4 | Dart 3.11; Flutter 3.41; Android 24 | Apache-2.0/BSD-3-Clause | Photo Picker dan kamera; cancel dan lost-data recovery wajib |
| path_provider | 2.1.6 | Dart 3.10; Flutter 3.38; Android 24 | BSD-3-Clause | Direktori private aplikasi |
| sqflite | 2.4.4+1 | Dart 3.12; Flutter 3.44 | BSD-2-Clause | Metadata SQLite; gambar tetap berkas terpisah |
| uuid | 4.6.0 | Dart 3.0 | MIT | ID stabil untuk proyek/layer/stiker/pack |
| flutter_lints | 6.0.0 | Dart 3.8 | BSD-3-Clause | Lint resmi; dependency development |

Semua kandidat mendukung Android menurut metadata sumber primer. Package dipilih untuk kebutuhan MVP, tanpa inference/model ML/backend/analytics/network service. Package transitif wajib diperiksa setelah lockfile tersedia. Navigasi awal memakai Navigator bawaan agar tidak menambah dependency routing sebelum diperlukan. Kandidat terbaru efektif memerlukan Flutter 3.44/Dart 3.12 dan minSdk24; SDK aktual di atas memenuhi requirement bahasa/framework.

Sumber package, metadata, lisensi, changelog:

- [image_picker](https://pub.dev/packages/image_picker), [metadata](https://pub.dev/api/packages/image_picker), [backend Android](https://pub.dev/api/packages/image_picker_android).
- [image](https://pub.dev/packages/image), [metadata](https://pub.dev/api/packages/image), [changelog](https://pub.dev/packages/image/changelog).
- [flutter_riverpod](https://pub.dev/packages/flutter_riverpod), [metadata](https://pub.dev/api/packages/flutter_riverpod).
- [sqflite](https://pub.dev/packages/sqflite), [metadata](https://pub.dev/api/packages/sqflite), [source Android](https://github.com/tekartik/sqflite).
- [path_provider](https://pub.dev/packages/path_provider), [metadata](https://pub.dev/api/packages/path_provider), [changelog Android](https://pub.dev/packages/path_provider_android/changelog).
- [uuid](https://pub.dev/packages/uuid), [flutter_lints](https://pub.dev/packages/flutter_lints).

## WebP dan alpha

`image` 4.10.1 menyediakan `encodeWebP`; 4.10.0 menambah encoder lossy dan 4.10.1 memperbaiki masalah alpha. Default encoder **lossless**. Fallback harus memakai `lossless: false`; menurunkan `quality` saja pada mode lossless tidak membuktikan ukuran berkurang. Kandidat export statis: `singleFrame: true`, `alphaQuality: 100`, percobaan kualitas berbatas. [API encodeWebP](https://pub.dev/documentation/image/latest/image/encodeWebP.html), [WebPEncoder](https://pub.dev/documentation/image/latest/image/WebPEncoder-class.html).

Validasi sumber dan resolver tidak membuktikan output Android. `TASK-EXPORT-02` wajib menguji RGBA, membaca output dengan decoder Android independen, memeriksa dimensi/alpha/byte, menolak oversized. Jangan mengganti backend ke plugin native sebelum kandidat Dart diuji.

## Kontrak WhatsApp

Referensi resmi WhatsApp/stickers dipin pada commit `06144a1f6077bbb346e1230032fc4e0bce996d03`: [README](https://github.com/WhatsApp/stickers/blob/06144a1f6077bbb346e1230032fc4e0bce996d03/Android/README.md), [validator](https://github.com/WhatsApp/stickers/blob/06144a1f6077bbb346e1230032fc4e0bce996d03/Android/app/src/main/java/com/example/samplestickerapp/StickerPackValidator.java), [provider](https://github.com/WhatsApp/stickers/blob/06144a1f6077bbb346e1230032fc4e0bce996d03/Android/app/src/main/java/com/example/samplestickerapp/StickerContentProvider.java), [activity](https://github.com/WhatsApp/stickers/blob/06144a1f6077bbb346e1230032fc4e0bce996d03/Android/app/src/main/java/com/example/samplestickerapp/AddStickerPackActivity.java), [manifest](https://github.com/WhatsApp/stickers/blob/06144a1f6077bbb346e1230032fc4e0bce996d03/Android/app/src/main/AndroidManifest.xml), [lisensi](https://github.com/WhatsApp/stickers/blob/06144a1f6077bbb346e1230032fc4e0bce996d03/LICENSE).

- Stiker statis WebP transparan **512 × 512**, maksimal **102400 byte**; pack **3–30** stiker. Batas resmi setara 100 KiB.
- README membatasi **1–10 pack** yang ditawarkan per aplikasi/provider; batas koleksi lokal dapat diatur pada TASK-WA-01 tanpa menawarkan pack di luar batas kontrak.
- Tray dipilih PNG **96 × 96**, maksimal **51200 byte**; memenuhi README dan validator.
- Metadata pack: `publisher`, identifier stabil, `image_data_version`. Version berubah saat isi/tray berubah. `avoid_cache` deprecated; setiap stiker memiliki **1–3 emoji** sesuai validator.
- Provider routes: `metadata`, `metadata/<identifier>`, `stickers/<identifier>`, `stickers_asset/<identifier>/<filename>`. Kolom cursor mengikuti sample; MIME stiker `image/webp`, tray `image/png`.
- Provider exported/enabled dengan read permission `com.whatsapp.sticker.READ`; visibility untuk `com.whatsapp` dan `com.whatsapp.w4b`. Dynamic pack harus membaca metadata terbaru dan hanya membuka filename terdaftar pada private storage; validasi path/request wajib.
- Intent `com.whatsapp.intent.action.ENABLE_STICKER_PACK`; extras `sticker_pack_id`, `sticker_pack_authority`, `sticker_pack_name`.
- WhatsApp mempertahankan konfirmasi pengguna. Tangani missing app, cancel, `validation_error`; mengirim intent tidak membuktikan pack ditambahkan.
- Bila mengadaptasi kode sample, pertahankan copyright/lisensi BSD. Tidak perlu memasukkan semua dependency demo ke Stikimo.
- Renderer ekspor membuat canvas RGBA baru agar metadata EXIF/GPS/ICC foto sumber tidak otomatis disalin oleh encoder ke berkas ekspor.

## Batas bukti

`TASK-SETUP-02` memvalidasi dukungan/lisensi/API/keputusan dependency. Lockfile harus dilacak begitu Pub digunakan. Bukti output Android dan perangkat tetap acceptance task import/export/provider/WhatsApp. `TASK-APP-01` membutuhkan analyzer, test, APK debug, dan aplikasi benar-benar dibuka; scaffold saja tidak cukup.

## Hasil verifikasi aktual

- `flutter pub get` — PASS, 84 dependency diselesaikan dan lockfile tersedia.
- Audit 80 package hosted pada cache: semua memiliki LICENSE, dalam keluarga BSD-3 (60), MIT (9), BSD-2 (5), Apache-2 (3), atau BSD-3/Apache-2 gabungan (3). Tidak ditemukan SDK AI/ML/analytics dalam graph resolver.
- `http` 1.6.0 transitif berasal dari platform interface picker dan desktop file selector. Picker Android memilih implementasi `dart:io` lokal; pemakaian `http.readBytes` pada source picker yang diperiksa berada pada implementasi web. Kehadiran package tidak membuktikan request Android; verifikasi runtime/network tetap TASK-QA-02.
- `path_provider_android` 2.3.1 memakai JNI BSD-3 (`jni`, `jni_flutter`, `jni_util`) untuk API direktori Android. `jni_flutter` saat audit memakai compileSdk35, sehingga SDK platform35 perlu tersedia selain platform36 untuk aplikasi.
- `flutter test --no-pub test/core/webp_codec_contract_test.dart --reporter expanded` — PASS, dua test WebP lossless/lossy melalui decoder engine Flutter Windows. Alpha 0, 128, 255, dimensi, format RIFF/WEBP, satu frame, dan nilai RGB lossless diperiksa. Ini belum bukti decoder perangkat Android.
- `flutter analyze --no-pub` — PASS, no issues found.
- `dart format --output=none --set-exit-if-changed test` dan `git diff --check` — PASS.
