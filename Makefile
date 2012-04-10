SOURCES=$(wildcard *.vala)
PROGRAM=ep

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
$(error Not all dependencies are met)
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
$(PROGRAM): $(SOURCES) | Makefile
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
