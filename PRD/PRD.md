# Product Requirements Document (PRD)

## 1. Ringkasan Produk

**Nama sementara:** Sticker Studio  
**Platform MVP:** Android  
**Framework:** Flutter + Dart  
**Tujuan:** Membantu pengguna mengubah foto menjadi stiker WhatsApp melalui pemrosesan gambar lokal, mengedit hasilnya, menyimpan hasil, lalu menambahkan kumpulan stiker ke WhatsApp.

### Aturan produk yang tidak boleh dilanggar

- AI hanya boleh digunakan oleh agentic AI selama tahap development sebagai alat bantu menulis, memahami, menguji, atau mereview kode.
- **Aplikasi yang dikirim ke pengguna tidak boleh memakai AI/ML sama sekali**, baik melalui API, server, model on-device, TensorFlow, ONNX, ML Kit, maupun layanan inferensi lain.
- Seluruh pemrosesan gambar pada MVP berjalan lokal di perangkat menggunakan algoritma deterministik dan library pemrosesan gambar biasa.
- Tidak ada backend, akun pengguna, unggahan foto, analitik pihak ketiga, atau API key pada MVP.
- Agent tidak boleh menambahkan kemampuan AI/ML atau layanan jaringan tanpa persetujuan eksplisit pemilik proyek.

## 2. Masalah yang Diselesaikan

Membuat stiker secara manual biasanya mengharuskan pengguna berpindah aplikasi untuk menghapus latar, memotong objek, menambahkan teks, mengekspor gambar, dan mengatur paket stiker. Alur ini memakan waktu dan hasilnya bisa tidak konsisten.

Aplikasi ini menyatukan pemilihan foto, pembuatan efek stiker, pengeditan, penyimpanan lokal, dan integrasi paket WhatsApp dalam satu alur.

### Batasan penting

Penghapusan latar belakang yang rapi dari **foto dengan latar kompleks** umumnya memerlukan segmentasi yang lebih canggih. Karena aplikasi ini melarang AI/ML, MVP hanya menjanjikan penghapusan latar sederhana yang dapat dilakukan dengan algoritma klasik, misalnya latar polos/warna yang dipilih pengguna, color-distance/chroma-key, dan flood-fill dari tepi. Hasilnya tidak dijamin sempurna untuk setiap foto.

Untuk gambar yang tidak cocok, aplikasi harus memberi tahu pengguna dan menyediakan penghapusan/pemulihan manual menggunakan brush. Jangan menampilkan klaim seperti "AI background removal" atau "bekerja untuk semua foto".

## 3. Target Pengguna

### Pengguna utama

- Pengguna WhatsApp Android yang ingin membuat stiker sendiri dari foto pribadi.
- Pengguna kasual yang membutuhkan editor ringan dan mudah dipahami, bukan aplikasi desain profesional.
- Pengguna yang ingin menambahkan teks, coretan, outline, atau dekorasi ke stiker.

### Kebutuhan pengguna

- Memulai dari satu gambar tanpa perlu akun.
- Melihat preview sebelum menyimpan atau mengekspor.
- Dapat memperbaiki hasil penghapusan latar yang kurang bagus.
- Dapat menyunting kembali proyek yang disimpan.
- Menambahkan kumpulan stiker ke WhatsApp dengan alur yang jelas.

## 4. Tujuan dan Indikator Keberhasilan

### Tujuan MVP

1. Pengguna dapat memilih gambar lokal dan melihat preview.
2. Pengguna dapat membuat efek transparansi untuk latar sederhana secara offline.
3. Pengguna dapat melakukan koreksi manual, crop, menambahkan teks, coretan, dan outline.
4. Aplikasi dapat menyimpan proyek edit yang bisa dibuka kembali.
5. Aplikasi dapat menghasilkan WebP transparan yang valid dan memvalidasi spesifikasi stiker.
6. Pengguna dapat mengumpulkan stiker dan menambahkan pack ke WhatsApp melalui integrasi Android yang didukung.

### Indikator penerimaan MVP

- Semua pemrosesan gambar utama dapat dijalankan dalam mode pesawat.
- Tidak ada request jaringan buatan aplikasi untuk memproses foto.
- Ekspor berukuran tepat 512 × 512 piksel, format WebP, mempertahankan alpha/transparansi, dan ukuran file statis tidak lebih dari 100 KB.
- Proyek tersimpan dapat dibuka kembali tanpa kehilangan urutan dan properti layer.
- Semua fitur MVP memiliki unit/widget test yang relevan.
- Build debug berhasil dan pemeriksaan `flutter analyze` tidak menghasilkan issue yang belum ditangani.

## 5. Fitur Inti (MVP)

### P0 — Wajib

1. **Import gambar**
   - Pilih gambar melalui Android Photo Picker/galeri dan, jika implementasinya stabil, kamera.
   - Tangani izin, pembatalan picker, format tidak didukung, dan gambar terlalu besar.
   - Normalisasi orientasi berdasarkan EXIF sebelum pengeditan.

2. **Pembuatan transparansi lokal tanpa AI/ML**
   - Mode latar polos: pengguna memilih warna latar melalui eyedropper atau sampel tepi.
   - Gunakan color distance/threshold dan flood-fill yang terhubung ke tepi agar warna serupa di bagian dalam objek tidak otomatis selalu terhapus.
   - Sediakan pengaturan toleransi/softness jika bisa diterapkan dengan hasil yang dapat diprediksi.
   - Sediakan brush **Erase** dan **Restore** untuk memperbaiki mask/transparansi secara manual.
   - Pertahankan file sumber asli; setiap proses baru menghasilkan hasil turunan yang dapat dibatalkan.
   - Saat algoritma tidak sesuai untuk foto, tampilkan keterbatasannya dan arahkan pengguna ke koreksi manual.

3. **Editor berbasis layer**
   - Layer gambar/hasil cutout, teks, coretan, dan dekorasi sederhana.
   - Pilih layer, pindahkan, ubah ukuran, rotasi, ubah urutan, dan hapus layer.
   - Crop dan transformasi gambar.
   - Teks: konten, ukuran, warna, perataan sederhana, dan stroke/outline.
   - Coretan: warna, ketebalan brush, undo, redo, dan penghapus.
   - Tambahkan outline sederhana pada siluet jika memungkinkan melalui operasi morfologi/mask berbasis piksel tanpa ML.
   - Undo/redo untuk operasi edit utama.

4. **Proyek lokal**
   - Simpan metadata proyek dan dokumen layer ke database/file lokal.
   - Simpan aset gambar sebagai file di direktori aplikasi, bukan blob besar di tabel database.
   - Buka, ganti nama, duplikasi, dan hapus proyek.
   - Konfirmasi sebelum tindakan yang dapat menghapus pekerjaan.

5. **Ekspor stiker**
   - Render hanya isi canvas transparan, bukan warna background checkerboard preview.
   - Fit objek di dalam canvas persegi 512 × 512 tanpa merusak aspect ratio; beri margin aman.
   - Encode WebP dengan alpha.
   - Validasi dimensi, alpha, format, dan ukuran file maksimal 100 KB.
   - Jika file melebihi batas, coba kualitas/parameter kompresi yang lebih rendah hingga batas aman; jika masih gagal, tampilkan pesan dan jangan menyatakan ekspor berhasil.
   - Simpan ekspor lokal dengan opsi berbagi file yang sesuai.

6. **Paket WhatsApp**
   - Buat dan kelola paket lokal dengan nama, identifier stabil, ikon tray, dan urutan stiker.
   - Paket statis berisi minimal 3 dan maksimal 30 stiker.
   - Validasi item sebelum menampilkan aksi “Tambahkan ke WhatsApp”.
   - Implementasikan Android `ContentProvider` dan intent yang diperlukan mengikuti contoh/kontrak resmi WhatsApp Stickers.
   - Jika WhatsApp tidak terpasang atau tidak kompatibel, tampilkan penjelasan yang dapat ditindaklanjuti.
   - Jangan mengklaim satu stiker dapat ditambahkan sebagai sticker pack sebelum jumlah minimum dipenuhi.

7. **Privasi dan error handling**
   - Tidak mengunggah gambar atau proyek ke jaringan.
   - Minta izin hanya saat dibutuhkan dan jelaskan tujuannya.
   - Jangan mencatat isi gambar atau data sensitif ke log.
   - Berikan state loading, empty state, error state, dan recovery untuk proses utama.

### P1 — Setelah MVP terbukti stabil

- Preset outline, bayangan, dan bentuk dekorasi tambahan.
- Filter warna non-AI.
- Ekspor batch beberapa stiker.
- Tutorial pertama kali dan contoh canvas.
- Backup/restore lokal melalui berkas ekspor proyek.

## 6. Di Luar Scope MVP

- Semua bentuk AI/ML di runtime aplikasi, termasuk background removal berbasis neural network/model.
- API background removal, LLM, cloud inference, akun, sinkronisasi cloud, dan backend.
- Penghapusan latar berkualitas tinggi yang dijamin untuk semua jenis foto.
- Stiker animasi/video/GIF.
- Integrasi iOS.
- Marketplace, komunitas, login sosial, atau berbagi proyek melalui server aplikasi.
- Fitur generative image, prompt-to-sticker, AI caption, dan rekomendasi otomatis.
- Langganan, iklan, analytics pihak ketiga, dan in-app purchase.
- Pengiriman stiker langsung ke chat WhatsApp secara diam-diam; pengguna harus tetap mengonfirmasi tindakan pada WhatsApp.

## 7. User Journey Utama

1. Pengguna membuka aplikasi dan memilih **Buat Stiker**.
2. Pengguna memilih foto.
3. Aplikasi membuka editor dengan foto asli.
4. Pengguna memilih mode latar polos, mengambil sampel warna, atau melewati penghapusan latar.
5. Aplikasi menerapkan algoritma deterministik lokal dan menampilkan preview transparan.
6. Pengguna memperbaiki hasil dengan Erase/Restore, lalu melakukan crop dan menambahkan layer lain.
7. Pengguna menyimpan proyek yang dapat diedit kembali.
8. Pengguna mengekspor hasil sebagai WebP dan menambahkannya ke paket lokal.
9. Setelah paket berisi 3–30 stiker valid, pengguna memilih **Tambahkan ke WhatsApp** dan menyetujui konfirmasi pada WhatsApp.

## 8. Persyaratan Nonfungsional

- **Offline-first:** fungsi utama tersedia tanpa koneksi internet.
- **Privasi:** gambar hanya diproses dan disimpan lokal, kecuali pengguna sendiri memilih fitur berbagi Android.
- **Performa:** operasi berat tidak boleh memblokir UI; gunakan isolate atau worker yang sesuai untuk proses piksel.
- **Keandalan:** kegagalan proses tidak boleh merusak sumber gambar atau proyek sebelumnya.
- **Aksesibilitas:** kontrol utama memiliki label semantik, area sentuh layak, dan kontras yang cukup.
- **Pemeliharaan:** kode domain dan pemrosesan gambar tidak boleh bergantung pada widget UI.
- **Kompatibilitas:** target Android ditentukan setelah memeriksa perangkat/SDK yang tersedia; gunakan minSdk yang diperlukan oleh dependency paling ketat dan dokumentasikan alasannya.

## 9. Referensi Teknis

- WhatsApp Sticker requirements dan Android integration: https://github.com/WhatsApp/stickers/blob/main/Android/README.md
- WhatsApp Help Center: https://faq.whatsapp.com/1056840314992666
- Flutter documentation: https://docs.flutter.dev/
- Dart Image package: https://pub.dev/packages/image

Periksa ulang dokumentasi resmi pada saat implementasi karena aturan WhatsApp dan kompatibilitas library bisa berubah.
