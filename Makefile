IMAGE ?= latex-builder
PROJECT ?= pyme-farmacia
PROJECTS := pyme-farmacia

.PHONY: build rebuild pdf pdf-farmacia pdf-all docx docx-farmacia docx-all clean clean-farmacia clean-all normalize normalize-all prune

build:
	docker build --pull -t $(IMAGE) .

rebuild:
	docker build --pull --no-cache -t $(IMAGE) .

pdf: build
	docker run --rm \
		-v "$(PWD)":/workspace \
		-e PROJECT="$(PROJECT)" \
		$(IMAGE)

pdf-farmacia:
	$(MAKE) pdf PROJECT=pyme-farmacia

pdf-all: build
	$(MAKE) pdf PROJECT=pyme-farmacia IMAGE=$(IMAGE)

docx: build
	docker run --rm \
		-v "$(PWD)":/workspace \
		$(IMAGE) \
		bash -lc 'cd "$(PROJECT)" && if [ -f ../scripts/normalize_figures.sh ]; then bash ../scripts/normalize_figures.sh .; fi && pandoc main.tex --resource-path=.:figuras --bibliography=references.bib --citeproc -o main.docx'

docx-farmacia:
	$(MAKE) docx PROJECT=pyme-farmacia

docx-all: build
	$(MAKE) docx PROJECT=pyme-farmacia IMAGE=$(IMAGE)

normalize:
	python3 scripts/normalize_figures.py "$(PROJECT)"

normalize-all:
	python3 scripts/normalize_figures.py $(PROJECTS)

clean:
	rm -f "$(PROJECT)"/main.aux "$(PROJECT)"/main.bbl "$(PROJECT)"/main.bcf "$(PROJECT)"/main.blg "$(PROJECT)"/main.log "$(PROJECT)"/main.out "$(PROJECT)"/main.run.xml "$(PROJECT)"/main.toc "$(PROJECT)"/main.lof "$(PROJECT)"/main.lot "$(PROJECT)"/main.xdv "$(PROJECT)"/main.fdb_latexmk "$(PROJECT)"/main.fls "$(PROJECT)"/main.pdf "$(PROJECT)"/main.docx

clean-farmacia:
	$(MAKE) clean PROJECT=pyme-farmacia

clean-all:
	$(MAKE) clean PROJECT=pyme-farmacia

prune:
	docker buildx prune -af
	docker builder prune -af
	docker system prune -af
