FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

# Do not use texlive-full here: it is several GB and often fails in Docker
# Desktop with "not enough free space in /var/cache/apt/archives".
# This targeted set covers the packages used by main.tex:
# fontspec/xelatex, babel Spanish, biblatex-apa+biber, newtxmath,
# tables/figures/captions/hyperlinks, and the image normalizer.
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

CMD ["bash", "-lc", "if [ -f scripts/normalize_figures.sh ]; then bash scripts/normalize_figures.sh; fi && xelatex -interaction=nonstopmode main.tex && biber main && xelatex -interaction=nonstopmode main.tex && xelatex -interaction=nonstopmode main.tex"]
