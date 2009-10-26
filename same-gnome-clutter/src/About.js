Gtk = imports.gi.Gtk;
GnomeGamesSupport = imports.gi.GnomeGamesSupport;

main = imports.main;

_ = imports.gettext.gettext;

function show_about_dialog()
{
	var about_dialog = new Gtk.AboutDialog();
	about_dialog.program_name = _("Same GNOME");
	about_dialog.version = "1.0";
	about_dialog.comments = _("I want to play that game! You know, they all go whirly-round and you click on them and they vanish!\n\nSame GNOME is a part of GNOME Games.");
	about_dialog.copyright = _("Copyright \xa9 2009 Tim Horton");
	about_dialog.license = GnomeGamesSupport.get_license(_("Same GNOME"));
	about_dialog.wrap_license = true;
	about_dialog.logo_icon_name = "gnome-samegnome";
	about_dialog.website = "http://www.gnome.org/projects/gnome-games/";
	about_dialog.website_label = _("GNOME Games web site"); // this doesn't work for anyone
	about_dialog.translator_credits = _("translator-credits");

	about_dialog.set_authors(["Tim Horton"]);
	about_dialog.set_artists(["Tim Horton"]);

	// TODO: some form of wrapper so we can use gtk_show_about_dialog instead
	// of faking all of its window-management-related stuff

	about_dialog.set_transient_for(main.window);
	about_dialog.run();
	
	about_dialog.hide();
}
