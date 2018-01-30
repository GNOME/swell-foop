# Icons
install_subdir('icons',
  install_dir: join_paths(get_option('datadir')),
  exclude_files: [ 'Makefile', 'Makefile.in', 'Makefile.am', 'icon-source.svg','.gitignore' ],
)

# Themes
install_subdir('themes',
  install_dir: pkgdatadir,
  exclude_files: [ '**/Makefile', '**/Makefile.in', '**/Makefile.am', '**/.gitignore' ],
)

# UI files
install_data('preferences.ui',
  install_dir: pkgdatadir,
)

install_data('swell-foop.css',
  install_dir: pkgdatadir,
)

# Desktop file
i18n.merge_file(
  input: 'swell-foop.desktop.in',
  output: 'swell-foop.desktop',
  type: 'desktop',
  po_dir: podir,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'applications'),
)

# Appdata
i18n.merge_file(
  input: 'swell-foop.appdata.xml.in',
  output: 'swell-foop.appdata.xml',
  type: 'xml',
  po_dir: podir,
  install: true,
  install_dir: join_paths(get_option('datadir'), 'metainfo')
)

# Gschema
install_data('org.gnome.swell-foop.gschema.xml',
  install_dir: join_paths(get_option('datadir'), 'glib-2.0', 'schemas'),
)

