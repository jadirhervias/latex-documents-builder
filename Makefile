SHELL := /bin/sh

PROJECT_DIR := $(CURDIR)
DOCUMENT ?= example
DOCUMENT_CONFIG := documents/$(DOCUMENT)/document.mk
-include $(DOCUMENT_CONFIG)

BUILDER_IMAGE ?= latex-docs-builder:latest
BASE_IMAGE ?= latex-builder:latest
BUILD_DIR := $(PROJECT_DIR)/build
OUTPUT_DIR := $(PROJECT_DIR)/output
FONT_ROOT ?= $(PROJECT_DIR)/.fonts
FONT_DIR ?= $(FONT_ROOT)/$(DOCUMENT)
PROGRESS_INTERVAL ?= 15

FILE ?= $(DOCUMENT).tex
SOURCE ?= documents/$(DOCUMENT)/$(FILE)
OUTPUT_NAME ?= $(notdir $(basename $(SOURCE)))
BIBLIOGRAPHY ?=
RESOURCE_PATHS ?= .:documents/$(DOCUMENT)
FONT_SOURCE_DIR ?=
FONT_PROFILE ?= none
PDF_CHECK_ARGS ?= --paper a4
DOCX_PROFILE ?= plain
DOCX_REFERENCE ?=
DOCX_LANG ?= en-US

.PHONY: help list info require-document builder ensure-builder fonts test \
	pdf pdf-check docx docx-check all clean

help:
	@printf '%s\n' \
	  'Generic LaTeX document builder' \
	  '' \
	  'Usage: make DOCUMENT=<name> [FILE=<source.tex>] <target>' \
	  '' \
	  'Targets:' \
	  '  list          List available document profiles' \
	  '  info          Show the selected document configuration' \
	  '  pdf           Build output/pdf/<output-name>.pdf' \
	  '  pdf-check     Validate the generated PDF' \
	  '  docx          Build output/docx/<output-name>.docx' \
	  '  docx-check    Validate and render the generated DOCX' \
	  '  all           Test, build, and validate PDF and DOCX' \
	  '  clean         Remove generated artifacts' \
	  '' \
	  'Examples:' \
	  '  make all' \
	  '  make DOCUMENT=report FILE=summary.tex pdf' \
	  '' \
	  'Optional infrastructure variables: BUILDER_IMAGE, BASE_IMAGE,' \
	  'FONT_ROOT, FONT_DIR, FONT_SOURCE_DIR, FONT_PROFILE,' \
	  'DOCX_PROFILE, PROGRESS_INTERVAL'

list:
	@for config in documents/*/document.mk; do \
	  test -f "$$config" || continue; \
	  name=$${config#documents/}; name=$${name%/document.mk}; \
	  title=$$(sed -E -n 's/^DOCUMENT_TITLE[[:space:]]*[:?+]?=[[:space:]]*//p' "$$config"); \
	  printf '%-12s %s\n' "$$name" "$$title"; \
	done

info: require-document
	@printf '%s\n' \
	  'Document:     $(DOCUMENT)' \
	  'Title:        $(DOCUMENT_TITLE)' \
	  'Source:       $(SOURCE)' \
	  'PDF:          output/pdf/$(OUTPUT_NAME).pdf' \
	  'DOCX:         output/docx/$(OUTPUT_NAME).docx' \
	  'Bibliography: $(if $(BIBLIOGRAPHY),$(BIBLIOGRAPHY),none)' \
	  'Resources:    $(RESOURCE_PATHS)' \
	  'Font source:  $(if $(FONT_SOURCE_DIR),$(FONT_SOURCE_DIR),local directory)' \
	  'Font profile: $(FONT_PROFILE)' \
	  'Font dir:     $(FONT_DIR)' \
	  'DOCX profile: $(DOCX_PROFILE)'

require-document:
	@test -f "$(DOCUMENT_CONFIG)" || { \
	  printf 'Unknown document %s. Run "make list".\n' "$(DOCUMENT)" >&2; \
	  exit 2; \
	}
	@test -f "$(SOURCE)" || { \
	  printf 'Configured source does not exist: %s\n' "$(SOURCE)" >&2; \
	  exit 2; \
	}
	@test -n "$(OUTPUT_NAME)" || { \
	  printf 'The source must have a filename that can be used for output.\n' >&2; \
	  exit 2; \
	}

builder:
	docker build --build-arg BASE_IMAGE=$(BASE_IMAGE) -t $(BUILDER_IMAGE) docker

ensure-builder:
	@docker image inspect $(BUILDER_IMAGE) >/dev/null 2>&1 || $(MAKE) builder

fonts: require-document
	./scripts/stage-fonts.sh "$(FONT_DIR)" "$(FONT_SOURCE_DIR)" "$(FONT_PROFILE)"

test:
	python3 -m unittest discover -s tests -p 'test_preprocess.py' -v

pdf: require-document ensure-builder fonts
	docker run --rm \
	  -e PROGRESS_INTERVAL=$(PROGRESS_INTERVAL) \
	  -v "$(PROJECT_DIR):/work" \
	  -v "$(FONT_DIR):/usr/local/share/fonts/document:ro" \
	  -w /work $(BUILDER_IMAGE) ./scripts/pdf/build.sh \
	    "$(SOURCE)" "$(OUTPUT_NAME)" "$(BIBLIOGRAPHY)" "$(DOCUMENT)"

pdf-check: require-document ensure-builder
	docker run --rm -v $(PROJECT_DIR):/work -w /work $(BUILDER_IMAGE) \
	  python3 scripts/pdf/validate.py \
	    "output/pdf/$(OUTPUT_NAME).pdf" \
	    "build/$(DOCUMENT)/$(OUTPUT_NAME)/pdf/$(notdir $(basename $(SOURCE))).log" \
	    $(PDF_CHECK_ARGS)

docx: require-document ensure-builder fonts
	docker run --rm \
	  -e PROGRESS_INTERVAL=$(PROGRESS_INTERVAL) \
	  -v "$(PROJECT_DIR):/work" \
	  -v "$(FONT_DIR):/usr/local/share/fonts/document:ro" \
	  -w /work $(BUILDER_IMAGE) ./scripts/docx/build.sh \
	    "$(SOURCE)" "$(OUTPUT_NAME)" "$(DOCUMENT)" \
	    "$(BIBLIOGRAPHY)" "$(RESOURCE_PATHS)" "$(DOCX_PROFILE)" \
	    "$(DOCX_REFERENCE)" "$(DOCX_LANG)"

docx-check: require-document ensure-builder
	docker run --rm -v $(PROJECT_DIR):/work -w /work $(BUILDER_IMAGE) \
	  ./scripts/docx/check.sh \
	    "output/docx/$(OUTPUT_NAME).docx" \
	    "build/$(DOCUMENT)/$(OUTPUT_NAME)/docx/metadata.json" \
	    "$(DOCX_PROFILE)" "build/$(DOCUMENT)/$(OUTPUT_NAME)/docx"

all: test pdf pdf-check docx docx-check

clean:
	find $(BUILD_DIR) $(OUTPUT_DIR) -mindepth 1 -type f ! -name .gitignore -delete
	find $(BUILD_DIR) $(OUTPUT_DIR) -depth -mindepth 1 -type d -empty -delete
