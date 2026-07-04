"""Genera blood_npc_supermarket_albedo.png — modo incremental: solo brazos."""
from __future__ import annotations

import math
import random
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

ROOT = Path(__file__).resolve().parents[1]
BASE_PATH = ROOT / "assets/characters/npc_supermarket/Character_05.png"
OUT_PATH = ROOT / "assets/characters/blood_npc_supermarket/blood_npc_supermarket_albedo.png"

random.seed(1337)

DRIED = (32, 5, 7)
COAG = (68, 9, 11)
MID = (118, 16, 13)
FRESH = (188, 30, 20)
BRIGHT = (228, 44, 26)

PALE = (198, 95, 82)
PALE_WASH = (215, 115, 100)
PALE_LIGHT = (225, 140, 125)

# UV aproximadas de mangas / antebrazos (512×512)
ARM_SHIRT_REGIONS: tuple[tuple[int, int, int, int, float], ...] = (
    (416, 96, 512, 268, 0.78),   # manga derecha (columna derecha)
    (32, 384, 168, 480, 0.78),   # manga izquierda (esquina inferior izq.)
    (192, 252, 218, 372, 0.62),  # hombro/codo — borde izq. del torso
    (292, 252, 322, 372, 0.62),  # hombro/codo — borde der. del torso
    (188, 24, 288, 98, 0.45),    # hombros superiores (tira central)
)

ARM_SKIN_REGIONS: tuple[tuple[int, int, int, int, float], ...] = (
    (410, 188, 454, 325, 0.72),  # antebrazo piel derecho
    (360, 268, 398, 325, 0.65),  # muñeca derecha
    (2, 90, 148, 185, 0.72),     # antebrazo piel izquierdo
    (47, 28, 155, 90, 0.68),     # dorso mano / muñeca izq.
    (348, 28, 444, 120, 0.68),   # dorso mano / muñeca der.
)


def _blob(draw: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float, alpha: int, color: tuple[int, int, int]) -> None:
    draw.ellipse((cx - rx, cy - ry, cx + rx, cy + ry), fill=(*color, alpha))


def _smeared_blob(draw: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float, angle: float, alpha: int, color: tuple[int, int, int]) -> None:
    pts = []
    for i in range(16):
        t = i / 16 * math.tau
        wobble = 0.5 + random.random() * 0.7
        px = cx + math.cos(t + angle) * rx * wobble
        py = cy + math.sin(t + angle) * ry * wobble
        pts.append((px, py))
    draw.polygon(pts, fill=(*color, alpha))


def _drip(draw: ImageDraw.ImageDraw, x: float, y: float, length: float, width: float, alpha: int, color: tuple[int, int, int]) -> None:
    steps = max(2, int(length / 4))
    for i in range(steps + 1):
        t = i / steps
        w = width * (1.0 - t * 0.55) * (0.8 + random.random() * 0.35)
        oy = y + t * length
        _blob(draw, x + random.uniform(-2, 2), oy, w, w * 0.72, int(alpha * (1.0 - t * 0.3)), color)


def _splatter(draw: ImageDraw.ImageDraw, cx: float, cy: float, count: int, spread: float, alpha: int, color: tuple[int, int, int]) -> None:
    for _ in range(count):
        ox = cx + random.uniform(-spread, spread)
        oy = cy + random.uniform(-spread, spread)
        r = random.uniform(1.5, spread * 0.38)
        _blob(draw, ox, oy, r, r * random.uniform(0.45, 1.2), int(alpha * random.uniform(0.45, 1.0)), color)


def _pale_blood(draw: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float, intensity: float = 0.55) -> None:
    a = int(255 * intensity)
    _smeared_blob(draw, cx, cy, rx, ry, random.uniform(-0.5, 0.5), int(a * 0.55), PALE_WASH)
    _smeared_blob(draw, cx, cy, rx * 0.75, ry * 0.7, random.uniform(-0.5, 0.5), int(a * 0.45), PALE)
    _smeared_blob(draw, cx + random.uniform(-4, 4), cy, rx * 0.45, ry * 0.4, random.uniform(-0.5, 0.5), int(a * 0.35), PALE_LIGHT)
    _splatter(draw, cx, cy, 8, rx * 0.5, int(a * 0.3), PALE)


def _layered_blood(draw: ImageDraw.ImageDraw, cx: float, cy: float, rx: float, ry: float, intensity: float = 1.0) -> None:
    a = int(255 * intensity)
    _smeared_blob(draw, cx, cy, rx, ry, random.uniform(-0.7, 0.7), int(a * 0.95), DRIED)
    _smeared_blob(draw, cx + random.uniform(-3, 3), cy + random.uniform(-2, 2), rx * 0.78, ry * 0.72, random.uniform(-0.7, 0.7), int(a * 0.82), COAG)
    _smeared_blob(draw, cx, cy, rx * 0.52, ry * 0.48, random.uniform(-0.7, 0.7), int(a * 0.62), MID)
    _smeared_blob(draw, cx + random.uniform(-5, 5), cy + random.uniform(-4, 4), rx * 0.35, ry * 0.32, random.uniform(-0.7, 0.7), int(a * 0.45), FRESH)
    _splatter(draw, cx, cy, 10, rx * 0.45, int(a * 0.35), BRIGHT)


def _is_shirt_fabric(r: int, g: int, b: int, a: int) -> bool:
    if a < 20:
        return False
    if 90 < g < 180 and g > r + 8 and abs(r - b) < 55:
        return True
    if r > 180 and g > 180 and b > 180:
        return True
    if 40 < g < 120 and r < 90 and b < 90 and g > r:
        return True
    return False


def _is_skin(r: int, g: int, b: int, a: int) -> bool:
    if a < 20:
        return False
    return 180 < r < 255 and 130 < g < 220 and 100 < b < 200


def _paint_on_mask(
    out: Image.Image,
    base: Image.Image,
    x0: int,
    y0: int,
    x1: int,
    y1: int,
    strength: float,
    predicate,
    palette: tuple[tuple[int, int, int], ...],
) -> None:
    out_px = out.load()
    base_px = base.load()
    for y in range(y0, y1):
        for x in range(x0, x1):
            br, bg, bb, ba = base_px[x, y]
            if ba == 0 or not predicate(br, bg, bb, ba):
                continue
            n = (math.sin(x * 0.17 + y * 0.23) + math.sin(x * 0.41 - y * 0.11)) * 0.5
            if n < -0.35:
                continue
            t = strength * (0.4 + 0.6 * ((n + 1) * 0.5))
            sr, sg, sb = palette[min(len(palette) - 1, int((n + 1) * 0.5 * len(palette)))]
            or_, og, ob, oa = out_px[x, y]
            nr = int(or_ * (1 - t) + sr * t)
            ng = int(og * (1 - t) + sg * t)
            nb = int(ob * (1 - t) + sb * t)
            out_px[x, y] = (min(255, nr), min(255, ng), min(255, nb), oa)


def build_sleeve_draw_layer(size: int) -> Image.Image:
    """Manchas grandes sobre UV de mangas (hombro → codo)."""
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    # Manga derecha — columna x≈448
    for cy in range(105, 255, 14):
        _pale_blood(draw, 478, cy, 26, 15, 0.78)
    _pale_blood(draw, 468, 135, 32, 22, 0.85)
    _pale_blood(draw, 490, 175, 28, 20, 0.82)
    _pale_blood(draw, 475, 210, 24, 18, 0.75)
    _smeared_blob(draw, 465, 160, 20, 55, 0.12, 150, COAG)
    _drip(draw, 482, 195, 35, 4, 160, PALE)
    _drip(draw, 472, 120, 28, 3, 140, COAG)

    # Manga izquierda — esquina inferior izquierda
    for cx in range(48, 155, 16):
        _pale_blood(draw, cx, 410, 18, 22, 0.78)
    for cy in range(395, 465, 18):
        _pale_blood(draw, 95, cy, 22, 16, 0.75)
    _pale_blood(draw, 72, 430, 30, 26, 0.85)
    _pale_blood(draw, 118, 448, 26, 20, 0.8)
    _smeared_blob(draw, 88, 420, 45, 18, -0.3, 140, COAG)
    _drip(draw, 100, 440, 30, 4, 150, PALE)

    # Hombros en alas del torso central
    for cy in (268, 295, 322, 350):
        _pale_blood(draw, 205, cy, 24, 18, 0.72)
        _pale_blood(draw, 305, cy, 24, 18, 0.72)
    _pale_blood(draw, 198, 340, 20, 16, 0.68)
    _pale_blood(draw, 312, 355, 20, 16, 0.68)

    return layer.filter(ImageFilter.GaussianBlur(radius=0.4))


def build_forearm_skin_layer(size: int) -> Image.Image:
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(layer)

    for cx, cy, rx, ry in [
        (432, 240, 18, 38), (432, 210, 16, 22), (378, 295, 14, 18),
        (75, 140, 20, 40), (75, 115, 16, 18), (100, 55, 18, 16),
        (395, 55, 18, 16), (420, 95, 16, 18),
    ]:
        _layered_blood(draw, cx, cy, rx, ry, 0.82)
        _drip(draw, cx, cy + rx * 0.5, 20, 3, 170, COAG)

    return layer.filter(ImageFilter.GaussianBlur(radius=0.35))


def _blend_layer(base: Image.Image, overlay: Image.Image, strength: float = 1.0) -> None:
    base_px = base.load()
    over_px = overlay.load()
    w, h = base.size
    for y in range(h):
        for x in range(w):
            br, bg, bb, ba = base_px[x, y]
            if ba == 0:
                continue
            sr, sg, sb, sa = over_px[x, y]
            if sa == 0:
                continue
            t = (sa / 255.0) * strength
            nr = int(br * (1.0 - t) + sr * t)
            ng = int(bg * (1.0 - t) + sg * t)
            nb = int(bb * (1.0 - t) + sb * t)
            base_px[x, y] = (min(255, nr), min(255, ng), min(255, nb), ba)


def main() -> None:
    if not OUT_PATH.exists():
        raise SystemExit(f"Falta {OUT_PATH}; genera la textura base antes de añadir brazos.")

    base = Image.open(BASE_PATH).convert("RGBA")
    out = Image.open(OUT_PATH).convert("RGBA")
    size = base.size[0]

    sleeve_draw = build_sleeve_draw_layer(size)
    skin_draw = build_forearm_skin_layer(size)

    _blend_layer(out, sleeve_draw, 0.95)
    _blend_layer(out, skin_draw, 0.92)

    shirt_palette = (PALE_WASH, PALE, COAG, MID)
    skin_palette = (PALE_WASH, MID, COAG, FRESH)

    for x0, y0, x1, y1, strength in ARM_SHIRT_REGIONS:
        _paint_on_mask(out, base, x0, y0, x1, y1, strength, _is_shirt_fabric, shirt_palette)

    for x0, y0, x1, y1, strength in ARM_SKIN_REGIONS:
        _paint_on_mask(out, base, x0, y0, x1, y1, strength, _is_skin, skin_palette)

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    out.save(OUT_PATH)
    print(f"Saved {OUT_PATH} — solo brazos (cara/pecho intactos)")


if __name__ == "__main__":
    main()
