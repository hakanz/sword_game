"""Post-processing for Gemini-generated source art -> game-ready textures.

The image model returns opaque JPEG only, so transparency is recovered here:
  * `cutout`  - art painted on a flat magenta field; magenta -> alpha, with a
                despill pass so no pink fringe survives on the silhouette.
  * `glow`    - additive VFX painted on black; luminance -> alpha, RGB kept.
  * `opaque`  - backdrops/materials, no keying.
  * `tile`    - opaque + a mirrored cross-fade so the texture wraps seamlessly.

Nothing here talks to the network; `generate.py` owns that half.
"""
from __future__ import annotations

from PIL import Image, ImageChops, ImageFilter
import numpy as np

KEY = np.array([255.0, 0.0, 255.0])


def _to_rgb_array(img: Image.Image) -> np.ndarray:
    return np.asarray(img.convert("RGB"), dtype=np.float32)


def cutout(img: Image.Image, tol: float = 118.0, soft: float = 62.0) -> Image.Image:
    """Magenta chroma-key with despill. `tol` = fully transparent below this
    distance from pure magenta, `soft` = the feathered band above it."""
    rgb = _to_rgb_array(img)
    dist = np.sqrt(((rgb - KEY) ** 2).sum(axis=2))
    alpha = np.clip((dist - tol) / soft, 0.0, 1.0)

    # Despill: magenta bleeds into edge pixels as "green is the odd one out".
    r, g, b = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    spill = np.minimum(r, b) - g
    fix = np.clip(spill, 0.0, None) * 0.85
    r = np.clip(r - fix, 0.0, 255.0)
    b = np.clip(b - fix, 0.0, 255.0)
    out = np.dstack([r, g, b, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def glow(img: Image.Image, floor: float = 10.0) -> Image.Image:
    """Black-field VFX -> luminance alpha, colour preserved and re-normalised
    so a dim wisp still carries its hue when drawn additively."""
    rgb = _to_rgb_array(img)
    lum = rgb.max(axis=2)
    alpha = np.clip((lum - floor) / (255.0 - floor), 0.0, 1.0)
    scale = np.where(lum > 1.0, 255.0 / np.maximum(lum, 1.0), 1.0)[..., None]
    bright = np.clip(rgb * scale, 0.0, 255.0)
    out = np.dstack([bright, alpha * 255.0]).astype(np.uint8)
    return Image.fromarray(out, "RGBA")


def trim(img: Image.Image, pad_fraction: float = 0.04) -> Image.Image:
    """Crops to the visible pixels and re-pads to a square, so every icon in a
    row is optically the same size no matter how the model framed it."""
    alpha = img.getchannel("A")
    box = alpha.point(lambda v: 255 if v > 8 else 0).getbbox()
    if box is None:
        return img
    art = img.crop(box)
    side = int(max(art.size) * (1.0 + pad_fraction * 2.0))
    canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    canvas.paste(art, ((side - art.width) // 2, (side - art.height) // 2))
    return canvas


def trim_vertical(img: Image.Image, pad_fraction: float = 0.02) -> Image.Image:
    """Crops to the visible pixels WITHOUT squaring — used for weapon sprites,
    where the aspect ratio is the weapon's real proportion and the grip must
    stay at a predictable place along the bottom edge."""
    alpha = img.getchannel("A")
    box = alpha.point(lambda v: 255 if v > 8 else 0).getbbox()
    if box is None:
        return img
    art = img.crop(box)
    pad = int(max(art.size) * pad_fraction)
    canvas = Image.new("RGBA", (art.width + pad * 2, art.height + pad * 2), (0, 0, 0, 0))
    canvas.paste(art, (pad, pad))
    return canvas


def seamless(img: Image.Image, blend: float = 0.18) -> Image.Image:
    """Cross-fades a mirrored copy over each edge so the tile wraps without a
    visible seam. Cheap, and good enough for the small material patches the
    rig fills polygons with."""
    im = img.convert("RGB")
    w, h = im.size
    bw, bh = max(1, int(w * blend)), max(1, int(h * blend))
    base = np.asarray(im, dtype=np.float32)

    rolled = np.roll(np.roll(base, w // 2, axis=1), h // 2, axis=0)
    mask = np.ones((h, w), dtype=np.float32)
    ramp_x = np.linspace(0.0, 1.0, bw, dtype=np.float32)
    mask[:, :bw] = np.minimum(mask[:, :bw], ramp_x[None, :])
    mask[:, w - bw:] = np.minimum(mask[:, w - bw:], ramp_x[::-1][None, :])
    ramp_y = np.linspace(0.0, 1.0, bh, dtype=np.float32)
    mask[:bh, :] = np.minimum(mask[:bh, :], ramp_y[:, None])
    mask[h - bh:, :] = np.minimum(mask[h - bh:, :], ramp_y[::-1][:, None])

    merged = base * mask[..., None] + rolled * (1.0 - mask[..., None])
    return Image.fromarray(merged.astype(np.uint8), "RGB")


def fit(img: Image.Image, size: tuple[int, int], cover: bool = True) -> Image.Image:
    """Resamples to `size`. `cover` crops the overflow (backdrops); otherwise
    the image is squashed to the exact box (tiles)."""
    if not cover:
        return img.resize(size, Image.LANCZOS)
    target_w, target_h = size
    scale = max(target_w / img.width, target_h / img.height)
    scaled = img.resize((max(1, round(img.width * scale)),
                         max(1, round(img.height * scale))), Image.LANCZOS)
    left = (scaled.width - target_w) // 2
    top = (scaled.height - target_h) // 2
    return scaled.crop((left, top, left + target_w, top + target_h))


def contain(img: Image.Image, size: tuple[int, int]) -> Image.Image:
    """Resamples so the whole image fits inside `size`, preserving aspect."""
    out = img.copy()
    out.thumbnail(size, Image.LANCZOS)
    return out


def soften_edge(img: Image.Image) -> Image.Image:
    """One-pixel alpha blur — kills the stair-stepping the chroma key leaves
    on a hard silhouette once the icon is scaled down."""
    alpha = img.getchannel("A").filter(ImageFilter.GaussianBlur(0.7))
    out = img.copy()
    out.putalpha(alpha)
    return out
