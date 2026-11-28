-- =====================================================================
-- SpotKerja: izin akses tabel untuk app
--
-- Project Supabase baru tidak lagi otomatis memberi izin ke tabel yang
-- dibuat lewat SQL, jadi izinnya ditulis eksplisit di sini.
-- RLS (di migrasi sebelumnya) tetap membatasi BARIS mana yang boleh diakses;
-- GRANT di bawah ini menentukan OPERASI apa yang boleh dicoba.
--
-- Jalankan di SQL Editor setelah 20261128000000_init.sql.
-- =====================================================================

grant usage on schema public to anon, authenticated;

-- Cabut izin bawaan yang tidak dibutuhkan app (TRUNCATE tidak tunduk pada RLS,
-- jadi lebih aman dicabut walau tidak bisa dipanggil lewat API).
revoke truncate, trigger, references
  on public.spots, public.profiles, public.reviews
  from anon, authenticated;

-- Semua orang (termasuk yang belum login) boleh membaca.
grant select on public.spots, public.profiles, public.reviews
  to anon, authenticated;

-- User login: menulis & menghapus review sendiri, mengubah profil sendiri
-- (detailnya dijaga oleh policy RLS).
grant insert, delete on public.reviews to authenticated;
grant update (display_name, avatar_url) on public.profiles to authenticated;

-- Sengaja TIDAK ada insert/update/delete untuk spots dari app:
-- data tempat hanya diisi lewat script import (service_role / secret key).
