SOURCES=$(wildcard *.vala)
PROGRAM=ep

PKGS=\
	gtk+-3.0\
	glib-2.0\
	json-glib-1.0\
	sqlite3

VALA_FLAGS=$(foreach PKG, $(PKGS), --pkg=$(PKG))

PKG_EXISTS=$(shell pkg-config --exists $(PKGS);echo $$?)
PKG_FALSE=1

ifeq ($(PKG_EXISTS),$(PKG_FALSE))
$(error Not all dependencies are met)
endif


##
# Build program
##
$(PROGRAM): $(SOURCES)
	valac -o $@ $^ $(VALA_FLAGS) 


###
# Clean up
###
clean: $(PROGRAM)
	@rm $^
