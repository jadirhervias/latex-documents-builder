#!/usr/bin/env python3
"""Validate format-independent DOCX invariants."""
from __future__ import annotations

import argparse
import json
import zipfile
from pathlib import Path

from docx import Document


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Validate a generic DOCX.")
    parser.add_argument("document", type=Path)
    parser.add_argument("metadata", type=Path)
    return parser.parse_args()


def fail(message: str) -> None:
    raise SystemExit(f"ERROR: {message}")


def main() -> None:
    args = parse_args()
    if not args.document.is_file():
        fail(f"document does not exist: {args.document}")
    if not args.metadata.is_file():
        fail(f"metadata does not exist: {args.metadata}")
    metadata = json.loads(args.metadata.read_text(encoding="utf-8"))

    if not zipfile.is_zipfile(args.document):
        fail("the file is not a valid DOCX package")
    with zipfile.ZipFile(args.document) as archive:
        damaged = archive.testzip()
        if damaged:
            fail(f"damaged ZIP entry: {damaged}")

    document = Document(args.document)
    expected_images = int(metadata.get("images", 0))
    if len(document.inline_shapes) != expected_images:
        fail(
            f"expected {expected_images} inline image(s), found "
            f"{len(document.inline_shapes)}"
        )

    text = "\n".join(paragraph.text for paragraph in document.paragraphs)
    if not text.strip() and not document.tables and not document.inline_shapes:
        fail("the DOCX contains no visible content")

    print(
        f"OK: valid DOCX with {len(document.paragraphs)} paragraph(s), "
        f"{len(document.tables)} table(s), and {len(document.inline_shapes)} image(s)."
    )


if __name__ == "__main__":
    main()
