#!/usr/bin/env python3
"""Normalize figure files in one or more LaTeX project folders.

Usage examples:
  python3 scripts/normalize_figures.py pyme-comercio
  python3 scripts/normalize_figures.py pyme-farmacia
  python3 scripts/normalize_figures.py pyme-comercio pyme-farmacia
  python3 scripts/normalize_figures.py .

The script keeps the original filenames referenced by main.tex. It only rewrites
supported image files in a LaTeX-friendly format when Pillow can open them.
It uses a local cache file (.normalize_cache.txt) to avoid re-processing unmodified files.
"""
from __future__ import annotations

import sys
import hashlib
from pathlib import Path
from PIL import Image, ImageOps, UnidentifiedImageError

SUPPORTED = {".png", ".jpg", ".jpeg"}
CACHE_FILE_NAME = ".normalize_cache.txt"


def get_file_hash(path: Path) -> str:
    """Calculate SHA-256 hash of a file to check for changes."""
    hasher = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def load_cache(fig_dir: Path) -> set[str]:
    """Load existing hashes from the cache file."""
    cache_path = fig_dir / CACHE_FILE_NAME
    if not cache_path.is_file():
        return set()
    try:
        with open(cache_path, "r", encoding="utf-8") as f:
            return {line.strip() for line in f if line.strip()}
    except OSError:
        return set()


def save_cache(fig_dir: Path, hashes: set[str]) -> None:
    """Save all processed hashes back to the cache file."""
    cache_path = fig_dir / CACHE_FILE_NAME
    try:
        with open(cache_path, "w", encoding="utf-8") as f:
            for h in sorted(hashes):
                f.write(f"{h}\n")
    except OSError as exc:
        print(f"[warn] Could not save cache to {cache_path}: {exc}", file=sys.stderr)


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
    skipped = 0
    dirs: list[Path] = []
    
    for target in targets:
        dirs.extend(figure_dirs(target))
        
    if not dirs:
        print("[info] No figuras directory found.")
        return 0
        
    for fig_dir in dirs:
        cache = load_cache(fig_dir)
        new_cache = set()
        
        for path in sorted(fig_dir.rglob("*")):
            if path.is_file() and path.name != CACHE_FILE_NAME:
                suffix = path.suffix.lower()
                if suffix not in SUPPORTED:
                    continue
                    
                # Calculate initial hash before doing anything
                file_hash = get_file_hash(path)
                
                if file_hash in cache:
                    # Already normalized in a previous run
                    new_cache.add(file_hash)
                    skipped += 1
                    continue
                
                if normalize_image(path):
                    normalized += 1
                    # Re-calculate hash since the file was rewritten and changed
                    new_hash = get_file_hash(path)
                    new_cache.add(new_hash)
                    
        # Update cache file for this folder
        save_cache(fig_dir, new_cache)
        
    print(f"[info] Normalized {normalized} figure file(s), skipped {skipped} already optimized file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))