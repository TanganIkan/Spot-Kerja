"""Membuat aset brand SpotKerja: ikon app, foreground ikon adaptif Android,
dan logo splash screen.

Logo "Radius spot": titik di tengah cincin, dikelilingi cincin putus-putus.
Maknanya: sebuah spot dan radius pencarian di sekitarnya, sama seperti
lingkaran radius di peta app. Cincin luar sengaja putus-putus supaya tidak
terbaca sebagai logo "bullseye" (sasaran panah) milik brand lain.

Jalankan dari root project:
    python3 tool/generate_brand_assets.py

Butuh Pillow (pip install pillow). Hasilnya di assets/branding/.
Setelah itu jalankan ulang generator ikon & splash (lihat README).
"""

import math
from pathlib import Path

from PIL import Image, ImageDraw

OUT = Path(__file__).resolve().parent.parent / "assets" / "branding"
SIZE = 1024
SS = 4  # supersampling supaya tepi halus

PRIMARY = (0xEE, 0x62, 0x00, 255)
ORANGE = (0xFF, 0x9A, 0x00, 255)
PEACH = (0xFB, 0xA1, 0x7E, 255)
WHITE = (255, 255, 255, 255)
WHITE_SOFT = (255, 255, 255, 150)  # cincin luar di atas oranye (±60%)

# Proporsi logo terhadap sisi kanvas (dihitung dari sketsa, lalu ditebalkan
# sedikit supaya tetap terbaca di ukuran ikon kecil).
OUTER_RADIUS = 0.285
INNER_RADIUS = 0.165
RING_WIDTH = 0.054
DOT_RADIUS = 0.062
# Cincin luar putus-putus: jumlah segmen & porsi garis per segmen.
OUTER_SEGMENTS = 12
OUTER_DASH_RATIO = 0.62


def gradient(size: int) -> Image.Image:
    """Gradasi diagonal dari oranye terang (kiri atas) ke oranye tua (kanan bawah)."""
    img = Image.new("RGBA", (size, size))
    px = img.load()
    for y in range(size):
        for x in range(size):
            t = (x + y) / (2 * (size - 1))
            px[x, y] = tuple(
                round(ORANGE[i] + (PRIMARY[i] - ORANGE[i]) * t) for i in range(3)
            ) + (255,)
    return img


def ring(layer: Image.Image, center: float, radius: float, width: float, color):
    draw = ImageDraw.Draw(layer)
    r_out = radius + width / 2
    draw.ellipse(
        [center - r_out, center - r_out, center + r_out, center + r_out],
        outline=color, width=round(width),
    )


def dashed_ring(layer: Image.Image, center: float, radius: float, width: float, color):
    draw = ImageDraw.Draw(layer)
    r_out = radius + width / 2
    box = [center - r_out, center - r_out, center + r_out, center + r_out]
    step = 360 / OUTER_SEGMENTS
    dash = step * OUTER_DASH_RATIO
    for i in range(OUTER_SEGMENTS):
        start = -90 + i * step - dash / 2  # segmen pertama tepat di atas
        draw.arc(box, start, start + dash, fill=color, width=round(width))
    # Ujung segmen dibulatkan.
    for i in range(OUTER_SEGMENTS):
        for edge in (-dash / 2, dash / 2):
            a = math.radians(-90 + i * step + edge)
            x, y = center + radius * math.cos(a), center + radius * math.sin(a)
            draw.ellipse([x - width / 2, y - width / 2, x + width / 2, y + width / 2], fill=color)


def render(background, scale, outer_color, inner_color, dot_color):
    """Gambar logo di kanvas besar lalu perkecil (anti-aliasing)."""
    s = SIZE * SS
    base = (background.resize((s, s)) if background is not None
            else Image.new("RGBA", (s, s), (0, 0, 0, 0)))
    c = s / 2

    # Tiap bagian di layer sendiri supaya warna transparan tercampur benar.
    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    dashed_ring(layer, c, s * OUTER_RADIUS * scale, s * RING_WIDTH * scale, outer_color)
    base = Image.alpha_composite(base, layer)

    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    ring(layer, c, s * INNER_RADIUS * scale, s * RING_WIDTH * scale, inner_color)
    base = Image.alpha_composite(base, layer)

    layer = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    r = s * DOT_RADIUS * scale
    ImageDraw.Draw(layer).ellipse([c - r, c - r, c + r, c + r], fill=dot_color)
    base = Image.alpha_composite(base, layer)

    return base.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bg = gradient(256)  # di-resize, cukup kecil untuk dihitung

    # 1. Ikon utama (iOS & web): full bleed, tanpa transparansi.
    render(bg, 1.0, WHITE_SOFT, WHITE, WHITE).convert("RGB").save(OUT / "app_icon.png")

    # 2. Foreground ikon adaptif Android: logo diperkecil supaya masuk area aman
    #    (Android memotong ikon menjadi lingkaran/rounded square).
    render(None, 0.8, WHITE_SOFT, WHITE, WHITE).save(OUT / "app_icon_foreground.png")

    # 3. Logo splash & onboarding: di atas latar putih.
    render(None, 1.3, PEACH, PRIMARY, PRIMARY).save(OUT / "splash_logo.png")

    print("Aset tersimpan di", OUT)


if __name__ == "__main__":
    main()
