"""Membuat aset brand SpotKerja: ikon app, foreground ikon adaptif Android,
dan logo splash screen.

Jalankan dari root project:
    python3 tool/generate_brand_assets.py

Butuh Pillow (pip install pillow). Hasilnya di assets/branding/.
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "branding"
SIZE = 1024
SS = 4  # supersampling supaya tepi halus

PRIMARY = (0xEE, 0x62, 0x00)
ORANGE = (0xFF, 0x9A, 0x00)
WHITE = (255, 255, 255)

# Petir (Work Score) dalam kotak 0..1
BOLT = [
    (0.60, 0.00), (0.16, 0.58), (0.46, 0.58), (0.38, 1.00),
    (0.84, 0.40), (0.54, 0.40), (0.60, 0.00),
]


def gradient(size: int) -> Image.Image:
    """Gradasi diagonal dari oranye terang (kiri atas) ke oranye tua (kanan bawah)."""
    img = Image.new("RGB", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(
                round(ORANGE[i] + (PRIMARY[i] - ORANGE[i]) * t) for i in range(3)
            )
    return img


def draw_pin(draw: ImageDraw.ImageDraw, cx, cy, r, tip_y, pin_color, bolt_color):
    """Pin lokasi = lingkaran + segitiga yang menyinggung lingkaran."""
    d = tip_y - cy
    a = math.asin(r / d)
    # titik singgung garis dari ujung pin ke lingkaran
    left = (cx - r * math.cos(a), cy + r * math.sin(a))
    right = (cx + r * math.cos(a), cy + r * math.sin(a))
    draw.polygon([left, (cx, tip_y), right], fill=pin_color)
    draw.ellipse([cx - r, cy - r, cx + r, cy + r], fill=pin_color)

    # petir di tengah lingkaran
    bw, bh = r * 0.78, r * 1.12
    bx, by = cx - bw / 2, cy - bh / 2
    draw.polygon([(bx + px * bw, by + py * bh) for px, py in BOLT], fill=bolt_color)


def render(background, pin_scale, pin_color, bolt_color, transparent=False):
    s = SIZE * SS
    if transparent:
        img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    else:
        img = background.resize((s, s)).convert("RGBA")
    draw = ImageDraw.Draw(img)
    r = s * 0.25 * pin_scale
    cy = s * 0.5 - r * 0.475  # pin (lingkaran + ekor) tepat di tengah
    tip_y = cy + r * 1.95
    draw_pin(draw, s / 2, cy, r, tip_y, pin_color, bolt_color)
    return img.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bg = gradient(256)  # di-resize, cukup kecil untuk dihitung

    # 1. Ikon utama (iOS & web): full bleed, tanpa transparansi
    render(bg, 1.0, WHITE, PRIMARY).convert("RGB").save(OUT / "app_icon.png")

    # 2. Foreground ikon adaptif Android: pin putih di area aman (lebih kecil)
    render(None, 0.72, WHITE, PRIMARY, transparent=True).save(
        OUT / "app_icon_foreground.png"
    )

    # 3. Logo splash: pin oranye di atas latar transparan
    render(None, 0.9, PRIMARY, WHITE, transparent=True).save(OUT / "splash_logo.png")

    print("Aset tersimpan di", OUT)


if __name__ == "__main__":
    main()
