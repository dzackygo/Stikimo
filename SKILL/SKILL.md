# SKILL.md — Reusable Agent Prompt Patterns

Gunakan pola prompt berikut saat meminta agentic AI melakukan pekerjaan berulang. Sertakan konteks task dan ID dari `TODO.md`. Prompt ini adalah bantuan untuk **development saja**; bukan fitur atau prompt yang dimasukkan ke runtime aplikasi.

## Cara Menggunakan

1. Pilih satu template yang sesuai dengan pekerjaan saat ini.
2. Ganti placeholder seperti `[TASK-ID]`, `[scope]`, dan `[changed files]`.
3. Tempelkan ke agent bersama `AGENTS.md`, `PRD.md`, `ARCHITECTURE.md`, `TODO.md`, dan `WORKFLOW.md` yang relevan.
4. Minta agent melaporkan bukti, bukan sekadar menyatakan berhasil.

## 1. Planning sebelum implementasi

```text
Baca PRD.md, AGENTS.md, ARCHITECTURE.md, TODO.md, dan WORKFLOW.md.
Task: [TASK-ID dan tujuan].
Jangan mengubah kode dulu. Periksa repository dan identifikasi:
1. file dan modul yang relevan,
2. dependency dan kontrak yang dipengaruhi,
3. rancangan paling sederhana yang sesuai arsitektur,
4. test yang dibutuhkan,
5. risiko, pertanyaan, atau keputusan yang membutuhkan izin.
Pastikan solusi tidak memasukkan AI/ML atau layanan jaringan saat runtime.
Kembalikan rencana singkat beserta acceptance criteria. Jangan mengulang pertanyaan yang jawabannya sudah ada di dokumentasi.
```

## 2. Implementasi satu task

```text
Implementasikan hanya [TASK-ID] sesuai ARCHITECTURE.md.
Baca AGENTS.md dan periksa git status terlebih dahulu. Jangan menyentuh perubahan pengguna atau fitur di luar scope.
Buat perubahan sekecil mungkin yang menyelesaikan acceptance criteria. Pisahkan UI, domain, persistence, pemrosesan gambar, dan native integration sesuai batas modul.
Tambahkan/ubah test yang relevan, jalankan formatter, flutter analyze, test yang relevan, serta build jika diperlukan.
Jangan menambah AI/ML, model, API, analytics, atau request jaringan ke aplikasi runtime.
Pada akhir pekerjaan laporkan file yang berubah, keputusan teknis, command yang benar-benar dijalankan, hasil test, keterbatasan, dan usulan status TODO. Jangan tandai DONE bila belum diverifikasi.
```

## 3. Testing dan debugging

```text
Bantu investigasi [bug/perilaku] tanpa langsung melakukan refactor luas.
Pertama reproduksi atau buat test yang menunjukkan masalah. Cari penyebab utama dan bedakan bug kode dari asumsi yang keliru atau batasan dependency/platform.
Buat perubahan minimum, tambahkan regression test, lalu jalankan test terarah dan analyzer.
Jangan menonaktifkan test, menurunkan coverage, menambah delay arbitrary, atau menyembunyikan error hanya agar test lulus.
Laporkan langkah reproduksi, root cause, perubahan, hasil test, serta kondisi yang belum diuji.
```

## 4. Review kode

```text
Lakukan review atas [changed files / diff] berdasarkan PRD.md, AGENTS.md, dan ARCHITECTURE.md.
Prioritaskan temuan berdasarkan severity: Blocker, High, Medium, Low.
Periksa correctness, edge cases, error handling, performa/memori, keamanan file, privasi, aksesibilitas, persistensi proyek, konsistensi preview/export, dan test.
Cari pelanggaran keras: AI/ML atau network service di runtime, source image tertimpa, log berisi data privat, atau integrasi WhatsApp tanpa validasi pack.
Jangan melakukan perubahan kode selama review kecuali diminta. Untuk tiap temuan sebutkan file/baris, kondisi pemicu, dampak, dan perbaikan yang disarankan. Jika tidak ada temuan, sebutkan area yang belum diverifikasi.
```

## 5. Security dan privacy review

```text
Lakukan security/privacy review untuk [scope]. Anggap foto dan metadata proyek adalah data pribadi.
Periksa apakah gambar atau metadata dapat keluar dari perangkat, apakah ada izin Android berlebihan, logging sensitif, file path traversal, input image decompression bomb, validasi ukuran/dimensi yang hilang, penyalahgunaan MethodChannel, URI/provider permission yang terlalu luas, atau intent yang tak tervalidasi.
Periksa manifest, permission, dependency, dan native provider.
Jangan menambahkan network, telemetry, AI/ML atau library baru. Berikan temuan berprioritas, bukti, skenario eksploit/risiko, dan mitigasi yang paling sederhana.
```

## 6. Refactor aman

```text
Refactor [module/files] tanpa mengubah perilaku eksternal.
Sebelum mengubah kode, identifikasi kontrak publik, state yang dipersistenkan, transformasi koordinat, dan test yang melindungi perilaku sekarang.
Pecah refactor menjadi langkah kecil. Jangan menggabungkan perubahan arsitektur, penambahan fitur, dan format ulang seluruh repository sekaligus.
Jalankan regression tests setelah tiap perubahan bermakna. Pertahankan compatibility untuk project dokumen yang sudah tersimpan atau buat migration versioned bila memang diperlukan.
Laporkan perubahan perilaku (jika ada), test, risiko, dan file yang diubah.
```

## 7. Review algoritma gambar

```text
Review [image-processing algorithm] dengan input deterministik dan fixture kecil.
Verifikasi ukuran/dimensi, koordinat, color distance, flood-fill connectivity, alpha, tepi, memory usage, cancellation, serta output pada kasus batas.
Jelaskan kegagalan yang wajar untuk metode klasik, khususnya background kompleks atau warna objek yang mirip background. Jangan memperkenalkan model AI/ML untuk menutupi keterbatasan.
Buat unit test yang memeriksa nilai piksel dan alpha secara eksplisit, bukan hanya bahwa fungsi selesai.
```

## 8. Review export dan WhatsApp pack

```text
Review [export/WhatsApp integration] dengan kontrak resmi yang tersedia saat ini.
Verifikasi WebP statis, 512x512, transparansi, ukuran setiap sticker <=100 KB, pack terdiri dari 3-30 sticker, tray icon, urutan, identifier stabil, metadata, provider URI, dan error handling.
Pastikan file output benar-benar dapat dibaca kembali oleh decoder dan preview checkerboard tidak ikut diekspor.
Jangan menyatakan integrasi end-to-end lulus tanpa pengujian pada perangkat/emulator dengan WhatsApp yang kompatibel. Bedakan unit test provider dari uji app-to-app sebenarnya.
```

## 9. Penyelesaian task dan update tracker

```text
Lakukan pemeriksaan akhir untuk [TASK-ID]. Cocokkan implementasi dengan semua acceptance criteria pada ARCHITECTURE.md.
Pastikan formatter/analyzer/test relevan telah dijalankan dan hasilnya diketahui. Periksa git diff dan pastikan tidak ada perubahan tidak terkait atau file pengguna tertimpa.
Update TODO.md menjadi DONE hanya jika kriteria benar-benar terpenuhi; jika tidak, gunakan IN_PROGRESS atau BLOCKED dan tulis alasan serta langkah berikutnya.
Perbarui dokumentasi arsitektur hanya bila keputusan/kontrak berubah. Laporkan bukti, bukan asumsi.
```

## 10. Kapan Agent Harus Berhenti dan Bertanya

Berhenti dan minta izin jika:

- Solusi memerlukan AI/ML runtime, akses jaringan baru, backend, telemetry, atau upload gambar.
- Perubahan memodifikasi banyak file yang tidak terkait, menghapus data, mengganti database, melakukan migrasi destruktif, atau mengubah identitas/package name aplikasi.
- Ada lisensi dependency yang tidak jelas atau tidak kompatibel.
- Diperlukan keputusan produk yang mengubah behavior pengguna atau scope MVP.
- Kontrak WhatsApp/native yang diperlukan tidak dapat diverifikasi.

Untuk keputusan lokal, reversibel, dan sudah tercakup di dokumentasi, agent boleh memilih solusi sederhana serta mendokumentasikan alasannya.
