IMAGE ?= latex-builder

.PHONY: build rebuild pdf docx clean prune

build:
	docker build --pull -t $(IMAGE) .

rebuild:
	docker build --pull --no-cache -t $(IMAGE) .

pdf: build
	docker run --rm -v "$(PWD)":/workspace $(IMAGE)

docx: build
	docker run --rm \
		-v "$(PWD)":/workspace \
		$(IMAGE) \
		bash -lc 'if [ -f scripts/normalize_figures.sh ]; then bash scripts/normalize_figures.sh; fi && pandoc main.tex --resource-path=. --bibliography=references.bib --citeproc -o main.docx'

clean:
	rm -f main.aux main.bbl main.bcf main.blg main.log main.out main.run.xml main.toc main.lof main.lot main.pdf main.docx
