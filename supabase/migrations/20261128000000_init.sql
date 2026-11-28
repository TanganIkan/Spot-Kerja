-- =====================================================================
-- SpotKerja: skema awal database
--
-- Cara menjalankan: Dashboard Supabase -> SQL Editor -> New query ->
-- tempel seluruh isi file ini -> Run. Aman dijalankan sekali di project baru.
--
-- Isi:
--   1. PostGIS (untuk query berbasis lokasi)
--   2. Tabel: spots, profiles, reviews
--   3. Aturan bisnis di sisi server (check-in terverifikasi, 1 review/hari)
--   4. Keamanan baris (RLS): siapa boleh baca/tulis apa
--   5. View & fungsi yang dipanggil app
-- =====================================================================

-- 1. PostGIS -----------------------------------------------------------
create extension if not exists postgis with schema extensions;


-- 2. Tabel ---------------------------------------------------------------

-- Tempat kerja (kafe, co-working, roastery).
create table public.spots (
  id          uuid primary key default gen_random_uuid(),
  name        text not null check (char_length(name) between 1 and 120),
  area        text not null,
  address     text not null default '',
  category    text not null check (category in ('kafe', 'coworking', 'roastery')),
  location    extensions.geography(point, 4326) not null,
  open_hour   smallint check (open_hour between 0 and 23),   -- null = belum diketahui
  close_hour  smallint check (close_hour between 1 and 24),  -- 24 = tengah malam
  price_level smallint check (price_level between 1 and 3),  -- 1 hemat, 2 sedang, 3 premium
  description text not null default '',
  photos      text[] not null default '{}',                  -- URL foto
  osm_id      text unique,                                   -- id OpenStreetMap, contoh 'node/123'
  source      text not null default 'seed' check (source in ('seed', 'osm', 'user')),
  created_at  timestamptz not null default now()
);

-- Index spasial: membuat query "spot dalam radius X" tetap cepat.
create index spots_location_idx on public.spots using gist (location);

-- Profil publik user (nama & foto dari akun Google).
create table public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  display_name text not null,
  avatar_url   text,
  created_at   timestamptz not null default now()
);

-- Review / check-in. Nilai enum memakai nama yang sama dengan kode Dart.
create table public.reviews (
  id               uuid primary key default gen_random_uuid(),
  spot_id          uuid not null references public.spots on delete cascade,
  user_id          uuid references auth.users on delete set null default auth.uid(),
  author_name      text not null default 'Pengguna',
  wifi             smallint not null check (wifi between 1 and 5),
  power            smallint not null check (power between 1 and 5),
  quiet            smallint not null check (quiet between 1 and 5),
  comfort          smallint not null check (comfort between 1 and 5),
  crowd            text not null check (crowd in ('sepi', 'sedang', 'ramai')),
  wifi_speed_mbps  numeric check (wifi_speed_mbps > 0 and wifi_speed_mbps <= 2000),
  comment          text not null default '' check (char_length(comment) <= 280),

  -- Atribut lokal (opsional)
  smoking          text check (smoking in ('smokeFree', 'separateArea', 'allowed')),
  seating          text check (seating in ('indoorAc', 'outdoor', 'both')),
  motor_parking    boolean,
  stay             text check (stay in ('unlimited', 'minimumOrder', 'timeLimited')),
  busy_times       text[] not null default '{}'
                     check (busy_times <@ array['pagi', 'siang', 'sore', 'malam']),

  -- Posisi user saat mengirim review. HANYA dipakai untuk menghitung
  -- verified_check_in, lalu dikosongkan oleh trigger (tidak pernah disimpan).
  checkin_location extensions.geography(point, 4326),
  verified_check_in boolean not null default false,

  source           text not null default 'app' check (source in ('app', 'seed')),
  visited_at       timestamptz not null default now(),  -- kapan tempat dikunjungi
  created_at       timestamptz not null default now()
);

create index reviews_spot_idx on public.reviews (spot_id, visited_at desc);

-- Anti-spam: 1 review per user per spot per hari (zona waktu Bali / WITA).
create unique index reviews_one_per_day_idx on public.reviews (
  user_id, spot_id, ((created_at at time zone 'Asia/Makassar')::date)
) where user_id is not null;


-- 3. Aturan bisnis di server ---------------------------------------------

-- Saat user login pertama kali, buat profil dari data akun Google.
create function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name, avatar_url)
  values (
    new.id,
    coalesce(
      new.raw_user_meta_data ->> 'full_name',
      new.raw_user_meta_data ->> 'name',
      split_part(new.email, '@', 1),
      'Pengguna'
    ),
    new.raw_user_meta_data ->> 'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Sebelum review disimpan:
--   - review dari app: nama & waktu diisi server (tidak bisa dipalsukan app)
--   - check-in terverifikasi dihitung server dari jarak ke spot (<= 200 m)
--   - posisi user dibuang setelah dipakai
create function public.reviews_before_insert()
returns trigger
language plpgsql
security definer set search_path = ''
as $$
declare
  spot_location extensions.geography;
  profile_name text;
begin
  select s.location into spot_location from public.spots s where s.id = new.spot_id;

  if new.user_id is not null then
    select p.display_name into profile_name from public.profiles p where p.id = new.user_id;
    new.author_name := coalesce(profile_name, 'Pengguna');
    new.source := 'app';
    new.created_at := now();
    new.visited_at := now();
  end if;

  new.verified_check_in := new.checkin_location is not null
    and spot_location is not null
    and extensions.st_dwithin(new.checkin_location, spot_location, 200);
  new.checkin_location := null;
  return new;
end;
$$;

create trigger reviews_before_insert
  before insert on public.reviews
  for each row execute function public.reviews_before_insert();


-- 4. Keamanan baris (RLS) ------------------------------------------------
alter table public.spots enable row level security;
alter table public.profiles enable row level security;
alter table public.reviews enable row level security;

-- Semua orang (termasuk yang belum login) boleh membaca spot, profil, review.
create policy "spots dapat dibaca semua" on public.spots
  for select to anon, authenticated using (true);

create policy "profil dapat dibaca semua" on public.profiles
  for select to anon, authenticated using (true);

create policy "review dapat dibaca semua" on public.reviews
  for select to anon, authenticated using (true);

-- User hanya boleh mengubah profilnya sendiri.
create policy "user mengubah profil sendiri" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- User login boleh menulis review atas namanya sendiri,
-- dan menghapus review miliknya sendiri.
create policy "user menulis review sendiri" on public.reviews
  for insert to authenticated
  with check ((select auth.uid()) = user_id);

create policy "user menghapus review sendiri" on public.reviews
  for delete to authenticated
  using ((select auth.uid()) = user_id);

-- Tidak ada policy insert/update untuk spots: data tempat hanya diisi
-- lewat script import (memakai service_role key, di luar app).


-- 5. View & fungsi untuk app -------------------------------------------

-- Spot dengan latitude/longitude sebagai angka biasa (lebih mudah dibaca app).
create view public.spots_view
with (security_invoker = on) as
select
  s.id, s.name, s.area, s.address, s.category,
  extensions.st_y(s.location::extensions.geometry) as lat,
  extensions.st_x(s.location::extensions.geometry) as lng,
  s.open_hour, s.close_hour, s.price_level, s.description, s.photos, s.created_at
from public.spots s;

-- Spot dalam radius tertentu dari sebuah titik, terurut dari yang terdekat.
create function public.nearby_spots(
  lat double precision,
  lng double precision,
  radius_m double precision default 5000
)
returns table (id uuid, distance_m double precision)
language sql
stable
set search_path = ''
as $$
  select
    s.id,
    extensions.st_distance(
      s.location,
      extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography
    ) as distance_m
  from public.spots s
  where extensions.st_dwithin(
    s.location,
    extensions.st_setsrid(extensions.st_makepoint(lng, lat), 4326)::extensions.geography,
    radius_m
  )
  order by distance_m;
$$;

grant select on public.spots_view to anon, authenticated;
grant execute on function public.nearby_spots(double precision, double precision, double precision)
  to anon, authenticated;
