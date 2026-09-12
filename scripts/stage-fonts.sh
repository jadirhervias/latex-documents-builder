#!/bin/sh
set -eu

destination=${1:-.fonts/default}
source_dir=${2:-}
profile=${3:-none}

mkdir -p "$destination"

case "$profile" in
  none) ;;
  *)
    printf 'Unknown font profile: %s\n' "$profile" >&2
    exit 2
    ;;
esac

if [ -z "$source_dir" ]; then
  printf 'Using document fonts already present in %s\n' "$destination"
  exit 0
fi

if [ ! -d "$source_dir" ]; then
  printf 'Configured font directory does not exist: %s\n' "$source_dir" >&2
  exit 1
fi

found=0
for font in "$source_dir"/*.ttf "$source_dir"/*.otf "$source_dir"/*.ttc; do
  [ -f "$font" ] || continue
  cp "$font" "$destination/"
  found=1
done

if [ "$found" -eq 0 ]; then
  printf 'No supported font files found in: %s\n' "$source_dir" >&2
  exit 1
fi

printf 'Fonts staged in %s\n' "$destination"
