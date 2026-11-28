# S'Meals 🍽️

Asisten gizi dan budget makan untuk anak kos. Aplikasi Flutter yang membantu mencatat makan, menghitung target kalori, memilih menu sesuai sisa budget, dan berkonsultasi dengan AI.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-3.11-0175C2?logo=dart&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android&logoColor=white)
![AI](https://img.shields.io/badge/AI-Gemini_%2B_Groq-8E75B2)

## Fitur

### Gizi & budget

- Profil (tinggi, berat, umur, aktivitas, tujuan) dengan target kalori otomatis memakai rumus Mifflin-St Jeor
- Ringkasan kalori, makronutrien, dan budget harian
- Catatan makan harian dengan foto, riwayat, dan streak
- Rekomendasi menu berdasarkan sisa budget dan sisa kalori (skor harga, protein, gula, garam)
- Pencarian makanan dari tabel master untuk mencatat tanpa foto

### Berbasis AI

- **Chat gizi "Sona"** — streaming jawaban via Cloudflare Worker (Gemini + Groq), bisa kirim foto makanan
- **Analisis foto makanan** — estimasi kalori dan gizi dari gambar
- **Baca label gizi** — foto label kemasan diubah menjadi data gizi
- **Perencana menu** — masukkan bahan yang ada, AI menyusun rencana menu
- **Slash command** siap pakai: `/ide`, `/protein`, `/hemat`, `/kalori`, `/label`, `/camilan`, `/air`, `/sisa`, `/banding`, `/sarapan`
- **Barcode scanner** untuk produk kemasan
- **Text-to-speech** bahasa Indonesia untuk membacakan jawaban (hanya saat ditekan)

### Lainnya

- Login opsional: Google, email/password, atau lewati tanpa akun
- Sinkronisasi catatan ke Cloudflare D1 saat login (best-effort)
- Pengingat makan & minum lewat notifikasi lokal
- Dark/light mode, halaman bantuan/FAQ, dan UI Material 3

## Teknologi

| Bagian | Teknologi |
| --- | --- |
| Mobile | Flutter, Dart ^3.11.4, Material 3 |
| State & penyimpanan | Stateful widget, `shared_preferences` |
| AI | Cloudflare Worker proxy → Gemini & Groq, streaming SSE |
| Backend data | Cloudflare Worker + D1 (`/v1/foods`, sinkronisasi catatan) |
| Pendukung | `http`, `image_picker`, `image`, `google_sign_in`, `mobile_scanner`, `flutter_local_notifications`, `timezone`, `flutter_tts`, `intl` |
| Testing | `flutter_test` + `integration_test` |

## Arsitektur AI

```
Flutter app ──POST /v1/chat/completions──► Cloudflare Worker ──► Gemini
     │                                          └──────────────► Groq
     └──GET /v1/foods──────────────────────────► D1 (tabel makanan)
```

API key AI **tidak disimpan di aplikasi**. Semua panggilan melewati Worker proxy; aplikasi hanya menyimpan URL proxy dan Google OAuth client ID (identifier publik, bukan secret). Konfigurasi ada di `lib/services/ai_config.dart`.

Tanpa koneksi ke Worker, chat dan analisis foto tidak tersedia; pencatatan manual, target kalori, dan rekomendasi budget tetap berjalan lokal.

## Kebutuhan

- Flutter SDK dengan Dart ^3.11.4
- Android SDK (minSdk 21)
- Akses ke Worker proxy Sona (atau Worker milik sendiri)

## Menjalankan

```bash
flutter pub get
flutter run
```

Build APK:

```bash
flutter build apk --release
```

### Konfigurasi

Ubah `lib/services/ai_config.dart` jika memakai Worker atau OAuth client sendiri:

```dart
static const proxyBaseUrl = 'https://<worker-anda>/v1/';
static const googleServerClientId = '<client-id-anda>';
```

Jangan menaruh API key Gemini/Groq di aplikasi. Simpan sebagai secret di Cloudflare Worker.

## Struktur Proyek

```
lib/
├── data/          # SonaStore: penyimpanan lokal & sinkronisasi
├── domain/        # Logika murni: gizi, budget, menu plan, chat command
├── models/        # MealLog & model data
├── screens/       # Beranda, menu, scan, chat, catatan, profil, pengaturan
├── services/      # AI, auth, food, barcode, notifikasi, TTS
├── theme/         # Tema light/dark
└── widgets/       # Komponen & animasi bersama
test/              # Unit & widget test
integration_test/  # Integration test
```

## Testing

```bash
flutter test
flutter test integration_test
```

## Keamanan

- Tidak ada API key AI yang di-commit; kredensial hanya ada di Worker.
- Google OAuth client ID adalah identifier publik dan bukan rahasia.
- Data harian disimpan lokal di perangkat; sinkronisasi hanya berjalan setelah login.

## Lisensi

Proyek ini dibuat untuk keperluan pembelajaran dan portofolio.
