# OccO ontology Makefile
# Jie Zheng
#
# This Makefile is used to build artifacts for the Occupation Ontology.
#

### Configuration
#
# prologue:
# <http://clarkgrubb.com/makefile-style-guide#toc2>

MAKEFLAGS += --warn-undefined-variables
SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := all
.DELETE_ON_ERROR:
.SUFFIXES:

### Definitions

SHELL   := /bin/bash
OBO     := http://purl.obolibrary.org/obo
OCCO  := $(OBO)/OCCO_
TODAY   := $(shell date +%Y-%m-%d)

### Directories
#
# This is a temporary place to put things.
build:
	mkdir -p $@


### ROBOT
#
# We use the latest official release version of ROBOT
build/robot.jar: | build
	curl -L -o $@ "https://github.com/ontodev/robot/releases/latest/download/robot.jar"

ROBOT := java -jar build/robot.jar


### Imports
#
# Use Ontofox to import various modules.
build/%_imports.owl: src/ontology/Ontofox_input/%_import_input.txt | build/robot.jar build
	curl -s -F file=@$< -o $@ https://ontofox.hegroup.org/service.php

# Use ROBOT to remove external java axioms
src/ontology/imports/%_imports.owl: build/%_imports.owl
	$(ROBOT) remove --input build/$*_imports.owl \
	--base-iri 'http://purl.obolibrary.org/obo/$*_' \
	--axioms external \
	--preserve-structure false \
	--trim false \
	--output $@ 

IMPORT_FILES := $(wildcard src/ontology/imports/*_imports.owl)

.PHONY: imports
imports: $(IMPORT_FILES)


### Templates
#
src/ontology/Modules/%.owl: src/ontology/Templates/%.tsv | build/robot.jar
	echo '' > $@
	$(ROBOT) merge \
	--input src/ontology/occo-edit.owl \
	template \
	--template $< \
	--prefix "OCCO: http://purl.obolibrary.org/obo/OCCO_" \
	--ontology-iri "http://purl.obolibrary.org/obo/occo/dev/$(notdir $@)" \
	--output $@

# Update all modules
MODULE_NAMES := occo_terms\
 US_SOC_ID\
 ability_types\
 skill_types\
 job_zones_equivalent\
 job_zones\
 top_abilities_axioms\
 top_abilities_annotations\
 top_skills_axioms\
 top_skills_annotations\
 Alabama_subset\
 occo_obsolete

MODULE_FILES := $(foreach x,$(MODULE_NAMES),src/ontology/Modules/$(x).owl)

.PHONY: modules
modules: $(MODULE_FILES)

### Views
# Build Alabama occupation view
views/occo_alabama.owl: occo.owl src/ontology/views/Alabama.txt | build/robot.jar
	$(ROBOT) extract \
	--input $< \
	--method STAR \
	--term-file $(word 2,$^) \
	--individuals definitions \
	--copy-ontology-annotations true \
	annotate \
	--ontology-iri "$(OBO)/occo/occo_alabama.owl" \
	--version-iri "$(OBO)/occo/$(TODAY)/occo_alabama.owl" \
	--output $@
.PHONY: views
views: views/occo_alabama.owl


### Build
#
# Here we create a standalone OWL file appropriate for release.
# This involves merging, reasoning, annotating,
# and removing any remaining import declarations.

build/occo-merged.owl: src/ontology/occo-edit.owl | build/robot.jar build
	$(ROBOT) merge \
	--input $< \
	annotate \
	--ontology-iri "$(OBO)/occo/occo-merged.owl" \
	--version-iri "$(OBO)/occo/$(TODAY)/occo-merged.owl" \
	--annotation owl:versionInfo "$(TODAY)" \
	--output build/occo-merged.tmp.owl
	sed '/<owl:imports/d' build/occo-merged.tmp.owl > $@
	rm build/occo-merged.tmp.owl

occo.owl: build/occo-merged.owl
	$(ROBOT) reason \
	--input $< \
	--reasoner HermiT \
	annotate \
	--ontology-iri "$(OBO)/occo.owl" \
	--version-iri "$(OBO)/occo/$(TODAY)/occo.owl" \
	--annotation owl:versionInfo "$(TODAY)" \
	--output $@

robot_report.tsv: build/occo-merged.owl
	$(ROBOT) report \
	--input $< \
        --fail-on none \
	--output $@

### 
#
# Full build
.PHONY: all
all: occo.owl robot_report.tsv

# Remove generated files
.PHONY: clean
clean:
	rm -rf build

