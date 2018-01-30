SUBDIRS = icons themes

gsettings_SCHEMAS = org.gnome.swell-foop.gschema.xml
@GSETTINGS_RULES@

swelldir=$(datadir)/swell-foop
swell_DATA = \
    preferences.ui \
    swell-foop.css

desktop_in_files = swell-foop.desktop.in
desktopdir = $(datadir)/applications
desktop_DATA = $(desktop_in_files:.desktop.in=.desktop)
$(desktop_DATA): $(desktop_in_files)
	$(AM_V_GEN)$(MSGFMT) --desktop --template $< -d $(top_srcdir)/po -o $@

appstream_in_files = swell-foop.appdata.xml.in
appstream_XML = $(appstream_in_files:.xml.in=.xml)
$(appstream_XML): $(appstream_in_files)
	$(AM_V_GEN)$(MSGFMT) --xml --template $< -d $(top_srcdir)/po -o $@

EXTRA_DIST = \
    $(appstream_in_files) \
    $(swell_DATA) \
    $(gsettings_SCHEMAS) \
    $(desktop_in_files)

CLEANFILES = \
	$(appstream_XML) \
	$(desktop_DATA)

check-local: $(desktop_DATA)
	$(DESKTOP_FILE_VALIDATE) $(desktop_DATA)

DISTCHECK_CONFIGURE_FLAGS = --enable-appdata-check

-include $(top_srcdir)/git.mk
