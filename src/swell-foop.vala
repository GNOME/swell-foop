/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

public class SwellFoop : Gtk.Application
{
    /* Application settings */
    private Settings settings;

    /* Main window */
    private Gtk.Window window;

    /* Game history */
    private History history;

    /* Game being played */
    private Game? game = null;

    /* Rendering of game */
    private GameView view;

    private Clutter.Stage stage;
    private GtkClutter.Embed clutter_embed;

    private Gtk.Dialog? preferences_dialog = null;

    private Gtk.HeaderBar headerbar;

    /* Store size options */
    public Size[] sizes;

    private const GLib.ActionEntry[] action_entries =
    {
        { "new-game",      new_game_cb    },
        { "scores",        scores_cb      },
        { "preferences",   preferences_cb },
        { "help",          help_cb        },
        { "about",         about_cb       },
        { "quit",          quit_cb        }
    };

    /* Constructor */
    public SwellFoop ()
    {
        Object (application_id: "org.gnome.swell-foop", flags: ApplicationFlags.FLAGS_NONE);
    }

    protected override void startup ()
    {
        base.startup ();

        settings = new Settings ("org.gnome.swell-foop");

        add_action_entries (action_entries, this);
        add_accelerator ("<Primary>n", "app.new-game", null);
        add_accelerator ("F1", "app.help", null);
        add_accelerator ("<Primary>q", "app.quit", null);

        /* Create the main window */
        window = new Gtk.ApplicationWindow (this);
        window.set_title (_("Swell Foop"));
        window.icon_name = "swell-foop";
        window.resizable = false;
        window.set_events (window.get_events () | Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 0);
        vbox.show ();
        window.add (vbox);

        /* Create the menus */
        var menu = new Menu ();
        var section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_New Game"), "app.new-game");
        section.append (_("_Scores"), "app.scores");
        section.append (_("_Preferences"), "app.preferences");
        section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Help"), "app.help");
        section.append (_("_About"), "app.about");
        section.append (_("_Quit"), "app.quit");
        set_app_menu (menu);

        /* Create a headerbar */
        headerbar = new Gtk.HeaderBar ();
        headerbar.show ();
        headerbar.title = _("Swell Foop");
        headerbar.show_close_button = true;
        headerbar.show_fallback_app_menu = true;
        window.set_titlebar (headerbar);

        if (Gtk.Settings.get_default ().gtk_shell_shows_app_menu)
        {
            var new_game_button = new Gtk.Button ();
            new_game_button.valign = Gtk.Align.CENTER;
            new_game_button.label = _("_New");
            new_game_button.get_style_context ().add_class ("text-button");
            new_game_button.use_underline = true;
            new_game_button.action_name = "app.new-game";
            new_game_button.show ();
            headerbar.add (new_game_button);
        }

        /* show the current score */
        update_score_cb (0);

        /* Create a clutter renderer widget */
        clutter_embed = new GtkClutter.Embed ();
        clutter_embed.show ();
        vbox.pack_start (clutter_embed, true, true);

        stage = (Clutter.Stage) clutter_embed.get_stage ();
        stage.color = Clutter.Color.from_string ("#000000");  /* background color is black */

        /* Initialize the options for sizes */
        sizes = new Size[3];
        sizes[0] = { "small", _("Small"), 6, 5 };
        sizes[1] = { "normal", _("Normal"), 15, 10 };
        sizes[2] = { "large", _("Large"), 20, 15 };

        /* Create an instance of game with initial values for row, column and color */
        game = new Game (get_size ().rows, get_size ().columns, settings.get_int ("colors"));

        /* Game score change will be sent to the main window and show in the score label */
        game.update_score.connect (update_score_cb);
        game.complete.connect (complete_cb);

        /* Create an instance of game view. This follow the Model-View-Controller paradigm */
        view = new GameView ();
        /* Initialize the themes needed by actors */
        view.theme_name = settings.get_string ("theme");
        view.is_zealous = settings.get_boolean ("zealous");
        view.game = game;
        stage.add_actor (view);
        /* Request an appropriate size for the game view */
        stage.set_size (view.width, view.height);
        clutter_embed.set_size_request ((int) stage.width, (int) stage.height);

        /* When the mouse leaves the window we need to update the view */
        clutter_embed.leave_notify_event.connect (view.board_left_cb);

        history = new History (Path.build_filename (Environment.get_user_data_dir (), "swell-foop", "history"));
        history.load ();

        window.key_press_event.connect (key_press_event_cb);
    }

    private bool key_press_event_cb (Gtk.Widget widget, Gdk.EventKey event)
    {
        switch (event.keyval)
        {
            case Gdk.Key.F2:
                new_game ();
                break;
            case Gdk.Key.Up:
                view.cursor_move (0, 1);
                break;
            case Gdk.Key.Down:
                view.cursor_move (0, -1);
                break;
            case Gdk.Key.Left:
                view.cursor_move (-1, 0);
                break;
            case Gdk.Key.Right:
                view.cursor_move (1, 0);
                break;
            case Gdk.Key.space:
                view.cursor_click ();
                return true; //handle this one to avoid activating the toolbar button
            default:
                break;
        }

        return false;
    }

    private Size get_size ()
    {
        for (var i = 0; i < sizes.length; i++)
        {
            if (sizes[i].id == settings.get_string ("size"))
                return sizes[i];
        }

        return sizes[0];
    }

    private void update_score_cb (int points_awarded)
    {
        var score = 0;
        if (game != null)
            score = game.score;

        /* I left one more blank space at the end to make the score not too close to the window border */
        headerbar.subtitle = _("Score: %u ").printf (score);
    }

    private void complete_cb ()
    {
        var date = new DateTime.now_local ();
        var entry = new HistoryEntry (date, game.columns, game.rows, game.color_num, game.score);
        history.add (entry);
        history.save ();
    }

    protected override void shutdown ()
    {
        base.shutdown ();

        /* Record the score if the game isn't over. */
        if (game != null && !game.has_completed() && game.score > 0)
            complete_cb ();
    }

    protected override void activate ()
    {
        window.present ();
    }

    public void preferences_cb ()
    {
        /* Show existing dialog */
        if (preferences_dialog != null)
        {
            preferences_dialog.present ();
            return;
        }

        var preferences_builder = new Gtk.Builder ();
        try
        {
            preferences_builder.add_from_file (Path.build_filename (DATADIR, "preferences.ui", null));
        }
        catch (Error e)
        {
            warning ("Could not load preferences UI: %s", e.message);
        }

        preferences_dialog = (Gtk.Dialog) preferences_builder.get_object ("preferences");
        preferences_dialog.transient_for = window;
        preferences_dialog.modal = true;

        /* Theme */
        var theme_combo = preferences_builder.get_object ("theme-selector") as Gtk.ComboBox;
        var model = (Gtk.ListStore) theme_combo.model;
        Gtk.TreeIter iter;
        model.append (out iter);
        model.set (iter, 0, _("Colors"), 1, "colors", -1);
        if (settings.get_string ("theme") == "colors")
            theme_combo.set_active_iter (iter);
        model.append (out iter);
        model.set (iter, 0, _("Shapes and Colors"), 1, "shapesandcolors", -1);
        if (settings.get_string ("theme") == "shapesandcolors")
            theme_combo.set_active_iter (iter);

        /* Board size */
        var size_combo = preferences_builder.get_object ("size-selector") as Gtk.ComboBox;
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

        view.theme_name = new_theme;
    }

    [CCode (cname = "G_MODULE_EXPORT set_zealous_animation", instance_pos = -1)]
    public void set_zealous_animation (Gtk.CheckButton button)
    {
        settings.set_boolean ("zealous", button.active);
        view.is_zealous = settings.get_boolean ("zealous");
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
        new_game ();
    }

    [CCode (cname = "G_MODULE_EXPORT update_colors", instance_pos = -1)]
    public void update_colors (Gtk.SpinButton button)
    {
        int new_colors = (int) button.get_value();

        if (new_colors == settings.get_int ("colors"))
            return;

        settings.set_int ("colors", new_colors);
        new_game ();
    }

    private void preferences_response_cb ()
    {
        preferences_dialog.destroy ();
        preferences_dialog = null;
    }

    public void show ()
    {
        window.show ();
    }

    private void new_game_cb ()
    {
        new_game ();
    }

    private void scores_cb ()
    {
        var dialog = new ScoreDialog (history);
        dialog.modal = true;
        dialog.transient_for = window;

        dialog.run ();
        dialog.destroy ();
    }

    private void quit_cb ()
    {
        window.destroy ();
    }

    private void help_cb ()
    {
        try
        {
            Gtk.show_uri (window.get_screen (), "help:swell-foop", Gtk.get_current_event_time ());
        }
        catch (Error e)
        {
            warning ("Failed to show help: %s", e.message);
        }
    }

    private void about_cb ()
    {
        string[] authors = { "Tim Horton", "Sophia Yu", null };
        string[] artists = { "Tim Horton", null };
        string[] documenters = { null };

        Gtk.show_about_dialog (window,
                               "program-name", _("Swell Foop"),
                               "version", VERSION,
                               "comments",
                               _("I want to play that game!\nYou know, they all light-up and you click on them and they vanish!\n\nSwell Foop is a part of GNOME Games."),
                               "copyright", _("Copyright \xc2\xa9 2009 Tim Horton"),
                               "license-type", Gtk.License.GPL_2_0,
                               "authors", authors,
                               "artists", artists,
                               "documenters", documenters,
                               "translator-credits", _("translator-credits"),
                               "logo-icon-name", "swell-foop",
                               "website", "http://www.gnome.org/projects/gnome-games",
                               "website-label", _("GNOME Games web site"),
                               null);
    }

    public void new_game ()
    {
        game = new Game (get_size ().rows,
                         get_size ().columns,
                         settings.get_int ("colors"));
        game.update_score.connect (update_score_cb);
        game.complete.connect (complete_cb);
        view.theme_name = settings.get_string ("theme");
        view.game = game;
        view.is_zealous = settings.get_boolean ("zealous");

        stage.set_size (view.width, view.height);
        clutter_embed.set_size_request ( (int) stage.width, (int) stage.height);

        update_score_cb (0);
    }

    public static int main (string[] args)
    {
        Intl.setlocale (LocaleCategory.ALL, "");
        Intl.bindtextdomain (GETTEXT_PACKAGE, LOCALEDIR);
        Intl.bind_textdomain_codeset (GETTEXT_PACKAGE, "UTF-8");
        Intl.textdomain (GETTEXT_PACKAGE);

        if (GtkClutter.init (ref args) != Clutter.InitError.SUCCESS)
        {
            warning ("Failed to initialise Clutter");
            return Posix.EXIT_FAILURE;
        }

        var context = new OptionContext (null);
        context.set_translation_domain (GETTEXT_PACKAGE);

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

        Environment.set_application_name (_("Swell Foop"));

        Gtk.Window.set_default_icon_name ("swellfoop");

        var app = new SwellFoop ();
        return app.run (args);
    }
}

/* An array will store multiply game size options. */
public struct Size
{
    public string id;
    public string name;
    public int    columns;
    public int    rows;
}
