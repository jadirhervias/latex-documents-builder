#!/bin/sh
set -eu

if [ "$#" -ne 4 ]; then
  printf 'Usage: %s SOURCE OUTPUT_NAME BIBLIOGRAPHY DOCUMENT\n' "$0" >&2
  exit 2
fi

source_file=$1
output_name=$2
bibliography=$3
document=$4
build_dir="build/$document/$output_name/pdf"
output_dir=output/pdf
job_name=$(basename "${source_file%.tex}")
source_dir=$(dirname "$source_file")
texinputs="$source_dir//:"
bibinputs="$(dirname "$bibliography")//:"

. scripts/lib/progress.sh

mkdir -p "$build_dir" "$output_dir"
progress_init PDF

progress_run 1 5 "Preparing fonts" "$build_dir/font-cache.console.log" \
  fc-cache -f

run_xelatex() {
  stage=$1
  pass=$2
  progress_run "$stage" 5 "XeLaTeX, pass $pass of 3" \
    "$build_dir/xelatex-pass-$pass.console.log" \
  env TEXINPUTS="$texinputs" \
  xelatex -interaction=nonstopmode -halt-on-error -file-line-error \
    -output-directory="$build_dir" "$source_file"
}

run_xelatex 2 1
if [ -n "$bibliography" ]; then
  if [ ! -f "$bibliography" ]; then
    printf 'Configured bibliography does not exist: %s\n' "$bibliography" >&2
    exit 2
  fi
  progress_run 3 5 "Processing bibliography with Biber" \
    "$build_dir/biber.console.log" \
    env BIBINPUTS="$bibinputs" \
    biber --input-directory="$build_dir" --output-directory="$build_dir" "$job_name"
else
  progress_skip 3 5 "No bibliography configured."
fi
run_xelatex 4 2
run_xelatex 5 3

cp "$build_dir/$job_name.pdf" "$output_dir/$output_name.pdf"
progress_finish "$output_dir/$output_name.pdf"
