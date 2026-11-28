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
- ⭐ wajib **kalau memberi review**: `bulan_kunjungan` + keempat rating
  (`wifi`, `colokan`, `tenang`, `nyaman`). Isi kelimanya, atau kosongkan
  kelimanya (tempat masuk tanpa review). Sama seperti di app, review baru sah
  kalau keempat rating terisi.

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
| `keramaian` | | Biasanya: `sepi` · `sedang` · `ramai` | `sedang` |
| `harga` | | Per orang: `hemat` (< 30rb) · `sedang` (30–60rb) · `premium` (> 60rb) | `sedang` |
| `jam_buka` | | Format 24 jam `HH:MM` | `08:00` |
| `jam_tutup` | | Format 24 jam `HH:MM`, buka 24 jam → `00:00` dan `24:00` | `22:00` |
| `rokok` | | `bebas_rokok` · `area_terpisah` · `boleh_merokok` | `bebas_rokok` |
| `tempat_duduk` | | `indoor_ac` · `outdoor` · `keduanya` | `keduanya` |
| `parkir_motor` | | Parkir motor mudah? `ya` · `tidak` | `ya` |
| `duduk_lama` | | `bebas` · `minimum_order` · `dibatasi_waktu` | `bebas` |
| `jam_ramai` | | Satu atau lebih dari `pagi` `siang` `sore` `malam`, pisahkan dengan `;` | `siang;sore` |
| `komentar` | | Catatan bebas (maks. 280 karakter) | `Ramai saat sunset` |
| `link_maps_pribadi` | | Link Google Maps untuk **referensimu sendiri** saat mencocokkan lokasi. Tidak ditampilkan di app. | |

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
