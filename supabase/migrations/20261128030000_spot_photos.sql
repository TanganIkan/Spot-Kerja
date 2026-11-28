-- =====================================================================
-- SpotKerja: foto dari user
--
-- User yang login bisa melampirkan maksimal 3 foto saat menulis review.
-- File foto disimpan di Supabase Storage (bucket `spot-photos`), dan
-- catatannya di tabel `spot_photos`.
--
-- Jalankan di SQL Editor setelah 20261128020000_service_role_grants.sql.
-- =====================================================================

-- 1. Tempat penyimpanan file (bucket) -----------------------------------
-- Publik untuk dibaca (foto tampil di app tanpa login), maksimal 2 MB,
-- hanya gambar. App sudah mengecilkan foto sebelum diunggah.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('spot-photos', 'spot-photos', true, 2097152,
        array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do nothing;

-- User hanya boleh mengunggah ke foldernya sendiri: "<user_id>/..."
create policy "user unggah foto ke folder sendiri" on storage.objects
  for insert to authenticated
  with check (
    bucket_id = 'spot-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

create policy "user hapus foto sendiri" on storage.objects
  for delete to authenticated
  using (
    bucket_id = 'spot-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );


-- 2. Tabel catatan foto --------------------------------------------------
create table public.spot_photos (
  id           uuid primary key default gen_random_uuid(),
  spot_id      uuid not null references public.spots on delete cascade,
  review_id    uuid not null references public.reviews on delete cascade,
  user_id      uuid not null default auth.uid() references auth.users on delete cascade,
  -- Lokasi file di bucket. URL publik dibuat oleh app dari path ini,
  -- jadi user tidak bisa menyisipkan link ke situs lain.
  storage_path text not null unique,
  -- Moderasi: admin bisa menyembunyikan foto dari Table Editor.
  is_hidden    boolean not null default false,
  created_at   timestamptz not null default now()
);

create index spot_photos_spot_idx on public.spot_photos (spot_id, created_at desc);
create index spot_photos_review_idx on public.spot_photos (review_id);

-- Maksimal 3 foto per review.
create function public.spot_photos_limit()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  if (select count(*) from public.spot_photos p where p.review_id = new.review_id) >= 3 then
    raise exception 'Maksimal 3 foto per review' using errcode = 'check_violation';
  end if;
  return new;
end;
$$;

create trigger spot_photos_limit
  before insert on public.spot_photos
  for each row execute function public.spot_photos_limit();


-- 3. Keamanan baris (RLS) ------------------------------------------------
alter table public.spot_photos enable row level security;

create policy "foto tampil untuk semua (kecuali disembunyikan)" on public.spot_photos
  for select to anon, authenticated
  using (not is_hidden);

-- Foto hanya boleh ditempel ke review milik sendiri, untuk spot yang sama,
-- dan file-nya harus ada di folder milik sendiri.
create policy "user menambah foto ke review sendiri" on public.spot_photos
  for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and storage_path like (select auth.uid())::text || '/%'
    and exists (
      select 1 from public.reviews r
      where r.id = review_id
        and r.user_id = (select auth.uid())
        and r.spot_id = spot_photos.spot_id
    )
  );

create policy "user menghapus foto sendiri" on public.spot_photos
  for delete to authenticated
  using (user_id = (select auth.uid()));


-- 4. Izin tabel ----------------------------------------------------------
grant select on public.spot_photos to anon, authenticated;
grant insert, delete on public.spot_photos to authenticated;
grant select, insert, update, delete on public.spot_photos to service_role;
