SUBDIRS = data help po src

MAINTAINERCLEANFILES = \
	$(GITIGNORE_MAINTAINERCLEANFILES_TOPLEVEL) \
	$(GITIGNORE_MAINTAINERCLEANFILES_MAKEFILE_IN)

# We currently have no custom macros
GITIGNOREFILES = m4

EXTRA_DIST = \
  meson.build \
  data/meson.build \
  help/meson.build \
  po/meson.build \
  src/meson.build \
  meson_post_install.py

-include $(top_srcdir)/git.mk
