# Building and verification

## Architecture

Each directory under `documents/` is an independent build profile:

```text
documents/<name>/<source>.tex
├── XeLaTeX (+ Biber when configured) -> output/pdf/<output>.pdf
└── preprocessing + Pandoc            -> output/docx/<output>.docx
```

Intermediate files are isolated under
`build/<document>/<output-name>/`. Generated files are not versioned.

## Dependencies

- Docker Desktop.
- A local `latex-builder:latest` base image containing XeLaTeX, Biber, and
  Pandoc.

Run `make builder` once to create `latex-docs-builder:latest`. This project
image adds LibreOffice, Poppler, `python-docx`, and `pypdf` for validation and
rendering.

Document-specific fonts live in `.fonts/<document>/` at the project root. The
directory is ignored by Git and mounted into both build pipelines only for the
selected document. Add `.ttf`, `.otf`, or `.ttc` files there directly, or use
`FONT_SOURCE_DIR` to copy them from another local directory with `make fonts`.
The neutral `FONT_PROFILE=none` policy uses that directory as-is.

## Commands

| Command | Result |
|---|---|
| `make builder` | Build the reproducible toolchain image. |
| `make list` | List document profiles. |
| `make info` | Show the selected profile and output paths. |
| `make test` | Run preprocessing unit tests. |
| `make pdf` | Build the selected PDF. |
| `make pdf-check` | Check pages, paper size, logs, and an optional font. |
| `make docx` | Convert the selected source to DOCX. |
| `make docx-check` | Validate and render the DOCX. |
| `make all` | Test, build, and validate both formats. |
| `make clean` | Remove generated artifacts while preserving placeholders. |

The DOCX check verifies package integrity, included-image count, visible
content, and a successful LibreOffice render. This behavior is selected by the
neutral `DOCX_PROFILE=plain` policy. Diagnostic pages remain under the selected
document's build directory.

See [ADDING_DOCUMENTS.md](ADDING_DOCUMENTS.md) to create a profile or configure
a bibliography, reference DOCX, language, font, and paper size.
