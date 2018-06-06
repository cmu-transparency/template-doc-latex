OPEN := $(shell command -v \
	/Applications/Skim.app/Contents/MacOS/Skim \
	/Applications/Preview.app/Contents/MacOSPreview \
	/mnt/c/Program\ Files\ \(x86\)/Adobe/Acrobat\ Reader\ DC/Reader/AcroRd32.exe \
	evince \
	xpdf \
	gv \
	2> /dev/null)

DOC  := to-be-specified
MAIN := root
PDFLATEX := pdflatex

DEP_FIGS := $(shell find ./figures \
	-name '*.tex' \
	)
DEP := *.tex *.bib $(DEP_FIGS)
DEP := $(foreach i,$(DEP),$(shell ls $(i) 2> /dev/null))

start:
	make draft

start-%:
	make open-$*
	make watch-$*

draft:
	make start-draft

final:
	make start-final

open-%: $(DOC).%.pdf
ifneq ("$(OPEN)","")
	$(OPEN) $(DOC).$*.pdf &
else
	@echo "Could not find a PDF reader. If you'd like this \
	makefile to open the generated pdfs, add your PDF reader to \
	the opening section of the Makefile."
	@exit 1
endif

$(DOC).pdf: $(DEP)
	perl watch.pl render_latex $(MAIN) "\input{$(MAIN).tex}"
	@cp $(MAIN).pdf $(DOC).pdf
	@cp $(MAIN).synctex.gz $(DOC).synctex.gz


$(DOC).%.pdf: $(DEP)
	perl watch.pl render_latex $(MAIN) "\def\$*{}\input{$(MAIN).tex}"
	@cp $(MAIN).pdf $(DOC).$*.pdf
	@cp $(MAIN).synctex.gz $(DOC).$*.synctex.gz

watch-%:
	perl watch.pl watch $(DOC).$*.pdf $(DEP)
	perl watch.pl watch $(DOC).pdf $(DEP)

# SPLITTING DOC INTO PIECES
$(DOC).final.main.pdf: $(DOC).final.pdf
	pdftk $(DOC).final.pdf cat 1-9 output $@

$(DOC).final.supplemental.pdf: $(DOC).final.pdf
	pdftk $(DOC).final.pdf cat 10-12 output $@

parts: $(DOC).final.main.pdf $(DOC).final.supplemental.pdf

# DEBUGGING UTILS
# https://www.cmcrossroads.com/article/printing-value-makefile-variable
print-%  : ; @echo $* = $($*)

debug: $(DEP)
	$(PDFLATEX) -interaction nonstopmode "\input{$(MAIN).tex}"
	$(OPEN) $(DOC).pdf

# To debug unicode issues:
# useful emacs command: find-file-literally
show_unicode: $(DEP)
	pcregrep --color='auto' -n "[\x80-\xFF]" *.tex *.bib

# List all references to the thing after find_ in the tex sources.
find_%: *.tex
	grep -I -C 1 -n --color=auto '$*' *.tex; true

# CLEANING
clean:
	rm -Rf *.aux *.lof *.log *.lot *.bbl *.blg *.toc *.out *.bcf *.run.xml; true
	rm -Rf *~; true
	rm -Rf $(DOC).pdf $(MAIN).pdf $(DOC).*.pdf; true
	rm -Rf main-blx.bib
	rm -Rf .DS_Store; true
	rm -Rf .iTeXMac; true
	rm -Rf *.*.gz; true
	rm -Rf *.pdfsync; true
	rm -Rf *.synctex; true

desvn:
	find . -type d -name .svn -exec rm -rf {} +

#ARTIFACTS := $(shell find artifact)

#artifact: ${ARTIFACTS}
#	COPYFILE_DISABLE=1 tar -cvf artifact.tar artifact
#	gzip artifact.tar

# PACKAGING

DEP_TEX := $(shell find . \
	-not \( -path ./old-sections -prune \) \
	-not \( -path ./supplemental -prune \) \
	-not \( -path ./ijcai2018-formatting-guidelines -prune \) \
	-not \( -path ./arXiv -prune \) \
	-not \( -path ./formatting_instructions -prune \) \
	-not \( -path ./styles -prune \) \
	-name '*.tex' \
	)

DEP_TEX2 := $(DEP_TEX:%=arXiv/%)

arXiv/%.tex: %.tex
	latexpand --empty-comments $< > arXiv/$<
	sed -e '/^\s*%/d' -i '' arXiv/$< 

arXiv:
	mkdir arXiv
	mkdir arXiv/figures

$(MAIN).bbl: $(DOC).arXiv.pdf

bundle: $(MAIN).bbl arXiv $(DEP_TEX:%=arXiv/%) ijcai18.sty
	cp -R $(MAIN).bbl ijcai18.sty arXiv
	cp -R $(DEP_FIGS) arXiv/figures
	(echo "\def\\\\arXiv{}\n"; cat arXiv/$(MAIN).tex) \
           > arXiv/$(MAIN).tex.temp
	mv arXiv/$(MAIN).tex.temp arXiv/$(MAIN).tex
	tar -cvf arXiv.tar arXiv
	gzip arXiv.tar

rebundle:
	rm -Rf arXiv; true
	rm -Rf arXiv.tar.gz; true
	make bundle
