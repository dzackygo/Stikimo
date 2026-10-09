# TODO — Local Issue Tracker

Status yang diperbolehkan: `TODO`, `IN_PROGRESS`, `BLOCKED`, `DONE`. Jangan tandai `DONE` hanya karena kode sudah dibuat; gunakan Definition of Done pada `AGENTS.md` dan acceptance criteria di `ARCHITECTURE.md`.

| ID | Task | Status | Prioritas | Depends on | Acceptance / catatan |
|---|---|---|---|---|---|
| TASK-SETUP-01 | Audit environment dan repository | DONE | P0 | — | Bukti dan blocker pada docs/audit/2026-10-09.md; belum ada toolchain/project saat audit awal. Repository kemudian dibuat dan README dipush atas instruksi pengguna. |
| TASK-SETUP-02 | Validasi dependency dan kontrak native | DONE | P0 | SETUP-01 | Sumber/lisensi/API diverifikasi; resolver dan lockfile tersedia; dua test codec engine Flutter, analyzer, format lulus. Bukti Android tetap acceptance export/provider; lihat docs/dependency_decisions.md. |
| TASK-APP-01 | Setup Flutter application, lint, theme, test | DONE | P0 | SETUP-01, SETUP-02 | 7 test, analyzer dan format PASS; APK debug dibangun, dipasang, dan dibuka di emulator API36. Bukti pada docs/task_reports.md. |
| TASK-APP-02 | Navigasi dan halaman dasar | DONE | P0 | APP-01 | Empat tujuan dan empty state; stack/AppBar/Android back serta layar 320 dp dengan teks 2× lulus widget test. |
| TASK-IMG-01 | Import dan normalisasi gambar | DONE | P0 | APP-01 | JPEG/PNG, batas input, EXIF, alpha, source immutable, cancel/error dan draft recovery teruji; 108 test PASS, APK/Photo Picker/restart API36 PASS. |
| TASK-DATA-01 | Project persistence lokal | DONE | P0 | APP-01 | CRUD, layer/mask round-trip dan source immutable; 173 test host PASS, 5 SQLite Android PASS, build dan UI restart PASS. |
| TASK-IMG-02 | Image processing service | TODO | P0 | IMG-01 | Crop/resize/rotate/flip/alpha benar; operasi berat tidak memblokir UI. |
| TASK-IMG-03 | Color-key background remover tanpa ML | TODO | P0 | IMG-02 | Test fixture latar polos lulus; keterbatasan hasil dijelaskan; tidak ada model AI/ML. |
| TASK-IMG-04 | Erase/Restore brush | TODO | P0 | IMG-03 | Mask bisa diperbaiki manual dan undo; gambar sumber tetap tersimpan. |
| TASK-IMG-05 | Outline dari alpha mask | TODO | P0 | IMG-03 | Outline mengikuti bentuk dan tidak mengisi background; wajib sesuai permintaan pengguna. |
| TASK-EDITOR-01 | Canvas dan model layer | TODO | P0 | IMG-01, DATA-01 | Layer bisa dipilih, digeser, diubah ukuran/rotasi, disusun ulang dan diserialisasi. |
| TASK-EDITOR-02 | Crop/transform dan background edit | TODO | P0 | EDITOR-01, IMG-02, IMG-04 | Tools bekerja, transformasi konsisten, undo/redo benar. |
| TASK-EDITOR-03 | Text layer | TODO | P0 | EDITOR-01 | Teks dapat diedit, ditransformasi, disimpan, dan dirender sama dengan preview. |
| TASK-EDITOR-04 | Drawing layer | TODO | P0 | EDITOR-01 | Brush, eraser, warna, ketebalan, persistensi dan rendering bekerja. |
| TASK-EDITOR-05 | Undo/redo terpadu dan recovery | TODO | P0 | EDITOR-02, EDITOR-03, EDITOR-04 | Edit utama bisa undo/redo; penggunaan memori terkendali. |
| TASK-EXPORT-01 | Render canvas transparan | TODO | P0 | EDITOR-02, EDITOR-03, EDITOR-04 | Alpha transparan dipertahankan; checkerboard UI tidak ikut ekspor. |
| TASK-EXPORT-02 | WebP export dan validasi | TODO | P0 | EXPORT-01, IMG-02 | 512×512, WebP, alpha; maksimal 100 KB atau error eksplisit. |
| TASK-EXPORT-03 | Riwayat hasil dan share sheet | TODO | P1 | EXPORT-02 | Berkas ekspor bisa ditemukan/dibagikan; cancel ditangani. |
| TASK-WA-01 | Manajemen sticker pack | TODO | P0 | DATA-01, EXPORT-02 | Pack 3–30 sticker, metadata dan tray icon valid; invalid pack ditolak. |
| TASK-WA-02 | Kotlin ContentProvider | TODO | P0 | WA-01 | Provider menyajikan metadata dan file stiker yang valid; error provider ditangani. |
| TASK-WA-03 | Integrasi intent WhatsApp | TODO | P0 | WA-02 | Add-pack diuji di perangkat dengan WhatsApp; cancel tidak dianggap sukses. |
| TASK-QA-01 | End-to-end workflow | TODO | P0 | EXPORT-03, WA-03 | Import→edit→save/reopen→export→add pack diuji dan dicatat. |
| TASK-QA-02 | Privacy, robustness, performance | TODO | P0 | APP-02, IMG-01–05, DATA-01, EDITOR-01–05, EXPORT-01–03, WA-01–03 | Mode pesawat, file besar, storage penuh, permission denied dan WhatsApp missing diuji; tidak bergantung pada QA-02 atau DOC-01. |
| TASK-DOC-01 | Dokumentasi dan handoff final | TODO | P1 | QA-01, QA-02 | Setup, dependency, test, batasan, dan status task akurat untuk developer berikutnya. |

## Catatan Perubahan Status

Tambahkan catatan singkat di bawah ini saat mengubah status task penting.

| Tanggal | ID | Perubahan | Bukti / catatan |
|---|---|---|---|
| 2026-10-09 | — | Initial planning baseline | Belum ada task development yang dinyatakan selesai. |
| 2026-10-09 | TASK-SETUP-01 | TODO → DONE | Audit pada docs/audit/2026-10-09.md. Tidak ada source atau toolchain pada kondisi awal; minSdk belum tersedia. README first commit c81c4f7 berhasil dipush ke origin/master. |
| 2026-10-09 | TASK-SETUP-02 | TODO → IN_PROGRESS | Verifikasi dependency, WebP alpha, dan kontrak WhatsApp dari sumber primer sedang dilakukan. |
| 2026-10-09 | TASK-SETUP-02 | IN_PROGRESS → DONE | pub get PASS; lockfile dilacak bersama keputusan dependency; 2 codec tests PASS, analyze no issues, format/diff check PASS. Runtime Android belum diklaim. |
| 2026-10-09 | TASK-APP-01 | IN_PROGRESS → DONE | 7 test dan analyze PASS; build APK PASS; adb install/start PASS; screenshot app01.png diperiksa, logcat AndroidRuntime/flutter error kosong. |
| 2026-10-09 | TASK-APP-02 | TODO → IN_PROGRESS → DONE | Suite awal 10 PASS; test tambahan Android back PASS (4 test navigasi); analyzer PASS, review tidak menemukan issue material. |
| 2026-10-09 | TASK-IMG-01 | TODO → IN_PROGRESS → DONE | 108 test, analyzer, format dan APK PASS. Photo Picker PNG/JPEG, source hash, cancel, replacement cleanup dan restart terverifikasi Android16; lihat docs/task_reports.md. |
| 2026-10-10 | TASK-DATA-01 | IN_PROGRESS → DONE | 173 host PASS/1 skip symlink Windows, 5 SQLite Android PASS mencakup symlink/recovery; analyzer/format/build PASS, UI CRUD dan buka ulang salinan setelah hapus asal PASS. |
