# Generic Makefile that can live in the same directory as an R package.

PKGNAME = $(shell awk '{if(/Package:/) print $$2}' DESCRIPTION)
VERSION = $(shell awk '{if(/Version:/) print $$2}' DESCRIPTION)
PKG = $(PKGNAME)_$(VERSION).tar.gz

# Helpful for debugging:
$(info R package is: $(PKG))

RFILES = $(wildcard R/*.R)
TESTFILES = $(wildcard tests/testthat/test*.R)
VIGNETTES = $(wildcard vignettes/*.Rmd)

# User local install
install: $(PKG)
	R CMD INSTALL $<

$(PKG): $(RFILES) $(TESTFILES) $(TEMPLATES) $(VIGNETTES) DESCRIPTION
	R -e "devtools::document()"
	rm -f $(PKG)  # Otherwise it's included in build
	R CMD build . --no-build-vignettes

check: $(PKG)
	R CMD check $(PKG) --as-cran --run-dontrun

clean:
	rm -rf vignettes/*.html $(PKG) *.Rcheck
