PROJECT ?= pyme-farmacia
PROJECTS := pyme-farmacia
SERVICE ?= latex-env

.DEFAULT_GOAL := help

.PHONY: \
	help \
	build rebuild up down restart shell \
	pdf pdf-farmacia pdf-all \
	docx docx-farmacia docx-all \
	normalize normalize-all \
	clean clean-farmacia clean-all \
	prune \
	compose-up compose-build compose-pdf compose-docx compose-stop

# All Docker operations use Docker Compose V2 only: docker compose ...


help:
	@echo "LaTeX Builder - available commands"
	@echo ""
	@echo "Usage:"
	@echo "  make <command> [PROJECT=pyme-farmacia]"
	@echo ""
	@echo "Main commands:"
	@echo "  make help             Show this help message"
	@echo "  make build            Build the Docker Compose image"
	@echo "  make rebuild          Rebuild the image without cache and start the service"
	@echo "  make up               Start the Docker Compose service"
	@echo "  make down             Stop and remove the Docker Compose service"
	@echo "  make restart          Restart the Docker Compose service"
	@echo "  make shell            Open a shell in the selected project workspace"
	@echo ""
	@echo "Document commands:"
	@echo "  make pdf              Normalize figures and compile main.tex to main.pdf"
	@echo "  make docx             Normalize figures and export main.tex to main.docx"
	@echo "  make normalize        Optimize/normalize images in the figuras directory"
	@echo "  make clean            Remove generated LaTeX, PDF, and DOCX output files"
	@echo ""
	@echo "Project shortcuts:"
	@echo "  make pdf-farmacia     Build PDF for PROJECT=pyme-farmacia"
	@echo "  make docx-farmacia    Build DOCX for PROJECT=pyme-farmacia"
	@echo "  make clean-farmacia   Clean generated files for PROJECT=pyme-farmacia"
	@echo "  make pdf-all          Build PDFs for all configured projects"
	@echo "  make docx-all         Build DOCX files for all configured projects"
	@echo "  make normalize-all    Normalize figures for all configured projects"
	@echo "  make clean-all        Clean generated files for all configured projects"
	@echo ""
	@echo "Maintenance:"
	@echo "  make prune            Remove Compose volumes, local images, and orphans"
	@echo ""
	@echo "Notes:"
	@echo "  - All Docker operations use Docker Compose V2 only: docker compose"
	@echo "  - PROJECT defaults to pyme-farmacia"

build:
	docker compose build

rebuild:
	docker compose down
	docker compose build --no-cache
	docker compose up -d

up:
	docker compose up -d

down:
	docker compose down

restart:
	docker compose down
	docker compose up -d

shell: build up
	docker compose exec -T -e PROJECT="$(PROJECT)" $(SERVICE) bash -lc 'cd "/workspace/workspaces/$(PROJECT)" && bash'

pdf: build up
	docker compose exec -T -e PROJECT="$(PROJECT)" $(SERVICE) bash -lc 'set -euo pipefail; cd "/workspace/workspaces/$(PROJECT)"; if [ -f ../scripts/normalize_figures.sh ]; then bash ../scripts/normalize_figures.sh .; fi; xelatex -interaction=nonstopmode -halt-on-error main.tex; biber main; xelatex -interaction=nonstopmode -halt-on-error main.tex; xelatex -interaction=nonstopmode -halt-on-error main.tex'

pdf-farmacia:
	$(MAKE) pdf PROJECT=pyme-farmacia

pdf-all: build up
	@for project in $(PROJECTS); do \
		$(MAKE) pdf PROJECT="$$project"; \
	done

docx: build up
	docker compose exec -T -e PROJECT="$(PROJECT)" $(SERVICE) bash -lc 'set -euo pipefail; cd "/workspace/workspaces/$(PROJECT)"; if [ -f ../scripts/normalize_figures.sh ]; then bash ../scripts/normalize_figures.sh .; fi; pandoc main.tex --resource-path=.:figuras --bibliography=references.bib --citeproc -o main.docx'

docx-farmacia:
	$(MAKE) docx PROJECT=pyme-farmacia

docx-all: build up
	@for project in $(PROJECTS); do \
		$(MAKE) docx PROJECT="$$project"; \
	done

normalize: build up
	docker compose exec -T -e PROJECT="$(PROJECT)" $(SERVICE) bash -lc 'set -euo pipefail; python3 "/workspace/workspaces/scripts/normalize_figures.py" "/workspace/workspaces/$(PROJECT)"'

normalize-all: build up
	@for project in $(PROJECTS); do \
		docker compose exec -T -e PROJECT="$$project" $(SERVICE) bash -lc 'set -euo pipefail; python3 "/workspace/workspaces/scripts/normalize_figures.py" "/workspace/workspaces/'"$$project"'"'; \
	done

clean: build up
	docker compose exec -T -e PROJECT="$(PROJECT)" $(SERVICE) bash -lc 'set -euo pipefail; rm -f "/workspace/workspaces/$(PROJECT)"/main.aux "/workspace/workspaces/$(PROJECT)"/main.bbl "/workspace/workspaces/$(PROJECT)"/main.bcf "/workspace/workspaces/$(PROJECT)"/main.blg "/workspace/workspaces/$(PROJECT)"/main.log "/workspace/workspaces/$(PROJECT)"/main.out "/workspace/workspaces/$(PROJECT)"/main.run.xml "/workspace/workspaces/$(PROJECT)"/main.toc "/workspace/workspaces/$(PROJECT)"/main.lof "/workspace/workspaces/$(PROJECT)"/main.lot "/workspace/workspaces/$(PROJECT)"/main.xdv "/workspace/workspaces/$(PROJECT)"/main.fdb_latexmk "/workspace/workspaces/$(PROJECT)"/main.fls "/workspace/workspaces/$(PROJECT)"/main.pdf "/workspace/workspaces/$(PROJECT)"/main.docx'

clean-farmacia:
	$(MAKE) clean PROJECT=pyme-farmacia

clean-all: build up
	@for project in $(PROJECTS); do \
		$(MAKE) clean PROJECT="$$project"; \
	done

prune:
	docker compose down --volumes --rmi local --remove-orphans

# Backward-compatible aliases, still using Docker Compose V2 only.
compose-up: up
compose-build: rebuild
compose-pdf: pdf
compose-docx: docx
compose-stop: down
