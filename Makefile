# Constants
DEPS :=

export LATEX := lualatex

# Configurations
.SUFFIXES:
.DELETE_ON_ERROR:
.SECONDARY:
.ONESHELL:
export SHELL := /bin/bash
export SHELLOPTS := pipefail:errexit:nounset:noclobber

all_files := $(shell git ls-files)
dbj_files := $(filter dbj/%.dbj,$(all_files))

dbj_names := $(dbj_files:dbj/%.dbj=%)
all_names := $(dbj_names)

# Functions
sha256 = $(1:%=%.sha256)
unsha256 = $(1:%.sha256=%)

cart_prod_2 = $(foreach x,$(1),$(addprefix $(x),$(2)))

addps = $(addprefix $(1),$(addsuffix $(2),$(3)))

parse_stem = $(subst @, ,$(subst ~,=,$(1)))
declare = declare -r $(call parse_stem,$(1))
args = $(addprefix --,$(call parse_stem,$(1)))
get = $(wordlist 2,2,$(subst =, ,$(filter $(1)=%,$(call parse_stem,$(2)))))


patsubst_multi = $(foreach target,$(2), \
	            $(patsubst $(1),$(target),$(3)))


# Tasks
.PHONY: all deps dbj pdf
all: deps dbj pdf
deps: $(DEPS:%=dep/%.updated)
dbj: $(dbj_names:%=report/bst/%.bst)
pdf: $(all_names:%=report/pdf/%.pdf)

# Files

# Rules

report/pdf/%.pdf: work/%.pdf
	mkdir -p $(@D)
	cp -f $< $@

work/%.pdf: work/%.tex report/bst/%.bst example.bib
	latexmk \
	   -pdf \
	   -latex=$(LATEX) \
	   --output-directory=$(@D) \
	   -latexoption="--halt-on-error --shell-escape --interaction=nonstopmode --file-line-error" \
	   $<

work/%.tex: template.tex
	mkdir -p $(@D)
	sed -e 's/@name@/$*/g' < $< >| $@

report/bst/%.bst: bst/%.bst
	mkdir -p $(@D)
	cp -f $< $@

report/bst/%.bst: work/%.bst
	mkdir -p $(@D)
	cp -f $< $@

work/%.bst work/%.log: dbj/%.dbj
	mkdir -p $(@D)
	cd $(@D)
	$(LATEX) $(CURDIR)/$<

define DEPS_RULE_TEMPLATE =
dep/$(1)/%.sha256: dep/$(1)/%.sha256.new
	@cmp -s $$< $$@ || cp -f $$< $$@

dep/$(1)/%.sha256.new: dep/$(1)/%
	$(SHA256SUM) $$< >| $$@

dep/$(1)/%.exe: dep/$(1).updated ;
dep/$(1)/%.f90: dep/$(1).updated ;
dep/$(1)/%.py: dep/$(1).updated ;
dep/$(1)/%.rb: dep/$(1).updated ;
dep/$(1)/%.sh: dep/$(1).updated ;
endef
$(foreach f,$(DEPS),$(eval $(call DEPS_RULE_TEMPLATE,$(f))))

$(DEPS:%=dep/%.updated): dep/%.updated: config/dep/%.ref dep/%.synced
	cd $(@D)/$*
	git fetch origin
	git checkout "$$(cat $(CURDIR)/$<)"
	cd $(CURDIR)
	if [[ -r dep/$*/Makefile ]]; then
	   $(MAKE) -C dep/$*
	fi
	touch $@

$(DEPS:%=dep/%.synced): dep/%.synced: config/dep/%.uri | dep/%
	cd $(@D)/$*
	git remote remove origin
	git remote add origin "$$(cat $(CURDIR)/$<)"
	cd $(CURDIR)
	touch $@

$(DEPS:%=dep/%): dep/%:
	git init $@
	cd $@
	git remote add origin "$$(cat $(CURDIR)/config/dep/$*.uri)"
