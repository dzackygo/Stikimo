# ARCHITECTURE.md — Rencana Implementasi

## 1. Tujuan Dokumen

Dokumen ini memecah MVP menjadi bagian implementasi kecil dengan dependensi dan kriteria selesai yang dapat diverifikasi. Ikuti urutan dependency; jangan langsung mengerjakan semua fitur sekaligus.

## 2. Keputusan Arsitektur Utama

- **Platform:** Android terlebih dahulu.
- **Framework:** Flutter + Dart. Periksa `flutter --version` sebelum mulai; pada 9 Oktober 2026, dokumentasi Flutter mencantumkan Flutter 3.47 dan Dart 3.13 sebagai rilis stabil terbaru yang relevan. Gunakan stable yang terpasang/kompatibel dan lock versinya; jangan melakukan upgrade SDK global tanpa kebutuhan.
- **Arsitektur:** feature-first + MVVM ringan, dengan pemisahan Presentation, Domain, dan Data untuk logika yang perlu diuji. Tidak perlu menerapkan Clean Architecture secara ritual pada setiap model sederhana.
- **State management:** `flutter_riverpod` untuk state teruji dan dependency injection.
- **Navigation:** `go_router` jika aplikasi memakai beberapa route; jika MVP sangat kecil, evaluasi apakah cukup memakai Navigator bawaan. Pilih satu, jangan memasang keduanya tanpa alasan.
- **Image processing:** package `image` (Dart Image Library) untuk decode, transformasi, kompositing/encoding yang didukung; versi dipilih dan dikunci setelah verifikasi kompatibilitas. Operasi berat dijalankan di isolate.
- **Import:** `image_picker` atau plugin resmi/terpelihara yang cocok dengan Android Photo Picker. Periksa perilaku Android dan dukungan SDK aktual.
- **File storage:** `path_provider` untuk direktori aplikasi. Gambar disimpan sebagai file terpisah.
- **Metadata lokal:** `sqflite` untuk proyek, pack, sticker, dan indeks aset; file proyek dapat menyimpan JSON layer bila skema lebih nyaman. Jangan menyimpan file biner gambar besar di kolom DB.
- **ID:** UUID stabil untuk proyek, layer, pack, dan sticker.
- **Native Android:** Kotlin `ContentProvider` + intent WhatsApp untuk dynamic sticker packs. Implementasikan sebagai bagian Android host dan akses melalui platform channel hanya untuk operasi yang dibutuhkan Flutter.
- **Testing:** `flutter_test`, unit test Dart, widget test, `integration_test`, dan test kontrak Kotlin/provider yang praktis.

### Catatan versi

Versi final dependency tidak boleh ditebak. Jalankan `flutter pub add`/cek pub.dev, tinjau dukungan SDK, lisensi, dan changelog, lalu commit `pubspec.lock`. Referensi awal: https://docs.flutter.dev/release/whats-new dan https://pub.dev/packages/image.

Keputusan audit 9 Oktober 2026, versi SDK aktual, lisensi, batas WebP, dan kontrak WhatsApp yang dipin dicatat di `docs/dependency_decisions.md`. Verifikasi runtime tetap mengikuti acceptance task terkait.

## 3. Larangan Runtime

Tidak boleh ada:

- LLM, AI API, model AI, machine learning, neural network, TensorFlow, TFLite, ONNX, ML Kit, atau model segmentasi.
- Pemrosesan foto melalui backend, upload otomatis, analytics pihak ketiga, atau cloud storage.
- Fitur yang diam-diam memanggil internet untuk menghasilkan/menyunting gambar.

Algoritma klasik yang diperbolehkan termasuk crop, resize, rotate, flip, threshold warna, color-distance, flood-fill, alpha-mask, eraser/restore, compositing, morphology untuk outline, dan encoding WebP.

## 4. Batasan Teknik Background Removal

Background removal bukan masalah crop biasa. MVP menggunakan **color-key removal** deterministik untuk latar sederhana:

1. Pengguna memilih satu warna latar lewat eyedropper atau sistem sampling tepi.
2. Lakukan flood-fill dari pixel seed di tepi yang memenuhi color-distance threshold agar area mirip di bagian dalam objek tidak langsung dihapus jika tidak tersambung ke background.
3. Konversikan mask menjadi alpha dengan transisi/feather terbatas untuk mengurangi tepi bergerigi.
4. Sediakan Erase/Restore brush sebagai koreksi manual.
5. Pertahankan original image/mask history sehingga pengguna bisa membatalkan operasi.

Kondisi gagal yang diketahui: latar ramai/bertekstur, warna latar sangat mirip objek, rambut atau tepi halus, bayangan kompleks, objek menyentuh tepi, dan banyak area warna latar yang terputus. UI harus menyatakan metode ini paling cocok untuk latar polos/sederhana. Jangan memasukkan library/model ML untuk memperbaikinya tanpa perubahan PRD yang disetujui.

## 5. Struktur Folder yang Disarankan

```text
lib/
  main.dart
  app/
    app.dart
    router.dart
    theme/
  core/
    errors/
    result/
    utils/
    storage/
  features/
    home/
      presentation/
    image_import/
      data/
      domain/
      presentation/
    sticker_editor/
      data/
      domain/
      presentation/
        widgets/
        controllers/
    projects/
      data/
      domain/
      presentation/
    sticker_export/
      data/
      domain/
      presentation/
    whatsapp_packs/
      data/
      domain/
      presentation/
android/app/src/main/kotlin/<package>/
test/
  core/
  features/
integration_test/
```

Struktur folder boleh disesuaikan dengan standar repository yang sudah ada. Jangan memindahkan banyak folder bila proyek sudah memiliki struktur yang sehat.

## 6. Domain Model Inti

### `Project`

- `id`, `name`, `createdAt`, `updatedAt`
- `sourceAssetPath`: gambar awal yang immutable selama proyek masih memakai sumber itu
- `canvasWidth`, `canvasHeight` atau rasio kanonik canvas
- `layers`: daftar layer berurutan
- `version`: versi skema dokumen untuk migrasi

### `EditorLayer`

- `id`, `type`, `zIndex`, `isVisible`, `isLocked`
- posisi dan ukuran ternormalisasi relatif terhadap canvas
- transformasi: rotasi dan scale
- properti spesifik tipe layer

Jenis layer MVP: `image`, `text`, `drawing`, dan `shape/decorative` bila shape sederhana tidak menambah scope secara berlebihan.

### `TextLayer`

- teks, family font yang tersedia, ukuran, warna, alignment, stroke/outline, transformasi.
- Simpan hanya nama font yang tersedia di app atau fallback ke font sistem; jangan mengandalkan path font arbitrer.

### `DrawingLayer`

- daftar stroke, tiap stroke berisi poin ternormalisasi, warna, ketebalan, opacity, dan jenis tool.
- Jangan membuat satu bitmap penuh per event pointer. Render ulang vector stroke, lalu cache raster bila dibutuhkan.

### `StickerPack` dan `Sticker`

- Pack: `id`, `name`, `publisher`, `identifier`, `trayIconPath`, `imageDataVersion`, `createdAt`, `updatedAt`.
- Sticker: `id`, `packId`, `webpPath`, `width`, `height`, `byteSize`, `order`, 1–3 emoji tags sesuai validator resmi.
- Batas validator statis: sticker 102400 byte, tray 51200 byte; tray dipilih PNG 96 × 96. `imageDataVersion` berubah saat isi/tray berubah.
- Jangan menganggap file WebP saja cukup untuk integrasi pack; integrasi memerlukan metadata dan kontrak native provider.

## 7. Batas Modul

### Presentation

- Widget, halaman, editor canvas, controller/notifier, validasi input form.
- Tidak melakukan operasi piksel berat langsung di widget.

### Domain

- Entity, aturan validasi, use case, repository interface.
- Bebas dari Flutter widget dan akses Android native.

### Data

- Implementasi repository, SQLite, file storage, serialization, dan image processing adapter.

### Android bridge

- Kotlin `ContentProvider` membaca pack dan sticker yang valid dari storage lokal.
- Validasi pack, otorisasi akses file, dan kontrak intent sesuai dokumentasi resmi.
- Flutter menginstruksikan add-pack; keputusan/konfirmasi akhir tetap dilakukan WhatsApp.

## 8. Alur Data Utama

### Import dan editor

1. Image picker mengembalikan file yang dipilih.
2. Validasi tipe/ukuran, normalisasi EXIF, salin ke direktori app dengan nama unik.
3. Buat `Project` dengan `ImageLayer` atau source layer.
4. Editor menyimpan perubahan sebagai state layer; sumber asli tidak ditimpa.
5. Save use case menulis metadata ke SQLite dan file JSON dokumen ke storage.

### Background removal klasik

1. Pengguna memilih color-key mode dan warna sample.
2. `RemoveBackgroundUseCase` memanggil `ColorKeyBackgroundRemover` di isolate.
3. Service menghasilkan alpha mask dan image turunan.
4. Editor menampilkan hasil, dengan undo/restore tersedia.
5. Hasil dan parameter mask disimpan agar proyek bisa dibuka kembali.

### Export

1. `ExportStickerUseCase` meminta editor renderer merender canvas transparan.
2. Pastikan area background tetap alpha=0; grid/checkerboard hanya bagian dari UI preview.
3. Resize/contain ke kanvas 512 × 512 dengan margin aman.
4. Encode WebP dengan alpha menggunakan backend yang telah dibuktikan di Android.
5. Decode/inspect output untuk memvalidasi format, dimensi, alpha, dan ukuran byte.
6. Jika >100 KB, lakukan percobaan kompresi berbatas. Hentikan setelah batas percobaan; tampilkan error jika tetap >100 KB.
7. Simpan output ke storage dan buat/update metadata `Sticker`.

### Tambah ke WhatsApp

1. Pengguna mengatur pack dan tray icon.
2. Validasi jumlah 3–30, file WebP, 512 × 512, maksimal 100 KB per sticker, tray icon 96 × 96 dan maksimal 50 KB menurut referensi WhatsApp yang digunakan.
3. Kotlin `ContentProvider` menyediakan metadata dan berkas stiker pada permintaan WhatsApp.
4. App mengirim intent enable pack sesuai contoh resmi.
5. WhatsApp menampilkan konfirmasi untuk pack; app menangani cancel, package missing, atau error provider.

## 9. Tahapan Implementasi, Dependencies, dan Definition of Done

### Phase 0 — Pemeriksaan repository dan kontrak teknis

**TASK-SETUP-01: Audit environment dan repository**
- Baca dokumen ini dan dokumentasi lain.
- Periksa `git status`, struktur repo, `flutter --version`, Android SDK, minSdk, `pubspec.yaml` jika ada.
- **Selesai jika:** laporan environment tersedia; tidak ada file pengguna yang ditimpa; versi/toolchain aktual terdokumentasi.

**TASK-SETUP-02: Validasi package dan native contract**
- Verifikasi package import, image decode/encode WebP alpha, DB, state management, dan sample WhatsApp saat implementasi.
- **Selesai jika:** dependency yang dipilih memiliki dukungan Android/lisensi yang layak dan keputusan dicatat; `pubspec.lock` committed saat proyek menggunakan Pub.

### Phase 1 — Fondasi aplikasi

**TASK-APP-01: Setup Flutter application** (depends on SETUP-01, SETUP-02)
- App entry point, theme light/dark, error boundary sederhana, linting, test setup.
- **Selesai jika:** build debug berhasil, aplikasi terbuka, `flutter analyze` dan test dasar lulus.

**TASK-APP-02: Navigasi dan halaman dasar** (depends on APP-01)
- Home, New Sticker, Projects, Sticker Packs, Settings placeholder jika diperlukan.
- **Selesai jika:** navigasi berjalan, empty states ada, tidak ada fitur palsu yang diklaim sudah bekerja.

### Phase 2 — Import dan storage

**TASK-IMG-01: Import dan normalisasi gambar** (depends on APP-01)
- Picker, handling cancel/error, EXIF orientation, jenis/ukuran file, file cache lokal.
- **Selesai jika:** fixture JPEG/PNG besar, cancel, dan file invalid ditangani; sumber tidak diubah.

**TASK-DATA-01: Project persistence** (depends on APP-01)
- SQLite metadata, file assets, serialisasi dokumen versi.
- **Selesai jika:** project create/save/load/rename/duplicate/delete berjalan dan tes round-trip mempertahankan urutan/properti layer, sumber immutable, serta mask/parameter background removal yang diperlukan Restore.

### Phase 3 — Core image processing tanpa AI/ML

**TASK-IMG-02: Image processing service** (depends on IMG-01)
- Adapter untuk resize/crop/rotate/flip/alpha dan operasi image package.
- **Selesai jika:** transform test memverifikasi dimensi, aspect ratio, EXIF, alpha, dan tidak memblokir UI pada fixture besar.

**TASK-IMG-03: Color-key background remover** (depends on IMG-02)
- Sampling warna, color distance, edge flood-fill, alpha mask, threshold, error states.
- **Selesai jika:** fixture sederhana lulus test piksel; keterbatasan terlihat di UI; tidak ada dependency/model AI/ML.

**TASK-IMG-04: Erase/Restore brush** (depends on IMG-03)
- Manual mask correction dengan brush size/strength dan undo.
- **Selesai jika:** erase membuat area transparan, restore memulihkan area dari sumber yang tersimpan, dan perubahan dapat di-undo.

**TASK-IMG-05: Outline** (depends on IMG-03)
- Stroke/outline berbasis alpha mask, warna dan ketebalan terbatas.
- **Selesai jika:** outline mengikuti alpha mask tanpa mengisi background dan test output dasar lulus.

### Phase 4 — Editor

**TASK-EDITOR-01: Canvas dan model layer** (depends on IMG-01, DATA-01)
- Coordinate model, layer manager, transform gesture, z-order, selection.
- **Selesai jika:** image layer bisa dipilih/digeser/scale/rotate; serialized state round-trip.

**TASK-EDITOR-02: Crop/transform dan background edit** (depends on EDITOR-01, IMG-02, IMG-04)
- Crop, rotate, flip, Erase/Restore tool integration.
- **Selesai jika:** semua kontrol bekerja dan undo/redo mengembalikan state yang benar.

**TASK-EDITOR-03: Text layer** (depends on EDITOR-01)
- Add/edit text, font size, color, alignment, outline, transform.
- **Selesai jika:** teks dapat diedit lagi setelah project reload dan hasil render sesuai preview.

**TASK-EDITOR-04: Drawing layer** (depends on EDITOR-01)
- Brush, stroke history, eraser, color/thickness, undo/redo.
- **Selesai jika:** stroke tersimpan, bisa dipilih/dihapus sesuai desain, hasil export sama dengan preview.

**TASK-EDITOR-05: Unified undo/redo dan project recovery** (depends on EDITOR-02, EDITOR-03, EDITOR-04)
- Command/history strategy dengan batas memori.
- **Selesai jika:** operasi editor utama dapat dibatalkan/dimajukan secara konsisten dan tidak kehilangan source image.

### Phase 5 — Export

**TASK-EXPORT-01: Transparent canvas renderer** (depends on EDITOR-02, EDITOR-03, EDITOR-04)
- Render semua layer pada canvas transparan dengan transform yang konsisten.
- **Selesai jika:** fixture rendering memiliki dimensi/alpha yang diharapkan; checkerboard preview tidak ikut diekspor.

**TASK-EXPORT-02: WebP encode and validate** (depends on EXPORT-01, IMG-02)
- 512 × 512, alpha, ukuran <=100 KB, compression fallback.
- **Selesai jika:** valid output lolos parser/decoder; file oversized menghasilkan error jelas; source project tetap utuh.

**TASK-EXPORT-03: Export history and share file** (depends on EXPORT-02)
- Simpan output dan Android share sheet (bukan mengganti paket stiker).
- **Selesai jika:** pengguna bisa menemukan file hasil dan berbagi file; pembatalan berbagi ditangani.

### Phase 6 — WhatsApp sticker packs

**TASK-WA-01: Pack and sticker management** (depends on DATA-01, EXPORT-02)
- CRUD pack, tray icon, urutan, validasi min 3/max 30.
- **Selesai jika:** pack invalid tidak bisa dikirim ke WhatsApp; metadata disimpan round-trip.

**TASK-WA-02: Kotlin ContentProvider contract** (depends on WA-01)
- Implementasi provider metadata/files berdasarkan sample resmi, URI access, MIME type, error path.
- **Selesai jika:** unit/instrumentation test provider menjawab informasi pack/stiker yang valid dan menolak input invalid.

**TASK-WA-03: Enable sticker pack intent** (depends on WA-02)
- Platform channel/intent, WhatsApp missing/error handling, user confirmation.
- **Selesai jika:** tes pada perangkat/emulator dengan WhatsApp menunjukkan jalur add-pack; cancel tidak menandai pack sukses ditambahkan.

### Phase 7 — Hardening dan release readiness

**TASK-QA-01: End-to-end workflow** (depends on EXPORT-03, WA-03)
- Import → edit → save/reopen → export → build pack → add to WhatsApp.
- **Selesai jika:** test manual dengan checklist terdokumentasi dan tidak ada blocker P0.

**TASK-QA-02: Privacy, robustness, performance** (depends on APP-02, IMG-01–05, DATA-01, EDITOR-01–05, EXPORT-01–03, WA-01–03; excludes itself and DOC-01)
- Mode pesawat, file besar, storage penuh, app restart, izin ditolak, paket WhatsApp tidak ada.
- **Selesai jika:** tidak ada outbound request aplikasi yang tidak diharapkan, kegagalan ditangani, dan risiko tersisa didokumentasikan.

**TASK-DOC-01: Final documentation and handoff** (depends on QA tasks)
- Perbarui README/setup/dependency decisions dan TODO.
- **Selesai jika:** developer baru dapat menjalankan, menguji, dan memahami batasan tanpa penjelasan lisan.

## 10. Test dan Command Verifikasi

Jalankan dari root Flutter project (sesuaikan jika repository memang belum menjadi project Flutter):

```bash
flutter --version
flutter pub get
dart format --set-exit-if-changed .
flutter analyze
flutter test
flutter build apk --debug
```

Jika `integration_test` disiapkan, jalankan pada emulator sesuai petunjuk proyek. Test WhatsApp add-pack tetap memerlukan WhatsApp yang kompatibel terpasang dan persetujuan pengguna.

## 11. Risiko yang Harus Dipantau

- Color-key klasik tidak bisa menggantikan segmentasi cerdas untuk latar kompleks.
- Memenuhi batas 100 KB tanpa degradasi visual yang berlebihan mungkin tidak mungkin untuk beberapa gambar; berikan pesan error/opsi menyederhanakan gambar.
- Integrasi ContentProvider/intent bergantung pada format dan kontrak WhatsApp yang berlaku saat diuji.
- Memori tinggi pada foto resolusi besar; proses di isolate dan gunakan batas input yang rasional.
- Perbedaan hasil render widget dan export pixel-level; bangun golden/fixture tests untuk transformasi kritis.

## 12. Referensi Resmi

- WhatsApp Android sticker app README (requirements, `ContentProvider`, intent, pack metadata): https://github.com/WhatsApp/stickers/blob/main/Android/README.md
- WhatsApp Help Center: https://faq.whatsapp.com/1056840314992666
- Flutter release notes: https://docs.flutter.dev/release/whats-new
- Dart Image Library: https://pub.dev/packages/image
- Flutter image picker: https://pub.dev/packages/image_picker
- Riverpod: https://pub.dev/packages/flutter_riverpod
- sqflite: https://pub.dev/packages/sqflite
