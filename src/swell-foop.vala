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

public class SwellFoop : Gtk.Application
{
    /* Application settings */
    private Settings settings;

    /* Main window */
    private SwellFoopWindow window;

    private Gtk.Dialog? preferences_dialog = null;

    /* Store size options */
    internal static Size [] sizes;
    class construct
    {
        sizes = {
            /* Translators: name of a possible size of the grid, as seen in the Preferences dialog “board size” combobox */
            { "small",  _("Small"),   6,  5 },

            /* Translators: name of a possible size of the grid, as seen in the Preferences dialog “board size” combobox */
            { "normal", _("Normal"), 15, 10 },

            /* Translators: name of a possible size of the grid, as seen in the Preferences dialog “board size” combobox */
            { "large",  _("Large"),  20, 15 }
        };
    }

    private const GLib.ActionEntry[] action_entries =
    {
        { "preferences",   preferences_cb },
        { "help",          help_cb        },
        { "about",         about_cb       },
        { "quit",          quit_cb        }
    };

    /* Constructor */
    public SwellFoop ()
    {
        Object (application_id: "org.gnome.SwellFoop", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void startup ()
    {
        base.startup ();

        Gtk.Settings.get_default ().@set ("gtk-application-prefer-dark-theme", true);

        settings = new Settings ("org.gnome.swell-foop");

        add_action_entries (action_entries, this);
        set_accels_for_action ("win.new-game",          { "<Primary>n"      });
        set_accels_for_action ("app.help",              {          "F1"     });
        set_accels_for_action ("win.toggle-hamburger",  {          "F10"    });
        set_accels_for_action ("app.quit",              { "<Primary>q"      });

        /* Create the main window */
        window = new SwellFoopWindow (this, settings);
        add_window (window);
    }

    protected override void shutdown ()
    {
        window.on_shutdown ();
        base.shutdown ();
    }

    protected override void activate ()
    {
        window.present ();
    }

    public inline void preferences_cb (/* SimpleAction action, Variant? variant */)
    {
        /* Show existing dialog */
        if (preferences_dialog != null)
        {
            preferences_dialog.present ();
            return;
        }

        var preferences_builder = new Gtk.Builder.from_resource ("/org/gnome/SwellFoop/ui/preferences.ui");

        preferences_dialog = (Gtk.Dialog) preferences_builder.get_object ("preferences");
        preferences_dialog.transient_for = window;
        preferences_dialog.modal = true;

        /* Theme */
        var theme_combo = (Gtk.ComboBox) preferences_builder.get_object ("theme-selector");
        var model = (Gtk.ListStore) theme_combo.model;
        Gtk.TreeIter iter;
        model.append (out iter);
        /* Translators: name of a possible theme, as seen in the Preferences dialog “theme” combobox */
        model.set (iter, 0, _("Colors"), 1, "colors", -1);
        if (settings.get_string ("theme") == "colors")
            theme_combo.set_active_iter (iter);
        model.append (out iter);
        /* Translators: name of a possible theme, as seen in the Preferences dialog “theme” combobox */
        model.set (iter, 0, _("Shapes and Colors"), 1, "shapesandcolors", -1);
        if (settings.get_string ("theme") == "shapesandcolors")
            theme_combo.set_active_iter (iter);

        /* Board size */
        var size_combo = (Gtk.ComboBox) preferences_builder.get_object ("size-selector");
        model = (Gtk.ListStore) size_combo.model;
        for (int i = 0; i < sizes.length; i++)
        {
            model.append (out iter);
            model.set (iter, 0, sizes[i].name, 1, sizes[i].id, -1);
            if (settings.get_string ("size") == sizes[i].id)
                size_combo.set_active_iter (iter);
        }

        /* Number of colors */
        ((Gtk.SpinButton) preferences_builder.get_object ("colors-spinner")).value = settings.get_int ("colors");

        /* Zealous moves */
        ((Gtk.CheckButton) preferences_builder.get_object ("zealous-checkbox")).active = settings.get_boolean ("zealous");

        preferences_builder.connect_signals (this);
        preferences_dialog.response.connect (preferences_response_cb);
        preferences_dialog.present ();
    }

    [CCode (cname = "G_MODULE_EXPORT select_theme", instance_pos = -1)]
    public void select_theme (Gtk.ComboBox theme_combo)
    {
        Gtk.TreeIter iter;
        if (!theme_combo.get_active_iter (out iter))
            return;
        string new_theme;
        theme_combo.model.get (iter, 1, out new_theme, -1);

        if (new_theme == settings.get_string ("theme"))
            return;

        settings.set_string ("theme", new_theme);

        window.set_theme_name (new_theme);
    }

    [CCode (cname = "G_MODULE_EXPORT set_zealous_animation", instance_pos = -1)]
    public void set_zealous_animation (Gtk.CheckButton button)
    {
        settings.set_boolean ("zealous", button.active);
        window.set_is_zealous (settings.get_boolean ("zealous"));
    }

    [CCode (cname = "G_MODULE_EXPORT update_size", instance_pos = -1)]
    public void update_size (Gtk.ComboBox size_combo)
    {
        Gtk.TreeIter iter;
        if (!size_combo.get_active_iter (out iter))
            return;
        string new_size;
        size_combo.model.get (iter, 1, out new_size, -1);

        if (new_size == settings.get_string ("size"))
            return;

        settings.set_string ("size", new_size);
        window.new_game ();
    }

    [CCode (cname = "G_MODULE_EXPORT update_colors", instance_pos = -1)]
    public void update_colors (Gtk.SpinButton button)
    {
        int new_colors = (int) button.get_value ();

        if (new_colors == settings.get_int ("colors"))
            return;

        settings.set_int ("colors", new_colors);
        window.new_game ();
    }

    private inline void preferences_response_cb ()
    {
        preferences_dialog.destroy ();
        preferences_dialog = null;
    }

    private inline void quit_cb (/* SimpleAction action, Variant? variant */)
    {
        window.destroy ();
    }

    private inline void help_cb (/* SimpleAction action, Variant? variant */)
    {
        try
        {
            Gtk.show_uri_on_window (window, "help:swell-foop", Gtk.get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
    }

    private inline void about_cb (/* SimpleAction action, Variant? variant */)
    {
        string[] authors = {
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

        Gtk.show_about_dialog (window,
                               /* Translators: About dialog text, name of the application */
                               "program-name", _("Swell Foop"),
                               "version", Config.VERSION,
                               "comments",
                               /* Translators: About dialog text, small description of the application */
                               _("I want to play that game!\nYou know, they all light-up and you click on them and they vanish!"),
                               "license-type", Gtk.License.GPL_2_0,
                               "authors", authors,
                               /* Translators: About dialog text, copyright line */
                               "copyright", _("Copyright \xc2\xa9 2009 Tim Horton"),
                               "artists", artists,
                               "documenters", documenters,
                               /* Translators: About dialog text, should be replaced with a credit for you and your team; do not translate literally! */
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "org.gnome.SwellFoop",
                               "website", Config.PACKAGE_URL);
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (Config.GETTEXT_PACKAGE, Config.LOCALEDIR);
        Intl.bind_textdomain_codeset (Config.GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (Config.GETTEXT_PACKAGE);

        if (GtkClutter.init (ref args) != Clutter.InitError.SUCCESS)
        {
            warning ("Failed to initialise Clutter");
            return Posix.EXIT_FAILURE;
        }

        var context = new OptionContext (null);
        context.set_translation_domain (Config.GETTEXT_PACKAGE);

        context.add_group (Gtk.get_option_group (true));
        context.add_group (Clutter.get_option_group_without_init ());

        try
        {
            context.parse (ref args);
        }
        catch (Error e)
        {
            stderr.printf ("%s\n", e.message);
            return Posix.EXIT_FAILURE;
        }

        /* Translators: name of the application, as displayed in the window manager */
        Environment.set_application_name (_("Swell Foop"));
        Gtk.Window.set_default_icon_name ("org.gnome.SwellFoop");

        var app = new SwellFoop ();
        return app.run (args);
    }
}

/* An array will store multiply game size options. */
private struct Size
{
    public string id;
    public string name;
    public int    columns;
    public int    rows;
}
