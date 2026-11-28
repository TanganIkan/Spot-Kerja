-- =====================================================================
-- SpotKerja: izin tabel untuk service_role (secret key)
--
-- Dipakai oleh script import data awal (tool/import_seed.py).
-- service_role melewati RLS, tapi tetap butuh izin tabel, dan project
-- Supabase baru tidak memberikannya otomatis.
--
-- Jalankan di SQL Editor setelah 20261128010000_grants.sql.
-- =====================================================================

grant usage on schema public to service_role;

grant select, insert, update, delete
  on public.spots, public.reviews, public.profiles
  to service_role;

grant select on public.spots_view to service_role;

grant execute
  on function public.nearby_spots(double precision, double precision, double precision)
  to service_role;
