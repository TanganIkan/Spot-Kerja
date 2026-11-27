# SpotKerja — Cafe & Remote Work Spot Finder

Aplikasi mobile (Flutter) untuk menemukan kafe yang cocok untuk kerja remote,
berdasarkan hal yang penting bagi pekerja: kecepatan WiFi, colokan,
ketenangan, dan kenyamanan, bukan sekadar rating makanan.

> Status: **MVP v0.1**. Data masih data contoh (fiktif) di area Jakarta Selatan.

## Alur aplikasi

```
Buka app
  └─ Minta izin lokasi (boleh ditolak → pakai pusat area contoh)
       │
       ▼
Tab BERANDA ──────────── Tab PETA ──────────── Tab TERSIMPAN
  spot terdekat            marker = Work Score    spot yang di-bookmark
  rekomendasi/kategori     sheet daftar + filter
  "Lihat semua" → cari + filter
       │                        │                     │
       └────────────┬───────────┴─────────────────────┘
                    ▼
            DETAIL SPOT
              info, jam buka, harga, jarak
              Work Score + nilai per aspek
              WiFi & keramaian terakhir
              daftar review
              [Petunjuk arah] [🔖 Simpan] [Check-in & Review]
                    │
                    ▼
            FORM REVIEW
              rating 4 aspek (wajib), keramaian, speed WiFi (opsional), komentar
              → cek lokasi: dalam 200 m = check-in terverifikasi
              → Work Score spot langsung ter-update
```

## Desain

Terinspirasi dari referensi desain aplikasi co-working (layout & hierarki),
dengan palet warna sendiri. Semua token ada di `lib/theme/app_theme.dart`.

| Token | Warna | Dipakai untuk |
|---|---|---|
| `primary` | `#EE6200` | tombol utama, chip/tab aktif, ikon nav aktif |
| `orange` | `#FF9A00` | ikon Work Score (⚡), bintang rating |
| `peach` | `#FBA17E` | lingkaran radius di peta, track progress bar |
| `sand` | `#F7D794` | latar ikon & avatar |
| `primaryText` | `#B84C00` | teks/link oranye kecil (kontras lebih baik di atas putih) |

Prinsip: latar putih, oranye hanya untuk hal penting, foto sebagai elemen utama,
info ringkas dalam satu baris ikon (`harga · jarak · buka`).

| Layar | Isi |
|---|---|
| Beranda | sapaan + lokasi, kartu "Cari tempat lewat peta", carousel **Spot terdekat**, **Rekomendasi** per kategori |
| Detail | galeri foto bergeser, info, Work Score per aspek, WiFi & keramaian, mini map, review, tombol **Check-in & Review** |
| Peta | search bar, marker pill Work Score, lingkaran radius 1,5 km, bottom sheet daftar spot + filter |
| Tersimpan | daftar spot yang di-bookmark |

Foto dari Unsplash (lisensi gratis), daftar sumber di `assets/images/spots/CREDITS.md`.

## Batasan (aturan bisnis)

Semua angka di bawah bisa diubah di satu tempat (lihat kolom "Di mana").

| Aturan | Nilai | Di mana |
|---|---|---|
| Work Score | WiFi 35% · Colokan 25% · Ketenangan 20% · Kenyamanan 20%, skala 0–100 | `models/spot_stats.dart` |
| Bobot kebaruan review | ≤ 30 hari = 1.0 · ≤ 90 hari = 0.5 · lebih lama = 0.25 | `models/spot_stats.dart` |
| Filter "WiFi cepat" | speed test terbaru ≥ 25 Mbps | `models/spot_filter.dart` |
| Filter "Banyak colokan" / "Tenang" | rata-rata rating ≥ 4.0 | `models/spot_filter.dart` |
| Filter "Buka malam" | tutup jam 22.00 atau lebih | `models/spot.dart` |
| Check-in terverifikasi | posisi user ≤ 200 m dari spot saat kirim review | `state/spot_store.dart` |
| Anti-spam | 1 review per spot per hari per user | `state/spot_store.dart` |
| Data keramaian "basi" | dilaporkan > 3 jam lalu → diberi keterangan "mungkin sudah berubah" | `screens/spot_detail_screen.dart` |
| Speed test manual | 0–2000 Mbps | `screens/review_form_screen.dart` |
| Tanpa izin lokasi | jarak dihitung dari pusat area contoh | `state/spot_store.dart` |

### Di luar cakupan MVP (sengaja belum dibuat)

- Login / akun (semua review atas nama "Kamu", disimpan di perangkat)
- Backend online (Supabase) → review belum terlihat oleh user lain
- Speed test otomatis di dalam app
- Upload foto
- Tambah spot baru oleh user
- Marker clustering (belum perlu karena data masih sedikit)

## Struktur kode

```
lib/
├─ main.dart                  titik awal: siapkan storage, repository, state
├─ models/                    bentuk data + logika murni (mudah di-test)
│   ├─ spot.dart              data tetap tempat (nama, lokasi, jam buka)
│   ├─ review.dart            satu review / check-in
│   ├─ spot_stats.dart        hitung Work Score dari kumpulan review
│   └─ spot_filter.dart       aturan filter & urutan
├─ data/                      sumber data
│   ├─ spot_repository.dart   kontrak (interface)
│   ├─ dummy_spot_repository.dart  implementasi MVP
│   ├─ dummy_data.dart        data contoh
│   └─ local_storage.dart     simpan favorit & review di perangkat
├─ services/location_service.dart  GPS (aman kalau izin ditolak)
├─ state/                     state global (pola Provider + ChangeNotifier)
│   ├─ spot_store.dart        spot, review, filter, lokasi
│   └─ favorites_store.dart   favorit
├─ theme/app_theme.dart       design system: warna, tipografi, gaya komponen
├─ screens/                   layar-layar
└─ widgets/                   komponen UI yang dipakai ulang
```

Alur data: **Repository → Store (state) → Screen**. Layar tidak pernah
mengambil data langsung. Karena itu, mengganti data dummy dengan Supabase cukup
dilakukan di satu file.

## Menjalankan

```bash
flutter pub get
flutter run -d chrome      # preview di browser
flutter test               # unit test logika Work Score & filter
```

Untuk iOS Simulator, install Xcode dulu dari App Store, lalu `flutter run`.

## Roadmap

1. **v0.1 (sekarang)**: list, peta, filter, detail, Work Score, review, favorit
2. **v0.2**: Supabase (auth + database + PostGIS untuk query "spot dalam radius X")
3. **v0.3**: speed test otomatis, upload foto, tambah spot baru
4. **v0.4**: seed data nyata dari OpenStreetMap (Overpass API), marker clustering
