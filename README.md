# Stikimo

Aplikasi Android Flutter untuk membuat dan mengedit stiker dengan pemrosesan gambar lokal, menyimpan proyek yang dapat diedit kembali, dan mengelola paket stiker WhatsApp.

## Status proyek

Fondasi, navigasi, dan import JPEG/PNG sudah berjalan di emulator Android 16. Foto sumber tetap utuh, preview dinormalisasi, dan draf aktif pulih setelah restart. Sebanyak 108 test, analyzer, serta build debug lulus. Penyimpanan proyek, editor, ekspor, dan WhatsApp berlanjut mengikuti [tracker](TODO/TODO.md) dan [catatan verifikasi](docs/task_reports.md).

## Spesifikasi proyek

- [Alur kerja dan aturan persetujuan](WORKFLOW/WORKFLOW.md)
- [Standar engineering](AGENTS/AGENTS.md)
- [Kebutuhan produk](PRD/PRD.md)
- [Arsitektur dan acceptance criteria](ARCHITECTURE/ARCHITECTURE.md)
- [Status task](TODO/TODO.md)
- [Pola prompt development](SKILL/SKILL.md)

## Privasi

Pemrosesan gambar harus berjalan lokal menggunakan algoritma klasik. Aplikasi tidak menggunakan AI/ML runtime, upload foto, backend, atau analytics.

## Toolchain

Flutter 3.47.5 / Dart 3.13.4 dan JDK 17 dipakai untuk development. Lihat [petunjuk setup dan verifikasi](docs/setup.md), [laporan audit](docs/audit/2026-10-09.md), serta [keputusan dependency](docs/dependency_decisions.md).
