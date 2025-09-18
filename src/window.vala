/*
   This file is part of Swell-Foop.

   Copyright (C) 2020 Arnaud Bonatti <arnaud.bonatti@gmail.com>
   Copyright (C) 2023 Ben Corby

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

using Gtk; /* designed for Gtk 4, link with libgtk-4-dev or gtk4-devel */

[GtkTemplate (ui = "/org/gnome/SwellFoop/ui/swell-foop.ui")]
private class SwellFoopWindow : Adw.ApplicationWindow
{
    [GtkChild] private unowned Overlay      overlay;
    [GtkChild] private unowned Stack        stack;
    [GtkChild] private unowned Adw.WindowTitle window_title;
    [GtkChild] internal unowned MenuButton  hamburger_button;

    private AspectFrame aspect_frame;
    private Label score_label;
    private Label to_high_score_label;
    private Box game_over_box;


    private GLib.Settings settings;

    /* Game being played */
    private Game? game = null;

    /* Rendering of game */
    private GameView view;

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
        settings = new GLib.Settings ("org.gnome.SwellFoop");

        hamburger_button.get_popover ().closed.connect (() =>
        {
            if (null != view)
                set_focus (view);
        });

        add_action_entries (win_actions, this);
        add_action (settings.create_action ("size"));

        set_default_size (settings.get_int ("window-width"), settings.get_int ("window-height"));
        if (settings.get_boolean ("window-is-maximized"))
            maximize ();

        string theme = settings.get_string ("theme");
        if (theme != "colors" && theme != "shapesandcolors" && theme != "boringshapes")
            theme = "shapesandcolors";
        SimpleAction theme_action = (SimpleAction) lookup_action ("change-theme");
        theme_action.set_state (new Variant.@string (theme));

        int32 colors = settings.get_int ("colors"); // 2 <= colors <= 4, per schema file
        SimpleAction colors_action = (SimpleAction) lookup_action ("change-colors");
        colors_action.set_state (new Variant.@string (colors.to_string ()));

        init_scores ();

        /* Create a cairo view */
        view = new GameView ();
        Gtk.Settings.get_default ().bind_property ("gtk-enable-animations", view, "animated", BindingFlags.SYNC_CREATE);
        view.show ();
        Size size = get_board_size ();

        aspect_frame = new AspectFrame (0.5f, 0.5f, (float)size.columns/size.rows, false);
        aspect_frame.show ();
        aspect_frame.hexpand = true;
        aspect_frame.vexpand = true;
        aspect_frame.set_child (view);

        var first_run = settings.get_boolean ("first-run");

        var first_run_view = build_first_run_view ();
        game_over_box = build_game_over_view ();
        game_over_box.visible = false;
        overlay.add_overlay (game_over_box);

        stack.add_named (first_run_view, "first_run");
        stack.add_named (aspect_frame, "game");

        stack.set_visible_child_name (first_run ? "first_run" : "game");

        close_request.connect (()=>
        {
            settings.delay ();
            // window state
            int window_width;
            int window_height;
            get_default_size (out window_width, out window_height); 
            settings.set_int ("window-width", window_width);
            settings.set_int ("window-height", window_height);
            settings.set_boolean ("window-is-maximized", maximized);
            // game properties
            settings.set_value ("saved-game", game.get_saved_game ());
            settings.set_int ("colors", game.color_num);
            for (uint8 i = 0; i < sizes.length; i++)
                if (game.rows == sizes [i].rows && game.columns == sizes [i].columns)
                {
                    settings.set_string ("size", sizes [i].id);
                    break;
                }
            settings.apply ();
            return false;
        });
    }

    internal SwellFoopWindow (Gtk.Application application)
    {
        Object (application: application);

        new_game (settings.get_value ("saved-game"));
    }

    /*internal void add_keypress_handler (KeypressHandlerFunction handler)
    {
        keypress_handlers.push (handler);
    }*/

    private inline Widget build_first_run_view ()
    {
        Builder builder = new Builder.from_resource ("/org/gnome/SwellFoop/ui/first-run.ui");
        var page = (Adw.StatusPage) builder.get_object ("first_run_page");
        /* Translators: text appearing on the first-run screen; to test, run `gsettings set org.gnome.SwellFoop first-run true` before launching application */
        page.set_description (_("Clear as many blocks as you can.\nFewer clicks means more points."));
        var play_button = (Button) builder.get_object ("play_button");
        play_button.clicked.connect (() => {
            stack.set_visible_child_name ("game");
            settings.set_boolean ("first-run", false);
        });
        return page;
    }

    private inline Box build_game_over_view ()
    {
        Builder builder = new Builder.from_resource ("/org/gnome/SwellFoop/ui/game-over.ui");
        var box = (Box) builder.get_object ("game_over");
        
        score_label = (Label) builder.get_object ("score_label");
        to_high_score_label = (Label) builder.get_object ("to_high_score_label");

        var play_button = (Button) builder.get_object ("play_button");
        play_button.clicked.connect (() => {
            box.set_visible (false);
        });
        return box;
    }

    /*\
    * * various
    \*/

    private void update_score_cb ()
    {
        if (game != null && game.is_started) {
            uint score = game.score;
            window_title.subtitle = _("Score: %u").printf(score);
        } else {
            window_title.subtitle = "";
        }
    }

    private void complete_cb ()
    {
        undo_action.set_enabled (false);
        string id = @"$(get_board_size ().id)-$(game.color_num)";
        Games.Scores.Category? category = score_categories.lookup (id);
        if (category == null)
            assert_not_reached ();

        Idle.add (() => { add_score (category); return Source.REMOVE; });

        /* Translators: the text for the score total shown on the game over screen */
        score_label.set_label (_("%u Points").printf(game.score));

        var scores = scores_context.get_high_scores (category);
        var lowest_high_score = (scores.size == 10 ? scores.last ().score : -1);

        if (lowest_high_score != -1 && lowest_high_score > game.score) {
            /* Translators: the text for the high score goal shown on the game over screen */
            to_high_score_label.set_label (_("%u points to reach the leaderboard").printf ((uint)lowest_high_score));
            to_high_score_label.visible = true;
        } else {
            to_high_score_label.visible = false;
        }

        game_over_box.visible = true;

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
        aspect_frame.set_ratio ((float)size.columns/size.rows);
        game = new Game (size.rows,
                         size.columns,
                         (uint8) settings.get_int ("colors"),
                         view,
                         saved_game);
        update_score_cb ();

        /* Game score change will be sent to the main window and show in the score label */
        game.update_score.connect (update_score_cb);
        game.complete.connect (complete_cb);
        game.started.connect (update_score_cb);

        /* Initialize the view */
        view.set_theme_name (settings.get_string ("theme"));
        view.set_game ((!) game);
        game_over_box.visible = false;

        /* Update undo and redo actions states */
        undo_action = (SimpleAction) lookup_action ("undo");
        game.bind_property ("can-undo", undo_action, "enabled", BindingFlags.SYNC_CREATE);

        redo_action = (SimpleAction) lookup_action ("redo");
        game.bind_property ("can-redo", redo_action, "enabled", BindingFlags.SYNC_CREATE);
        view.grab_focus ();
    }

    /*\
    * * actions
    \*/

    private inline void change_theme_cb (SimpleAction action, Variant? variant)
        requires (variant != null)
    {
        string new_theme = ((!) variant).get_string ();
        action.set_state ((!) variant);
        view.set_theme_name (new_theme);
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
        scores_context.present_dialog ();
    }

    private inline void new_game_cb (/* SimpleAction action, Variant? variant */)
    {
        if (game.is_started)
            show_new_game_confirmation_dialog.begin ();
        else
            new_game ();
    }

    private async void show_new_game_confirmation_dialog ()
    {
        var dialog = new Adw.AlertDialog(
                                         /* Translators: heading of a Dialog that may appear if you start a new game while one is running */
                                         _("Start New Game?"),
                                         /* Translators: text of a Dialog that may appear if you start a new game while one is running */
                                         _("Abandon this game to start a new one?"));

        dialog.add_responses ("cancel",
                              /* Translators: text of one of the two buttons of a Dialog that appears if you start a new game while one is running; the other is “_New Game” */
                              _("_Cancel"),
                              "new",
                              /* Translators: text of one of the two buttons of a Dialog that appears if you start a new game while one is running; the other is “_Cancel” */
                              _("_New Game"),
                              null
        );
        dialog.default_response = "new";
        dialog.close_response = "cancel";

        dialog.set_response_appearance ("new", SUGGESTED);

        var response = yield dialog.choose (this, null);

        if (response == "new")
            new_game ();
    }

    private inline void toggle_hamburger (/* SimpleAction action, Variant? variant */)
    {
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
        scores_context = new Games.Scores.Context (
            "swell-foop",
            /* Translators: in the Scores dialog, label introducing for which board configuration (size and number of colors) the best scores are displayed */
            _("Type"),
            this,
            category_request,
            Games.Scores.Style.POINTS_GREATER_IS_BETTER,
            "org.gnome.SwellFoop");
    }

    private inline Games.Scores.Category? category_request (string key)
    {
        Games.Scores.Category? category = score_categories.lookup (key);
        if (category == null)
            assert_not_reached ();
        return (!) category;
    }

    private inline void add_score (Games.Scores.Category category)
    {
        scores_context.add_score.begin (game.score,
                                        (!) category,
                                        /* cancellable */ null,
                                        (object, result) =>
            {
                try
                {
                    scores_context.add_score.end (result);
                }
                catch (Error e)
                {
                    warning ("Failed to add score: %s", e.message);
                }
            });
    }
}

