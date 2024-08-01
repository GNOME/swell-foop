sources = [
  'game.vala',
  'game-view.vala',
  'swell-foop.vala',
  'window.vala'
]

resource_files = files ('@0@.gresource.xml'.format('org.gnome.SwellFoop'))
resources = gnome.compile_resources ('org.gnome.SwellFoop', resource_files)

deps = [
  config_dep,
  posix_dep,
  libmath_dep,
  gmodule_dep,
  glib_dep,
  gobject_dep,
  gtk_dep,
  adw_dep,
  rsvg_dep,
  libgnome_games_support_dep,
  gee_dep,
  pangocairo_dep
]

c_flags = [
  '-DDATADIR="@0@"'.format(pkgdatadir),
  '-DLOCALEDIR="@0@"'.format(localedir),
  '-DGETTEXT_PACKAGE="@0@"'.format(meson.project_name())
]

executable('swell-foop', sources + resources,
  dependencies: deps,
  include_directories: config_h_inc,
  c_args: c_flags,
  vala_args: gtk_define + glib_define + target_glib,
  install: true,
)
