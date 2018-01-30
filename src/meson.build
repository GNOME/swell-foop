swell_foop_sources = [
  'config.vapi',
  'history.vala',
  'game.vala',
  'game-view.vala',
  'score-dialog.vala',
  'swell-foop.vala',
]

swell_foop_deps = [
  posix,
  libmath,
  gmodule,
  glib,
  gobject,
  gtk,
  clutter,
  clutter_gtk,
]

swell_foop_c_flags = [ 
  '-DVERSION="@0@"'.format (meson.project_version ()),
  '-DGETTEXT_PACKAGE="@0@"'.format (meson.project_name()),
  '-DLOCALEDIR="@0@"'.format (localedir),
  '-DDATADIR="@0@"'.format (pkgdatadir),
]

swell_foop_vala_flags = [
  '--target-glib', glib_min_version,
]

executable('swell-foop', swell_foop_sources,
  dependencies: swell_foop_deps,
  vala_args: swell_foop_vala_flags,
  c_args: swell_foop_c_flags,
  install: true,
)
