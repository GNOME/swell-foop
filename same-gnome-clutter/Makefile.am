SUBDIRS = data/themes

#if BUILD_HELP
#SUBDIRS += help
#endif

samedir=$(pkgdatadir)/same-gnome-clutter

same_DATA = \
    src/About.js \
    src/Board.js \
    src/Light.js \
    src/main.js \
    src/Settings.js \
    data/same-gnome.ui \
    data/settings.ui \
    src/Score.js \
    src/Path.js \
    src/ThemeLoader.js

bin_SCRIPTS = same-gnome-clutter

schema_in_files = same-gnome-clutter.schemas.in
if HAVE_GNOME
schemadir = $(GCONF_SCHEMA_FILE_DIR)
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
endif

desktop_in_files = same-gnome-clutter.desktop.in.in
desktopdir = $(datadir)/applications
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@
        
CLEANFILES = $(desktop_DATA)

EXTRA_DIST = \
    src/About.js \
    src/Board.js \
    src/Light.js \
    src/main.js \
    src/Settings.js \
    data/same-gnome.ui \
    data/settings.ui \
    src/Score.js \
    src/Path.js.in \
    src/ThemeLoader.js \
    $(schema_in_files)

install-schemas-local: $(schema_DATA)
if GCONF_SCHEMAS_INSTALL
	if test -z "$(DESTDIR)" ; then \
		for p in $^ ; do \
			GCONF_CONFIG_SOURCE=$(GCONF_SCHEMA_CONFIG_SOURCE) $(GCONFTOOL) --makefile-install-rule $$p 2>&1 > /dev/null; \
		done \
	fi
endif

install-data-local: install-schemas-local

@INTLTOOL_SCHEMAS_RULE@

-include $(top_srcdir)/git.mk
