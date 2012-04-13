SOURCES=$(wildcard *.vala)
DEPENDENCIES=\
	Makefile\
	TODO
PROGRAM=ep
VERSION=0.0.1


# install location.
PREFIX?=$(HOME)/.local/

PKGS=\
	gtk+-3.0\
	glib-2.0\
	json-glib-1.0\
	sqlite3

##
# Check packages
##
PKG_EXISTS=$(shell pkg-config --exists $(PKGS);echo $$?)
PKG_FALSE=1

ifeq ($(PKG_EXISTS),$(PKG_FALSE))
$(error Not all dependencies are met. Check if $(PKGS) exists.)
endif

VALA_FLAGS=
CSOURCES=
-include Makefile.settings
##
# VALA flags.
##
VALA_FLAGS+=$(foreach PKG, $(PKGS), --pkg=$(PKG)) -g 

##
# Build program
##
$(PROGRAM): $(SOURCES) | $(DEPENDENCIES) 
	valac -o $@ $^ $(VALA_FLAGS) 

###
# Clean up
###
.PHONY: clean
clean: $(PROGRAM) $(CSOURCES) 
	rm -f $^ 

enable-cfiles: 
	$(info Enabling building of C files)
	@rm -f $(PROGRAM) $(CSOURCES)
	@echo "VALA_FLAGS:=--save-temps" > Makefile.settings
	@echo "CSOURCES="$(SOURCES:%.vala=%.c)"" >> Makefile.settings

disable-cfiles: 
	$(info Disable building of C files)
	@rm -f $(PROGRAM) $(CSOURCES)
	@rm -f Makefile.settings

DIST_NAME=$(PROGRAM)-$(shell date +%d%m%Y)
DIST_FILE=$(DIST_NAME).tar.gz
.PHONY: dist
dist: $(DIST_FILE) 

$(DIST_FILE): $(SOURCES) $(DEPENDENCIES) 
	mkdir $(DIST_NAME)
	cp $^   $(DIST_NAME)
	tar cvvzf $@ $(DIST_NAME)
	rm -rf $(DIST_NAME)

##
# installing
##
BIN_PATH=$(PREFIX)/bin/

.PHONY: install
install: $(BIN_PATH)/$(PROGRAM)

$(BIN_PATH): $(PROGRAM)
	mkdir -p $@ 

$(BIN_PATH)/$(PROGRAM): $(PROGRAM) | $(BIN_PATH) 
	install $^ $@

.PHONY: uninstall
uninstall:
	rm -f $(BIN_PATH)/$(PROGRAM)
