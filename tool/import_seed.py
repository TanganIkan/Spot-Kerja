"""Import data awal (CSV) ke Supabase.

Pemakaian (dari root project):

    # 1. Pratinjau: cek isian + cari koordinat. TIDAK menulis apa pun.
    python3 tool/import_seed.py seed/spots_bali.csv

    # 2. Tulis ke Supabase (butuh .env berisi secret key, lihat .env.example)
    python3 tool/import_seed.py seed/spots_bali.csv --apply

Untuk setiap baris CSV:
  1. Isian dicek (aturan yang sama dengan tool/validate_seed.py).
  2. Koordinat dicari: dari link Google Maps pribadi (kalau ada koordinatnya),
     kalau tidak dari OpenStreetMap (nama mirip + dekat dengan area).
  3. Tempat dimasukkan ke tabel `spots` (atau diperbarui kalau sudah ada).
  4. Rating-mu masuk sebagai review "data awal" (source = 'seed').

Aman dijalankan berulang kali: tempat tidak dobel, review data awal diganti.
"""

import argparse
import csv
import difflib
import json
import math
import re
import ssl
import sys
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(Path(__file__).resolve().parent))
from validate_seed import EXAMPLE_PREFIX, check_row, parse_rupiah  # noqa: E402

# ---- Pengaturan ---------------------------------------------------------

CACHE_FILE = ROOT / "seed" / ".cache" / "osm_bali.json"
CACHE_MAX_AGE_DAYS = 7
BALI_BBOX = (-8.86, 114.43, -8.06, 115.72)  # selatan, barat, utara, timur
OVERPASS_URL = "https://overpass-api.de/api/interpreter"
USER_AGENT = "SpotKerja-seed-import/1.0"

# Nama dianggap cocok kalau kemiripannya >= ini (0..1).
MATCH_MIN_SCORE = 0.82
# Nama pendek (setelah kata umum dibuang) harus sama persis, tidak cukup
# "terkandung" di nama lain.
MIN_CONTAINED_LENGTH = 4
# Tempat OSM yang lebih jauh dari ini dari pusat area diabaikan.
MAX_DISTANCE_KM = 10

# Titik tengah perkiraan tiap area (untuk memilih tempat OSM yang tepat
# kalau ada beberapa nama yang mirip).
AREA_CENTERS = {
    "canggu": (-8.6478, 115.1385),
    "berawa": (-8.6590, 115.1430),
    "pererenan": (-8.6400, 115.1220),
    "umalas": (-8.6620, 115.1620),
    "kerobokan": (-8.6560, 115.1710),
    "seminyak": (-8.6913, 115.1682),
    "legian": (-8.7050, 115.1690),
    "kuta": (-8.7180, 115.1686),
    "denpasar": (-8.6705, 115.2126),
    "renon": (-8.6750, 115.2330),
    "sanur": (-8.6929, 115.2620),
    "jimbaran": (-8.7907, 115.1600),
    "uluwatu": (-8.8291, 115.0849),
    "nusa dua": (-8.8000, 115.2300),
    "ubud": (-8.5069, 115.2625),
    "gianyar": (-8.5440, 115.3250),
    "tabanan": (-8.5410, 115.1250),
}

SMOKING = {"bebas_rokok": "smokeFree", "area_terpisah": "separateArea",
           "boleh_merokok": "allowed"}
SEATING = {"indoor_ac": "indoorAc", "outdoor": "outdoor", "keduanya": "both"}
STAY = {"bebas": "unlimited", "minimum_order": "minimumOrder",
        "dibatasi_waktu": "timeLimited"}


# ---- HTTP ---------------------------------------------------------------

def _ssl_context() -> ssl.SSLContext:
    """Python dari python.org di macOS kadang tidak membawa sertifikat;
    pakai sertifikat sistem / certifi kalau tersedia."""
    ctx = ssl.create_default_context()
    try:
        import certifi  # type: ignore
        ctx.load_verify_locations(certifi.where())
    except ImportError:
        pass
    if Path("/etc/ssl/cert.pem").exists():
        ctx.load_verify_locations("/etc/ssl/cert.pem")
    return ctx


SSL = _ssl_context()


class HttpError(Exception):
    pass


def http(method, url, headers=None, body=None, timeout=120):
    data = None
    if body is not None:
        data = body if isinstance(body, bytes) else json.dumps(body).encode()
    req = urllib.request.Request(
        url, data=data, method=method,
        headers={"User-Agent": USER_AGENT, **(headers or {})},
    )
    try:
        with urllib.request.urlopen(req, timeout=timeout, context=SSL) as res:
            raw = res.read()
            return json.loads(raw) if raw.strip() else None, res.geturl()
    except urllib.error.HTTPError as e:
        detail = e.read().decode(errors="replace")[:300]
        raise HttpError(f"HTTP {e.code} {url.split('?')[0]}: {detail}") from None


# ---- OpenStreetMap ------------------------------------------------------

def load_osm_places(refresh=False):
    """Semua kafe & co-working di Bali dari OpenStreetMap (di-cache 7 hari)."""
    if CACHE_FILE.exists() and not refresh:
        age_days = (time.time() - CACHE_FILE.stat().st_mtime) / 86400
        if age_days < CACHE_MAX_AGE_DAYS:
            return json.loads(CACHE_FILE.read_text())

    s, w, n, e = BALI_BBOX
    bbox = f"{s},{w},{n},{e}"
    query = f"""[out:json][timeout:120];
(
  nwr["amenity"="cafe"]({bbox});
  nwr["amenity"="coworking_space"]({bbox});
  nwr["office"="coworking"]({bbox});
  nwr["shop"="coffee"]({bbox});
);
out center tags;"""
    print("Mengunduh data kafe & co-working Bali dari OpenStreetMap...")
    data, _ = http(
        "POST", OVERPASS_URL,
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        body=urllib.parse.urlencode({"data": query}).encode(),
    )

    places = []
    for el in data.get("elements", []):
        tags = el.get("tags", {})
        name = tags.get("name")
        lat = el.get("lat", el.get("center", {}).get("lat"))
        lng = el.get("lon", el.get("center", {}).get("lon"))
        if not name or lat is None or lng is None:
            continue
        places.append({
            "osm_id": f"{el['type']}/{el['id']}",
            "name": name,
            "other_names": [tags[k] for k in ("name:en", "name:id", "alt_name",
                                              "old_name", "brand") if k in tags],
            "lat": lat,
            "lng": lng,
            "opening_hours": tags.get("opening_hours"),
            "street": tags.get("addr:street"),
            "housenumber": tags.get("addr:housenumber"),
        })
    CACHE_FILE.parent.mkdir(parents=True, exist_ok=True)
    CACHE_FILE.write_text(json.dumps(places))
    print(f"  {len(places)} tempat tersimpan di cache.\n")
    return places


GENERIC_WORDS = r"\b(the|cafe|caffe|coffee|coffeeshop|kopi|kedai|warung|bali|and|dan|n)\b"


# Nama daerah juga diabaikan: "Zin Cafe Canggu" di OSM = "Zin" di CSV.
AREA_WORDS = r"\b(" + "|".join(re.escape(a) for a in AREA_CENTERS) + r")\b"


def normalize(name: str) -> str:
    s = unicodedata.normalize("NFKD", name).encode("ascii", "ignore").decode().lower()
    s = re.sub(r"[^a-z0-9 ]+", " ", s)
    stripped = " ".join(re.sub(AREA_WORDS, " ", re.sub(GENERIC_WORDS, " ", s)).split())
    # Kalau namanya hanya kata umum ("Kopi Bali"), jangan dibuang semua.
    return stripped or " ".join(s.split())


def similarity(a: str, b: str) -> float:
    na, nb = normalize(a), normalize(b)
    if not na or not nb:
        return 0.0
    if na == nb:
        return 1.0
    score = difflib.SequenceMatcher(None, na, nb).ratio()
    # Nama satu terkandung utuh di nama lain, mis. "Zin" vs "Zin Cafe Canggu".
    # Hanya untuk nama yang cukup panjang: "co" jangan dianggap cocok
    # dengan semua tempat yang mengandung kata "co".
    shorter, longer = sorted((na, nb), key=len)
    if len(shorter) >= MIN_CONTAINED_LENGTH and re.search(rf"\b{re.escape(shorter)}\b", longer):
        score = max(score, 0.9)
    return score


def distance_km(a, b) -> float:
    lat1, lng1, lat2, lng2 = map(math.radians, (*a, *b))
    h = (math.sin((lat2 - lat1) / 2) ** 2
         + math.cos(lat1) * math.cos(lat2) * math.sin((lng2 - lng1) / 2) ** 2)
    return 6371 * 2 * math.asin(math.sqrt(h))


def find_in_osm(name: str, area: str, places):
    """Cari tempat OSM paling cocok. Hasil: (place, skor, jarak_km, n_mirip) atau None."""
    center = AREA_CENTERS.get(area.strip().lower())
    candidates = []
    for p in places:
        score = max(similarity(name, n) for n in (p["name"], *p["other_names"]))
        if score < MATCH_MIN_SCORE:
            continue
        dist = distance_km(center, (p["lat"], p["lng"])) if center else None
        if dist is not None and dist > MAX_DISTANCE_KM:
            continue
        candidates.append((score, -(dist or 0.0), p, dist))
    if not candidates:
        return None
    candidates.sort(key=lambda c: (c[0], c[1]), reverse=True)
    score, _, place, dist = candidates[0]
    similar = sum(1 for c in candidates if c[0] >= score - 0.02)
    return place, score, dist, similar


# ---- Link Google Maps pribadi -------------------------------------------

COORD_PATTERNS = [
    r"!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)",                                # pin tempat
    r"[?&](?:q|query|ll|destination)=(-?\d+\.\d+)(?:,|%2C)\s*(-?\d+\.\d+)",
    r"@(-?\d+\.\d+),(-?\d+\.\d+)",                                    # tengah peta
]


def in_bali(lat, lng) -> bool:
    s, w, n, e = BALI_BBOX
    return s <= lat <= n and w <= lng <= e


def resolve_redirect(url: str):
    """Ikuti link pendek sampai URL akhirnya. Halaman tujuannya HTML,
    jadi isinya tidak dibaca, cukup alamat akhirnya."""
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(req, timeout=20, context=SSL) as res:
            return res.geturl()
    except Exception as e:
        print(f"  (link {url} tidak bisa dibuka: {e})")
        return None


def coords_from_link(link: str):
    """Ambil koordinat dari link Google Maps yang kamu tempel sendiri.
    Link pendek (maps.app.goo.gl) diikuti dulu ke link lengkapnya."""
    url = (link or "").strip()
    if not url:
        return None
    if re.match(r"https?://(maps\.app\.goo\.gl|goo\.gl)/", url):
        url = resolve_redirect(url)
        if url is None:
            return None
    url = urllib.parse.unquote(url)
    for pattern in COORD_PATTERNS:
        m = re.search(pattern, url)
        if m:
            lat, lng = float(m.group(1)), float(m.group(2))
            if in_bali(lat, lng):
                return lat, lng
    return None


# ---- Konversi isian CSV -------------------------------------------------

def parse_hour(text: str, is_close: bool):
    """'08:30' -> 9 untuk jam buka (dibulatkan ke atas), 22 untuk jam tutup
    (dibulatkan ke bawah), supaya app tidak bilang "buka" padahal belum."""
    if not text:
        return None
    h, m = map(int, text.split(":"))
    if is_close:
        return 24 if h in (0, 24) else h
    return min(23, h + (1 if m else 0))


def hours_from_osm(opening_hours):
    """Hanya format sederhana: '24/7' atau 'Mo-Su 08:00-22:00' / '08:00-22:00'."""
    if not opening_hours:
        return None, None
    oh = opening_hours.strip()
    if oh == "24/7":
        return 0, 24
    m = re.fullmatch(r"(?:Mo-Su\s+)?(\d{1,2}:\d\d)\s*-\s*(\d{1,2}:\d\d)", oh)
    if not m:
        return None, None
    open_h = parse_hour(m.group(1), is_close=False)
    close_h = parse_hour(m.group(2), is_close=True)
    if close_h <= open_h:  # tutup lewat tengah malam
        close_h = 24
    return open_h, close_h


def build_plan(rows, places, author_name):
    """Ubah baris CSV menjadi rencana: spot + review (+ cara dapat koordinat)."""
    plans = []
    for line, row in rows:
        get = lambda col: (row.get(col) or "").strip()  # noqa: E731
        name, area = get("nama_tempat"), get("area")

        coords, source_note, osm = coords_from_link(get("link_maps_pribadi")), None, None
        if coords:
            source_note = "📍 dari link Google Maps-mu"
            match = find_in_osm(name, area, places)
            # Pakai data OSM (jam, alamat) hanya kalau lokasinya memang berdekatan.
            if match and distance_km(coords, (match[0]["lat"], match[0]["lng"])) < 0.3:
                osm = match[0]
        else:
            match = find_in_osm(name, area, places)
            if match:
                osm, score, dist, similar = match
                coords = (osm["lat"], osm["lng"])
                where = f", {dist:.1f} km dari pusat {area}" if dist is not None else ""
                source_note = f"🗺️  OSM: \"{osm['name']}\" (mirip {score:.0%}{where})"
                if similar > 1:
                    source_note += (f" ⚠️ {similar} tempat bernama mirip, dipilih yang "
                                    f"terdekat ke pusat area. Kalau cabangnya salah, "
                                    f"isi link_maps_pribadi")

        open_h = parse_hour(get("jam_buka"), is_close=False)
        close_h = parse_hour(get("jam_tutup"), is_close=True)
        if open_h is None and close_h is None and osm:
            open_h, close_h = hours_from_osm(osm.get("opening_hours"))

        address = ""
        if osm and osm.get("street"):
            address = " ".join(filter(None, [osm["street"], osm.get("housenumber")]))

        spot = {
            "name": name,
            "area": area,
            "category": get("kategori").lower(),
            "open_hour": open_h,
            "close_hour": close_h,
            "avg_price": parse_rupiah(get("harga_per_orang")),
            "address": address,
            "osm_id": osm["osm_id"] if osm else None,
            "source": "seed",
        }
        if coords:
            spot["location"] = f"SRID=4326;POINT({coords[1]} {coords[0]})"

        review = None
        if get("wifi"):
            speed = get("speed_mbps").replace(",", ".")
            review = {
                "author_name": author_name,
                "wifi": int(get("wifi")),
                "power": int(get("colokan")),
                "quiet": int(get("tenang")),
                "comfort": int(get("nyaman")),
                "crowd": get("keramaian").lower(),
                "wifi_speed_mbps": float(speed) if speed else None,
                "comment": get("komentar"),
                "smoking": SMOKING.get(get("rokok").lower()),
                "seating": SEATING.get(get("tempat_duduk").lower()),
                "motor_parking": {"ya": True, "tidak": False}.get(get("parkir_motor").lower()),
                "stay": STAY.get(get("duduk_lama").lower()),
                "busy_times": [t.strip() for t in get("jam_ramai").lower().split(";") if t.strip()],
                # Pertengahan bulan kunjungan, zona waktu Bali.
                "visited_at": f"{get('bulan_kunjungan')}-15T12:00:00+08:00",
                "source": "seed",
                "verified_check_in": False,
                "user_id": None,
            }

        plans.append({"line": line, "spot": spot, "review": review,
                      "found": coords is not None, "note": source_note})
    return plans


# ---- Supabase -----------------------------------------------------------

class Supabase:
    def __init__(self, url: str, key: str):
        self.base = url.rstrip("/") + "/rest/v1"
        self.headers = {"apikey": key, "Content-Type": "application/json"}
        if key.startswith("eyJ"):  # service_role key versi lama (JWT)
            self.headers["Authorization"] = f"Bearer {key}"

    def _call(self, method, path, body=None, prefer=None):
        headers = dict(self.headers)
        if prefer:
            headers["Prefer"] = prefer
        data, _ = http(method, self.base + path, headers=headers, body=body)
        return data

    def existing_spots(self):
        return self._call("GET", "/spots?select=id,name,area,osm_id")

    def insert_spot(self, spot):
        return self._call("POST", "/spots", spot, prefer="return=representation")[0]["id"]

    def update_spot(self, spot_id, spot):
        self._call("PATCH", f"/spots?id=eq.{spot_id}", spot, prefer="return=minimal")

    def replace_seed_review(self, spot_id, review):
        self._call("DELETE",
                   f"/reviews?spot_id=eq.{spot_id}&source=eq.seed&user_id=is.null",
                   prefer="return=minimal")
        if review:
            self._call("POST", "/reviews", {**review, "spot_id": spot_id},
                       prefer="return=minimal")


def load_env():
    env = {}
    path = ROOT / ".env"
    if path.exists():
        for raw in path.read_text().splitlines():
            line = raw.strip()
            if line and not line.startswith("#") and "=" in line:
                key, value = line.split("=", 1)
                env[key.strip()] = value.strip().strip('"').strip("'")
    return env


# ---- Main ---------------------------------------------------------------

def read_rows(csv_path: Path):
    with csv_path.open(newline="", encoding="utf-8-sig") as f:
        rows = []
        for line, row in enumerate(csv.DictReader(f), start=2):
            if not any((v or "").strip() for v in row.values()):
                continue
            if (row.get("nama_tempat") or "").strip().startswith(EXAMPLE_PREFIX):
                continue
            rows.append((line, row))
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description="Import data awal SpotKerja ke Supabase.")
    parser.add_argument("csv", nargs="?", default="seed/spots_bali.csv")
    parser.add_argument("--apply", action="store_true",
                        help="benar-benar menulis ke Supabase (tanpa ini: pratinjau saja)")
    parser.add_argument("--refresh-osm", action="store_true",
                        help="unduh ulang data OpenStreetMap (abaikan cache)")
    args = parser.parse_args()

    csv_path = (ROOT / args.csv) if not Path(args.csv).is_absolute() else Path(args.csv)
    if not csv_path.exists():
        print(f"File tidak ditemukan: {csv_path}")
        return 1

    rows = read_rows(csv_path)
    if not rows:
        print("Belum ada data tempat (selain baris contoh).")
        return 1

    # 1. Cek isian dulu. Jangan menulis apa pun kalau ada yang salah.
    problems = [(line, e) for line, row in rows for e in check_row(row)]
    if problems:
        for line, e in problems:
            print(f"Baris {line}: {e}")
        print(f"\n❌ {len(problems)} masalah. Jalankan: python3 tool/validate_seed.py {args.csv}")
        return 1

    env = load_env()
    author = env.get("SEED_AUTHOR_NAME") or "Tim SpotKerja"

    # 2. Cari koordinat.
    places = load_osm_places(refresh=args.refresh_osm)
    plans = build_plan(rows, places, author)

    # Satu tempat OSM tidak boleh dipakai dua baris.
    seen = {}
    for plan in plans:
        osm_id = plan["spot"]["osm_id"]
        if osm_id and osm_id in seen:
            plan["found"] = False
            plan["note"] = f"❌ cocok dengan tempat OSM yang sama seperti baris {seen[osm_id]}"
        elif osm_id:
            seen[osm_id] = plan["line"]

    # 3. Laporan.
    print(f"{'Baris':<6} {'Tempat':<34} Koordinat")
    print("-" * 100)
    for plan in plans:
        label = f"{plan['spot']['name']} ({plan['spot']['area']})"
        note = plan["note"] if plan["found"] else (plan["note"] or "❌ tidak ditemukan")
        print(f"{plan['line']:<6} {label[:33]:<34} {note}")

    ready = [p for p in plans if p["found"]]
    missing = [p for p in plans if not p["found"]]
    with_review = sum(1 for p in ready if p["review"])
    print("-" * 100)
    print(f"{len(ready)} siap di-import ({with_review} dengan review), "
          f"{len(missing)} belum punya koordinat.")
    if missing:
        print("Untuk yang ❌: tempel link Google Maps tempat itu di kolom "
              "link_maps_pribadi, lalu jalankan lagi.")

    if not args.apply:
        print("\nIni baru PRATINJAU, belum ada yang ditulis. "
              "Tambahkan --apply untuk memasukkan ke Supabase.")
        return 0

    # 4. Tulis ke Supabase.
    url, key = env.get("SUPABASE_URL", ""), env.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or not key or "ISI-" in url or "ISI-" in key:
        print("\n❌ .env belum diisi. Jalankan: cp .env.example .env lalu isi "
              "SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY (secret key).")
        return 1

    db = Supabase(url, key)
    try:
        existing = db.existing_spots()
    except HttpError as e:
        print(f"\n❌ Tidak bisa membaca database: {e}")
        if "42501" in str(e):
            print("   Izin service_role belum diberikan. Jalankan di SQL Editor:\n"
                  "   supabase/migrations/20261128020000_service_role_grants.sql")
        elif "401" in str(e) or "Invalid API key" in str(e):
            print("   Secret key di .env salah. Salin ulang dari Project Settings -> API Keys.")
        return 1
    by_osm = {s["osm_id"]: s["id"] for s in existing if s.get("osm_id")}
    by_name = {(s["name"].lower(), s["area"].lower()): s["id"] for s in existing}

    print(f"\nMenulis {len(ready)} tempat ke Supabase...")
    created = updated = failed = 0
    for plan in ready:
        spot = plan["spot"]
        spot_id = by_osm.get(spot["osm_id"]) or by_name.get((spot["name"].lower(), spot["area"].lower()))
        try:
            if spot_id:
                db.update_spot(spot_id, spot)
                updated += 1
            else:
                spot_id = db.insert_spot(spot)
                created += 1
            db.replace_seed_review(spot_id, plan["review"])
        except HttpError as e:
            failed += 1
            print(f"  ❌ baris {plan['line']} ({spot['name']}): {e}")

    print(f"\n✅ Selesai: {created} tempat baru, {updated} diperbarui"
          + (f", {failed} gagal" if failed else "") + ".")
    print("Buka app lalu tekan 'Muat ulang' / refresh untuk melihat hasilnya.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
