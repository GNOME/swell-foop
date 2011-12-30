SUBDIRS = data src

if BUILD_HELP
SUBDIRS += help
endif

bin_SCRIPTS = swell-foop

swell-foop: swell-foop.in Makefile
	$(AM_V_GEN) $(SED) -e "s|%pkglibdir%|$(pkglibdir)|" -e "s|%pkgdatadir%|$(pkgdatadir)|" $< > $@

EXTRA_DIST = \
    swell-foop.in

CLEANFILES = \
	swell-foop

DISTCLEANFILES = \
	swell-foop

-include $(top_srcdir)/git.mk
