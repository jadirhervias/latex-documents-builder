#!/bin/sh
set -eu

if [ "$#" -ne 8 ]; then
  printf '%s\n' \
    "Usage: $0 SOURCE OUTPUT_NAME DOCUMENT BIBLIOGRAPHY RESOURCE_PATHS" \
    "          PROFILE REFERENCE_DOC LANGUAGE" >&2
  exit 2
fi

source_file=$1
output_name=$2
document=$3
bibliography=$4
resource_paths=$5
profile=$6
reference=$7
language=$8
build_dir="build/$document/$output_name/docx"
output_dir=output/docx
output_file="$output_dir/$output_name.docx"

. scripts/lib/progress.sh

case "$profile" in
  plain) ;;
  *)
    printf 'Unknown DOCX profile: %s\n' "$profile" >&2
    exit 2
    ;;
esac

mkdir -p "$build_dir" "$output_dir"
progress_init DOCX

progress_run 1 5 "Preparing fonts" "$build_dir/font-cache.console.log" \
  fc-cache -f

if [ -n "$reference" ] && [ ! -f "$reference" ]; then
  printf 'Configured reference DOCX does not exist: %s\n' "$reference" >&2
  exit 2
fi

progress_run 2 5 "Preprocessing LaTeX" \
  "$build_dir/preprocess.console.log" \
  python3 scripts/docx/preprocess.py \
  "$source_file" "$build_dir/source-pandoc.tex" "$build_dir/metadata.json"

set -- pandoc "$build_dir/source-pandoc.tex" \
  --from=latex \
  --to=docx \
  --standalone \
  --number-sections \
  "--resource-path=$resource_paths" \
  "--metadata=lang:$language" \
  "--output=$build_dir/pandoc.docx"
if [ -n "$reference" ]; then
  set -- "$@" "--reference-doc=$reference"
fi
if [ -n "$bibliography" ]; then
  set -- "$@" "--bibliography=$bibliography" --citeproc
fi
progress_run 3 5 "Converting the document with Pandoc" \
  "$build_dir/pandoc.console.log" "$@"

progress_run 4 5 "Copying the generated document" \
  "$build_dir/copy.console.log" \
  cp "$build_dir/pandoc.docx" "$output_file"

progress_run 5 5 "Validating DOCX integrity" \
  "$build_dir/validate.console.log" \
  python3 scripts/docx/validate_generic.py \
  "$output_file" "$build_dir/metadata.json"
tail -n 1 "$build_dir/validate.console.log"
progress_finish "$output_file"
