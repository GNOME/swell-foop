/*
   This file is part of Swell-Foop.

   Copyright (C) 2020 Arnaud Bonatti <arnaud.bonatti@gmail.com>

   Swell-Foop is free software: you can redistribute it and/or modify
   it under the terms of the GNU General Public License as published by
   the Free Software Foundation, either version 2 of the License, or
   (at your option) any later version.

   Swell-Foop is distributed in the hope that it will be useful,
   but WITHOUT ANY WARRANTY; without even the implied warranty of
   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
   GNU General Public License for more details.

   You should have received a copy of the GNU General Public License
   along with Swell-Foop.  If not, see <https://www.gnu.org/licenses/>.
*/

using Gtk;

[GtkTemplate (ui = "/org/gnome/SwellFoop/ui/swell-foop.ui")]
private class SwellFoopWindow : ApplicationWindow
{
    [GtkChild] private HeaderBar    headerbar;
    [GtkChild] private Box          main_box;
    [GtkChild] private MenuButton   hamburger_button;

    private GLib.Settings settings;

    /* Game being played */
    private Game? game = null;

    /* Rendering of game */
    private GameView view;

    private bool game_in_progress = false;

    /* Store size options */
    private struct Size
    {
        public string id;
        public string name;
        public uint8  columns;
        public uint8  rows;
    }
    private static Size [] sizes;
    private static inline void class_init_sizes ()     // called on class construct
    {
        sizes = {
            /* Translators: name of a possible size of the grid */
            { "small",  _("Small"),   6,  5 },

            /* Translators: name of a possible size of the grid */
            { "normal", _("Normal"), 15, 10 },

            /* Translators: name of a possible size of the grid */
            { "large",  _("Large"),  20, 15 }
        };
    }

    class construct
    {
        class_init_sizes ();
        class_init_scores ();
    }

    private const GLib.ActionEntry[] win_actions =
    {
        { "change-theme",       null,       "s", "'shapesandcolors'",   change_theme_cb     },  // cannot be done via create_action as long as it’s an open form
        { "change-colors",      null,       "s", "'3'",                 change_colors_cb    },  // cannot be done via create_action because it’s an int
        { "new-game",           new_game_cb         },
        { "scores",             scores_cb           },
        { "toggle-hamburger",   toggle_hamburger    },

        { "undo",               undo                },
        { "redo",               redo                }
    };

    construct
    {
        CssProvider css_provider = new CssProvider ();
        css_provider.load_from_resource ("/org/gnome/SwellFoop/ui/swell-foop.css");
        Gdk.Display? gdk_display = Gdk.Display.get_default ();
        if (gdk_display != null) // else..?
            StyleContext.add_provider_for_display ((!) gdk_display, css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        settings = new GLib.Settings ("org.gnome.SwellFoop");

        add_action_entries (win_actions, this);
        add_action (settings.create_action ("size"));

        add_action (settings.create_action ("zealous"));
        settings.changed ["zealous"].connect ((_settings, _key_name) => { view.set_is_zealous (_settings.get_boolean (_key_name)); });

        settings.changed ["theme"].connect (load_theme);
        load_theme (settings, "theme");

        int32 colors = settings.get_int ("colors"); // 2 <= colors <= 4, per schema file
        SimpleAction colors_action = (SimpleAction) lookup_action ("change-colors");
        colors_action.set_state (new Variant.@string (colors.to_string ()));

        init_scores ();

        /* show the current score */
        update_score_cb ();

        /* Create a clutter renderer widget */
        view = new GameView ();
        view.show ();
        var first_run = settings.get_boolean ("first-run");

        if (first_run)
        {
            var stack = build_first_run_stack ();
            stack.add_named (view, "game");
            main_box.append (stack);
        }
        else
        {
            main_box.append (view);
            init_keyboard ();
        }
    }

    internal SwellFoopWindow (Gtk.Application application)
    {
        Object (application: application);

        new_game (settings.get_value ("saved-game"));

        init_motion ();
    }

    private inline Stack build_first_run_stack ()
    {
        Builder builder = new Builder.from_resource ("/org/gnome/SwellFoop/ui/first-run-stack.ui");
        var stack = (Stack) builder.get_object ("first_run_stack");
        var tip_label = (Label) builder.get_object ("tip_label");
        /* Translators: text appearing on the first-run screen; to test, run `gsettings set org.gnome.SwellFoop first-run true` before launching application */
        tip_label.set_label (_("Clear as many blocks as you can.\nFewer clicks means more points."));
        var play_button = (Button) builder.get_object ("play_button");
        play_button.clicked.connect (() => {
            /* FIXME: Currently, on Wayland, the game frame is displayed outside
             * the window if there's a transition set. Uncomment these 2 lines
             * when that's no longer a problem.
             */
              stack.set_transition_type (StackTransitionType.SLIDE_UP);
              stack.set_transition_duration (500);
             /* */
            stack.set_visible_child_name ("game");
            init_keyboard ();
            settings.set_boolean ("first-run", false);
        });
        return stack;
    }

    /*\
    * * various
    \*/

    private void update_score_cb ()
    {
        uint score = 0;
        if (game != null)
            score = game.score;

        /* Translators: subtitle of the headerbar; the %u is replaced by the score */
//        headerbar.subtitle = _("Score: %u").printf (score);
    }

    private void complete_cb ()
    {
        undo_action.set_enabled (false);
        Idle.add (() => { add_score (); return Source.REMOVE; });
        game_in_progress = false;
    }

    private inline void started_cb ()
    {
        game_in_progress = true;
    }

    private Size get_board_size ()
    {
        string current_size = settings.get_string ("size");
        for (var i = 0; i < sizes.length; i++)
        {
            if (sizes [i].id == current_size)
                return sizes [i];
        }

        return sizes [0];
    }

    /*\
    * * various calls
    \*/

    // for keeping in memory
    private SimpleAction undo_action;
    private SimpleAction redo_action;

    private void new_game (Variant? saved_game = null)
    {
        Size size = get_board_size ();
        game = new Game (size.rows,
                         size.columns,
                         (uint8) settings.get_int ("colors"),
                         saved_game);
        game_in_progress = game.score != 0;
        update_score_cb ();

        /* Game score change will be sent to the main window and show in the score label */
        game.update_score.connect (update_score_cb);
        game.complete.connect (complete_cb);
        game.started.connect (started_cb);

        /* Initialize the themes needed by actors */
        view.set_is_zealous (settings.get_boolean ("zealous"));
        view.set_game ((!) game);

        /* Update undo and redo actions states */
        undo_action = (SimpleAction) lookup_action ("undo");
        game.bind_property ("can-undo", undo_action, "enabled", BindingFlags.SYNC_CREATE);

        redo_action = (SimpleAction) lookup_action ("redo");
        game.bind_property ("can-redo", redo_action, "enabled", BindingFlags.SYNC_CREATE);
    }

//    protected override void destroy ()
//    {
//        settings.delay ();
//        settings.set_value ("saved-game", game.get_saved_game ());
//        settings.set_int ("colors", game.color_num);
//        for (uint8 i = 0; i < sizes.length; i++)
//            if (game.rows == sizes [i].rows && game.columns == sizes [i].columns)
//            {
//                settings.set_string ("size", sizes [i].id);
//                break;
//            }
//        settings.apply ();
//
//        base.destroy ();
//    }

    /*\
    * * actions
    \*/

    private inline void change_theme_cb (SimpleAction action, Variant? variant)
        requires (variant != null)
    {
        string new_theme = ((!) variant).get_string ();
        action.set_state ((!) variant);
        if (settings.get_string ("theme") != new_theme)
            settings.set_string ("theme", new_theme);
    }

    private inline void change_colors_cb (SimpleAction action, Variant? variant)
        requires (variant != null)
    {
        int32 new_colors = (int32) int.parse (((!) variant).get_string ());
        action.set_state ((!) variant);
        if (settings.get_int ("colors") != new_colors)
            settings.set_int ("colors", new_colors);
    }

    private inline void scores_cb (/* SimpleAction action, Variant? variant */)
    {
        scores_context.run_dialog ();
    }

    private inline void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        if (game_in_progress)
            show_new_game_confirmation_dialog ();
        else
            new_game ();
    }

    private inline void show_new_game_confirmation_dialog ()
    {
        var dialog = new MessageDialog.with_markup (this,
                                                    DialogFlags.MODAL,
                                                    MessageType.QUESTION,
                                                    ButtonsType.NONE,
                                                    "<span weight=\"bold\" size=\"larger\">%s</span>",
                                                    /* Translators: text of a Dialog that may appear if you start a new game while one is running */
                                                    _("Abandon this game to start a new one?"));

        /* Translators: text of one of the two buttons of a Dialog that appears if you start a new game while one is running; the other is “_New Game” */
        dialog.add_button (_("_Cancel"),    ResponseType.CANCEL);

        /* Translators: text of one of the two buttons of a Dialog that appears if you start a new game while one is running; the other is “_Cancel” */
        dialog.add_button (_("_New Game"),  ResponseType.YES);

        dialog.present ();
        dialog.response.connect (on_confirmation_response);

    }

    private inline void on_confirmation_response (Gtk.Widget dialog, int result)
    {
        dialog.destroy ();
        if (result == ResponseType.YES)
            new_game ();
    }

    private inline void toggle_hamburger (/* SimpleAction action, Variant? variant */)
    {
//        hamburger_button.active = !hamburger_button.active;
        hamburger_button.popup ();    // TODO toggle
    }

    private inline void undo (/* SimpleAction action, Variant? variant */)
    {
        game.undo ();
    }

    private inline void redo (/* SimpleAction action, Variant? variant */)
    {
        game.redo ();
    }

    /*\
    * * keyboard
    \*/

    private EventControllerKey key_controller;          // for keeping in memory

    private inline void init_keyboard ()
    {
        key_controller = new EventControllerKey ();
        key_controller.key_pressed.connect (on_key_pressed);
        ((Widget) this).add_controller (key_controller);
    }

    private inline bool on_key_pressed (EventControllerKey _key_controller, uint keyval, uint keycode, Gdk.ModifierType state)
    {
//        if (hamburger_button.get_active())
//            return false;

        switch (keyval)
        {
            case Gdk.Key.F2:
                new_game ();
                break;

            case Gdk.Key.Up:
                view.cursor_move ( 0,  1);
                break;
            case Gdk.Key.Down:
                view.cursor_move ( 0, -1);
                break;
            case Gdk.Key.Left:
                view.cursor_move (-1,  0);
                break;
            case Gdk.Key.Right:
                view.cursor_move ( 1,  0);
                break;

            case Gdk.Key.space:
            case Gdk.Key.Return:
                view.cursor_click ();
                return true; //handle this one to avoid activating the toolbar button

            default:
                break;
        }

        return false;
    }

    /*\
    * * scores
    \*/

    private Games.Scores.Context scores_context;
    private static HashTable<string, Games.Scores.Category> score_categories;

    private static inline void class_init_scores ()    // called on class construct
    {
        score_categories = new HashTable<string, Games.Scores.Category> (str_hash, str_equal);
        for (uint8 i = 2; i <= 4; i++)
            foreach (unowned Size size in sizes)
            {
                string id = @"$(size.id)-$i";
                string name = ngettext ("%s, %d color", "%s, %d colors", i).printf (size.name, i);
                Games.Scores.Category category = new Games.Scores.Category (id, name);
                score_categories.insert (id, (owned) category);
            }
    }

    private inline void init_scores ()  // called on construct
    {
        scores_context = new Games.Scores.Context.with_importer_and_icon_name (
            "swell-foop",
            /* Translators: in the Scores dialog, label introducing for which board configuration (size and number of colors) the best scores are displayed */
            _("Type"),
            this,
            category_request,
            Games.Scores.Style.POINTS_GREATER_IS_BETTER,
            new Games.Scores.HistoryFileImporter (parse_old_score),
            "org.gnome.SwellFoop");
    }

    private inline Games.Scores.Category? category_request (string key)
    {
        Games.Scores.Category? category = score_categories.lookup (key);
        if (category == null)
            assert_not_reached ();
        return (!) category;
    }

    private inline void parse_old_score (string line, out Games.Scores.Score? score, out Games.Scores.Category? category)
    {
        score = null;
        category = null;

        string [] tokens = line.split (" ");
        if (tokens.length != 5)
            return;

        int64 date = Games.Scores.HistoryFileImporter.parse_date (tokens [0]);
        if (date == 0)
            return;

        uint64 number_64;

        uint8 cols;
        uint8 rows;
        // cols
        if (!uint64.try_parse (tokens [1], out number_64))
            return;
        if (number_64 == 0 || number_64 > 255)
            return;
        cols = (uint8) number_64;
        // rows
        if (!uint64.try_parse (tokens [2], out number_64))
            return;
        if (number_64 == 0 || number_64 > 255)
            return;
        rows = (uint8) number_64;

        string id = "";
        foreach (unowned Size size in sizes)
        {
            if (size.rows == rows && size.columns == cols)
            {
                id = size.id;
                break;
            }
        }
        if (id == "")
            return;

        uint8 colors;
        long score_value;
        // colors
        if (!uint64.try_parse (tokens [3], out number_64))
            return;
        if (number_64 < 2 || number_64 > 4)
            return;
        colors = (uint8) number_64;
        // score
        if (!uint64.try_parse (tokens [4], out number_64))
            return;
        if (number_64 > long.MAX)
            return;
        score_value = (long) number_64;

        category = category_request (@"$id-$colors");
        score = new Games.Scores.Score (score_value, date);
        score.user = Environment.get_real_name ();
        if (score.user == "Unknown")
            score.user = Environment.get_user_name ();
    }

    private inline void add_score ()
    {
        string id = @"$(get_board_size ().id)-$(game.color_num)";
        Games.Scores.Category? category = score_categories.lookup (id);
        if (category == null)
            assert_not_reached ();
        scores_context.add_score.begin (game.score,
                                        (!) category,
                                        /* cancellable */ null,
                                        (object, result) => {
                try
                {
                    scores_context.add_score.end (result);
                }
                catch (Error e)
                {
                    warning ("Failed to add score: %s", e.message);
                }
                scores_context.run_dialog ();
            });
    }

    /*\
    * * motion control
    \*/

    private EventControllerMotion motion_controller;    // for keeping in memory

    private inline void init_motion ()
    {
        motion_controller = new EventControllerMotion ();
        motion_controller.set_propagation_phase (PropagationPhase.CAPTURE);
        motion_controller.leave.connect (view.board_left_cb);
        view.add_controller (motion_controller);
    }

    /*\
    * * theme
    \*/

    private bool icon_theme_added = false;

    private void load_theme (GLib.Settings _settings, string _key_name)
    {
        string theme = _settings.get_string (_key_name);
        if (theme != "colors" && theme != "shapesandcolors" && theme != "boringshapes")
            theme = "shapesandcolors";
        set_game_theme (theme);
        SimpleAction theme_action = (SimpleAction) lookup_action ("change-theme");
        theme_action.set_state (new Variant.@string (theme));
    }

    private inline void set_game_theme (string theme_name)
    {
        string theme_path = Path.build_filename (Config.DATADIR, "themes", theme_name);

        if (!icon_theme_added)
        {
            IconTheme.get_for_display (Gdk.Display.get_default ()).add_search_path (theme_path);
            icon_theme_added = true;
        }
        else
        {
            IconTheme icon_theme = IconTheme.get_for_display (Gdk.Display.get_default ());
            string[] icon_search_path = icon_theme.get_search_path ();
            icon_search_path[icon_search_path.length - 1] = theme_path;
            icon_theme.set_search_path (icon_search_path);
        }

        queue_draw ();
    }
}
