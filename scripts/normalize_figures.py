#!/usr/bin/env python3
"""Normalize figure files before XeLaTeX.

Some exported screenshots/Office images can have a .png or .jpg extension while
containing BMP/DIB data or metadata that xdvipdfmx cannot read. This script
opens each raster image with Pillow and rewrites it as a clean PNG/JPEG using
its current filename, so existing `\\includegraphics` paths keep working.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

try:
    from PIL import Image, ImageOps, UnidentifiedImageError
except Exception as exc:  # pragma: no cover
    print(f"normalize_figures.py: Pillow is not available: {exc}", file=sys.stderr)
    sys.exit(0)

ROOT = Path("figuras")
EXTS = {".png", ".jpg", ".jpeg"}

Image.MAX_IMAGE_PIXELS = None


def flatten_to_rgb(img: Image.Image) -> Image.Image:
    """Return an RGB image, compositing transparency on white when needed."""
    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        rgba = img.convert("RGBA")
        bg = Image.new("RGB", rgba.size, (255, 255, 255))
        bg.paste(rgba, mask=rgba.getchannel("A"))
        return bg
    if img.mode != "RGB":
        return img.convert("RGB")
    return img


def normalize(path: Path) -> bool:
    suffix = path.suffix.lower()
    tmp = path.with_name(f".{path.name}.normalized{suffix}")
    try:
        # Open once to validate and again for actual conversion after verify().
        with Image.open(path) as probe:
            probe.verify()
        with Image.open(path) as img:
            img = ImageOps.exif_transpose(img)
            if img.width <= 0 or img.height <= 0:
                raise ValueError(f"invalid dimensions {img.width}x{img.height}")
            img = flatten_to_rgb(img)
            if suffix == ".png":
                img.save(tmp, format="PNG", optimize=True)
            else:
                img.save(tmp, format="JPEG", quality=95, optimize=True)
        os.replace(tmp, path)
        print(f"normalized: {path}")
        return True
    except (UnidentifiedImageError, OSError, ValueError) as exc:
        if tmp.exists():
            tmp.unlink()
        print(f"normalize_figures.py: WARNING: could not normalize {path}: {exc}", file=sys.stderr)
        return False


def main() -> int:
    if not ROOT.is_dir():
        print("normalize_figures.py: figuras/ not found; skipping.", file=sys.stderr)
        return 0
    files = sorted(p for p in ROOT.rglob("*") if p.is_file() and p.suffix.lower() in EXTS)
    failed = [str(p) for p in files if not normalize(p)]
    if failed:
        print("normalize_figures.py: WARNING: some figure files could not be normalized:", file=sys.stderr)
        for item in failed:
            print(f"  - {item}", file=sys.stderr)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
