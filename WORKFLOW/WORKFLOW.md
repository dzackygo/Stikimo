# WORKFLOW.md — Aturan Kerja Agentic AI

## 1. Misi

Bekerja secara bertahap untuk membangun aplikasi Android Flutter pembuat stiker WhatsApp. Prioritas utama adalah correctness, privasi, kesederhanaan, kemudahan dirawat, dan bukti pengujian.

## 2. Wajib Dibaca sebelum Bekerja

Sebelum task apa pun:

1. Baca `PRD.md` untuk memahami batas produk.
2. Baca `AGENTS.md` untuk standar engineering.
3. Baca `ARCHITECTURE.md` untuk rencana, dependency, dan acceptance criteria.
4. Baca `TODO.md` untuk status aktual.
5. Gunakan `SKILL.md` jika task cocok dengan prompt yang tersedia.
6. Periksa repository dan `git status` sebelum mengedit.

Jika dokumentasi dan kode nyata berbeda, jangan langsung menimpa salah satunya. Laporkan selisih, tentukan mana yang benar berdasarkan history/tes, dan minta keputusan jika berdampak pada behavior atau data.

## 3. Batas Non-Negotiable

- AI hanya alat development; **dilarang memasukkan AI/ML ke runtime aplikasi**.
- Dilarang memakai model on-device, API inference, LLM, TensorFlow/TFLite, ONNX, ML Kit, atau layanan background removal cloud.
- Dilarang mengirim gambar, dokumen proyek, atau metadata pengguna melalui jaringan aplikasi.
- Dilarang menambahkan telemetry, iklan, login, backend, analytics, atau dependency network-first tanpa persetujuan.
- Algoritma background removal MVP harus deterministik dan klasik. Jelaskan keterbatasan untuk latar kompleks; jangan membuat klaim kualitas yang tidak bisa dibuktikan.
- Integrasi WhatsApp harus mempertahankan konfirmasi pengguna dan mengikuti kontrak resmi yang tersedia.

## 4. Alur Kerja untuk Setiap Task

### Langkah A — Pilih task

- Pilih task terkecil yang tidak melanggar urutan dependency di `ARCHITECTURE.md`.
- Jika belum ada ID task, buat task di `TODO.md` dengan acceptance criteria sebelum implementasi.
- Jangan mengerjakan beberapa task besar sekaligus.

### Langkah B — Rencana

- Nyatakan scope, file/modul kemungkinan terdampak, dependency, rencana test, dan risiko.
- Untuk task kecil, rencana boleh singkat dan langsung dilanjutkan.
- Ajukan pertanyaan hanya untuk keputusan penting yang belum didefinisikan. Jangan tanya ulang hal yang sudah dijawab di dokumen.

### Langkah C — Pemeriksaan awal

- Periksa `git status` dan diff yang sudah ada.
- Kenali versi SDK, struktur project, dan implementasi yang berlaku.
- Jangan hapus atau overwrite pekerjaan pengguna.
- Verifikasi API/dependency/native contract berdasarkan dokumentasi terbaru bila menyangkut kompatibilitas atau perilaku eksternal.

### Langkah D — Implementasi

- Buat perubahan paling kecil yang menyelesaikan task.
- Tambahkan test bersama kode, bukan ditunda sampai akhir proyek.
- Jangan melakukan refactor besar di luar scope.
- Jangan menambahkan dependency tanpa alasan dan pemeriksaan lisensi/kompatibilitas.
- Jangan memanggil network, file system, atau algoritma mahal dari `build()`.

### Langkah E — Verifikasi

Sesuai perubahan, jalankan:

```bash
dart format --set-exit-if-changed <changed-dart-files>
flutter analyze
flutter test
flutter build apk --debug
```

Tidak semua command harus dijalankan untuk setiap edit teks atau task dokumentasi, tetapi setiap klaim hasil wajib sesuai command yang benar-benar dijalankan. Jalankan test terarah lebih dulu jika suite penuh lambat. Untuk task image export, verifikasi output nyata: dimensi, format, alpha, ukuran byte. Untuk WhatsApp, bedakan unit test dengan uji perangkat sebenarnya.

### Langkah F — Review dan dokumentasi

- Periksa `git diff` untuk memastikan tidak ada file sensitif atau perubahan tidak terkait.
- Pastikan acceptance criteria dipenuhi.
- Update `TODO.md` sesuai bukti. Jika ada keputusan arsitektur baru, update `ARCHITECTURE.md`.
- Laporkan ringkasan, file berubah, command/test dan hasil, keterbatasan, serta task berikutnya yang masuk akal.

## 5. Kapan Agent Boleh Berjalan Sendiri

Agent boleh menentukan detail implementasi tanpa meminta izin jika semua kondisi ini terpenuhi:

- Keputusan sudah berada dalam scope PRD dan architecture.
- Perubahan lokal, reversibel, dan tidak destruktif.
- Tidak menambahkan akses jaringan, data collection, dependency berisiko, atau AI/ML runtime.
- Acceptance criteria jelas dan dapat diuji.
- Tidak ada konflik dengan perubahan pengguna atau instruksi eksplisit.

Contoh: memperbaiki bug lokal, menulis unit test, menyesuaikan widget dengan pola yang sudah dipilih, atau membuat helper privat yang sederhana.

## 6. Kapan Wajib Minta Izin

Jangan melakukan perubahan berikut sebelum mendapat persetujuan eksplisit:

1. Menambahkan fitur di luar scope MVP atau mengubah UX penting.
2. Memasukkan AI/ML, model, layanan web/API, upload, analytics, iklan, akun, atau backend.
3. Mengubah database atau format dokumen proyek dengan migrasi yang berpotensi kehilangan data.
4. Mengganti state management, arsitektur utama, database, atau library inti setelah keputusan ditetapkan.
5. Menambahkan dependency dengan lisensi, maintenance, atau praktik privasi yang tidak jelas.
6. Mengubah Android application ID, signing, izin sensitif, manifest contract, atau native integration secara luas.
7. Menjalankan operasi destruktif, menghapus data, menghapus file yang dibuat pengguna, atau mengubah banyak file tak terkait.
8. Membuat klaim kompatibilitas WhatsApp ketika kontrak atau pengujian aktual belum tersedia.

Jika perubahan dibutuhkan untuk memperbaiki blocker keamanan/data loss, jelaskan dampaknya dan minta persetujuan; jangan diam-diam melewati aturan.

## 7. Definition of Done

Task hanya boleh diubah menjadi `DONE` jika:

- Semua acceptance criteria task di `ARCHITECTURE.md` terpenuhi.
- Test relevan ditambahkan/diubah dan lulus, atau blocker test yang tidak dapat dijalankan dicatat secara jelas.
- Formatter/analyzer relevan dijalankan; issue baru tidak dibiarkan tanpa alasan.
- Tidak ada perubahan tidak terkait, data pengguna tertimpa, atau klaim test palsu.
- Tidak ada pelanggaran larangan AI/ML runtime atau pemrosesan gambar melalui jaringan.
- Dokumentasi dan `TODO.md` sesuai dengan kondisi aktual.
- Untuk fitur yang membutuhkan WhatsApp, keberhasilan unit test tidak boleh disebut sebagai bukti bahwa add-to-WhatsApp bekerja end-to-end jika belum diuji pada perangkat/emulator dengan WhatsApp.

## 8. Status Task

- `TODO`: belum dimulai.
- `IN_PROGRESS`: sedang dikerjakan.
- `BLOCKED`: terhambat oleh keputusan, dependency, lingkungan, atau verifikasi yang belum tersedia. Sertakan alasan dan langkah membuka blocker.
- `DONE`: acceptance criteria diverifikasi.

Tidak boleh menandai seluruh milestone DONE hanya karena kode berhasil dikompilasi.

## 9. Format Laporan Akhir Agent

```text
Task: [TASK-ID] — [judul]
Status: [DONE | IN_PROGRESS | BLOCKED]
Ringkasan:
- ...

File berubah:
- ...

Verifikasi:
- `command` — [PASS/FAIL/TIDAK DIJALANKAN dan alasan]

Acceptance criteria:
- [kriteria] — [bukti/status]

Risiko atau keterbatasan:
- ...

TODO.md:
- [status yang disarankan dan alasan]

Task berikutnya:
- [ID task yang dependency-nya sudah terpenuhi]
```

## 10. Prinsip Akhir

Utamakan implementasi yang dapat dipahami developer lain daripada kecepatan menghasilkan banyak kode. Bila requirement tidak bisa dipenuhi dengan algoritma non-ML, jelaskan keterbatasan dan tawarkan alternatif klasik yang dapat diuji; jangan diam-diam melanggar batas produk.
