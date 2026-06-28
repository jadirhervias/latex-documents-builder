#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
echo "=== Verificando caché de imágenes ==="
python3 "$SCRIPT_DIR/normalize_figures.py" "${@:-.}"