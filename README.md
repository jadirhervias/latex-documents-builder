# Reusable LaTeX document scaffold

This repository is a content-neutral starting point for building LaTeX
documents as PDF and DOCX files through one versioned Docker toolchain. Each
document lives in its own directory and provides a small build manifest.

The included `example` profile is intentionally minimal. Copy it when starting
a report, letter, article, or another document, then replace its placeholder
content.

## Quick start

Docker Desktop and the base image `latex-builder:latest` are required. Build
the project image once:

```bash
make builder
```

Build and validate both output formats:

```bash
make list
make info
make all
```

The generated files are `output/pdf/example.pdf` and
`output/docx/example.docx`.

To start a new document, copy the example profile and rename its source:

```bash
cp -R documents/example documents/report
mv documents/report/example.tex documents/report/report.tex
```

Then update `documents/report/document.mk` and build it:

```bash
make DOCUMENT=report all
```

Multiple entry points may share one profile. Select one with `FILE`:

```bash
make DOCUMENT=report FILE=appendix.tex all
```

The output basename follows the selected `.tex` filename unless the manifest
sets `OUTPUT_NAME`.

## Project layout

```text
documents/
  example/
    document.mk      # build manifest
    example.tex      # neutral starter source
.fonts/<document>/   # local, document-specific fonts (ignored by Git)
scripts/
  pdf/               # PDF build and validation
  docx/              # DOCX conversion and validation
build/<document>/<output-name>/ # isolated intermediates and diagnostic renders
output/pdf/          # final PDFs
output/docx/         # final Word documents
```

See [docs/ADDING_DOCUMENTS.md](docs/ADDING_DOCUMENTS.md) for the manifest
contract and [docs/BUILDING.md](docs/BUILDING.md) for toolchain details.
