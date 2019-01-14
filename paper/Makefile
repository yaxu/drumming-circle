all: iclc2019.pdf iclc2019.html

iclc2019.html: iclc2019.md references.bib
	pandoc --template=pandoc/iclc.html --filter pandoc-citeproc --number-sections iclc2019.md -o iclc2019.html

iclc2019.pdf: iclc2019.md references.bib pandoc/iclc.latex pandoc/iclc.sty
	pandoc --template=pandoc/iclc.latex --filter pandoc-citeproc --number-sections iclc2019.md -o iclc2019.pdf

iclc2019.docx: iclc2019.md references.bib
	pandoc --filter pandoc-citeproc --number-sections iclc2019.md -o iclc2019.docx

iclc2019x.pdf: iclc2019.md references.bib pandoc/iclc.latex pandoc/iclc.sty
	pandoc --template=pandoc/iclc.latex --filter pandoc-citeproc --number-sections iclc2019.md --latex-engine=xelatex -o iclc2019x.pdf
