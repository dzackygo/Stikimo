# Penyimpanan proyek lokal

TASK-DATA-01 menyimpan metadata SQLite, dokumen layer JSON versi 1, dan aset biner terpisah. Implementasi berada pada `lib/features/projects/domain/`, `LocalProjectRepository`, dan `ProjectFileStore`. Seluruh data berada pada root privat `Context.noBackupFilesDir` melalui `AppStorage.noBackupRoot()`.

```text
no_backup/
  stikimo.sqlite
  imports/...
  projects/<project-id>/
    .stikimo-project
    assets/<asset-id>.bin
    revisions/<revision-id>.json
```

SQLite dapat membuat berkas journal/WAL/SHM di sebelah database. Ekstensi aset selalu `.bin`; identitas proyek, aset, layer, dan revisi menggunakan UUIDv4. Dokumen menyimpan ID aset, role, panjang byte, dan dimensi yang relevan. Path file dibentuk oleh repository dari ID tervalidasi, bukan diambil dari JSON.

## Kontrak domain

`ProjectDocument` memuat `id`, `name`, `createdAt`, `updatedAt`, `version`, `canvasWidth`, `canvasHeight`, `sourceAssetId`, `assets`, dan `layers`. `version` adalah versi skema JSON. `SavedProject` membungkus dokumen dan `revisionId` untuk satu snapshot tersimpan; ID revisi bukan versi skema. `ProjectSummary` menyediakan identitas, nama, timestamp, dan revisi untuk daftar proyek.

Timestamp domain dinormalisasi ke UTC; JSON menggunakan ISO 8601 dengan zona waktu. Repository membuat timestamp dalam presisi milidetik, sama dengan kolom SQLite. Tanggal tidak valid, timestamp pembaruan sebelum pembuatan, versi/tipe/field tidak dikenal, referensi aset yang hilang, dan ID layer/aset duplikat menghasilkan `ProjectFailure` dengan pesan aman. Koleksi model dan byte `ProjectAssetWrite` disalin menjadi immutable agar perubahan state berikutnya tidak mengubah snapshot lama.

`ProjectRepository` menyediakan `list`, `create`, `load`, `save`, `rename`, `duplicate`, `delete`, `close`, serta `assetPath`. `save` dan `rename` menerima `SavedProject` terakhir sebagai dasar pemeriksaan konflik. `newAssets` pada `save` harus sesuai metadata yang dideklarasikan dokumen dan memakai ID baru. Identitas proyek, waktu pembuatan, dan `sourceAssetId` tidak boleh diganti melalui save.

## Kepemilikan sumber dan aset

`create` menyalin dua berkas dari `ImportedImage`: sumber asli menjadi aset role `original`, dan PNG hasil normalisasi menjadi aset role `working`. Ukuran working image saat create dibatasi 1–2048 piksel per sisi, sesuai kontrak import. Layer gambar awal diposisikan di tengah canvas 512 × 512 dengan rasio aspek dipertahankan.

Proyek memiliki salinan sendiri sebelum metadata SQLite dipublikasikan. Penggantian atau pembersihan draf di `imports/` tidak menghapus aset proyek. Repository tidak mengambil alih atau menghapus draf; lifecycle draf tetap milik layanan import, sebagaimana dijelaskan pada [dokumentasi import](image_import.md).

Aset yang sudah terdaftar tidak ditimpa, termasuk working image dan mask. Perubahan piksel disimpan dengan ID aset baru. Role yang tersedia: `original`, `working`, `mask`, dan `derived`. `sourceAssetId` wajib menunjuk role `original`; layer gambar menunjuk `working` atau `derived`, dengan mask opsional role `mask` yang dimensinya sama. Sumber asli dan working image hasil normalisasi tetap tersedia sebagai dasar operasi Restore berikutnya.

Duplikasi membuat ID proyek dan revisi baru, lalu menyalin seluruh aset yang terdaftar pada proyek asal, termasuk aset revisi lama yang masih dipertahankan. ID aset dan layer dapat tetap sama karena kepemilikannya berada dalam proyek berbeda. Dokumen aktif disalin dengan nama dan timestamp baru; berkas fisik tidak dibagi antarproyek. Riwayat JSON revisi asal tidak ikut disalin.

## Dokumen layer dan satuan koordinat

Urutan `layers` adalah urutan gambar dari bawah ke atas; tidak ada `zIndex` terpisah. Setiap layer menyimpan `id`, `content`, `centerX`, `centerY`, `width`, `height`, `rotation`, `isVisible`, dan `isLocked`. Posisi dan ukuran relatif terhadap canvas; ukuran menyimpan hasil scale, sedangkan rotasi menggunakan radian. Layer boleh berada sebagian di luar canvas.

| Payload | Data yang disimpan |
|---|---|
| `ImageLayerContent` | Referensi working/derived image, mask opsional, crop, flip X/Y, parameter background removal opsional |
| `TextLayerContent` | Teks, keluarga font sistem, ukuran font, ARGB, alignment, warna dan lebar outline opsional |
| `DrawingLayerContent` | Daftar stroke berurutan; poin, ARGB, lebar brush, opacity, tool `brush` atau `eraser` |

Crop memakai koordinat 0–1 relatif working image sebelum transformasi layer. Poin coretan memakai koordinat 0–1 relatif bidang layer; transformasi layer diterapkan saat render. Lebar brush relatif lebar bidang layer. Ukuran font dan outline teks relatif lebar canvas. Warna disimpan sebagai integer ARGB 32 bit.

`BackgroundRemovalParameters` menyimpan `algorithmVersion`, `colorArgb`, `tolerance`, `softness`, dan `edgeConnectedOnly`. Versi parameter saat ini 1; tolerance dan softness berada dalam 0–1. DATA-01 mempertahankan parameter dan mask secara round-trip. Implementasi algoritma dan kontrol edit berada pada task IMG/EDITOR berikutnya.

## Publikasi revisi dan konflik save

Database versi 1 memiliki tiga tabel: `projects` untuk metadata/pointer revisi aktif/tombstone, `project_assets` untuk metadata aset, dan `project_revisions` untuk revisi yang telah committed. Kedua tabel anak menggunakan foreign key dengan penghapusan cascade. Daftar proyek mengabaikan tombstone dan diurutkan berdasarkan pembaruan terbaru, lalu ID.

Create dan duplicate menulis serta melakukan flush pada salinan aset dahulu. JSON revisi ditulis ke `<revision-id>.tmp`, di-flush, lalu di-rename menjadi `.json`. Setelah seluruh file tersedia, satu transaksi SQLite menerbitkan metadata proyek, aset, dan revisi.

Save menulis aset baru, kemudian menerbitkan JSON revisi baru dengan pola yang sama. Transaksi SQLite mengganti pointer hanya jika ID revisi aktif masih sama dengan `SavedProject.revisionId` dan proyek belum dihapus. Pemeriksaan compare-and-swap ini menolak perubahan dari snapshot lama dengan pesan untuk membuka ulang proyek. Rename menggunakan jalur save sehingga nama pada JSON dan SQLite berubah bersama pointer revisi.

Operasi repository diurutkan dalam satu antrean per root kanonik, termasuk ketika beberapa instance repository hidup dalam proses yang sama. SQLite tetap melakukan pemeriksaan revisi di dalam transaksi. Antrean ini tidak menjanjikan koordinasi penulis dari proses atau isolate lain.

Load membaca JSON yang ditunjuk SQLite, mencocokkan identitas/nama/timestamp/sumber, lalu memeriksa metadata aset terhadap indeks dan keberadaan/panjang berkas. Pemilihan revisi tidak menggunakan nama file terbaru atau timestamp filesystem. Pemeriksaan berkas saat load belum mencakup checksum atau decode ulang piksel; perubahan isi dengan panjang byte yang sama tidak dideteksi sebagai korupsi oleh pemeriksaan tersebut.

Jika transaksi gagal sebelum commit, repository mencoba membersihkan aset/revisi baru operasi itu. Jika hasil commit tidak bisa dipastikan dari SQLite, berkas dipertahankan agar data yang mungkin sudah committed tidak terhapus. Pola ini menjaga snapshot lama pada kegagalan operasi biasa; tidak ada klaim transaksi atomik tunggal antara filesystem dan SQLite atau jaminan terhadap semua bentuk kehilangan daya/kerusakan media.

## Penghapusan dan pemulihan startup

Delete menulis tombstone `is_deleted = 1` dahulu, menghapus direktori proyek, lalu menghapus row database. Bila pembersihan gagal, operasi dapat mengembalikan error sementara tombstone tetap tersimpan; proyek tersebut sudah tidak muncul pada `list` dan tidak dapat dibuka melalui `load`. Pembukaan repository berikutnya mencoba menyelesaikan penghapusan itu.

`open` juga membersihkan aset dan JSON yang tidak terdaftar sebagai committed, berkas `.tmp`, serta direktori proyek yang belum dipublikasikan. Penghapusan direktori memerlukan UUID valid dan marker `.stikimo-project` yang berisi ID persis sama. Nama/file yang tidak cocok dengan pola milik aplikasi tidak dijadikan sasaran cleanup. Kegagalan cleanup file per proyek dapat dicoba kembali pada open berikutnya.

Root dan komponen path yang sudah ada diperiksa terhadap symlink serta lokasi di luar root kanonik. File tujuan yang sudah ada ditolak untuk mencegah penimpaan. Cleanup folder tanpa marker sesuai atau path yang gagal diverifikasi dihentikan. Detail path privat dan byte gambar tidak dimasukkan ke pesan domain.

## Batas penyimpanan dan validasi

| Data | Batas saat ini |
|---|---|
| Dokumen JSON UTF-8 | Maksimal 8 MiB, termasuk saat pembacaan streaming |
| Aset biner | 1 byte–32 MiB per berkas |
| Nama proyek | 1–80 Unicode code point setelah trim; karakter kontrol ASCII ditolak |
| Canvas dan metadata dimensi aset | 1–8192 piksel per sisi; dimensi original boleh tidak tersedia, role lain wajib memiliki pasangan dimensi |
| Isi dokumen | Maksimal 256 aset, 64 layer, 2.048 stroke total, 100.000 poin total |
| Stroke | 1–10.000 poin; lebar brush >0 sampai 1; opacity 0–1 |
| Transformasi layer | Pusat −8 sampai 8 canvas; ukuran >0 sampai 16 canvas; rotasi −10.000 sampai 10.000 radian |
| Crop dan poin coretan | 0–1; crop berdimensi positif dan tetap di dalam working image |
| Teks | Maksimal 2.000 Unicode code point; font `sans-serif`, `serif`, atau `monospace`; alignment kiri/tengah/kanan |
| Ukuran teks | Font >0 sampai 2; outline 0–0,25 dalam satuan lebar canvas |

Semua nilai pecahan wajib finite. Batas metadata dimensi bukan izin untuk melewati validator import atau jaminan kemampuan renderer pada ukuran tersebut.

Revisi yang sudah committed beserta aset terdaftarnya dipertahankan walaupun revisi aktif berubah. Belum ada garbage collection terhadap riwayat committed atau batas total penyimpanan proyek. Retensi dan pemangkasan yang aman terhadap undo/redo ditangani pada TASK-EDITOR-05; sampai saat itu save berulang dan duplikasi dapat menambah penggunaan storage. Menghapus proyek menghapus aset serta seluruh revisinya.

## Verifikasi

Pengujian domain mencakup tiga jenis layer, urutan/properti, source/mask/parameter, snapshot immutable, batas aggregate, dan penolakan JSON tidak valid. Pengujian filesystem memeriksa file/revisi serta keamanan kepemilikan/path. Pengujian Android menggunakan sqflite nyata untuk operasi repository dan pemulihan. Command, jumlah test, hasil aktual, pengecualian platform, serta bukti terbaru dicatat pada [laporan task](task_reports.md); dokumentasi ini bukan pengganti bukti run tersebut.
