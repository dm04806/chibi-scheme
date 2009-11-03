# -*- makefile-gmake -*-

.PHONY: all doc dist clean cleaner test install uninstall

CC       ?= cc
PREFIX   ?= /usr/local
BINDIR   ?= $(PREFIX)/bin
LIBDIR   ?= $(PREFIX)/lib
SOLIBDIR ?= $(PREFIX)/lib
INCDIR   ?= $(PREFIX)/include/chibi
MODDIR   ?= $(PREFIX)/share/chibi

DESTDIR ?=

ifndef PLATFORM
ifeq ($(shell uname),Darwin)
PLATFORM=macosx
else
ifeq ($(shell uname -o),Msys)
PLATFORM=mingw
SOLIBDIR = $(BINDIR)
DIFFOPTS = -b
else
PLATFORM=unix
endif
endif
endif

ifeq ($(PLATFORM),macosx)
SO  = .dylib
EXE =
CLIBFLAGS = -dynamiclib
STATICFLAGS = -static-libgcc
else
ifeq ($(PLATFORM),mingw)
SO  = .dll
EXE = .exe
CC = gcc
CLIBFLAGS = -shared
CPPFLAGS += -DUSE_STRING_STREAMS=0 -DBUILDING_DLL -DUSE_DEBUG=0
LDFLAGS += -Wl,--out-implib,libchibi-scheme$(SO).a
else
SO  = .so
EXE =
CLIBFLAGS = -fPIC -shared
STATICFLAGS = -static
endif
endif

all: chibi-scheme$(EXE)

ifdef USE_BOEHM
GCLDFLAGS := -lgc
XCPPFLAGS := $(CPPFLAGS) -Iinclude -DUSE_BOEHM=1
else
GCLDFLAGS :=
XCPPFLAGS := $(CPPFLAGS) -Iinclude
endif

XLDFLAGS  := $(LDFLAGS) $(GCLDFLAGS) -lm
XCFLAGS   := -Wall -g3 $(CFLAGS)

INCLUDES = include/chibi/sexp.h include/chibi/config.h include/chibi/install.h

include/chibi/install.h: Makefile
	echo '#define sexp_module_dir "'$(MODDIR)'"' > $@

sexp.o: sexp.c gc.c opt/bignum.c $(INCLUDES) Makefile
	$(CC) -c $(XCPPFLAGS) $(XCFLAGS) $(CLIBFLAGS) -o $@ $<

eval.o: eval.c debug.c opcodes.c $(INCLUDES) include/chibi/eval.h Makefile
	$(CC) -c $(XCPPFLAGS) $(XCFLAGS) $(CLIBFLAGS) -o $@ $<

main.o: main.c $(INCLUDES) include/chibi/eval.h Makefile
	$(CC) -c $(XCPPFLAGS) $(XCFLAGS) -o $@ $<

libchibi-scheme$(SO): eval.o sexp.o
	$(CC) $(CLIBFLAGS) -o $@ $^ $(XLDFLAGS)

chibi-scheme$(EXE): main.o libchibi-scheme$(SO)
	$(CC) $(XCPPFLAGS) $(XCFLAGS) -o $@ $< -L. -lchibi-scheme

chibi-scheme-static$(EXE): main.o eval.o sexp.o
	$(CC) $(XCFLAGS) $(STATICFLAGS) -o $@ $^ $(XLDFLAGS)

clean:
	rm -f *.o *.i *.s *.8

cleaner: clean
	rm -f chibi-scheme$(EXE) chibi-scheme-static$(EXE) *$(SO) *.a
	rm -rf *.dSYM

test-basic: chibi-scheme$(EXE)
	@for f in tests/basic/*.scm; do \
	    ./chibi-scheme$(EXE) $$f >$${f%.scm}.out 2>$${f%.scm}.err; \
	    if diff -q $(DIFFOPTS) $${f%.scm}.out $${f%.scm}.res; then \
	        echo "[PASS] $${f%.scm}"; \
	    else \
	        echo "[FAIL] $${f%.scm}"; \
	    fi; \
	done

test-numbers: chibi-scheme$(EXE)
	./chibi-scheme$(EXE) tests/numeric-tests.scm

test: chibi-scheme$(EXE)
	./chibi-scheme$(EXE) tests/r5rs-tests.scm

install: chibi-scheme$(EXE)
	mkdir -p $(DESTDIR)$(BINDIR)
	cp chibi-scheme$(EXE) $(DESTDIR)$(BINDIR)/
	mkdir -p $(DESTDIR)$(MODDIR)
	cp init.scm config.scm $(DESTDIR)$(MODDIR)/
	cp -r lib/ $(DESTDIR)$(MODDIR)/
	mkdir -p $(DESTDIR)$(INCDIR)
	cp $(INCLUDES) include/chibi/eval.h $(DESTDIR)$(INCDIR)/
	mkdir -p $(DESTDIR)$(LIBDIR)
	cp libchibi-scheme$(SO) $(DESTDIR)$(SOLIBDIR)/
	-cp libchibi-scheme.a $(DESTDIR)$(LIBDIR)/
	if type ldconfig >/dev/null 2>/dev/null; then ldconfig; fi

uninstall:
	rm -f $(BINDIR)/chibi-scheme*
	rm -f $(SOLIBDIR)/libchibi-scheme$(SO)
	rm -f $(LIBDIR)/libchibi-scheme$(SO).a
	cd $(INCDIR) && rm -f $(INCLUDES) include/chibi/eval.h
	rm -rf $(MODDIR)

dist: cleaner
	rm -f chibi-scheme-`cat VERSION`.tgz
	mkdir chibi-scheme-`cat VERSION`
	for f in `hg manifest`; do mkdir -p chibi-scheme-`cat VERSION`/`dirname $$f`; ln -s `pwd`/$$f chibi-scheme-`cat VERSION`/$$f; done
	tar cphzvf chibi-scheme-`cat VERSION`.tgz chibi-scheme-`cat VERSION`
	rm -rf chibi-scheme-`cat VERSION`
