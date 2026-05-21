# DOKUMENTASI PROJECT INDIRECT

## HALAMAN COVER

**Judul Project:** StoreHSK

**Deskripsi Singkat:** Aplikasi Flutter untuk manajemen stok toko, penjualan, laporan keuangan harian, notifikasi stok, dan asisten AI berbasis Firebase.

**Link cover:** https://canva.link/r8z09uzzkjuaqmx

## LEMBAR PENGESAHAN

Format lembar pengesahan mengikuti template pada lampiran. Data yang belum tersedia di source code:
- Nama mahasiswa dan NIM
- Nama dosen pengampu
- NIDN dosen pengampu

## KATA PENGANTAR

Dokumen ini disusun berdasarkan hasil penelusuran source code proyek StoreHSK. Aplikasi ini dikembangkan sebagai sistem digital untuk membantu pencatatan stok, transaksi penjualan, laporan keuangan harian, dan interaksi pengguna melalui AI assistant.

## DAFTAR ISI

Sesuaikan dengan isi laporan final.

## DAFTAR GAMBAR

Jika digunakan, isi dengan screenshot antarmuka aplikasi, diagram sistem, dan alur proses utama.

## DAFTAR TABEL

Jika digunakan, isi dengan tabel kebutuhan, tabel database, dan tabel pengujian.

## DAFTAR LAMPIRAN

Jika digunakan, isi dengan bukti kontribusi, screenshot sistem, tautan repo, tautan deployment, dan video demo.

# BAB I PENDAHULUAN

## 1.1 Latar Belakang

Berdasarkan source code, proyek StoreHSK dibuat untuk membantu toko atau usaha kecil dalam mengelola stok barang, mencatat penjualan, menghitung laba, dan menyimpan laporan keuangan harian secara terstruktur. Sistem juga menyediakan barcode scanner, notifikasi stok menipis, penyimpanan cloud melalui Firebase, serta AI assistant untuk membantu analisis dan tanya jawab operasional.

## 1.2 Rumusan Masalah

- Bagaimana mencatat stok, penjualan, dan laporan keuangan secara terpusat?
- Bagaimana memudahkan input barang dan penjualan melalui barcode scanner dan form cepat?
- Bagaimana menampilkan laporan keuangan harian yang mudah dibaca?
- Bagaimana memberi peringatan stok menipis dan stok habis secara otomatis?
- Bagaimana menyediakan asisten AI untuk membantu pengguna memahami data operasional?

## 1.3 Tujuan Project

- Membangun aplikasi manajemen toko berbasis Flutter.
- Menyediakan pencatatan stok dan penjualan berbasis Firebase Firestore.
- Menghasilkan laporan keuangan harian dari data yang dicatat.
- Menyediakan notifikasi stok menipis dan stok habis.
- Menyediakan AI chatbot untuk membantu pengguna berinteraksi dengan data bisnis.

## 1.4 Manfaat Project

- Mempermudah pencatatan stok barang dan transaksi penjualan.
- Mengurangi risiko kesalahan hitung manual.
- Mempercepat pembuatan laporan keuangan harian.
- Memberikan peringatan stok secara real-time.
- Membantu pengambilan keputusan melalui AI assistant dan ringkasan data.

## 1.5 Batasan Project

- Aplikasi fokus pada manajemen stok, penjualan, dan laporan keuangan harian.
- Data utama disimpan di Firebase Firestore.
- Target platform mengikuti dukungan Flutter: Android, iOS, web, macOS, Windows, dan Linux.
- Fitur AI bergantung pada layanan Firebase AI.
- Tidak ditemukan informasi authentication/login pada source code yang diperiksa.

# BAB II PROFIL PROJECT

## 2.1 Nama dan Deskripsi Sistem

Nama sistem pada repository adalah StoreHSK. Sistem ini merupakan aplikasi manajemen toko yang menggabungkan fitur stok barang, penjualan, laporan keuangan harian, notifikasi stok, pemindaian barcode, pengaturan aplikasi, dan AI chatbot.

## 2.2 Target Pengguna

- Pemilik toko
- Admin atau kasir toko
- Pengguna yang bertugas mencatat stok dan transaksi
- Pengguna yang membutuhkan ringkasan operasional berbasis AI

## 2.3 Teknologi yang Digunakan

- Flutter
- Dart 3.10.8
- Forui untuk komponen UI
- Firebase Core
- Cloud Firestore
- Firebase Messaging
- Flutter Local Notifications
- Firebase AI
- Camera
- Google ML Kit Barcode Scanning
- Image Picker
- Speech to Text
- Shared Preferences
- Permission Handler
- Intl untuk formatting rupiah dan tanggal
- fl_chart untuk grafik
- gap untuk spacing UI

## 2.4 Tim Pengembang

Data tim pengembang tidak ditemukan di source code repository. Isi manual pada laporan akhir.

# BAB III ANALISIS KEBUTUHAN

## 3.1 Analisis Masalah

Aplikasi dirancang untuk mengatasi pencatatan stok dan keuangan yang masih manual. Dari kode terlihat adanya kebutuhan untuk menyatukan data stok, penjualan, laporan keuangan harian, serta notifikasi otomatis agar pengelolaan toko lebih efisien.

## 3.2 Kebutuhan Fungsional

- Menampilkan dashboard laporan keuangan harian.
- Memilih tanggal laporan melalui kalender.
- Menambahkan laporan keuangan melalui form manual.
- Menyimpan data laporan keuangan ke Firestore.
- Menghitung laba bersih harian dari uang awal, penghasilan, dan pengeluaran.
- Membagi laba ke empat pos: modal awal, bagi hasil, pram, dan tab rollo.
- Menambahkan stok barang baru melalui dialog cepat.
- Mengubah stok ketika terjadi penjualan.
- Memindai barcode untuk menemukan barang.
- Menampilkan AI chatbot untuk tanya jawab operasional.
- Mengatur tema gelap/terang, warna tema, ukuran font, dan preferensi notifikasi.
- Mengirim notifikasi stok habis atau stok menipis.

## 3.3 Kebutuhan Non-Fungsional

- Antarmuka responsif berbasis Flutter.
- Penyimpanan data cloud dan sinkronisasi real-time melalui Firestore.
- Dukungan lintas platform Flutter.
- Penggunaan permission perangkat untuk kamera, mikrofon, dan notifikasi.
- Format angka dan tanggal sesuai konteks Indonesia.
- Pengelolaan preferensi lokal agar setelan tersimpan.

# BAB IV PERANCANGAN SISTEM

## 4.1 Flowchart Sistem

Alur utama sistem berdasarkan source code:
1. Pengguna membuka aplikasi.
2. Firebase diinisialisasi.
3. Aplikasi menampilkan navigasi utama.
4. Pengguna memilih Home, AI, atau Settings.
5. Pada Home, pengguna melihat laporan keuangan berdasarkan tanggal.
6. Pengguna dapat menambah laporan melalui form manual.
7. Data disimpan ke Firestore dan ditampilkan kembali secara real-time.
8. Pada modul stok dan penjualan, barcode scanner dapat membuka form barang baru atau form penjualan.
9. Sistem mengirim notifikasi saat stok menipis atau habis.

## 4.2 Use Case Diagram

Use case utama yang dapat digambarkan:
- Melihat laporan keuangan harian
- Menambah laporan keuangan
- Mengelola stok barang
- Memindai barcode
- Mencatat penjualan
- Melihat notifikasi stok
- Menggunakan AI chatbot
- Mengubah preferensi aplikasi

## 4.3 Activity Diagram

Aktivitas utama yang terlihat pada kode:
- Pengisian laporan keuangan: pilih tanggal -> isi uang awal/penghasilan/pengeluaran -> hitung laba -> simpan ke Firestore.
- Penjualan barang: pindai barcode -> cek barang di database -> buka form jual atau tambah barang -> simpan transaksi -> update stok.
- Pengaturan aplikasi: ubah mode tema/warna/font -> simpan ke SharedPreferences.

## 4.4 Desain Database

### Koleksi `stocks`
Field utama pada model `Stocks`:
- `itemName`
- `itemCount`
- `itemDate`
- `description`
- `category`
- `stockPrice`
- `sellPrice`
- `unit`
- `barcode`
- `lowStockThreshold`
- `createdAt`
- `updatedAt`

### Koleksi `sales`
Field utama pada model `Sale`:
- `itemId`
- `itemName`
- `quantitySold`
- `stockPrice`
- `sellPrice`
- `profit`
- `saleDate`
- `createdAt`

### Koleksi `financeEntries`
Field utama pada model `FinanceEntry`:
- `date`
- `uangAwal`
- `penghasilan`
- `pengeluaran`
- `labaBersihHarian`
- `modalAwal`
- `bagiHasil`
- `pram`
- `tabRollo`
- `createdAt`

## 4.5 Desain UI/UX

Komponen UI utama yang ada di source:
- Navigation bottom bar dengan 3 tab: Home, AI, Settings
- Dashboard laporan keuangan harian
- Kalender garis untuk memilih tanggal
- Kartu ringkasan keuangan
- Sheet form entri manual
- Dialog cepat untuk tambah barang dan jual barang
- AI chat screen dengan voice input
- Halaman settings untuk tema dan preferensi

# BAB V IMPLEMENTASI SISTEM

## 5.1 Implementasi Frontend

Implementasi frontend ditemukan pada:
- `lib/main.dart`
- `lib/widgets/navigation.dart`
- `lib/screens/home.dart`
- `lib/screens/AI_chatbot.dart`
- `lib/screens/settings.dart`
- `lib/widgets/item_form.dart`
- `lib/widgets/sell_form.dart`
- `lib/widgets/quick_item_dialog.dart`
- `lib/widgets/quick_sell_dialog.dart`
- `lib/screens/camera_scanner.dart`

Fitur frontend utama:
- Tema gelap/terang dengan beberapa pilihan warna.
- Dashboard laporan keuangan berdasarkan tanggal.
- Sheet form untuk input laporan keuangan.
- Chat AI dengan dukungan teks dan suara.
- Form cepat untuk stok dan penjualan.
- Kamera scanner untuk barcode.

## 5.2 Implementasi Backend

Backend pada proyek ini menggunakan Firebase dan service layer Dart:
- `FirebaseService` untuk stok barang.
- `SalesService` untuk transaksi penjualan.
- `FinanceService` untuk laporan keuangan.
- `AIService` untuk komunikasi dengan Firebase AI.
- `NotificationService` untuk push notification dan local notification.
- `PreferencesService` untuk setelan aplikasi.

## 5.3 Implementasi Database

Database yang dipakai adalah Cloud Firestore. Data tersimpan pada tiga koleksi utama: `stocks`, `sales`, dan `financeEntries`. Setiap koleksi menggunakan timestamp/date untuk filter per tanggal dan update real-time.

## 5.4 Fitur Utama Sistem

- Manajemen stok barang
- Pencatatan penjualan
- Perhitungan laba transaksi
- Laporan keuangan harian
- Pembagian laba ke empat pos
- Barcode scanning
- Peringatan stok habis/menipis
- AI assistant dengan tool calling ke data inventaris dan penjualan
- Pengaturan tema, warna, font, dan notifikasi

# BAB VI PENGUJIAN SISTEM

## 6.1 Metode Pengujian

Berdasarkan repository, belum ditemukan folder test otomatis. Pengujian yang paling relevan adalah pengujian manual berbasis skenario fitur.

## 6.2 Hasil Pengujian

Contoh hasil uji yang sesuai dengan implementasi:
- Input laporan keuangan berhasil tersimpan ke Firestore.
- Data laporan tampil sesuai tanggal yang dipilih.
- Penjualan mengurangi stok dan menambahkan data pada koleksi `sales`.
- Barcode yang dikenali membuka dialog barang atau dialog jual.
- Perubahan stok ke nol atau melewati ambang batas memicu notifikasi.
- Pengaturan tema dan font tersimpan setelah aplikasi dibuka ulang.

## 6.3 Evaluasi Sistem

Sistem sudah mengintegrasikan pencatatan stok, penjualan, dan laporan keuangan dalam satu aplikasi. Area yang masih bisa ditingkatkan adalah validasi data yang lebih ketat, pengujian otomatis, serta penambahan dashboard analitik yang lebih lengkap.

# BAB VII HASIL DAN PEMBAHASAN

## 7.1 Hasil Implementasi

Hasil utama yang terlihat dari source code adalah aplikasi Flutter dengan navigasi sederhana namun lengkap, dukungan Firebase untuk penyimpanan data, barcode scanner, notifikasi stok, dan AI assistant untuk membantu pengguna berinteraksi dengan data operasional.

## 7.2 Kelebihan Sistem

- Data terpusat di Firebase.
- Ada pencatatan stok dan penjualan yang saling terhubung.
- Ada laporan keuangan harian yang langsung dihitung.
- Ada notifikasi stok otomatis.
- Ada AI assistant dan voice input untuk kemudahan interaksi.
- UI menggunakan Forui sehingga konsisten dan modern.

## 7.3 Kekurangan Sistem

- Belum ditemukan autentikasi pengguna pada source code.
- Belum ditemukan pengujian otomatis.
- Data tim, link repository, dan deployment belum tercantum pada source code.
- Beberapa bagian AI service masih bergantung pada konfigurasi layanan eksternal.

# BAB VIII KESIMPULAN DAN SARAN

## 8.1 Kesimpulan

StoreHSK adalah aplikasi Flutter berbasis Firebase yang dirancang untuk manajemen toko, meliputi stok, penjualan, laporan keuangan harian, notifikasi, dan AI assistant. Struktur kode menunjukkan sistem sudah mengarah ke solusi operasional terintegrasi untuk toko kecil atau menengah.

## 8.2 Saran Pengembangan

- Menambahkan autentikasi pengguna dan role akses.
- Menambahkan dashboard analitik dengan grafik yang lebih lengkap.
- Menyusun pengujian otomatis untuk fitur utama.
- Menambahkan backup dan export data ke file PDF/Excel.
- Menyediakan halaman riwayat transaksi yang lebih detail.
- Menyempurnakan dokumentasi repository, deployment, dan kontribusi tim.

# DAFTAR PUSTAKA

Flutter. (n.d.). *Flutter documentation*. https://docs.flutter.dev/

Google. (n.d.). *Firebase documentation*. https://firebase.google.com/docs

Google. (n.d.). *Cloud Firestore documentation*. https://firebase.google.com/docs/firestore

Google. (n.d.). *Firebase AI documentation*. https://firebase.google.com/docs/ai

Google. (n.d.). *ML Kit barcode scanning documentation*. https://developers.google.com/ml-kit

ForUI. (n.d.). *ForUI package documentation*. https://pub.dev/packages/forui


# LAMPIRAN

1. Bukti kontribusi tim: belum tersedia di source code.
2. Screenshot sistem: ambil dari aplikasi yang sudah berjalan.
3. Link repository/GitHub: belum tercantum di source code.
4. Link deployment: belum tercantum di source code.
5. Video demo: opsional.

# FORMAT PENULISAN

- Font: Times New Roman 12
- Spasi: 1.5
- Margin kiri 4 cm, kanan 3 cm, atas 3 cm, bawah 3 cm

# DATA RINGKAS HASIL PEMETAAN SOURCE CODE

## Identitas Project
- Nama package: `storehsk`
- Nama aplikasi web: `storehsk`
- Firebase project: `storehsk-94540`
- Bundle iOS/macOS: `com.example.storehsk`

## Teknologi Inti dari `pubspec.yaml`
- Flutter SDK
- Forui
- fl_chart
- camera
- image_picker
- google_mlkit_barcode_scanning
- path_provider
- firebase_core
- cloud_firestore
- firebase_messaging
- flutter_local_notifications
- intl
- shared_preferences
- speech_to_text
- permission_handler
- firebase_ai

## Koleksi Firestore yang Terlihat
- `stocks`
- `sales`
- `financeEntries`

## Modul Utama pada Source Code
- `lib/screens/home.dart`
- `lib/screens/AI_chatbot.dart`
- `lib/screens/settings.dart`
- `lib/screens/camera_scanner.dart`
- `lib/widgets/navigation.dart`
- `lib/widgets/item_form.dart`
- `lib/widgets/sell_form.dart`
- `lib/widgets/quick_item_dialog.dart`
- `lib/widgets/quick_sell_dialog.dart`
- `lib/services/firebase_service.dart`
- `lib/services/sales_service.dart`
- `lib/services/finance_service.dart`
- `lib/services/ai_service.dart`
- `lib/services/notification_service.dart`
- `lib/services/preferences_service.dart`
