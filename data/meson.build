# Icons
install_subdir('icons',
  install_dir: datadir,
  exclude_files: [ 'icon-source.svg' ],
)

# Themes
install_subdir('themes',
  install_dir: pkgdatadir,
)

# UI files
install_data('preferences.ui',
  install_dir: pkgdatadir,
)

install_data('swell-foop.css',
  install_dir: pkgdatadir,
)

desktop = 'swell-foop.desktop'

# Desktop file
i18n.merge_file(
  input: desktop + '.in',
  output: desktop,
  type: 'desktop',
  po_dir: podir,
  install: true,
  install_dir: join_paths(datadir, 'applications'),
)

appdata = 'swell-foop.appdata.xml'

# Appdata
i18n.merge_file(
  input: appdata + '.in',
  output: appdata,
  po_dir: podir,
  install: true,
  install_dir: join_paths(datadir, 'metainfo')
)

# Gschema
install_data('org.gnome.swell-foop.gschema.xml',
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas'),
)

