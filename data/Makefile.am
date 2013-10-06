SUBDIRS = icons themes

gsettings_SCHEMAS = org.gnome.swell-foop.gschema.xml
@GSETTINGS_RULES@

swelldir=$(datadir)/swell-foop
swell_DATA = \
    preferences.ui

desktop_in_files = swell-foop.desktop.in
desktopdir = $(datadir)/applications
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
@INTLTOOL_DESKTOP_RULE@

appdatadir = $(datadir)/appdata
appdata_in_files = swell-foop.appdata.xml.in
appdata_DATA = $(appdata_in_files:.xml.in=.xml)
@INTLTOOL_XML_RULE@

EXTRA_DIST = \
    $(appdata_in_files) \
    $(swell_DATA) \
    $(gsettings_SCHEMAS) \
    $(desktop_in_files)

CLEANFILES = \
	$(appdata_DATA) \
	$(desktop_DATA)

check-local: $(appdata_DATA) $(desktop_DATA)
	$(APPDATA_VALIDATE) $(appdata_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

-include $(top_srcdir)/git.mk
