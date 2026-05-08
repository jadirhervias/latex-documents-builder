#!/usr/bin/env bash
set -euo pipefail

# Normalize raster figures before XeLaTeX. Prefer Pillow because it detects the
# real file format from the header, even when the extension is misleading.
if command -v python3 >/dev/null 2>&1 && python3 -c 'from PIL import Image' >/dev/null 2>&1; then
  python3 scripts/normalize_figures.py
  exit 0
fi

# Fallback for systems with ImageMagick but without Pillow. Debian often ships
# ImageMagick 6 as `convert` rather than ImageMagick 7 as `magick`.
if command -v magick >/dev/null 2>&1; then
  IM=(magick)
elif command -v convert >/dev/null 2>&1; then
  IM=(convert)
else
  echo "normalize_figures.sh: neither Pillow nor ImageMagick found; skipping figure normalization." >&2
  exit 0
fi

if [ ! -d figuras ]; then
  echo "normalize_figures.sh: figuras/ not found; skipping figure normalization." >&2
  exit 0
fi

while IFS= read -r -d '' img; do
  lower="${img,,}"
  case "$lower" in
    *.png)
      tmp="${img}.normalized.png"
      if "${IM[@]}" "$img" -auto-orient -background white -alpha remove -alpha off -strip "png:$tmp"; then
        mv "$tmp" "$img"
        echo "normalized: $img"
      else
        rm -f "$tmp"
        echo "normalize_figures.sh: WARNING: could not normalize $img" >&2
      fi
      ;;
    *.jpg|*.jpeg)
      tmp="${img}.normalized.jpg"
      if "${IM[@]}" "$img" -auto-orient -background white -alpha remove -alpha off -strip "jpg:$tmp"; then
        mv "$tmp" "$img"
        echo "normalized: $img"
      else
        rm -f "$tmp"
        echo "normalize_figures.sh: WARNING: could not normalize $img" >&2
      fi
      ;;
  esac
done < <(find figuras -type f \( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \) -print0)
