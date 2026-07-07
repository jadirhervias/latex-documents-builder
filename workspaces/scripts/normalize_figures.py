#!/usr/bin/env python3
"""Safely normalize figure files in one or more LaTeX project folders.

What this script does:
  - Optimizes/re-saves PNG/JPG/JPEG files inside each project's ``figuras`` folder.
  - Keeps the same filenames used by LaTeX.
  - Uses ``figuras/.normalize_cache.txt`` to skip images already normalized.
  - Stores the cache by relative file path + SHA-256 content hash.

Why the cache is path + content based:
  - A filename-only cache misses changes when an image is replaced but keeps the
    same name.
  - A hash-only cache can create false skips if two different paths share the
    same content hash.
  - The current cache format makes the decision per image path and binary
    content, so replacing ``figuras/foo.png`` with a new binary always triggers
    re-normalization.

What this script intentionally does NOT do:
  - It does not rename images.
  - It does not edit ``main.tex``.
  - It does not extract images from DOCX files.

If image references such as ``figuras/docx_image3.png`` appear in ``main.tex``,
that file was regenerated from a DOCX source, usually by a command similar to:
``pandoc something.docx -o main.tex --extract-media=figuras``. That workflow
must not be mixed with image optimization because it overwrites the curated
LaTeX source.
"""
from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path
from PIL import Image, ImageOps, UnidentifiedImageError

SUPPORTED = {".png", ".jpg", ".jpeg"}
CACHE_FILE_NAME = ".normalize_cache.txt"
CACHE_VERSION = "v2"
DOCX_IMAGE_PATTERN = re.compile(r"docx_image\d+\.(?:png|jpe?g)", re.IGNORECASE)


def get_file_hash(path: Path) -> str:
    """Calculate SHA-256 hash of a file to detect binary content changes."""
    hasher = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            hasher.update(chunk)
    return hasher.hexdigest()


def cache_key(fig_dir: Path, path: Path) -> str:
    """Return a stable POSIX-style relative path for cache matching."""
    return path.relative_to(fig_dir).as_posix()


def load_cache(fig_dir: Path) -> dict[str, str]:
    """Load cache entries as {relative_path: sha256_hash}.

    Current format, one item per line:
      v2<TAB>relative/path.png<TAB>sha256

    Legacy cache files that contain only hashes are intentionally ignored. That
    forces a one-time rebuild of the cache and prevents stale filename/hash-only
    strategies from hiding changed images.
    """
    cache_path = fig_dir / CACHE_FILE_NAME
    if not cache_path.is_file():
        return {}

    entries: dict[str, str] = {}
    try:
        with open(cache_path, "r", encoding="utf-8") as f:
            for raw_line in f:
                line = raw_line.strip()
                if not line or line.startswith("#"):
                    continue
                parts = line.split("\t")
                if len(parts) == 3 and parts[0] == CACHE_VERSION:
                    rel_path, digest = parts[1], parts[2]
                    if rel_path and re.fullmatch(r"[0-9a-f]{64}", digest):
                        entries[rel_path] = digest
    except OSError:
        return {}
    return entries


def save_cache(fig_dir: Path, entries: dict[str, str]) -> None:
    """Persist cache entries atomically."""
    cache_path = fig_dir / CACHE_FILE_NAME
    tmp_path = cache_path.with_suffix(cache_path.suffix + ".tmp")
    try:
        with open(tmp_path, "w", encoding="utf-8") as f:
            f.write("# normalize_figures cache\n")
            f.write("# format: v2<TAB>relative_path<TAB>sha256_after_normalization\n")
            for rel_path in sorted(entries):
                f.write(f"{CACHE_VERSION}\t{rel_path}\t{entries[rel_path]}\n")
        tmp_path.replace(cache_path)
    except OSError as exc:
        print(f"[warn] Could not save cache to {cache_path}: {exc}", file=sys.stderr)
        try:
            tmp_path.unlink(missing_ok=True)
        except OSError:
            pass


def figure_dirs(target: Path) -> list[Path]:
    target = target.resolve()
    candidates: list[Path] = []

    # Normal case: target is the project directory.
    if (target / "figuras").is_dir():
        candidates.append(target / "figuras")

    # If called from repository root with '.', normalize known workspaces.
    for child in ("pyme-comercio", "pyme-farmacia"):
        fig_dir = target / child / "figuras"
        if fig_dir.is_dir():
            candidates.append(fig_dir)

    # If called from repository root in this ZIP structure.
    workspace_root = target / "workspaces"
    if workspace_root.is_dir():
        for child in sorted(workspace_root.iterdir()):
            fig_dir = child / "figuras"
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
                # Save PNG without metadata that can confuse some TeX drivers.
                im.save(path, format="PNG", optimize=True)
            else:
                im = im.convert("RGB")
                im.save(path, format="JPEG", quality=95, optimize=True, progressive=False)
        return True
    except (UnidentifiedImageError, OSError) as exc:
        print(f"[warn] Could not normalize {path}: {exc}", file=sys.stderr)
        return False


def project_dir_from_fig_dir(fig_dir: Path) -> Path:
    return fig_dir.parent


def assert_main_tex_safe(project_dir: Path, before_hash: str | None = None) -> str | None:
    """Validate that main.tex is not a DOCX-regenerated file and optionally unchanged."""
    main_tex = project_dir / "main.tex"
    if not main_tex.is_file():
        return None

    text = main_tex.read_text(encoding="utf-8", errors="replace")
    if DOCX_IMAGE_PATTERN.search(text):
        print(
            "[error] main.tex contains references like 'docx_imageX.png'.\n"
            "        That means main.tex was regenerated from a DOCX or media-extraction step.\n"
            "        Image optimization does not rename images and must not overwrite main.tex.\n"
            "        Restore the curated main.tex that references files such as 'figura1-mapa_procesos.png'.",
            file=sys.stderr,
        )
        raise SystemExit(2)

    current_hash = get_file_hash(main_tex)
    if before_hash is not None and current_hash != before_hash:
        print(
            f"[error] Refusing to continue: {main_tex} changed during figure normalization.",
            file=sys.stderr,
        )
        raise SystemExit(3)
    return current_hash


def should_skip_path(path: Path) -> bool:
    """Skip OS metadata and cache files, even if their suffix looks like an image."""
    parts = set(path.parts)
    return (
        path.name == CACHE_FILE_NAME
        or path.name.startswith("._")
        or path.name == ".DS_Store"
        or "__MACOSX" in parts
    )


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

    # Validate main.tex before touching images and remember its hash.
    main_hashes: dict[Path, str | None] = {}
    for fig_dir in dirs:
        project_dir = project_dir_from_fig_dir(fig_dir)
        if project_dir not in main_hashes:
            main_hashes[project_dir] = assert_main_tex_safe(project_dir)

    for fig_dir in dirs:
        cache = load_cache(fig_dir)
        next_cache: dict[str, str] = {}

        for path in sorted(fig_dir.rglob("*")):
            if not path.is_file() or should_skip_path(path):
                continue

            suffix = path.suffix.lower()
            if suffix not in SUPPORTED:
                continue

            rel_path = cache_key(fig_dir, path)
            current_hash = get_file_hash(path)

            if cache.get(rel_path) == current_hash:
                next_cache[rel_path] = current_hash
                skipped += 1
                continue

            if normalize_image(path):
                normalized += 1
                next_cache[rel_path] = get_file_hash(path)

        save_cache(fig_dir, next_cache)

    # Verify main.tex did not change.
    for project_dir, before_hash in main_hashes.items():
        assert_main_tex_safe(project_dir, before_hash)

    print(f"[info] Normalized {normalized} figure file(s), skipped {skipped} already optimized file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
