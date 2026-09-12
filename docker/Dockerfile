ARG BASE_IMAGE=latex-builder:latest
FROM ${BASE_IMAGE}

ENV DEBIAN_FRONTEND=noninteractive \
    PIP_DISABLE_PIP_VERSION_CHECK=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    PATH=/opt/venv/bin:${PATH}

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      fontconfig \
      libreoffice-writer \
      poppler-utils \
      python3-venv \
 && python3 -m venv /opt/venv \
 && /opt/venv/bin/pip install --no-cache-dir \
      lxml==6.0.2 \
      pypdf==6.10.0 \
      python-docx==1.2.0 \
 && rm -rf /var/lib/apt/lists/*
