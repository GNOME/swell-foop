SUBDIRS = icons themes

gsettings_in_file = org.gnome.swell-foop.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

swelldir=$(pkgdatadir)/swell-foop
swell_DATA = \
    swell-foop.ui \
    settings.ui

desktop_in_files = swell-foop.desktop.in.in
desktopdir = $(datadir)/applications
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

EXTRA_DIST = \
    $(swell_DATA) \
    $(gsettings_in_file) \
    $(desktop_in_files)

CLEANFILES = \
	$(desktop_DATA)	\
	$(gsettings_SCHEMAS)

DISTCLEANFILES = \
	$(desktop_DATA)	\
	$(gsettings_SCHEMAS)

@INTLTOOL_SCHEMAS_RULE@

-include $(top_srcdir)/git.mk
