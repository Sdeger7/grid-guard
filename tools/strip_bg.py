#!/usr/bin/env python3
"""Remove the baked-in checkerboard/solid background from unit sprites.

The generated art shipped with the transparency-preview checkerboard flattened
into real pixels. This makes the neutral (R≈G≈B) background that is connected to
the image border transparent, leaving the coloured/bright subject intact.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage

FILES = ["pv_panel", "wind_turbine", "core", "bess"]
IMG_DIR = "assets/images"


def strip(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx = np.maximum(np.maximum(r, g), b)
    mn = np.minimum(np.minimum(r, g), b)
    lum = (r + g + b) / 3.0
    neutral = (mx - mn) <= 22  # checkerboard greys are neutral

    # Learn the background luminance band from neutral pixels on the border.
    h, w = lum.shape
    border = np.zeros((h, w), bool)
    border[0, :] = border[-1, :] = border[:, 0] = border[:, -1] = True
    seed = neutral & border
    if seed.sum() < 50:
        print(f"  {path}: no neutral border seed, skipped")
        return
    band = lum[seed]
    lo, hi = band.min() - 14, band.max() + 14

    candidate = neutral & (lum >= lo) & (lum <= hi)

    # Only remove candidate regions connected to the image border.
    labels, n = ndimage.label(candidate)
    border_labels = set(np.unique(labels[border])) - {0}
    bg = np.isin(labels, list(border_labels))

    out = np.asarray(im).copy()
    out[bg, 3] = 0

    # Semi-transparent glow flattened onto the checkerboard isn't neutral, so the
    # test above misses it and it shows up as a coloured checker halo. Those
    # pixels stay pale and washed out, unlike the solid subject or a saturated
    # light source — drop them too.
    sat = mx - mn
    haze = (out[..., 3] > 0) & (lum >= 150) & (sat <= 85)
    out[haze, 3] = 0

    # Feather the 1px fringe so edges aren't harsh.
    edge = bg ^ ndimage.binary_erosion(bg)
    keep_edge = edge & ~bg
    _ = keep_edge  # (no-op placeholder; hard cut is fine here)

    Image.fromarray(out, "RGBA").save(path)
    pct = 100 * bg.sum() / bg.size
    print(f"  {path}: removed {pct:.0f}% as background (band {lo:.0f}-{hi:.0f})")


if __name__ == "__main__":
    for name in FILES:
        p = f"{IMG_DIR}/{name}.png"
        try:
            strip(p)
        except FileNotFoundError:
            print(f"  {p}: missing")
    print("done")
