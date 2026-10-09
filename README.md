# Stikimo

Aplikasi Android Flutter untuk membuat dan mengedit stiker dengan pemrosesan gambar lokal, menyimpan proyek yang dapat diedit kembali, dan mengelola paket stiker WhatsApp.

## Status proyek

Audit, dependency, dan fondasi Flutter Android selesai. APK debug berhasil dibuka di emulator Android 16; 7 test dasar dan analyzer lulus. Implementasi fitur berlanjut mengikuti [tracker](TODO/TODO.md) dan [catatan verifikasi](docs/task_reports.md). Integrasi WhatsApp belum diverifikasi.

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
