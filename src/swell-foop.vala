/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

using Config;

public class SwellFoop : Adw.Application
{
    /* Translators: name of the program, as seen in the headerbar, in GNOME Shell, or in the about dialog */
    private const string PROGRAM_NAME = _("Swell Foop");

    /* Main window */
    private SwellFoopWindow window;

    /* Command-line options */
    private const OptionEntry [] option_entries =
    {
        /* Translators: command-line option description, see 'swell-foop --help' */
        { "version", 'v', OptionFlags.NONE, OptionArg.NONE, null, N_("Print release version and exit"), null },

        {}
    };

    /* Actions */
    private const GLib.ActionEntry[] action_entries =
    {
        { "help",          help_cb        },
        { "about",         about_cb       },
        { "quit",          quit_cb        }
    };

    /* Constructor */
    public SwellFoop ()
    {
        Object (application_id: "org.gnome.SwellFoop", flags: ApplicationFlags.FLAGS_NONE);
        add_main_option_entries (option_entries);
    }

    protected override void startup ()
    {
        base.startup ();

        style_manager.color_scheme = FORCE_DARK;

        add_action_entries (action_entries, this);
        set_accels_for_action ("app.help",              {                 "F1"  });
        set_accels_for_action ("win.toggle-hamburger",  {                 "F10" });
        set_accels_for_action ("win.new-game",          {        "<Primary>n", "F2"});
        set_accels_for_action ("app.quit",              {        "<Primary>q"   });
        set_accels_for_action ("win.undo",              {        "<Primary>z"   });
        set_accels_for_action ("win.redo",              { "<Shift><Primary>z"   });
    }

    protected override int handle_local_options (GLib.VariantDict options)
    {
        if (options.contains ("version"))
        {
            stderr.printf ("%1$s %2$s\n", PROGRAM_NAME, Config.VERSION);
            return Posix.EXIT_SUCCESS;
        }
        return -1;
    }

    protected override void shutdown ()
    {
        if (window != null)
            window.close ();

        base.shutdown ();
    }

    protected override void activate ()
    {
        /* Create the main window */
        if (window == null)
            window = new SwellFoopWindow (this);

        window.present ();
    }

    private inline void quit_cb (/* SimpleAction action, Variant? variant */)
    {
        if (window != null)
            window.close ();
    }

    private inline void help_cb (/* SimpleAction action, Variant? variant */)
    {
#if GTK_5_0_or_above
        launch_help.begin ((obj,res)=>
        {
            launch_help.end (res);
        });
#else
        Gtk.show_uri (window, "help:swell-foop", Gdk.CURRENT_TIME);
#endif
    }

#if GTK_5_0_or_above
    async void launch_help ()
    {
        var help = new Gtk.UriLauncher ("help:swell-foop");
        try
        {
            yield help.launch (window, null);
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
    }
#endif

    private inline void about_cb (/* SimpleAction action, Variant? variant */)
    {
        string[] developers = {
            /* Translators: About dialog text, name of an author */
            _("Tim Horton"),


            /* Translators: About dialog text, name of an author */
            _("Sophia Yu")
        };
        string[] artists = {
            /* Translators: About dialog text, name of an artist */
            _("Tim Horton")
        };
        string[] documenters = {};

        Adw.show_about_dialog (window,
                               "application-icon", "org.gnome.SwellFoop",
                               "application-name", PROGRAM_NAME,
                               "developer-name", _("Swell Foop developers"),
                               "version", Config.VERSION,
                               "license-type", Gtk.License.GPL_2_0,
                               "developers", developers,
                               /* Translators: About dialog text, copyright line */
                               "copyright", _("Copyright \xc2\xa9 2009 Tim Horton"),
                               "artists", artists,
                               "documenters", documenters,
                               /* Translators: About dialog text, should be replaced with a credit for you and your team; do not translate literally! */
                               "translator-credits", _("translator-credits"),
                               "website", Config.PACKAGE_URL);
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
        Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (Config.GETTEXT_PACKAGE);

        Environment.set_application_name (PROGRAM_NAME);
        Gtk.Window.set_default_icon_name ("org.gnome.SwellFoop");

        var app = new SwellFoop ();
        return app.run (args);
    }
}
