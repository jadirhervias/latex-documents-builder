#!/usr/bin/env python3
"""Normalize figure files in one or more LaTeX project folders.

Usage examples:
  python3 scripts/normalize_figures.py pyme-comercio
  python3 scripts/normalize_figures.py pyme-farmacia
  python3 scripts/normalize_figures.py pyme-comercio pyme-farmacia
  python3 scripts/normalize_figures.py .

The script keeps the original filenames referenced by main.tex. It only rewrites
supported image files in a LaTeX-friendly format when Pillow can open them.
"""
from __future__ import annotations

import sys
from pathlib import Path
from PIL import Image, ImageOps, UnidentifiedImageError

SUPPORTED = {".png", ".jpg", ".jpeg"}


def figure_dirs(target: Path) -> list[Path]:
    target = target.resolve()
    candidates: list[Path] = []
    if (target / "figuras").is_dir():
        candidates.append(target / "figuras")
    # If called from repository root with '.', normalize both versions.
    for child in ("pyme-comercio", "pyme-farmacia"):
        fig_dir = target / child / "figuras"
        if fig_dir.is_dir():
            candidates.append(fig_dir)
    # De-duplicate while preserving order.
    seen = set()
    result = []
    for item in candidates:
        if item not in seen:
            seen.add(item)
            result.append(item)
    return result


def flatten_transparency(img: Image.Image) -> Image.Image:
    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        rgba = img.convert("RGBA")
        background = Image.new("RGBA", rgba.size, (255, 255, 255, 255))
        background.alpha_composite(rgba)
        return background.convert("RGB")
    if img.mode == "CMYK":
        return img.convert("RGB")
    return img


def normalize_image(path: Path) -> bool:
    suffix = path.suffix.lower()
    if suffix not in SUPPORTED:
        return False
    try:
        with Image.open(path) as im:
            im = ImageOps.exif_transpose(im)
            im = flatten_transparency(im)
            if suffix == ".png":
                # Save as RGB/RGBA-compatible PNG without metadata that can confuse some TeX drivers.
                im.save(path, format="PNG", optimize=True)
            else:
                im = im.convert("RGB")
                im.save(path, format="JPEG", quality=95, optimize=True, progressive=False)
        return True
    except (UnidentifiedImageError, OSError) as exc:
        print(f"[warn] Could not normalize {path}: {exc}", file=sys.stderr)
        return False


def main(argv: list[str]) -> int:
    targets = [Path(arg) for arg in argv] if argv else [Path(".")]
    normalized = 0
    dirs: list[Path] = []
    for target in targets:
        dirs.extend(figure_dirs(target))
    if not dirs:
        print("[info] No figuras directory found.")
        return 0
    for fig_dir in dirs:
        for path in sorted(fig_dir.rglob("*")):
            if path.is_file() and normalize_image(path):
                normalized += 1
    print(f"[info] Normalized {normalized} figure file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
