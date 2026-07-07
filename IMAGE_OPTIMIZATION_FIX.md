# Image optimization and `main.tex` safety

## What happened

The image optimizer does **not** rename files and does **not** write to `main.tex`.
Names such as `docx_image3.png` are produced when a DOCX file is converted/extracted back to LaTeX, usually with a command like:

```bash
pandoc source.docx -o main.tex --extract-media=figuras
```

That command overwrites the curated LaTeX file and replaces semantic image names such as:

```tex
figuras/figura1-mapa_procesos.png
```

with DOCX-extracted names such as:

```tex
figuras/docx_image3.png
```

## Fix included

`workspaces/scripts/normalize_figures.py` was hardened so it:

- optimizes only PNG/JPG/JPEG files inside `figuras`;
- skips macOS metadata files such as `.DS_Store`, `._*`, and `__MACOSX`;
- refuses to run if `main.tex` already contains `docx_imageX.png` references;
- verifies that `main.tex` has not changed during image optimization.

## Correct workflow

Build PDF:

```bash
make pdf
```

Optimize images only:

```bash
make normalize
```

Export DOCX from LaTeX:

```bash
make docx
```

Do **not** run a DOCX-to-LaTeX command with `-o main.tex` unless you intentionally want to regenerate and replace the LaTeX source.
