top_srcdir     = ../..
srcdir         = .

SHELL          = /bin/sh

# Installation targets
#
prefix      = /usr/local
exec_prefix = ${prefix}
datarootdir = ${prefix}/share
bindir      = ${exec_prefix}/bin
libdir      = ${exec_prefix}/lib
includedir  = ${prefix}/include
mandir      = ${datarootdir}/man
docdir      = ${datarootdir}/doc/${PACKAGE_TARNAME}
pdfdir      = ${docdir}
mandir      = ${datarootdir}/man
man1dir     = ${mandir}/man1
man1ext     = .1

HMMER_VERSION   =  3.4
HMMER_DATE      = "June 2025"
HMMER_COPYRIGHT = "Copyright (C) 2025 Howard Hughes Medical Institute."

INSTALL       = /usr/bin/install -c
RMAN          = rman
RMANPROCESS   = ${top_srcdir}/easel/devkit/rmanprocess.py

# beautification magic stolen from git
QUIET_SUBDIR0 = +${MAKE} -C #space separator after -c
QUIET_SUBDIR1 = 
ifndef V
	QUIET_SUBDIR0 = +@subdir=
	QUIET_SUBDIR1 = ; echo '    ' SUBDIR $$subdir; \
		        ${MAKE} -s -C $$subdir
endif

TEXFILES =\
	HMMot_userguide.tex          \
	copyright.tex    \
	titlepage_HMMot.tex 


.PHONY: pdf manpages clean distclean TAGS

pdf:    HMMot_userguide.pdf

# We add ${srcdir} to TEXINPUTS, etc so we can build userguide in a build tree, with input files in source tree.
HMMot_userguide.pdf: ${TEXFILES}
	@for prog in pdflatex bibtex; do \
	  command -v $$prog >/dev/null 2>&1 || { echo >&2 "$$prog is required to build Userguide, but it's not installed. Aborting."; exit 1; } \
	done
	@echo "     LATEX HMMot_serguide.pdf  (see latex.log for output)"
	@TEXINPUTS=${TEXINPUTS}:${srcdir} pdflatex HMMot_userguide                                >  latex.log 2>&1 
	@BIBINPUTS=${BIBINPUTS}:${srcdir} BSTINPUTS=${BSTINPUTS}:${srcdir} bibtex HMot_userguide >> latex.log 2>&1 
	@TEXINPUTS=${TEXINPUTS}:${srcdir} pdflatex HMMot_userguide                                >> latex.log 2>&1 
	@TEXINPUTS=${TEXINPUTS}:${srcdir} pdflatex HMMot_userguide                                >> latex.log 2>&1 
	@mv main.pdf Userguide.pdf

clean:
	${QUIET_SUBDIR0}inclusions   ${QUIET_SUBDIR1} clean
	-rm -f latex.log

ifndef V
	@echo '     ' CLEAN userguide
endif


distclean: clean
	${QUIET_SUBDIR0}inclusions   ${QUIET_SUBDIR1} distclean
	if test "x${srcdir}" != "x."; then \
	   for texfile in ${TEXFILES}; do \
	      rm -f $$texfile ;\
	   done ;\
	fi
	-rm -f titlepage.tex copyright.tex manpages.tex easel_manpages.tex
	-rm -f manpages_daemon.tex titlepage_daemon.tex titlepage_server.tex
	-rm -f Userguide.pdf
	-rm -f Daemon_userguide.pdf
	-rm -f Makefile

