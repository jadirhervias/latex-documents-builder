#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
  printf 'Usage: %s DOCUMENT.docx METADATA.json PROFILE BUILD_DIR\n' "$0" >&2
  exit 2
fi

docx=$1
metadata=$2
profile=$3
build_dir=$4
render_dir="$build_dir/rendered"
profile_dir="$build_dir/libreoffice-profile"

rm -rf "$render_dir" "$profile_dir"
mkdir -p "$render_dir" "$profile_dir"

case "$profile" in
  plain) python3 scripts/docx/validate_generic.py "$docx" "$metadata" ;;
  *)
    printf 'Unknown DOCX profile: %s\n' "$profile" >&2
    exit 2
    ;;
esac

absolute_profile=$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve().as_uri())' "$profile_dir")
libreoffice -env:UserInstallation="$absolute_profile" \
  --headless --convert-to pdf --outdir "$render_dir" "$docx" >/dev/null

rendered_pdf="$render_dir/$(basename "${docx%.docx}").pdf"
test -s "$rendered_pdf"
pdfinfo "$rendered_pdf" > "$render_dir/pdfinfo.txt"
pdftoppm -jpeg -r 72 "$rendered_pdf" "$render_dir/page" >/dev/null 2>&1

page_count=$(find "$render_dir" -name 'page-*.jpg' | wc -l | tr -d ' ')
test "$page_count" -gt 0
printf 'OK: DOCX validated and rendered as %s page(s) in %s.\n' \
  "$page_count" "$render_dir"
