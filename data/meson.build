# Icons
install_subdir('icons',
  install_dir: datadir,
  exclude_files: [ 'icon-source.svg' ],
)

# Themes
install_subdir('themes',
  install_dir: pkgdatadir,
)

desktop = 'org.gnome.SwellFoop.desktop'

# Desktop file
desktop_file = i18n.merge_file(
  input: desktop + '.in',
  output: desktop,
  type: 'desktop',
  po_dir: podir,
  install: true,
  install_dir: join_paths(datadir, 'applications'),
)
desktop_file_validate = find_program('desktop-file-validate', required: false)
if desktop_file_validate.found()
  test(
    'validate-desktop',
    desktop_file_validate,
    args: [
      desktop_file.full_path()
    ]
  )
endif

appdata = 'org.gnome.SwellFoop.appdata.xml'

# Appdata
appdata_file = i18n.merge_file(
  input: appdata + '.in',
  output: appdata,
  po_dir: podir,
  install: true,
  install_dir: join_paths(datadir, 'metainfo')
)
appstream_util = find_program('appstream-util', required: false)
if appstream_util.found()
  test(
    'validate-appdata', appstream_util,
    args: [
      'validate-relax', '--nonet', appdata_file.full_path()
    ]
  )
endif

# Gschema
install_data('org.gnome.swell-foop.gschema.xml',
  install_dir: join_paths(datadir, 'glib-2.0', 'schemas'),
)

