IMAGE ?= latex-builder

.PHONY: build pdf docx clean

build:
	docker build -t $(IMAGE) .

pdf: build
	docker run --rm -v "$(PWD)":/workspace $(IMAGE)

docx: build
	docker run --rm \
		-v "$(PWD)":/workspace \
		$(IMAGE) \
		pandoc main.tex \
		--bibliography=references.bib \
		--citeproc \
		-o main.docx

clean:
	rm -f main.aux main.bbl main.bcf main.blg main.log main.out main.run.xml main.toc main.lof main.lot main.pdf main.docx
