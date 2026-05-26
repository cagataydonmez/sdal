#!/usr/bin/env python3
"""
Generate per-theme logo variants from app_icon_1024.png.
The original logo has an orange-rust left figure and a green right figure.
We recolor the orange-rust region to each theme's accent color.
"""
from PIL import Image
import numpy as np
import os

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC = os.path.join(SCRIPT_DIR, "app_icon_1024.png")

# Theme accent colors (dark-mode accent, full opacity)
THEMES = {
    "kor":   (0xE9, 0x9A, 0x73),  # warm rust/terracotta
    "atlas": (0x82, 0xB8, 0xE0),  # cool steel blue
    "vibe":  (0xBB, 0x96, 0xF5),  # vivid violet
    "zinc":  (0xC8, 0xCD, 0xD6),  # cool silver slate
    "ember": (0xF0, 0xC0, 0x50),  # warm amber gold
    "mist":  (0x80, 0xC8, 0x9C),  # sage green
    "nova":  (0x60, 0xA5, 0xFA),  # luminous blue
    "prism": (0xA7, 0x8B, 0xFA),  # violet
    "dusk":  (0xFB, 0xAF, 0x24),  # warm amber
    "flux":  (0x2D, 0xD4, 0xBF),  # vibrant teal
}

img = Image.open(SRC).convert("RGBA")
arr = np.array(img, dtype=np.float32)

R, G, B, A = arr[..., 0], arr[..., 1], arr[..., 2], arr[..., 3]

# Identify the orange-rust region: high red, medium green, low blue, visible
orange_mask = (
    (R > 160) &
    (G > 80) & (G < 180) &
    (B < 100) &
    (A > 30) &
    (R > G * 1.3) &   # clearly more red than green
    (R > B * 2.0)     # clearly more red than blue
)

# Keep the green figure intact — green figure: high G, low R relative to G
green_mask = (G > R * 1.1) & (G > B * 1.1) & (A > 30)

# Refine: exclude pixels that are also green
orange_only = orange_mask & ~green_mask

print(f"Orange pixels detected: {orange_only.sum()}")
print(f"Green pixels detected: {green_mask.sum()}")

for theme_name, (tr, tg, tb) in THEMES.items():
    out_arr = arr.copy()

    # For each orange pixel, replace hue with theme accent, preserve luminance ratio
    mask = orange_only
    if mask.sum() == 0:
        print(f"WARNING: no orange pixels found for {theme_name}")
        continue

    src_r = arr[mask, 0]
    src_g = arr[mask, 1]
    src_b = arr[mask, 2]

    # Compute per-pixel luminance relative to source orange center (~180, 100, 60)
    orig_lum = (src_r * 0.299 + src_g * 0.587 + src_b * 0.114)
    # Reference luminance of the source accent
    ref_lum = 180 * 0.299 + 100 * 0.587 + 60 * 0.114  # ~113
    target_lum = tr * 0.299 + tg * 0.587 + tb * 0.114

    scale = orig_lum / max(ref_lum, 1.0)

    new_r = np.clip(tr * scale, 0, 255)
    new_g = np.clip(tg * scale, 0, 255)
    new_b = np.clip(tb * scale, 0, 255)

    out_arr[mask, 0] = new_r
    out_arr[mask, 1] = new_g
    out_arr[mask, 2] = new_b

    out_img = Image.fromarray(out_arr.astype(np.uint8), "RGBA")
    out_path = os.path.join(SCRIPT_DIR, f"logo_{theme_name}.png")
    out_img.save(out_path, "PNG")
    print(f"Saved: {out_path}")

print("Done.")
