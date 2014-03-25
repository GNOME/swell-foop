AC_PREREQ([2.63])
AC_INIT([Swell Foop], [3.12.0], [https://bugzilla.gnome.org/],
        [swell-foop], [https://wiki.gnome.org/Apps/Swell%20Foop])
AM_INIT_AUTOMAKE([1.11 no-dist-gzip dist-xz foreign])
AM_SILENT_RULES([yes])
AM_MAINTAINER_MODE
GNOME_MAINTAINER_MODE_DEFINES

AM_PROG_VALAC([0.22])
AM_PROG_CC_C_O

GLIB_GSETTINGS

dnl ###########################################################################
dnl Dependencies
dnl ###########################################################################

GLIB_REQUIRED=2.36.0
GTK_REQUIRED=3.10
CLUTTER_REQUIRED=1.14.0
CLUTTER_GTK_REQUIRED=1.5.0

PKG_CHECK_MODULES(SWELL_FOOP, [
  gmodule-export-2.0
  glib-2.0 >= $GLIB_REQUIRED
  gtk+-3.0 >= $GTK_REQUIRED
  clutter-1.0 >= $CLUTTER_REQUIRED
  clutter-gtk-1.0 >= $CLUTTER_GTK_REQUIRED
])

AC_CHECK_LIB([m],[floor])

AC_PATH_PROG([APPDATA_VALIDATE], [appdata-validate], [/bin/true])
AC_PATH_PROG([DESKTOP_FILE_VALIDATE], [desktop-file-validate], [/bin/true])

dnl ###########################################################################
dnl Internationalization
dnl ###########################################################################

IT_PROG_INTLTOOL([0.50])
AC_SUBST(GETTEXT_PACKAGE, swell-foop)

dnl ###########################################################################
dnl Documentation
dnl ###########################################################################

YELP_HELP_INIT

dnl ###########################################################################
dnl Files to generate
dnl ###########################################################################

AC_CONFIG_FILES([
Makefile
po/Makefile.in
data/Makefile
data/icons/Makefile
data/themes/Makefile
data/themes/colors/Makefile
data/themes/shapesandcolors/Makefile
help/Makefile
src/Makefile
])
AC_OUTPUT
