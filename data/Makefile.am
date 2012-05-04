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

install-scorefiles-local:
	-$(mkinstalldirs) $(DESTDIR)$(scoredir)
	-for i in small normal large; do \
		touch $(DESTDIR)$(scoredir)/swell-foop.$$i.scores; \
		chown $(scores_user):$(scores_group) $(DESTDIR)$(scoredir)/swell-foop.$$i.scores; \
		chmod 664 $(DESTDIR)$(scoredir)/swell-foop.$$i.scores; \
	done

install-data-local: install-scorefiles-local

-include $(top_srcdir)/git.mk
