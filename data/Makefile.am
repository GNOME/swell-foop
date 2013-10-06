SUBDIRS = icons themes

gsettings_in_file = org.gnome.swell-foop.gschema.xml.in
gsettings_SCHEMAS = $(gsettings_in_file:.xml.in=.xml)
@INTLTOOL_XML_NOMERGE_RULE@
@GSETTINGS_RULES@

swelldir=$(datadir)/swell-foop
swell_DATA = \
    preferences.ui

desktop_in_files = swell-foop.desktop.in.in
desktopdir = $(datadir)/applications
desktop_DATA = $(desktop_in_files:.desktop.in.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_DATA = swell-foop.appdata.xml

EXTRA_DIST = \
    $(appdata_DATA) \
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

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
