bin_PROGRAMS = swell-foop

swell_foop_SOURCES = \
	game-view.vala \
	game.vala \
	history.vala \
	config.vapi \
	swell-foop.vala

swell_foop_VALAFLAGS = \
	--pkg posix \
	--pkg gmodule-2.0 \
	--pkg clutter-gtk-1.0 \
	--target-glib 2.36

swell_foop_CFLAGS = \
	-DVERSION=\"$(VERSION)\" \
	-DGETTEXT_PACKAGE=\"$(GETTEXT_PACKAGE)\" \
	-DDATADIR=\""$(datadir)/swell-foop"\" \
	-DLOCALEDIR=\"$(datadir)/locale\" \
	$(SWELL_FOOP_CFLAGS)

swell_foop_LDADD =	\
	$(SWELL_FOOP_LIBS)

CLEANFILES = \
	$(patsubst %.vala,%.c,$(filter %.vala, $(SOURCES))) \
	*_vala.stamp

-include $(top_srcdir)/git.mk
