# Import gambar lokal

TASK-IMG-01 menerima **JPEG dan PNG statis**, melalui galeri/Android Photo Picker. Kamera, HEIC, GIF, WebP input, dan animasi belum ditawarkan. Plugin dipanggil tanpa resize/quality sehingga byte sumber yang diberikan picker dapat disimpan utuh. `requestFullMetadata: false` membatasi permintaan metadata plugin, bukan menghapus EXIF dari sumber.

## Batas dan normalisasi

- Input maksimal 32 MiB, 16.000.000 piksel, sisi maksimal 8192 piksel. Header diperiksa sebelum decode; pembacaan berkas juga dibatasi saat streaming.
- Normalisasi di isolate: orientasi EXIF diterapkan, rasio dipertahankan, sisi working image maksimal 2048 piksel, minimal 1 piksel.
- Working image berupa PNG RGBA8 baru, tanpa EXIF, ICC atau text chunk. Original tetap byte-identik dengan berkas pilihan. Profil warna khusus tidak dikelola; konversi ke RGBA ini tidak menjanjikan pencocokan warna profesional.
- PNG diperiksa signature/chunk/CRC, ukuran inflasi scanline, dan APNG ditolak. Metadata terkompresi tidak diteruskan ke decoder.
- JPEG memerlukan allowlist marker dan guard dimensi sebelum decoder karena pembacaan header library mengalokasikan blok DCT. EXIF/XMP sumber dibuang sebelum decode; hanya orientasi tervalidasi disisipkan kembali. APP0, profil ICC APP2, APP14 Adobe dan COM dapat diteruskan ke decoder; metadata hasil PNG tetap dibuang seluruhnya.
- Batas ini adalah kebijakan memori konservatif, bukan jaminan semua perangkat dapat memproses setiap foto. Error tidak memublikasikan hasil setengah jadi.

Library `image` 4.10.1 gagal mendekode sebagian PNG Adam7 sangat kecil (misalnya 1×1); kasus tersebut ditolak dengan pesan aman. PNG biasa, alpha 8/16-bit dan Adam7 8×8 memiliki fixture test. Tidak ada fork atau pelonggaran validator agar decoder tampak berhasil.

## Kepemilikan berkas

Channel Kotlin `com.dzackygo.stikimo/storage`, metode `noBackupPath` tanpa argumen, memberikan `Context.noBackupFilesDir`. Import menggunakan `imports/<UUIDv4>/source.bin` dan `preview.png`. Tidak memakai nama/path berkas dari metadata proyek.

`imports/current.json` versi 1 hanya mencatat UUID dan dimensi, lalu dipublikasikan dengan rename setelah kedua aset ditulis. Penggantian foto yang sukses membersihkan draf lama yang belum dimiliki proyek; cancel/error mempertahankan draf sebelumnya. Startup memulihkan draf aktif dan membersihkan direktori UUID yatim. Pembersihan bersifat best-effort bila storage gagal.

TASK-DATA-01 harus menyalin aset ke direktori proyek sebelum menyatakan proyek tersimpan; direktori `imports/` khusus draf dan dapat dibersihkan. Pemulihan draf bukan implementasi database proyek.

`retrieveLostData()` dijalankan satu kali saat Home pertama dibuat, untuk hasil picker setelah activity dihentikan Android. Hasil atau error disimpan dalam state aplikasi; pemilihan ulang diabaikan selama import berlangsung. Riwayat cancel/error tidak menghapus preview yang sudah berhasil.

## Verifikasi manual yang dapat diulang

Jalankan `dart run tool/create_import_fixtures.dart` untuk membuat fixture sintetis di `build/verification/import-fixtures/`. Salin fixture ke DCIM emulator, lakukan media scan, lalu gunakan Buat stiker → Pilih foto. PNG harus tampil 2048×1024, JPEG dengan EXIF orientation 6 harus tampil 1024×2048. Persegi berwarna memiliki alpha 180; generator memeriksa nilai ini agar bug alpha-blending fixture tidak disalahartikan sebagai bug import.

Jika isi fixture berubah, gunakan nama berkas baru di emulator. Android Photo Picker dapat mengembalikan cache dari MediaStore ID lama meskipun berkas dengan path sama ditimpa; selalu cocokkan hash sumber sebelum menilai hasil visual.

Bandingkan SHA256 sumber di host dengan `run-as com.dzackygo.stikimo sha256sum no_backup/imports/<id>/source.bin`. Uji Ganti foto → Back: preview tetap dan pesan batal tampil. Setelah restart aplikasi, draf aktif dapat dilanjutkan. Hasil command aktual dicatat pada [laporan task](task_reports.md).

Referensi primer: [kontrak image_picker dan recovery](https://pub.dev/packages/image_picker), [Android Context.noBackupFilesDir](https://developer.android.com/reference/android/content/Context#getNoBackupFilesDir()), serta source package terpin pada lockfile. Tidak ada proses atau unggahan foto melalui jaringan aplikasi.
