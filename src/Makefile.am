swelldir=$(pkgdatadir)/swell-foop

bin_SCRIPTS = swell-foop

swell-foop: swell-foop.in Makefile
	$(AM_V_GEN) $(SED) -e "s|%pkglibdir%|$(pkglibdir)|" -e "s|%pkgdatadir%|$(pkgdatadir)|" $< > $@
	chmod +x $@

swell_DATA = \
    About.js \
    Board.js \
    Light.js \
    main.js \
    Settings.js \
    Score.js \
    Path.js \
    ThemeLoader.js

Path.js: Path.js.in
	$(AM_V_GEN) $(SED) -e "s|%pkgdatadir%|$(pkgdatadir)|" $< > $@

EXTRA_DIST = \
    swell-foop.in \
    About.js \
    Board.js \
    Light.js \
    main.js \
    Settings.js \
    Score.js \
    Path.js.in \
    ThemeLoader.js

CLEANFILES = \
	swell-foop \
	Path.js

DISTCLEANFILES = \
	swell-foop \
	Path.js

-include $(top_srcdir)/git.mk
