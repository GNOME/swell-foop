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

    private Gtk.Label current_score_label;

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

        /* Create the main window */
        window = new Gtk.ApplicationWindow (this);
        window.set_title (_("Swell Foop"));
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
        section = new Menu ();
        menu.append_section (null, section);
        section.append (_("_Quit"), "app.quit");
        set_app_menu (menu);

        /* Create a toolbar */
        var toolbar = new Gtk.Toolbar ();
        toolbar.show_arrow = false;
        toolbar.get_style_context ().add_class (Gtk.STYLE_CLASS_PRIMARY_TOOLBAR);
        toolbar.show ();
        vbox.pack_start (toolbar, false, true, 0);

        var new_game_button = new Gtk.ToolButton (null, "_New");
        new_game_button.icon_name = "document-new";
        new_game_button.use_underline = true;
        new_game_button.action_name = "app.new-game";
        new_game_button.is_important = true;
        new_game_button.show ();
        toolbar.insert (new_game_button, -1);

        /* Create a label in toolbar showing the score etc. */
        var status_box = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 10);
        status_box.halign = Gtk.Align.END;
        status_box.valign = Gtk.Align.CENTER;
        status_box.show ();

        /* show the current score */
        current_score_label = new Gtk.Label ("");
        current_score_label.show ();
        status_box.pack_start (current_score_label, false, false, 0);
        update_score_cb (0);

        var status_item = new Gtk.ToolItem ();
        status_item.set_expand (true);
        status_item.add (status_box);
        status_item.show ();

        toolbar.insert (status_item, -1);

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
            case Clutter.Key.space:
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
        current_score_label.set_text (_("Score: %4u ").printf (score));
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

        var license = "Swell Foop is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or (at your option) any later version.\n\nSwell Foop is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.\n\nYou should have received a copy of the GNU General Public License along with Swell Foop; if not, write to the Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA";

        Gtk.show_about_dialog (window,
                               "program-name", _("Swell Foop"),
                               "version", VERSION,
                               "comments",
                               _("I want to play that game! You know, they all light-up and you click on them and they vanish!\n\nSwell Foop is a part of GNOME Games."),
                               "copyright", _("Copyright \xc2\xa9 2009 Tim Horton"),
                               "license", license,
                               "wrap-license", true,
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

        var context = new OptionContext ("");
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

public class ScoreDialog : Gtk.Dialog
{
    private History history;
    private HistoryEntry? selected_entry = null;
    private Gtk.ListStore size_model;
    private Gtk.ListStore score_model;
    private Gtk.ComboBox size_combo;

    public ScoreDialog (History history, HistoryEntry? selected_entry = null, bool show_quit = false)
    {
        this.history = history;
        history.entry_added.connect (entry_added_cb);
        this.selected_entry = selected_entry;

        if (show_quit)
        {
            add_button (Gtk.Stock.QUIT, Gtk.ResponseType.CLOSE);
            add_button (_("New Game"), Gtk.ResponseType.OK);
        }
        else
            add_button (Gtk.Stock.OK, Gtk.ResponseType.DELETE_EVENT);
        set_size_request (200, 300);

        var vbox = new Gtk.Box (Gtk.Orientation.VERTICAL, 5);
        vbox.border_width = 6;
        vbox.show ();
        get_content_area ().pack_start (vbox, true, true, 0);

        var hbox = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
        hbox.show ();
        vbox.pack_start (hbox, false, false, 0);

        var label = new Gtk.Label (_("Size:"));
        label.show ();
        hbox.pack_start (label, false, false, 0);

        size_model = new Gtk.ListStore (4, typeof (string), typeof (int), typeof (int), typeof (int));

        size_combo = new Gtk.ComboBox ();
        size_combo.changed.connect (size_changed_cb);
        size_combo.model = size_model;
        var renderer = new Gtk.CellRendererText ();
        size_combo.pack_start (renderer, true);
        size_combo.add_attribute (renderer, "text", 0);
        size_combo.show ();
        hbox.pack_start (size_combo, true, true, 0);

        var scroll = new Gtk.ScrolledWindow (null, null);
        scroll.shadow_type = Gtk.ShadowType.ETCHED_IN;
        scroll.set_policy (Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC);
        scroll.show ();
        vbox.pack_start (scroll, true, true, 0);

        score_model = new Gtk.ListStore (3, typeof (string), typeof (string), typeof (int));

        var scores = new Gtk.TreeView ();
        renderer = new Gtk.CellRendererText ();
        scores.insert_column_with_attributes (-1, _("Date"), renderer, "text", 0, "weight", 2);
        renderer = new Gtk.CellRendererText ();
        renderer.xalign = 1.0f;
        scores.insert_column_with_attributes (-1, _("Score"), renderer, "text", 1, "weight", 2);
        scores.model = score_model;
        scores.show ();
        scroll.add (scores);

        foreach (var entry in history.entries)
            entry_added_cb (entry);
    }

    public void set_size (uint width, uint height, uint n_colors)
    {
        score_model.clear ();

        var entries = history.entries.copy ();
        entries.sort (compare_entries);

        foreach (var entry in entries)
        {
            if (entry.width != width || entry.height != height || entry.n_colors != n_colors)
                continue;

            var date_label = entry.date.format ("%d/%m/%Y");

            var score_label = "%u".printf (entry.score);

            int weight = Pango.Weight.NORMAL;
            if (entry == selected_entry)
                weight = Pango.Weight.BOLD;

            Gtk.TreeIter iter;
            score_model.append (out iter);
            score_model.set (iter, 0, date_label, 1, score_label, 2, weight);
        }
    }

    private static int compare_entries (HistoryEntry a, HistoryEntry b)
    {
        if (a.width != b.width)
            return (int) a.width - (int) b.width;
        if (a.height != b.height)
            return (int) a.height - (int) b.height;
        if (a.n_colors != b.n_colors)
            return (int) a.n_colors - (int) b.n_colors;
        if (a.score != b.score)
            return (int) a.score - (int) b.score;
        return a.date.compare (b.date);
    }

    private void size_changed_cb (Gtk.ComboBox combo)
    {
        Gtk.TreeIter iter;
        if (!combo.get_active_iter (out iter))
            return;

        int width, height, n_colors;
        combo.model.get (iter, 1, out width, 2, out height, 3, out n_colors);
        set_size ((uint) width, (uint) height, (uint) n_colors);
    }

    private void entry_added_cb (HistoryEntry entry)
    {
        /* Ignore if already have an entry for this */
        Gtk.TreeIter iter;
        var have_size_entry = false;
        if (size_model.get_iter_first (out iter))
        {
            do
            {
                int width, height, n_colors;
                size_model.get (iter, 1, out width, 2, out height, 3, out n_colors);
                if (width == entry.width && height == entry.height && n_colors == entry.n_colors)
                {
                    have_size_entry = true;
                    break;
                }
            } while (size_model.iter_next (ref iter));
        }

        if (!have_size_entry)
        {
            var label = ngettext ("%u × %u, %u color", "%u × %u, %u colors", entry.n_colors).printf (entry.width, entry.height, entry.n_colors);

            size_model.append (out iter);
            size_model.set (iter, 0, label, 1, entry.width, 2, entry.height, 3, entry.n_colors);
    
            /* Select this entry if don't have any */
            if (size_combo.get_active () == -1)
                size_combo.set_active_iter (iter);

            /* Select this entry if the same category as the selected one */
            if (selected_entry != null && entry.width == selected_entry.width && entry.height == selected_entry.height && entry.n_colors == selected_entry.n_colors)
                size_combo.set_active_iter (iter);
        }
    }
}
