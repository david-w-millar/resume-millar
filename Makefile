# -*- Mode: Makefile -*-

# A list of documents (with .tex file extensions).
# SRC_FILES=$(shell ls *.tex)
SRC_FILES := $(shell egrep -l '^[^%]*\\begin\{document\}' *.tex)

export TEXINPUTS:=.:$(HOME)/latex/sty:$(TEXINPUTS)
export BSTINPUTS:=.:$(HOME)/latex/sty:$(BSTINPUTS)
export BIBINPUTS:=.:$(HOME)/latex/bibtex:$(BIBINPUTS)


#
# Author: Scott A. Kuhl
# http://www.cs.utah.edu/~skuhl/
#
# This makefile is for use with LaTeX documents.  It deals with LaTeX,
# bibtex, makeindex, dvips, ps2pdf and attempts to print as little to
# the terminal as possible.  Run "make help" for all of the targets
# that it provides.
#
# This makefile performs the following steps:
# 1) Run latex once.
#    If there are no errors, none of the LaTeX output is printed to the
#    screen.  If there is an error, all of the normal LaTeX output is
#    printed and Make exits with an error.
#
# 2) If there are undefined citations, run BibTeX.  If an .idx file
#    was created, run makeindex.  If there is a failure, normal output is
#    printed to the terminal.  Otherwise, none of the output is printed
#    to the terminal.
#
# 3) Run LaTeX repeatedly until there are no undefined
#    references/citations or labels that may have changed.  Fail if
#    LaTeX needs to be run more than MAX_PASSES.
#
#    - If any run of LaTeX produces an error, all of the LaTeX output
#      is printed to the screen and the makefile exits with an error.
#    - If there are no errors, none of LaTeX's output is printed to
#      the screen.
#
# 4) Print out any warnings from LaTeX's last run in the previous step.
#
# 5) Remove .aux, .log, .bbl, .blg, etc. files created by LaTeX/BibTeX.
#
# 6) dvips and ps2pdf are run if PS or PDF files are requested.
#
# NOTE: If you would like to inspect the output from the last run of
# LaTeX, bibtex, and DVIPS, see the tmp subdirectory.  Each SRC_FILE
# has its output stored seperately.
#
# If you have multiple processors and multiple SRC_FILES, you can
# use this makefile with -j N (to run N instances of Make
# simultaniously).
#



# Maximum number of latex passes if there are undefined references
# Note: MAX_PASSES does not count the first run of LaTeX as a pass.
MAX_PASSES=5

LATEX=pdflatex
LATEX_ARGS=-file-line-error-style -interaction=nonstopmode

BIBTEX=bibtex
PS2PDF=ps2pdf13
MAKEINDEX=makeindex

DVIPS=dvips
DVIPS_ARGS=-t letter -f -Ppdf -G0 
# For ACM SIGGRAPH using ghostscript 8.x
# DVIPS_ARGS="-dPDFSETTINGS=/prepress -dCompatibilityLevel=1.3 -dAutoFilterColorImages=false -dAutoFilterGrayImages=false -dColorImageFilter=/FlateEncode -dGrayImageFilter=/FlateEncode -dMonoImageFilter=/FlateEncode -dDownsampleColorImages=false -dDownsampleGrayImages=false"





# regex for the warnings we print to the screen
LATEX_WARNING_REGEX=-e '\(LaTeX Warning\)\|\(Overfull\)\|\(Underfull\)'

# regex for undefined citations
LATEX_UNDEF_CITE_REGEX='Citation.*undefined'

# regex for any type of undefined reference (including citations) and
# for labels that may have changed.  
LATEX_RERUN_REGEX=-e '\(Citation.*undefined\)\|\(LaTeX Warning: There were undefined references\)\|\(LaTeX Warning: Label(s) may have changed\)\|\(Package natbib Warning: There were undefined citations.\)\|\(Package natbib Warning: Citation(s) may have changed.\)'

# Regex for using an index
LATEX_IDX_REGEX="Writing index file.*idx"


##
## WARNING: Changing the following variables can break things!
##

# remove the .tex extensions
SRC_FILES:=$(SRC_FILES:.tex=)


# This makefile hides the output from latex, bibtex and dvips.  Their
# output is sent to files in a tmp subdirectory so you can inspect
# them later.
LATEX_OUTPUT=tmp/${basename ${@}}-latex.txt
BIBTEX_OUTPUT=tmp/${basename ${@}}-bibtex.txt
DVIPS_OUTPUT=tmp/${basename ${@}}-dvips.txt
INDEX_OUTPUT=tmp/${basename ${@}}-index.txt

# This makefile REQUIRES bash and will likely not work with other shells.
SHELL=/bin/bash


# Targets to create PDFs, PS files or DVI files for all of the SRC_FILES
.PHONY: pdf ps dvi dvipserror bibtexerror latexerror clean-inter-srcfile clean-intermediate clean clobber help

pdf: $(addsuffix .pdf,${SRC_FILES})

ps: $(addsuffix .ps,${SRC_FILES})

dvi: $(addsuffix .dvi,${SRC_FILES})


%.pdf: %.ps
	@echo "ps2pdf      ${@:.pdf=.ps} ${@}"
	@${PS2PDF} ${@:.pdf=.ps} ${@:.pdf=.pdf} || ( rm -f ${@}; false )
	@echo 

%.ps: %.dvi
	@mkdir -p tmp	
	@echo "dvips       ${@:.ps=.dvi} ${@}"
	@${DVIPS} ${DVIPS_ARGS} < ${@:.ps=.dvi} > ${@} 2> ${DVIPS_OUTPUT} || ${MAKE} -s --no-print-directory SRC_FILE=$(@:.ps=) dvipserror

%.dvi: %.tex
	@mkdir -p tmp
## Run latex one time
	@echo "LaTeX [0]   ${@:.dvi=}";
	@${LATEX} ${LATEX_ARGS} ${@:.dvi=} > ${LATEX_OUTPUT} || ${MAKE} -s --no-print-directory SRC_FILE=$(@:.dvi=) latexerror

## If there are undefined citations, try to run bibtex
	@BAD_REFS=`grep ${LATEX_UNDEF_CITE_REGEX} ${LATEX_OUTPUT} | wc -l`; \
	if (( $$BAD_REFS > 0 )); then \
	echo "BibTeX      ${@:.dvi=}"; \
	${BIBTEX} ${@:.dvi=} > ${BIBTEX_OUTPUT} || ${MAKE} -s --no-print-directory SRC_FILE=$(@:.dvi=) bibtexerror; \
	fi;

## If an index (.idx) file is created by latex, run makeindex.
	@INDEX=`grep ${LATEX_IDX_REGEX} ${LATEX_OUTPUT} | wc -l`; \
	if (( $$INDEX > 0 )); then \
	echo "makeindex   ${@:.dvi=}"; \
	${MAKEINDEX} ${@:.dvi=} > ${INDEX_OUTPUT} 2>&1 || ${MAKE} -s --no-print-directory SRC_FILE=$(@:.dvi=) indexerror; \
	fi;

## Run latex until there are no undefined references/changed labels or until we hit MAX_PASSES
	@PASS=1; \
	BAD_REFS=1; \
	while (( $$BAD_REFS != 0 && $$PASS <= ${MAX_PASSES} )); do \
	echo "LaTeX [$$PASS]   ${@:.dvi=}"; \
	${LATEX} ${LATEX_ARGS} ${@:.dvi=} > ${LATEX_OUTPUT} || ${MAKE} -s --no-print-directory SRC_FILE=$(@:.dvi=) latexerror; \
	BAD_REFS=`grep ${LATEX_RERUN_REGEX} ${LATEX_OUTPUT} | wc -l`; \
	(( PASS++ )); \
	done; \
	\
	if (( $$PASS > ${MAX_PASSES} )); then \
	echo "WARNING: We ran LaTeX MAX_PASSES=${MAX_PASSES} times and there are _STILL_ undefined references and/or undefined citations and/or labels that may have changed."; \
	fi;

	@NUM_WARNINGS=`grep ${LATEX_WARNING_REGEX} ${LATEX_OUTPUT} | wc -l`; \
	if (( $$NUM_WARNINGS > 0 )); then \
	echo "=== BEGIN LATEX WARNINGS for $(@:.dvi=.tex) ==="; \
	grep ${LATEX_WARNING_REGEX} ${LATEX_OUTPUT}; \
	echo "=== END LATEX WARNINGS for $(@:.dvi=.tex) ==="; \
	fi \

	@$(MAKE) -s --no-print-directory SRC_FILE=$(@:.dvi=) clean-inter-srcfile 


dvipserror:
	echo "=== BEGIN DVIPS OUTPUT for $(SRC_FILE).dvi ==="; 
	cat tmp/$(SRC_FILE)-dvips.txt; 
	echo "=== END DVIPS OUTPUT for $(SRC_FILE).dvi==="; 
	exit 1;


indexerror:
	echo "=== BEGIN MAKEINDEX OUTPUT for $(SRC_FILE).tex ==="; 
	cat tmp/$(SRC_FILE)-index.txt; 
	echo "=== END MAKEINDEX OUTPUT for $(SRC_FILE).tex ==="; 
	$(MAKE) -s --no-print-directory SRC_FILE=$(SRC_FILE) clean-inter-srcfile;
## If we failed to create the bibtex file, delete the dvi file from the first latex run.  
## If we don't, the makefile will create PS and PDF files from that dvi file on the next run. 
	rm -f $(SRC_FILE).dvi
# Clean up other LaTeX files
	$(MAKE) -s --no-print-directory SRC_FILE=$(@:.dvi=) clean-inter-srcfile 
	exit 1;


bibtexerror:
	echo "=== BEGIN BIBTEX OUTPUT for $(SRC_FILE).tex ==="; 
	cat tmp/$(SRC_FILE)-bibtex.txt; 
	echo "=== END BIBTEX OUTPUT for $(SRC_FILE).tex ==="; 
	$(MAKE) -s --no-print-directory SRC_FILE=$(SRC_FILE) clean-inter-srcfile;
## If we failed to create the bibtex file, delete the dvi file from the first latex run.  
## If we don't, the makefile will create PS and PDF files from that dvi file on the next run. 
	rm -f $(SRC_FILE).dvi
# Clean up other LaTeX files
	$(MAKE) -s --no-print-directory SRC_FILE=$(@:.dvi=) clean-inter-srcfile 
	exit 1;


latexerror:
	echo "=== BEGIN LATEX OUTPUT for ${SRC_FILE}.tex ==="; 
	cat tmp/$(SRC_FILE)-latex.txt;
	echo "=== END LATEX OUTPUT for ${SRC_FILE}.tex ==="; 
## Remove the dvi file such that LaTeX is forced to run next time
	rm -f $(SRC_FILE).dvi
## Clean up other LaTeX files
	$(MAKE) -s --no-print-directory SRC_FILE=$(@:.dvi=) clean-inter-srcfile
	exit 1


# Remove any intermediate files that LaTeX and bibtex make for all SRC_FILES.
clean-intermediate: 
	@${MAKE} -s --no-print-directory SRC_FILE="${SRC_FILES}" clean-inter-srcfile

# Remove intermediate that LaTeX and bibtex make ONLY for SRC_FILE.
clean-inter-srcfile:
	rm -f \
	$(addsuffix .aux,${SRC_FILE}) \
	$(addsuffix .log,${SRC_FILE}) \
	$(addsuffix .bbl,${SRC_FILE}) \
	$(addsuffix .blg,${SRC_FILE}) \
	$(addsuffix .toc,${SRC_FILE}) \
	$(addsuffix .ilg,${SRC_FILE}) \
	$(addsuffix .lof,${SRC_FILE}) \
	$(addsuffix .lot,${SRC_FILE}) \
	$(addsuffix .idx,${SRC_FILE}) \
	$(addsuffix .ind,${SRC_FILE}) \
	$(addsuffix .out,${SRC_FILE}) 


# Remove "intermediate" files and the output from latex/bibtex/dvips
clean: clean-intermediate
	rm -rf tmp *~
	# Millar
	rm millar.dvi millar.ps

# Remove all pdf/ps/dvi files created by us
clobber: clean
	rm -f \
	$(addsuffix .pdf,${SRC_FILES}) \
	$(addsuffix .ps ,${SRC_FILES}) \
	$(addsuffix .dvi,${SRC_FILES})

.DEFAULT help:
	@echo "Target  Description"
	@echo "==================="
	@echo "pdf     [DEFAULT] Create a PDF of each SRC_FILE"
	@echo "ps      Create PostScript files for each SRC_FILE"
	@echo "dvi     Create DVI files for each SRC_FILE"
	@echo
	@echo "X.pdf   Create X.pdf from X.tex, X.dvi, or X.ps"
	@echo "X.ps    Create X.ps from X.tex or X.dvi"
	@echo "X.dvi   Create X.dvi from X.tex"
	@echo
	@echo "clean    Removes unnecessary files."
	@echo "clobber  Removes unnecessary files (include PDFs, PS, and DVI files)."

