-- =====================================================================
-- SpotKerja: harga dalam Rupiah (menggantikan kategori hemat/sedang/premium)
--
-- - spots.avg_price          : perkiraan dari data awal (CSV)
-- - reviews.spend_per_person : laporan pengunjung "habis berapa per orang"
-- App menampilkan median laporan pengunjung; kalau belum ada, pakai avg_price.
--
-- Jalankan di SQL Editor setelah 20261128030000_spot_photos.sql.
-- =====================================================================

alter table public.spots
  add column if not exists avg_price integer
    check (avg_price between 1000 and 1000000);

alter table public.reviews
  add column if not exists spend_per_person integer
    check (spend_per_person between 1000 and 1000000);

-- Tambahkan avg_price ke view (kolom baru harus di urutan terakhir).
create or replace view public.spots_view
with (security_invoker = on) as
select
  s.id, s.name, s.area, s.address, s.category,
  extensions.st_y(s.location::extensions.geometry) as lat,
  extensions.st_x(s.location::extensions.geometry) as lng,
  s.open_hour, s.close_hour, s.price_level, s.description, s.photos, s.created_at,
  s.avg_price
from public.spots s;
