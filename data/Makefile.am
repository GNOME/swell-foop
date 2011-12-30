SUBDIRS = icons themes

swelldir=$(pkgdatadir)/swell-foop
swell_DATA = \
    swell-foop.ui \
    settings.ui

schema_in_files = swell-foop.schemas.in
if HAVE_GNOME
schemadir = $(GCONF_SCHEMA_FILE_DIR)
schema_DATA = $(schema_in_files:.schemas.in=.schemas)
endif

desktop_in_files = swell-foop.desktop.in.in
desktopdir = $(datadir)/applications
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

EXTRA_DIST = \
    $(swell_DATA) \
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

CLEANFILES = \
	$(desktop_DATA)	\
	$(schema_DATA)

DISTCLEANFILES = \
	$(desktop_DATA)	\
	$(schema_DATA)

@INTLTOOL_SCHEMAS_RULE@

-include $(top_srcdir)/git.mk
