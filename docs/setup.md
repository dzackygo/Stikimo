# Setup development Stikimo

Gunakan Flutter **3.47.5 / Dart 3.13.4** dan JDK **17**. Aplikasi ditargetkan ke Android, minSdk **24**, compileSdk/targetSdk **36**. Plugin JNI juga membutuhkan platform SDK **35**. Template Flutter memakai AGP **9.1.0**, Gradle **9.3.1**, Kotlin **2.4.0**, dan NDK **28.2.13676358**.

## Environment lokal Windows

Pada host pengembangan awal, SDK dipasang di direktori `develop` profile pengguna. PATH global tidak diubah. Jalankan konfigurasi berikut pada terminal PowerShell yang dipakai untuk proyek, sesuaikan path bila instalasi Anda berbeda:

```powershell
$env:JAVA_HOME = "$env:USERPROFILE\develop\jdk-17"
$env:ANDROID_HOME = "$env:USERPROFILE\develop\android-sdk"
$env:ANDROID_USER_HOME = "$env:ANDROID_HOME\.android-user"
$env:PATH = "$env:USERPROFILE\develop\flutter\bin;$env:JAVA_HOME\bin;$env:ANDROID_HOME\platform-tools;$env:PATH"
flutter --version
flutter doctor -v
```

Flutter lokal berasal dari tag resmi `3.47.5` pada revision `6a19cca56475dbfba1478ee68d7bd0c2ef891da1`; status channel `[user-branch]` pada doctor adalah konsekuensi checkout tag. Jangan menjalankan upgrade otomatis tanpa memeriksa kompatibilitas/lockfile. Visual Studio desktop bukan requirement target Android.

## Verifikasi proyek

Build pertama memasang CMake **3.22.1** untuk plugin native. Seluruh paket SDK terpasang memakai `android-sdk-license` yang sudah diterima. Doctor dapat memperingatkan tujuh lisensi katalog opsional (Google TV/XR, preview, ARM DBT, GDK, Micro XR, MIPS) yang tidak dipakai; lisensi opsional tersebut tidak diterima otomatis.

```powershell
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
flutter devices
flutter run -d <android-device-id>
```

`pubspec.lock` harus tetap dilacak di Git. `android/local.properties`, cache, SDK, build output, dan signing keys tidak dilacak. Identitas Android awal adalah `com.dzackygo.stikimo`. Signing release belum disiapkan; artifact debug bukan rilis produksi.

Pada clone baru, perintah Flutter build/run menyiapkan Gradle wrapper otomatis dari cache SDK. Perintah `android/gradlew` langsung tersedia setelah bootstrap tersebut; tidak perlu menjalankan ulang `flutter create`.

## Privasi development

Manifest utama tidak meminta INTERNET atau izin storage luas. Manifest debug/profile bawaan Flutter memakai INTERNET untuk tooling development/VM service. Fitur aplikasi tidak membuat request jaringan; pengujian mode pesawat dan audit runtime tetap diperlukan sebelum MVP dianggap selesai.

Auto Backup dinonaktifkan (`allowBackup=false`, `fullBackupContent=false`) dan semua domain cloud/device-transfer dikecualikan lewat `dataExtractionRules`. Keputusan ini mengikuti [dokumentasi Android](https://developer.android.com/identity/data/autobackup) agar file privat/SQLite tidak ikut backup otomatis. Penyimpanan aset pada TASK-DATA-01 harus memakai direktori no-backup sebagai perlindungan tambahan.

## Batas fitur saat fondasi

Theme dan tampilan awal merupakan fondasi. Import, editor, penyimpanan, export, dan add-pack dinyatakan tersedia hanya sesudah acceptance task terkait terpenuhi pada [tracker](../TODO/TODO.md). Test codec saat setup berjalan pada engine Flutter Windows, bukan bukti kompatibilitas WhatsApp.
