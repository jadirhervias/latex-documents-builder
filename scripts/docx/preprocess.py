#!/usr/bin/env python3
"""Prepare a LaTeX entry point for generic Pandoc DOCX conversion."""
from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


INCLUDE_RE = re.compile(r"\\(?:input|include)\{(?P<path>[^}]+)\}")
IMAGE_RE = re.compile(r"\\includegraphics(?:\[[^]]*\])?\{[^}]+\}")


def resolve_include(source: Path, include: str, search_roots: tuple[Path, ...]) -> Path:
    """Resolve an included TeX file relative to its parent or a resource root."""
    candidates = (source.parent, *search_roots)
    for root in candidates:
        candidate = root / include
        if candidate.suffix == "":
            candidate = candidate.with_suffix(".tex")
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(f"included file not found from {source}: {include}")


def expand_inputs(
    source: Path,
    stack: tuple[Path, ...] = (),
    search_roots: tuple[Path, ...] = (),
) -> str:
    """Recursively expand local input and include commands for Pandoc."""
    source = source.resolve()
    if source in stack:
        chain = " -> ".join(path.name for path in (*stack, source))
        raise ValueError(f"cyclic LaTeX include: {chain}")

    text = source.read_text(encoding="utf-8")

    def replace(match: re.Match[str]) -> str:
        child = resolve_include(source, match.group("path"), search_roots)
        return expand_inputs(child, (*stack, source), search_roots)

    return INCLUDE_RE.sub(replace, text)


def prepare_source(source: Path) -> tuple[str, dict[str, int]]:
    """Return expanded source and format-independent validation metadata."""
    converted = expand_inputs(source, search_roots=(Path.cwd(),))
    return converted, {"images": len(IMAGE_RE.findall(converted))}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("source", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("metadata", type=Path)
    args = parser.parse_args()

    converted, metadata = prepare_source(args.source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.metadata.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(converted, encoding="utf-8")
    args.metadata.write_text(json.dumps(metadata, indent=2), encoding="utf-8")
    print(f"Prepared LaTeX source with {metadata['images']} image(s).")


if __name__ == "__main__":
    main()
