# AGENTS.md — Aturan untuk Coding Agent

Dokumen ini adalah kontrak kerja bagi agentic AI dan developer yang mengubah repository. Jika aturan ini bertentangan dengan instruksi task, jangan mengabaikan prinsip privasi atau larangan AI/ML runtime; minta klarifikasi untuk konflik yang material.

## 1. Prinsip Utama

1. Baca `PRD.md`, `ARCHITECTURE.md`, `TODO.md`, `SKILL.md`, dan `WORKFLOW.md` sebelum melakukan perubahan.
2. Ikuti scope MVP. Jangan menambah fitur hanya karena terlihat menarik.
3. AI boleh membantu proses development, tetapi **aplikasi runtime dilarang memakai AI/ML**. Jangan menambahkan model, TensorFlow, TFLite, ONNX Runtime, ML Kit, API inference, LLM, atau request jaringan untuk memproses foto.
4. Pemrosesan gambar harus lokal dan deterministik. Beri nama yang jujur seperti `ColorKeyBackgroundRemover`; jangan menamai fitur klasik sebagai AI.
5. Jangan mengganti dependency, arsitektur, database, atau kontrak data secara besar tanpa alasan teknis dan persetujuan bila berdampak ke scope.
6. Jangan menghapus atau menimpa perubahan pengguna. Periksa `git status` sebelum modifikasi besar; jangan menjalankan `git reset --hard`, `git clean -fd`, atau force push.
7. Jangan menyimpan rahasia, foto, token, atau data pribadi di log, fixture publik, atau repository.

## 2. Bahasa, Nama, dan Format Kode

- Bahasa penjelasan dan dokumentasi: Bahasa Indonesia. Nama class, fungsi, field, file, dan API: Bahasa Inggris yang konsisten.
- Ikuti `dart format` dan idiom resmi Dart/Flutter.
- Gunakan `lower_snake_case.dart` untuk file Dart.
- Gunakan `UpperCamelCase` untuk class, enum, typedef, dan extension.
- Gunakan `lowerCamelCase` untuk variabel, parameter, dan fungsi.
- Gunakan `UPPER_SNAKE_CASE` hanya untuk konstanta global yang benar-benar konstan; utamakan `static const` atau `const` di scope terkecil yang sesuai.
- Jangan membuat file raksasa yang mencampur UI, persistence, pemrosesan piksel, dan integrasi native.
- Utamakan komposisi dan fungsi kecil yang mempunyai satu alasan untuk berubah.
- Hindari abstraksi generik sebelum ada kebutuhan nyata. Jangan membuat framework internal yang lebih rumit daripada fitur yang dibangun.

## 3. Komentar dan Dokumentasi

- Tulis komentar untuk menjelaskan **alasan**, batasan, atau keputusan non-obvious; jangan mengulang apa yang sudah jelas dari kode.
- Jangan menambahkan komentar seperti `// increment counter` untuk `counter++`.
- Dokumentasikan public API, model persistence, transformasi koordinat canvas, algoritma color-key, dan kontrak native Kotlin yang sulit ditebak.
- Untuk algoritma penghapusan latar, dokumentasikan: ruang warna/jarak warna yang digunakan, sumber seed/flood-fill, threshold, penanganan alpha, serta kondisi yang diketahui gagal.
- Jangan membuat klaim komentar yang tidak benar, misalnya “background removal works for any image”.
- TODO dalam kode harus merujuk ke ID task seperti `TODO(TASK-IMG-04): ...`; tugas baru harus ditambahkan juga ke `TODO.md`.

## 4. Error Handling dan Logging

- Jangan menelan exception tanpa alasan.
- Tangani error yang memang bisa dipulihkan dengan exception/domain result yang jelas dan pesan ramah pengguna.
- Simpan detail teknis secukupnya pada log debug, tetapi jangan pernah log byte gambar, konten foto, path sensitif secara penuh, atau metadata pribadi tanpa kebutuhan.
- Bedakan pembatalan picker dari kegagalan.
- Pastikan kegagalan ekspor/encoding tidak menandai proyek sebagai berhasil tersimpan.
- Hindari blokir UI untuk decoding, flood-fill, kompositing, atau encoding gambar besar.

## 5. Aturan UI dan State

- Widget UI hanya mengatur presentasi dan interaksi. Operasi domain dipanggil melalui controller/notifier/use case.
- Jangan memanggil file system, database, atau algoritma piksel berat langsung dari `build()`.
- Semua state async harus mencakup loading, success, error, dan empty/cancelled state yang relevan.
- Hindari side effect di `build()`.
- Perubahan editor harus menjaga urutan layer dan koordinat canvas yang konsisten.
- Simpan koordinat layer dalam unit kanonik yang terdokumentasi (disarankan koordinat ternormalisasi 0.0–1.0 relatif ke canvas) dan konversi ke pixel hanya saat render/export.
- Implementasikan undo/redo melalui command/history atau snapshot yang terkontrol; jangan menyimpan seluruh gambar penuh setiap kali brush bergerak jika hal itu menyebabkan penggunaan memori berlebihan.

## 6. Dependency dan Keamanan

- Periksa tanggal rilis, dukungan Android, aktivitas maintenance, lisensi, API, ukuran, dan dependency transitif sebelum menambah package.
- Hindari dependency yang membutuhkan jaringan saat runtime untuk fitur inti.
- Semua dependency baru harus memiliki alasan tertulis pada PR/task atau catatan `ARCHITECTURE.md`.
- Jangan menyalin kode berlisensi tidak kompatibel tanpa atribusi dan pemeriksaan lisensi.
- Jangan menyimpan API key di source code, assets, `BuildConfig`, atau `.env` yang dikomit.
- Terapkan validasi input: jenis file, dimensi, jumlah piksel, ukuran byte, indeks layer, koordinat crop, dan metadata paket.
- Jangan membuka file path arbitrer dari data proyek yang tidak tervalidasi.
- Bila menggunakan `MethodChannel`, validasi argumen dan tangani platform error di sisi Dart maupun Kotlin.
- Integrasi WhatsApp harus menggunakan mekanisme yang didokumentasikan, tanpa mengakali konfirmasi pengguna atau mencoba mengirim pesan otomatis.

## 7. Aturan Test

### Unit test

- Lokasi: `test/...` dengan struktur yang mengikuti `lib/...`.
- Nama test harus menyatakan perilaku dan kondisi, misalnya `returns_error_when_input_image_is_empty`.
- Uji jalur normal, nilai batas, input invalid, dan kegagalan yang diharapkan.
- Algoritma piksel harus memiliki fixture kecil yang mudah diverifikasi, bukan hanya tes “tidak melempar exception”.

### Widget test

- Gunakan untuk navigasi, interaksi kontrol, state loading/error/empty, undo/redo, dan rendering dasar editor.
- Hindari ketergantungan pada jaringan, waktu nyata, atau WhatsApp terpasang.

### Integration test

- Gunakan untuk alur inti: import fixture → editor → save/load → export.
- Interaksi WhatsApp hanya dapat diuji penuh di emulator/perangkat yang memiliki WhatsApp; sediakan unit test untuk metadata/contract provider yang dapat dijalankan tanpa aplikasi tersebut.

### Kriteria test minimum untuk perubahan

- Test ditambahkan/diubah sesuai risiko perubahan.
- Jalankan `dart format` pada file yang diubah.
- Jalankan `flutter analyze`.
- Jalankan `flutter test` untuk perubahan logika/UI yang relevan.
- Jika mengubah Kotlin/native integration, jalankan build Android yang sesuai.
- Laporkan command yang benar-benar dijalankan dan hasil sebenarnya. Jangan mengklaim test lulus jika tidak dijalankan.

## 8. Format Test Pemrosesan Gambar

Fixture dan test harus memverifikasi sekurangnya:

- Input transparan tetap memiliki alpha yang benar.
- Warna latar yang dipilih menjadi transparan sesuai threshold.
- Area dengan warna serupa yang tidak terhubung dengan border diperlakukan sesuai spesifikasi algoritma.
- Mode Erase membuat area transparan dan Restore memulihkan piksel/alpha sumber yang tersimpan.
- Orientasi, rasio aspek, crop, flip, dan rotasi benar.
- Export tepat 512 × 512, WebP, alpha tetap ada, dan file tidak lebih dari 100 KB atau menghasilkan error yang eksplisit.
- Ekspor tidak menimpa file/proyek sumber.

## 9. Kualitas Git dan Hasil Kerja

- Satu task idealnya satu perubahan yang dapat direview.
- Jangan mencampur refactor luas dengan penambahan fitur tanpa kebutuhan.
- Perbarui `TODO.md` hanya jika status benar-benar berubah dan hasil/acceptance criteria telah diverifikasi.
- Perbarui `ARCHITECTURE.md` jika keputusan atau kontrak teknis berubah.
- Jangan menyebut task selesai hanya karena kode sudah ditulis; task selesai setelah kriteria penerimaan dan verifikasi yang relevan terpenuhi.
- Laporan akhir setiap task harus mencantumkan: ringkasan, daftar file berubah, test/command yang dijalankan, hasil, keterbatasan, dan status TODO.

## 10. Definition of Done Umum

Sebuah task selesai jika:

1. Acceptance criteria pada task terpenuhi.
2. Kode diformat dan analyzer tidak memiliki issue baru yang belum dijelaskan.
3. Test yang relevan berjalan dan lulus, atau blocker terdokumentasi secara eksplisit.
4. Tidak ada AI/ML runtime, request jaringan baru, secret, atau data pribadi yang tidak diinginkan.
5. Dokumentasi dan `TODO.md` diperbarui jika diperlukan.
6. Tidak ada perubahan tidak terkait yang ikut dimasukkan.
