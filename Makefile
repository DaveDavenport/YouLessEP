SOURCES=$(wildcard *.vala)
PROGRAM=ep

PKGS=\
	gtk+-3.0\
	glib-2.0\
	json-glib-1.0\
	sqlite3

VALA_FLAGS=$(foreach PKG, $(PKGS), --pkg=$(PKG))


$(PROGRAM): $(SOURCES)
	valac -o $@ $^ $(VALA_FLAGS) 
