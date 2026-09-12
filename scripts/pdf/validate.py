#!/usr/bin/env python3
from __future__ import annotations

import argparse
import re
import subprocess
from pathlib import Path

from pypdf import PdfReader


PAPER_SIZES = {
    "a4": (595.28, 841.89),
    "letter": (612.0, 792.0),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate a generated PDF.")
    parser.add_argument("pdf", type=Path)
    parser.add_argument("log", type=Path)
    parser.add_argument("--paper", choices=sorted(PAPER_SIZES), default="a4")
    parser.add_argument(
        "--required-font",
        help="Require a font name (spaces are ignored) in pdffonts output.",
    )
    return parser.parse_args()


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def main() -> None:
    args = parse_args()
    if not args.pdf.is_file() or not args.log.is_file():
        fail("the generated PDF or XeLaTeX log is missing")

    reader = PdfReader(str(args.pdf))
    if not reader.pages:
        fail("the PDF has no pages")

    expected_width, expected_height = PAPER_SIZES[args.paper]
    invalid = []
    for number, page in enumerate(reader.pages, 1):
        width = float(page.mediabox.width)
        height = float(page.mediabox.height)
        valid = (
            abs(width - expected_width) < 2
            and abs(height - expected_height) < 2
        ) or (
            abs(width - expected_height) < 2
            and abs(height - expected_width) < 2
        )
        if not valid:
            invalid.append((number, round(width, 2), round(height, 2)))
    if invalid:
        fail(f"pages do not use {args.paper.upper()}: {invalid[:5]}")

    log_text = args.log.read_text(encoding="utf-8", errors="replace")
    fatal_patterns = (
        r"^! ",
        r"LaTeX Error:",
        r"Package .* Error:",
        r"There were undefined references",
        r"Citation .* undefined",
    )
    for pattern in fatal_patterns:
        if re.search(pattern, log_text, flags=re.MULTILINE | re.IGNORECASE):
            fail(f"the build log matches an error pattern: {pattern}")

    font_summary = ""
    if args.required_font:
        fonts = subprocess.run(
            ["pdffonts", str(args.pdf)], check=True, text=True, capture_output=True
        ).stdout
        normalized_fonts = re.sub(r"\s+", "", fonts).lower()
        normalized_required = re.sub(r"\s+", "", args.required_font).lower()
        if normalized_required not in normalized_fonts:
            fail(f"required font was not embedded: {args.required_font}")
        font_summary = f"; {args.required_font} detected"

    warnings = len(re.findall(r"Overfull \\[hv]box", log_text))
    print(
        f"OK: {len(reader.pages)} {args.paper.upper()} page(s){font_summary}; "
        f"{warnings} non-fatal overflow warning(s)."
    )


if __name__ == "__main__":
    main()
