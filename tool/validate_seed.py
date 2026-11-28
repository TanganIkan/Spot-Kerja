"""Cek isi CSV data awal sebelum di-import.

Pemakaian (dari root project):
    python3 tool/validate_seed.py seed/spots_bali.csv

Aturan kolom dijelaskan di seed/README.md.
"""

import csv
import re
import sys
from pathlib import Path

COLUMNS = [
    "nama_tempat", "area", "kategori", "bulan_kunjungan", "wifi", "speed_mbps",
    "colokan", "tenang", "nyaman", "keramaian", "harga_per_orang", "jam_buka", "jam_tutup",
    "rokok", "tempat_duduk", "parkir_motor", "duduk_lama", "jam_ramai",
    "komentar", "link_maps_pribadi",
]
REQUIRED = ["nama_tempat", "area", "kategori"]
REVIEW = ["bulan_kunjungan", "wifi", "colokan", "tenang", "nyaman", "keramaian"]
RATINGS = ["wifi", "colokan", "tenang", "nyaman"]
CHOICES = {
    "kategori": {"kafe", "coworking", "roastery"},
    "keramaian": {"sepi", "sedang", "ramai"},
    "rokok": {"bebas_rokok", "area_terpisah", "boleh_merokok"},
    "tempat_duduk": {"indoor_ac", "outdoor", "keduanya"},
    "parkir_motor": {"ya", "tidak"},
    "duduk_lama": {"bebas", "minimum_order", "dibatasi_waktu"},
}
BUSY_TIMES = {"pagi", "siang", "sore", "malam"}
EXAMPLE_PREFIX = "(CONTOH)"
MIN_RUPIAH, MAX_RUPIAH = 1000, 1_000_000


def parse_rupiah(text: str):
    """'35000', '35.000', '35rb', '35 ribu', '35k' -> 35000. Tidak valid -> None."""
    t = text.strip().lower().replace("rp", "").replace(" ", "")
    if not t:
        return None
    m = re.fullmatch(r"(\d+(?:[.,]\d+)?)(rb|ribu|k)", t)
    if m:
        return round(float(m.group(1).replace(",", ".")) * 1000)
    if re.fullmatch(r"\d{1,3}([.,]\d{3})+", t) or re.fullmatch(r"\d+", t):
        return int(re.sub(r"[.,]", "", t))
    return None


def check_row(row: dict) -> list[str]:
    errors = []
    get = lambda col: (row.get(col) or "").strip()  # noqa: E731

    for col in REQUIRED:
        if not get(col):
            errors.append(f"{col} wajib diisi")

    filled = [col for col in REVIEW if get(col)]
    if filled and len(filled) != len(REVIEW):
        missing = [c for c in REVIEW if c not in filled]
        errors.append(
            "review belum lengkap, isi juga: " + ", ".join(missing)
            + " (atau kosongkan semua kolom review)"
        )

    for col in RATINGS:
        v = get(col)
        if v and v not in {"1", "2", "3", "4", "5"}:
            errors.append(f"{col} harus angka 1-5, bukan '{v}'")

    v = get("bulan_kunjungan")
    if v and not re.fullmatch(r"20\d\d-(0[1-9]|1[0-2])", v):
        errors.append(f"bulan_kunjungan harus format TAHUN-BULAN (2026-08), bukan '{v}'")

    v = get("speed_mbps").replace(",", ".")
    if v:
        try:
            if not 0 < float(v) <= 2000:
                raise ValueError
        except ValueError:
            errors.append(f"speed_mbps harus angka 0-2000, bukan '{v}'")

    for col, allowed in CHOICES.items():
        v = get(col).lower()
        if v and v not in allowed:
            errors.append(f"{col} harus salah satu dari {sorted(allowed)}, bukan '{v}'")

    # Jam boleh "07:00" atau "7:00" (Google Sheets sering membuang nol depan).
    for col in ("jam_buka", "jam_tutup"):
        v = get(col)
        m = re.fullmatch(r"(\d{1,2}):([0-5]\d)", v) if v else None
        if v and (not m or int(m.group(1)) > 24 or (int(m.group(1)) == 24 and m.group(2) != "00")):
            errors.append(f"{col} harus format jam (08:00 atau 8:00), bukan '{v}'")

    v = get("jam_ramai").lower()
    if v:
        bad = [t for t in v.split(";") if t.strip() not in BUSY_TIMES]
        if bad:
            errors.append(f"jam_ramai hanya boleh {sorted(BUSY_TIMES)} dipisah ';', ada: {bad}")

    v = get("harga_per_orang")
    if v:
        rupiah = parse_rupiah(v)
        if rupiah is None or not MIN_RUPIAH <= rupiah <= MAX_RUPIAH:
            errors.append(f"harga_per_orang harus angka Rupiah (35000 atau 35rb), bukan '{v}'")

    if len(get("komentar")) > 280:
        errors.append("komentar lebih dari 280 karakter")

    return errors


def main(path: str) -> int:
    file = Path(path)
    if not file.exists():
        print(f"File tidak ditemukan: {file}")
        return 1

    with file.open(newline="", encoding="utf-8-sig") as f:
        reader = csv.DictReader(f)
        header = reader.fieldnames or []
        if "harga" in header and "harga_per_orang" not in header:
            print("Kolom 'harga' (hemat/sedang/premium) sudah diganti menjadi "
                  "'harga_per_orang' (angka Rupiah, mis. 35000 atau 35rb).\n"
                  "Ganti nama kolomnya di baris pertama, lalu isi angkanya.")
            return 1
        missing_cols = [c for c in COLUMNS if c not in header]
        extra_cols = [c for c in header if c not in COLUMNS]
        if missing_cols or extra_cols:
            if missing_cols:
                print("Kolom hilang:", ", ".join(missing_cols))
            if extra_cols:
                print("Kolom tidak dikenal:", ", ".join(extra_cols))
            print("Pastikan baris pertama sama persis dengan template.")
            return 1

        total = examples = with_review = 0
        problems = 0
        names = {}
        for line, row in enumerate(reader, start=2):
            name = (row.get("nama_tempat") or "").strip()
            if not any((v or "").strip() for v in row.values()):
                continue  # baris kosong
            if name.startswith(EXAMPLE_PREFIX):
                examples += 1
                continue
            total += 1
            errors = check_row(row)
            key = (name.lower(), (row.get("area") or "").strip().lower())
            if key in names:
                errors.append(f"duplikat dengan baris {names[key]}")
            names.setdefault(key, line)
            if (row.get("wifi") or "").strip():
                with_review += 1
            for e in errors:
                problems += 1
                print(f"Baris {line} ({name or 'tanpa nama'}): {e}")

    print()
    print(f"{total} tempat, {with_review} dengan review"
          + (f", {examples} baris contoh dilewati" if examples else ""))
    if total == 0:
        print("⚠️  Belum ada data tempat (selain baris contoh).")
        return 1
    if problems:
        print(f"❌ {problems} masalah ditemukan. Perbaiki lalu jalankan lagi.")
        return 1
    print("✅ Data siap di-import.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1] if len(sys.argv) > 1 else "seed/spots_bali.csv"))
