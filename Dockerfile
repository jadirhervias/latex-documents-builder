FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Do not use texlive-full here: it is several GB and often fails in Docker
# Desktop with "not enough free space in /var/cache/apt/archives".
# This targeted set covers the packages used by both thesis versions:
# fontspec/xelatex, babel Spanish, biblatex-apa+biber, newtxmath,
# tables/figures/captions/hyperlinks, diagrams/images, and the image normalizer.
RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates \
    biber \
    fontconfig \
    fonts-croscore \
    fonts-texgyre \
    fonts-texgyre-math \
    lmodern \
    texlive-xetex \
    texlive-latex-recommended \
    texlive-latex-extra \
    texlive-fonts-recommended \
    texlive-fonts-extra \
    texlive-lang-spanish \
    texlive-bibtex-extra \
    texlive-pictures \
    texlive-plain-generic \
    imagemagick \
    file \
    python3 \
    python3-pil \
    pandoc \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /var/cache/apt/archives/*

WORKDIR /workspace

# PROJECT
# Default keeps docker run usable even without Makefile arguments.
CMD ["bash", "-lc", "PROJECT=${PROJECT:-pyme-farmacia}; if [ ! -f \"$PROJECT/main.tex\" ]; then echo \"ERROR: $PROJECT/main.tex not found.\"; exit 1; fi; cd \"$PROJECT\" && if [ -f ../scripts/normalize_figures.sh ]; then bash ../scripts/normalize_figures.sh .; fi && xelatex -interaction=nonstopmode -halt-on-error main.tex && biber main && xelatex -interaction=nonstopmode -halt-on-error main.tex && xelatex -interaction=nonstopmode -halt-on-error main.tex"]
