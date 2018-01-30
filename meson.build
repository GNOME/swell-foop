project('swell-foop', ['c','vala'],
  version: '3.27.2',
  meson_version: '>= 0.37',
  license: 'GPLv3+',
)

gnome = import('gnome')
i18n = import('i18n')

localedir = join_paths(get_option('prefix'), get_option('localedir'))
podir = join_paths(meson.source_root(), 'po')
datadir = join_paths (get_option ('prefix'), get_option ('datadir'))
pkgdatadir = join_paths (datadir, 'swell-foop')

# Dependencies

glib_min_version = '2.36'

glib = dependency('glib-2.0', version: '>= ' + glib_min_version)
gmodule = dependency('gmodule-2.0')
gobject = dependency('gobject-2.0', version: '>= ' + glib_min_version)
gtk = dependency('gtk+-3.0', version: '>= 3.12')
clutter = dependency('clutter-1.0', version: '>= 1.14.0')
clutter_gtk = dependency('clutter-gtk-1.0', version: '>= 1.5.0')

# Check for compilers
valac = meson.get_compiler('vala')
cc = meson.get_compiler('c')

# Libraries
libmath = cc.find_library('m')
posix = valac.find_library('posix')

# Configuration
conf = configuration_data()

conf.set_quoted('GETTEXT_PACKAGE', meson.project_name())
conf.set_quoted('LOCALEDIR', localedir)
conf.set_quoted('DATADIR', localedir)
conf.set_quoted('VERSION', meson.project_version())

configure_file(output: 'config.h', configuration: conf)
config_h_dir = include_directories('.')

# Extra scripts
meson.add_install_script('meson_post_install.py')

# Subdirs
subdir('data')
subdir('src')
subdir('help')
subdir('po')


