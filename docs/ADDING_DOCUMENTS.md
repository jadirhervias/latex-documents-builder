# Adding a document

A document is a directory under `documents/` containing a `document.mk`
manifest and one or more `.tex` entry points. By default, the source has the
same name as its document directory. The builder selects the profile with
`DOCUMENT=<directory-name>` and an optional source variant with `FILE=<name>.tex`.

## Minimal profile

Copy the neutral example, or create `documents/report/document.mk`:

```make
DOCUMENT_TITLE := Quarterly report
RESOURCE_PATHS := .:documents/report:documents/report/assets
FONT_PROFILE := none
PDF_CHECK_ARGS := --paper a4
DOCX_PROFILE := plain
DOCX_LANG := en-US
```

Then add `documents/report/report.tex` and run:

```bash
make DOCUMENT=report pdf pdf-check
```

Generated and intermediate files are namespaced automatically:

```text
build/report/report/pdf/
build/report/report/docx/
output/pdf/report.pdf
output/docx/report.docx
```

## Multiple variants

Keep tailored entry points beside the base document and choose one at build
time:

```text
documents/report/
  document.mk
  report.cls
  report.tex
  summary.tex
  appendix.tex
```

```bash
make DOCUMENT=report FILE=summary.tex all
make DOCUMENT=report FILE=appendix.tex all
```

These commands create `summary.pdf`/`summary.docx` and
`appendix.pdf`/`appendix.docx`, with isolated intermediates for each version.
`SOURCE=path/to/file.tex` remains available when an entry point lives outside
the profile directory.

## Manifest fields

| Field | Purpose | Default |
|---|---|---|
| `DOCUMENT_TITLE` | Human-readable title shown by `make list` and `make info`. | Empty |
| `FILE` | Entry-point filename inside `documents/<name>/`. | `<name>.tex` |
| `SOURCE` | LaTeX entry point, relative to the repository root. Overrides `FILE`. | `documents/<name>/<FILE>` |
| `OUTPUT_NAME` | Basename used in `output/pdf` and `output/docx`. | Selected source basename |
| `BIBLIOGRAPHY` | Optional BibLaTeX/Biber database. Empty skips Biber and Pandoc cite processing. | Empty |
| `RESOURCE_PATHS` | Colon-separated Pandoc lookup paths for images and includes. | Root and document directory |
| `FONT_ROOT` | Project-local root containing the document font directories. | `.fonts` in the repository root |
| `FONT_DIR` | Local directory mounted as the selected document's font directory. | `.fonts/<name>` in the repository root |
| `FONT_SOURCE_DIR` | Optional directory containing `.ttf`, `.otf`, or `.ttc` fonts to copy into `FONT_DIR`. | Empty |
| `FONT_PROFILE` | Named font-staging policy. The scaffold provides `none`; derived document families may add policies. | `none` |
| `PDF_CHECK_ARGS` | PDF policy: `--paper a4` or `--paper letter`, optionally `--required-font "Name"`. | A4 |
| `DOCX_PROFILE` | Named Word post-processing policy. The scaffold provides `plain`; derived document families may add policies. | `plain` |
| `DOCX_REFERENCE` | Optional existing Pandoc reference DOCX. | Empty |
| `DOCX_LANG` | Language metadata passed to Pandoc. | `en-US` |

Paths are interpreted from the repository root because builds run from `/work`
inside the container. Keep reusable LaTeX packages or styles in a top-level
`tex/` directory and add that directory to `RESOURCE_PATHS` if several
documents share them. Keep document-specific images beside the document under
an `assets/` directory. Local `.cls` and `.sty` files may live beside the entry
point; the PDF builder automatically adds the selected source directory and its
subdirectories to `TEXINPUTS`.

## Output behavior

PDF compilation is generic XeLaTeX. Biber runs only when `BIBLIOGRAPHY` is set.
Every PDF is checked for fatal LaTeX diagnostics and the configured paper size;
a document may also require a specific embedded font.

Private fonts are kept in the project-local `.fonts/<name>/` directory, which
is ignored by Git. The directory is isolated by document and mounted into the
builder for both PDF and DOCX generation. Add `.ttf`, `.otf`, or `.ttc` files
directly to the selected document directory to extend its available fonts
without changing another document or the shared Docker image.

As an optional import step, set `FONT_SOURCE_DIR` in `document.mk` or on the
command line. For example,
`make DOCUMENT=report FONT_SOURCE_DIR=/path/to/fonts fonts` copies supported
files into `.fonts/report`. Set `FONT_DIR` only when a profile needs a different
project-local destination, or `FONT_ROOT` to relocate all document font
directories together.

`FONT_PROFILE := none` uses the selected directory as-is. A derived document
family can add a named policy for staging a known system font while preserving
the same manifest interface.

DOCX conversion expands local `\\input` and `\\include` files before running
Pandoc. It supports an optional reference DOCX and bibliography, then checks
the resulting OOXML package, included-image count, visible content, and
LibreOffice rendering. `DOCX_PROFILE := plain` preserves this generic flow. A
new document family can add another named profile with its own postprocessor
and validator without changing the Makefile-to-script interface.

## Useful commands

```bash
make list
make DOCUMENT=report info
make DOCUMENT=report pdf
make DOCUMENT=report pdf-check
make DOCUMENT=report docx
make DOCUMENT=report docx-check
make DOCUMENT=report all
```

`make clean` removes generated files for every document while preserving the
tracked `.gitignore` placeholders.
