IMAGE ?= latex-builder
PROJECT ?= pyme-farmacia
PROJECTS := pyme-farmacia

.PHONY: build rebuild pdf pdf-farmacia pdf-all docx docx-farmacia docx-all clean clean-farmacia clean-all normalize normalize-all prune compose-pdf compose-docx compose-stop

build:
	docker build --pull -t $(IMAGE) .

rebuild:
	docker build --pull --no-cache -t $(IMAGE) .

# --- Flujo Clásico (Docker Run - Contenedores Efímeros) ---

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
		bash -lc 'cd "workspaces/$(PROJECT)" && if [ -f ../scripts/normalize_figures.sh ]; then bash ../scripts/normalize_figures.sh .; fi && pandoc main.tex --resource-path=.:figuras --bibliography=references.bib --citeproc -o main.docx'

docx-farmacia:
	$(MAKE) docx PROJECT=pyme-farmacia

docx-all: build
	$(MAKE) docx PROJECT=pyme-farmacia IMAGE=$(IMAGE)

normalize:
	python3 workspaces/scripts/normalize_figures.py "workspaces/$(PROJECT)"

normalize-all:
	python3 workspaces/scripts/normalize_figures.py workspaces/$(PROJECTS)

clean:
	rm -f "workspaces/$(PROJECT)"/main.aux "workspaces/$(PROJECT)"/main.bbl "workspaces/$(PROJECT)"/main.bcf "workspaces/$(PROJECT)"/main.blg "workspaces/$(PROJECT)"/main.log "workspaces/$(PROJECT)"/main.out "workspaces/$(PROJECT)"/main.run.xml "workspaces/$(PROJECT)"/main.toc "workspaces/$(PROJECT)"/main.lof "workspaces/$(PROJECT)"/main.lot "workspaces/$(PROJECT)"/main.xdv "workspaces/$(PROJECT)"/main.fdb_latexmk "workspaces/$(PROJECT)"/main.fls "workspaces/$(PROJECT)"/main.pdf "workspaces/$(PROJECT)"/main.docx

clean-farmacia:
	$(MAKE) clean PROJECT=pyme-farmacia

clean-all:
	$(MAKE) clean PROJECT=pyme-farmacia

prune:
	docker buildx prune -af
	docker builder prune -af
	docker system prune -af

# --- Flujo Moderno (Docker Compose - Contenedor Siempre Activo) ---

compose-up:
	docker compose up -d

compose-build:
	docker compose down
	docker compose build --no-cache
	docker compose up -d

compose-pdf:
	docker compose exec latex-env bash -lc 'cd "/workspace/workspaces/$(PROJECT)" && if [ -f ../scripts/normalize_figures.sh ]; then bash ../scripts/normalize_figures.sh .; fi && xelatex -interaction=nonstopmode -halt-on-error main.tex && biber main && xelatex -interaction=nonstopmode -halt-on-error main.tex && xelatex -interaction=nonstopmode -halt-on-error main.tex'

compose-docx:
	docker compose exec latex-env bash -lc 'cd "/workspace/workspaces/$(PROJECT)" && if [ -f ../scripts/normalize_figures.sh ]; then bash ../scripts/normalize_figures.sh .; fi && pandoc main.tex --resource-path=.:figuras --bibliography=references.bib --citeproc -o main.docx'

compose-pdf-old:
	docker compose exec latex-env bash -lc 'cd "workspaces/$$(PROJECT)" && if [ -f ../scripts/normalize_figures.sh ]; then bash ../scripts/normalize_figures.sh .; fi && xelatex -interaction=nonstopmode -halt-on-error main.tex && biber main && xelatex -interaction=nonstopmode -halt-on-error main.tex && xelatex -interaction=nonstopmode -halt-on-error main.tex'

compose-docx-old:
	docker compose exec latex-env bash -lc 'cd "workspaces/$$(PROJECT)" && if [ -f ../scripts/normalize_figures.sh ]; then bash ../scripts/normalize_figures.sh .; fi && pandoc main.tex --resource-path=.:figuras --bibliography=references.bib --citeproc -o main.docx'

compose-stop:
	docker compose down
