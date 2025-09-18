project('swell-foop', ['c','vala'],
  version: '48.1',
  meson_version: '>= 0.60',
  license: 'GPLv2+',
)

gnome   = import('gnome')
i18n    = import('i18n')

gettext_package = meson.project_name()

localedir   = join_paths (get_option ('prefix'), get_option ('localedir'))
datadir     = join_paths (get_option ('prefix'), get_option ('datadir'))
pkgdatadir  = join_paths (datadir, 'swell-foop')
bindir      = join_paths (get_option ('prefix'), get_option ('bindir'))

podir   = join_paths(meson.project_source_root(), 'po')
vapidir = join_paths(meson.project_source_root(), 'vapi')

# Dependencies
glib_min_version = '2.74' # for Timeout.add_once
glib_target_version = '2.78' # most recent tested version
target_glib = '--target-glib=' + '@0@'.format(glib_target_version)
gtk_min_version = '4.10'
adw_min_version = '1.5'

glib_dep        = dependency('glib-2.0', version: '>= ' + glib_min_version)
gmodule_dep     = dependency('gmodule-2.0')
gobject_dep     = dependency('gobject-2.0')
gtk_dep         = dependency('gtk4', version: '>= ' + gtk_min_version)
adw_dep         = dependency('libadwaita-1', version: '>= ' + adw_min_version)
rsvg_dep        = dependency('librsvg-2.0', version: '>=2.46' )
gee_dep         = dependency('gee-0.8', version: '>= 0.14.0')
pangocairo_dep  = dependency('pangocairo')

libgnome_games_support = subproject ('libgnome-games-support',
                                     default_options: 'superproject_name=gnome-mines')
libgnome_games_support_dep = libgnome_games_support.get_variable ('lggs_dependency')

# version defines of GTK4 for #if e.g. #if GTK_4_6_or_above
gtk_version = gtk_dep.version()
gtk_define = []
foreach i : range(0, gtk_version.split('.')[1].to_int() + 1, 1)
	gtk_define += '--define=GTK_4_' + i.to_string() + '_or_above'
endforeach

# version defines of GLIB for #if e.g. #if GLIB_2_74_or_above
glib_version = glib_dep.version()
glib_define = []
foreach i : range(74, glib_version.split('.')[1].to_int() + 1, 1)
	glib_define += '--define=GLIB_2_' + i.to_string() + '_or_above'
endforeach

# Check for compilers
valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')

# Libraries
libmath_dep = cc.find_library('m')
config_dep = valac.find_library('config', dirs: vapidir)
posix_dep = valac.find_library('posix')

# Configuration
conf = configuration_data()

conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('PACKAGE_URL', 'https://wiki.gnome.org/Apps/Swell%20Foop')
conf.set_quoted('VERSION', meson.project_version())

config_h_inc = include_directories('.')

# Subdirs
subdir('data')
subdir('src')
subdir('help')
subdir('po')

config_file = configure_file(output: 'config.h', configuration: conf)
# Extra scripts
gnome.post_install(
  glib_compile_schemas: true,
  gtk_update_icon_cache: true,
)
