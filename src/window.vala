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

delegate bool KeypressHandlerFunction (uint a, uint b, out bool remove_handler);

[GtkTemplate (ui = "/org/gnome/SwellFoop/ui/swell-foop.ui")]
private class SwellFoopWindow : ApplicationWindow
{
    [GtkChild] private unowned Overlay      overlay;
    [GtkChild] private unowned Stack        stack;
    [GtkChild] internal unowned MenuButton  hamburger_button;

    private AspectFrame aspect_frame;
    private Label score_label;
    private Label to_high_score_label;
    private Box game_over_box;
    private Label current_score_label;

    private GLib.Settings settings;

    /* keyboard interface */
    class DelegateStack 
    {
        internal class DelegateStackIterator
        {
            /* variables */
            private Node? pIterator; /* pointer to next node */
            bool first_next;

            /* public functions */
            public DelegateStackIterator (DelegateStack p)
            {
                pIterator = p.pHead;
                first_next = true;
            }
            
            public bool next ()
            {
                if (pIterator == null)
                    return false;
                else if (first_next)
                {
                    first_next = !first_next;
                    return true;
                }
                else
                {
                    pIterator = pIterator.pNext;
                    return pIterator != null; 
                }
            }
            
            public KeypressHandlerFunction @get ()
            {
                return (KeypressHandlerFunction)(pIterator.keypress_handler);
            }
        }

        struct Node
        {
            KeypressHandlerFunction keypress_handler; /* to do, circumnavigate compiler warning message */
            Node? pNext;
        }
        Node? pHead = null;

        internal void push (KeypressHandlerFunction handler)
        {
            if (pHead == null)
                pHead = { (KeypressHandlerFunction)handler, null};
            else
                pHead = { (KeypressHandlerFunction)handler, pHead};
        }
        /*
        internal bool pop ()
        {
            if (pHead == null)
                return false;
            else
            {
                pHead = pHead.pNext;
                return true;
            }
        }
        */
        internal void remove (KeypressHandlerFunction handler)
        {
            if (pHead != null && pHead.keypress_handler == handler)
                pHead = pHead.pNext;
            else if (pHead != null && pHead.pNext != null)
            {
                var pTrail = pHead;
                for (var p = pTrail.pNext; p != null;)
                {
                    if (p.keypress_handler == handler)
                    {
                        pTrail.pNext = p.pNext;
                        break;
                    }
                    else
                    {
                         pTrail = p;
                         p = p.pNext;
                    }
                }
            }
        }

        public DelegateStackIterator iterator ()
        {
            return new DelegateStackIterator (this);
        }
    }
    DelegateStack keypress_handlers = new DelegateStack ();

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

        EventControllerKey key_controller = new EventControllerKey ();
        key_controller.key_pressed.connect ((/*EventControllerKey*/controller,/*uint*/keyval,/*uint*/keycode,/*Gdk.ModifierType*/state)=>
        {
            DelegateStack handlers_to_remove = new DelegateStack ();
            foreach (var handler in keypress_handlers)
            {
                bool remove_handler;
                bool r = handler (keyval, keycode, out remove_handler);
                if (remove_handler)
                    handlers_to_remove.push (handler);
                if (r)
                {
                    /* remove any handlers that need to be removed before we return */
                    foreach (var h in handlers_to_remove)
                        keypress_handlers.remove (h);
                    return r;
                }
            }
            /* remove any handlers that need to be removed before we return */
            foreach (var handler in handlers_to_remove)
                keypress_handlers.remove (handler);
            return false;
        });
        ((Widget)(this)).add_controller (key_controller);
        keypress_handlers.push (keypress);

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
        add_keypress_handler (view.keypress);
        view.show ();
        Size size = get_board_size ();

        aspect_frame = new AspectFrame (0.5f, 0.5f, (float)size.columns/size.rows, false);
        aspect_frame.show ();
        aspect_frame.hexpand = true;
        aspect_frame.vexpand = true;
        aspect_frame.set_child (view);

        var first_run = settings.get_boolean ("first-run");

        CssProvider css_provider = new CssProvider ();
        css_provider.load_from_resource ("/org/gnome/SwellFoop/ui/swell-foop.css");
        Gdk.Display? gdk_screen = Gdk.Display.get_default ();
        if (gdk_screen != null) // else..?
            StyleContext.add_provider_for_display ((!) gdk_screen, css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        var first_run_view = build_first_run_view ();
        game_over_box = build_game_over_view ();
        game_over_box.visible = false;
        overlay.add_overlay (game_over_box);

        current_score_label = new Label ("123456");
        current_score_label.visible = true;
        current_score_label.use_markup = true;
        current_score_label.valign = Align.START;
        
        current_score_label.set_css_classes ({"score"});
        overlay.add_overlay (current_score_label);
        
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

    internal void add_keypress_handler (KeypressHandlerFunction handler)
    {
        keypress_handlers.push (handler);
    }

    private inline Box build_first_run_view ()
    {
        Builder builder = new Builder.from_resource ("/org/gnome/SwellFoop/ui/first-run.ui");
        var box = (Box) builder.get_object ("first_run_box");
        var tip_label = (Label) builder.get_object ("tip_label");
        /* Translators: text appearing on the first-run screen; to test, run `gsettings set org.gnome.SwellFoop first-run true` before launching application */
        tip_label.set_label (_("Clear as many blocks as you can.\nFewer clicks means more points."));
        var play_button = (Button) builder.get_object ("play_button");
        play_button.clicked.connect (() => {
            stack.set_visible_child_name ("game");
            settings.set_boolean ("first-run", false);
        });
        return box;
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
        uint score = 0;
        if (game != null)
            score = game.score;
        current_score_label.label = "<span size=\"x-large\">%u</span>".printf(score);
    }

    private void complete_cb ()
    {
        undo_action.set_enabled (false);
        Idle.add (() => { add_score (); return Source.REMOVE; });
        game_in_progress = false;
        /* Translators: the text for the score total shown on the game over screen */
        score_label.set_label (_("%u Points").printf(game.score));

        current_score_label.visible = false;
        game_over_box.visible = true;

    }

    private inline void started_cb ()
    {
        game_in_progress = true;
        current_score_label.visible = true;
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
        game_in_progress = game.score != 0;
        update_score_cb ();

        /* Game score change will be sent to the main window and show in the score label */
        game.update_score.connect (update_score_cb);
        game.complete.connect (complete_cb);
        game.started.connect (started_cb);

        /* Initialize the view */
        view.set_theme_name (settings.get_string ("theme"));
        view.set_game ((!) game);
        view.set_score (game.score);

        /* Update undo and redo actions states */
        undo_action = (SimpleAction) lookup_action ("undo");
        game.bind_property ("can-undo", undo_action, "enabled", BindingFlags.SYNC_CREATE);

        redo_action = (SimpleAction) lookup_action ("redo");
        game.bind_property ("can-redo", redo_action, "enabled", BindingFlags.SYNC_CREATE);
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
        var dialog = new AlertDialog(
                                     /* Translators: text of a Dialog that may appear if you start a new game while one is running */
                                     _("Abandon this game to start a new one?"));

        dialog.modal = true;
        dialog.buttons = {
                            /* Translators: text of one of the two buttons of a Dialog that appears if you start a new game while one is running; the other is “_New Game” */
                            _("_Cancel"),
                            /* Translators: text of one of the two buttons of a Dialog that appears if you start a new game while one is running; the other is “_Cancel” */
                            _("_New Game")
        };
        dialog.default_button = 1;
        dialog.cancel_button = 0;

        dialog.choose.begin (this, null, (obj, res) => {
            try
            {
                var result = dialog.choose.end(res);
                if (result == 1)
                {
                    new_game ();
                }
            }
            catch (Error e)
            {
                warning ("Failed to get result of warning dialog: %s", e.message);
            }
        });
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
    * * keyboard
    \*/
    internal bool keypress (uint keyval, uint keycode, out bool remove_handler)
    {
        remove_handler = false;
        switch (keyval)
        {
            case Gdk.Key.F2:
                new_game ();
                return true;
            case Gdk.Key.Up:
            case Gdk.Key.W: /* added key for left hand use */
            case Gdk.Key.w: /* added key for left hand use */
                view.cursor_move (0, 1);
                return true;
            case Gdk.Key.Down:
            case Gdk.Key.S: /* added key for left hand use */
            case Gdk.Key.s: /* added key for left hand use */
                view.cursor_move (0, -1);
                return true;
            case Gdk.Key.Left:
            case Gdk.Key.A: /* added key for left hand use */
            case Gdk.Key.a: /* added key for left hand use */
                view.cursor_move (-1, 0);
                return true;
            case Gdk.Key.Right:
            case Gdk.Key.D: /* added key for left hand use */
            case Gdk.Key.d: /* added key for left hand use */
                view.cursor_move (1, 0);
                return true;
            case Gdk.Key.space:
            case Gdk.Key.Return:
                view.cursor_click ();
                return true;
            default:
                return false;
        }
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
        else
        {    
            var scores = scores_context.get_high_scores (category);
            var lowest_high_score = (scores.size == 10 ? scores.last ().score : -1);
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
                    if (game.score <= lowest_high_score)
                        scores_context.run_dialog ();
                });
        }
    }
}

