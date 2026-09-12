# Local document fonts

Font files live inside the project but remain outside version control. Each
document uses its own directory automatically:

```text
.fonts/
  example/
  report/
  <another-document>/
```

Add legally obtained `.ttf`, `.otf`, or `.ttc` files to `.fonts/<name>/`, then
build with `make DOCUMENT=<name> all`. The selected directory is mounted into
the builder's font path for both PDF and DOCX generation.

`make DOCUMENT=<name> fonts` creates the directory. When `FONT_SOURCE_DIR` is
configured, it also copies supported font files from that source into the
document directory. `FONT_DIR` can override one document's destination, while
`FONT_ROOT` relocates the common project-local root when needed.

`FONT_PROFILE := none` is the neutral scaffold policy: it uses the files
already present in the selected document directory. Derived document families
can add named staging policies without changing the manifest contract.
