# Data awal (seed): spot kerja di Bali

Template untuk mengisi data awal SpotKerja dari pengalaman kunjunganmu sendiri.
Nanti file ini dibaca oleh script import yang mencocokkan setiap baris dengan
OpenStreetMap (untuk koordinat) lalu memasukkannya ke Supabase.

## Cara mengisi

1. Buka [Google Sheets](https://sheets.google.com) → **File → Import → Upload**
   → pilih `spots_bali_template.csv` → *Separator type: Comma*.
2. Isi satu baris per tempat. **Hapus dua baris `(CONTOH)`** (atau biarkan,
   script import akan melewatinya).
3. Selesai: **File → Download → Comma-separated values (.csv)**, lalu simpan
   sebagai `seed/spots_bali.csv` (tanpa kata *template*).

4. Cek isinya sebelum di-import:

   ```bash
   python3 tool/validate_seed.py seed/spots_bali.csv
   ```

   Script ini menunjukkan baris mana yang salah (nilai tidak dikenal, format
   tanggal/jam keliru, review belum lengkap, nama duplikat).

> Excel dengan pengaturan bahasa Indonesia sering memakai titik koma (`;`)
> sebagai pemisah, sehingga kolomnya bisa berantakan. Google Sheets lebih aman.

Keterangan kolom **Wajib?**:
- ✅ selalu wajib: `nama_tempat`, `area`, `kategori`
- ⭐ wajib **kalau memberi review**: `bulan_kunjungan`, keempat rating
  (`wifi`, `colokan`, `tenang`, `nyaman`), dan `keramaian`. Isi keenamnya,
  atau kosongkan keenamnya (tempat masuk tanpa review). Sama seperti di app,
  review baru sah kalau semua rating & keramaian terisi.

**Kolom kosong boleh** untuk semua yang opsional. Lebih baik dikosongkan daripada
ditebak, karena di app atribut yang kosong ditampilkan sebagai "Belum ada info".

## Kolom

| Kolom | Wajib? | Isi | Contoh |
|---|---|---|---|
| `nama_tempat` | ✅ | Nama persis seperti di papan nama / Google Maps | `Kopi Sawah Workspace` |
| `area` | ✅ | Daerah | `Canggu`, `Ubud`, `Denpasar`, `Seminyak`, `Sanur`, `Kuta`, `Jimbaran`, `Uluwatu` |
| `kategori` | ✅ | `kafe` · `coworking` · `roastery` | `kafe` |
| `bulan_kunjungan` | ⭐ | Perkiraan kunjungan terakhir, format `TAHUN-BULAN` | `2026-08` |
| `wifi` | ⭐ | Kualitas WiFi 1–5 | `4` |
| `speed_mbps` | | Hasil speed test, **hanya kalau benar-benar pernah mengukur** | `45` |
| `colokan` | ⭐ | Kemudahan dapat stopkontak 1–5 | `5` |
| `tenang` | ⭐ | Ketenangan 1–5 (5 = sangat tenang) | `3` |
| `nyaman` | ⭐ | Kursi & meja untuk kerja lama 1–5 | `4` |
| `keramaian` | ⭐ | Biasanya: `sepi` · `sedang` · `ramai` | `sedang` |
| `harga_per_orang` | | Perkiraan pengeluaran makan/minum per orang, dalam Rupiah: `35000`, `35.000`, atau `35rb` | `35rb` |
| `jam_buka` | | Format 24 jam, `08:00` atau `8:00` | `08:00` |
| `jam_tutup` | | Format 24 jam `HH:MM`, buka 24 jam → `00:00` dan `24:00` | `22:00` |
| `rokok` | | `bebas_rokok` · `area_terpisah` · `boleh_merokok` | `bebas_rokok` |
| `tempat_duduk` | | `indoor_ac` · `outdoor` · `keduanya` | `keduanya` |
| `parkir_motor` | | Parkir motor mudah? `ya` · `tidak` | `ya` |
| `duduk_lama` | | `bebas` · `minimum_order` · `dibatasi_waktu` | `bebas` |
| `jam_ramai` | | Satu atau lebih dari `pagi` `siang` `sore` `malam`, pisahkan dengan `;` | `siang;sore` |
| `komentar` | | Catatan bebas (maks. 280 karakter) | `Ramai saat sunset` |
| `link_maps_pribadi` | | Link Google Maps untuk **referensimu sendiri** saat mencocokkan lokasi. Tidak ditampilkan di app. | |

## Import ke Supabase

Setelah validator menampilkan ✅:

1. **Pratinjau** (tidak menulis apa pun, aman dicoba berkali-kali):

   ```bash
   python3 tool/import_seed.py seed/spots_bali.csv
   ```

   Hasilnya daftar setiap tempat beserta asal koordinatnya:
   - 📍 dari link Google Maps-mu (kolom `link_maps_pribadi`)
   - 🗺️ dari OpenStreetMap (nama mirip + dekat pusat area)
   - ⚠️ ada beberapa tempat bernama mirip (misalnya jaringan seperti Starbucks).
     Cek apakah cabangnya benar, kalau salah isi `link_maps_pribadi`.
   - ❌ tidak ditemukan. Isi `link_maps_pribadi`, lalu jalankan lagi.

2. **Siapkan secret key** (sekali saja):

   ```bash
   cp .env.example .env
   ```

   Isi `SUPABASE_URL` dan `SUPABASE_SERVICE_ROLE_KEY` (secret key `sb_secret_...`
   dari Supabase → Project Settings → API Keys). File `.env` diabaikan Git.

3. **Tulis ke Supabase**:

   ```bash
   python3 tool/import_seed.py seed/spots_bali.csv --apply
   ```

Aman dijalankan ulang setelah CSV diperbaiki: tempat yang sudah ada **diperbarui**
(tidak dobel), dan review data awalnya **diganti** dengan isian terbaru.

Nama tempat disimpan **persis seperti yang kamu tulis** di CSV, jadi perhatikan
huruf besar-kecilnya. Area yang dikenali untuk pencarian koordinat:
Canggu, Berawa, Pererenan, Umalas, Kerobokan, Seminyak, Legian, Kuta, Denpasar,
Renon, Sanur, Jimbaran, Uluwatu, Nusa Dua, Ubud, Gianyar, Tabanan.

Menghapus **semua** data awal (misalnya untuk mengulang dari nol), di SQL Editor:

```sql
delete from public.spots where source = 'seed';  -- review ikut terhapus
```

## Aturan penting

- **Tulis dari pengalamanmu sendiri.** Jangan menyalin rating, review, atau foto
  dari Google Maps. Aturan Google melarang kontennya disimpan di database lain.
  Google Maps boleh dibuka untuk *mengingat* tempatnya saja.
- **Jujur soal waktu.** `bulan_kunjungan` dipakai untuk bobot kebaruan:
  kunjungan lama otomatis berpengaruh lebih kecil ke Work Score.
- Review dari file ini masuk sebagai **"berdasarkan kunjungan sebelumnya"**,
  bukan check-in terverifikasi.
- **Ingatan samar?** Isi kolom ✅ saja (nama, area, kategori) dan kosongkan
  sisanya. Tempatnya tetap masuk ke app, dan review-nya diisi pengunjung lain.

## Target awal

Satu area, **20–40 tempat**. Lebih baik sedikit tapi lengkap daripada banyak
tapi kosong.
