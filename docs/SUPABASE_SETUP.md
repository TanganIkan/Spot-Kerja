# Setup Supabase + Login Google

Panduan sekali jalan untuk menyambungkan SpotKerja ke Supabase.
Perkiraan waktu: 20–30 menit. Nama menu di dashboard bisa sedikit berbeda
dari yang tertulis di sini karena Supabase & Google rutin memperbarui tampilannya.

> **Dua jenis kunci Supabase**
> - **Publishable key** (atau *anon key*): dipakai app, aman ada di HP user.
> - **Secret key** (atau *service_role key*): kunci admin. Jangan pernah
>   di-commit, ditempel di chat, atau dimasukkan ke app.

---

## 1. Buat project Supabase

1. Buka <https://supabase.com/dashboard> → **New project**.
2. Isi:
   - **Name**: `spot-kerja`
   - **Database password**: buat password kuat dan **simpan di password manager**
   - **Region**: **Southeast Asia (Singapore)**, server terdekat dari Bali
3. **Create new project**, lalu tunggu ±2 menit sampai statusnya siap.

## 2. Buat tabel database

1. Menu kiri → **SQL Editor** → **New query**.
2. Buka file [`supabase/migrations/20261128000000_init.sql`](../supabase/migrations/20261128000000_init.sql),
   salin **seluruh** isinya, lalu tempel di editor.
3. Klik **Run**. Hasil yang diharapkan: *Success. No rows returned*.
4. Cek di **Table Editor**: harus ada tabel `spots`, `profiles`, `reviews`.

5. Ulangi langkah 1–3 untuk file kedua,
   [`supabase/migrations/20261128010000_grants.sql`](../supabase/migrations/20261128010000_grants.sql),
   yang berisi izin akses tabel untuk app.

Kalau muncul error, salin pesan errornya dan kirim ke chat. Jalankan setiap file
**hanya sekali** per project, berurutan sesuai nama file.

## 3. Isi kunci untuk app

1. **Project Settings** → **API Keys** (atau **Data API**). Salin:
   - **Project URL**, contoh `https://abcdefgh.supabase.co`
   - **Publishable key**. Kalau belum ada, pakai **anon key** di bagian *Legacy API keys*.
2. Di folder project, buat file kunci dari contohnya:

   ```bash
   cp env.example.json env.json
   ```

3. Buka `env.json` dan ganti dua nilainya. File ini **diabaikan Git**, jadi
   aman dan tidak akan ikut ter-commit.

## 4. Siapkan login Google

### 4a. Di Google Cloud Console

1. Buka <https://console.cloud.google.com> → buat project baru bernama `SpotKerja`.
2. **APIs & Services → OAuth consent screen** (bisa juga bernama *Google Auth Platform*)
   → **Get started**:
   - App name: `SpotKerja`
   - User support email & contact email: email-mu
   - Audience: **External**
3. Di bagian **Audience / Test users**, tambahkan **email Gmail-mu sendiri**.
   Selama app berstatus *Testing*, hanya test user yang bisa login.
4. **Clients → Create client**:
   - Application type: **Web application**
   - Name: `SpotKerja Supabase`
   - **Authorized redirect URIs**: salin *Callback URL* dari Supabase
     (langkah 4b nomor 2), formatnya `https://<project-ref>.supabase.co/auth/v1/callback`
5. **Create**, lalu salin **Client ID** dan **Client secret**.

### 4b. Di Supabase

1. **Authentication → Sign In / Providers → Google** → aktifkan.
2. Di halaman ini ada **Callback URL**: salin ke Google Cloud (langkah 4a nomor 4).
3. Tempel **Client ID** dan **Client secret** dari Google → **Save**.
4. **Authentication → URL Configuration**:
   - **Site URL**: `http://localhost:8080`
   - **Redirect URLs**, tambahkan dua:
     - `http://localhost:8080`
     - `com.spotkerja.app://login-callback` (untuk Android & iOS)

## 5. Jalankan app dengan Supabase

- **VS Code**: Run and Debug → pilih **"SpotKerja + Supabase (Chrome, ukuran HP)"** → F5.
- **Terminal**:

  ```bash
  flutter run -d chrome --web-port=8080 --dart-define-from-file=env.json
  ```

Port **8080** harus sama dengan yang didaftarkan di langkah 4b, supaya login
Google bisa kembali ke app.

Database masih kosong, jadi Beranda belum menampilkan spot. Itu normal: data
Bali akan masuk lewat script import di tahap berikutnya.

## 6. Uji coba cepat (opsional)

Tambahkan satu spot percobaan lewat **SQL Editor**:

```sql
insert into public.spots (name, area, category, location, open_hour, close_hour, price_level, description)
values (
  'Spot Uji Coba', 'Canggu', 'kafe',
  extensions.st_setsrid(extensions.st_makepoint(115.1385, -8.6478), 4326)::extensions.geography,
  8, 22, 2, 'Spot untuk uji coba, hapus nanti.'
);
```

Lalu, di app:

1. Muat ulang halaman, dan **Spot Uji Coba** muncul di Beranda.
2. Buka spot itu → **Check-in & Review** → muncul ajakan **Masuk dengan Google**.
3. Login, kembali ke spot, lalu kirim review.
4. Di Supabase → **Table Editor → reviews**: ada baris baru dengan
   `author_name` = nama akun Google-mu, dan `checkin_location` **kosong**
   (posisi tidak disimpan).
5. Coba kirim review kedua untuk spot yang sama di hari yang sama. App harus
   menolak (batas 1 review/hari dijaga oleh database).

Hapus spot uji coba setelah selesai:

```sql
delete from public.spots where name = 'Spot Uji Coba';
```

## Kalau ada masalah

| Gejala | Penyebab umum |
|---|---|
| App masih menampilkan data Jakarta | `env.json` belum dibuat, atau app dijalankan tanpa `--dart-define-from-file=env.json` |
| `redirect_uri_mismatch` di halaman Google | *Authorized redirect URI* di Google Cloud tidak sama persis dengan *Callback URL* Supabase |
| *Access blocked / app not verified* | Email-mu belum ditambahkan sebagai **test user** |
| Setelah login kembali ke halaman kosong / port lain | App tidak berjalan di `localhost:8080`, atau URL itu belum ada di *Redirect URLs* |
| *Unsupported provider* | Provider Google belum diaktifkan di Supabase |
