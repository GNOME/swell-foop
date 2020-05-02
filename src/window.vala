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

    public GLib.Settings settings { private get; protected construct; }

    /* Game being played */
    private Game? game = null;

    /* Rendering of game */
    private GameView view;

    private Clutter.Stage stage;
    private GtkClutter.Embed clutter_embed;

    private bool game_in_progress = false;

    private const GLib.ActionEntry[] win_actions =
    {
        { "new-game",   new_game_cb },
        { "scores",     scores_cb   }
    };

    construct
    {
        add_action_entries (win_actions, this);

        add_events (Gdk.EventMask.KEY_PRESS_MASK | Gdk.EventMask.KEY_RELEASE_MASK);

        init_scores ();

        /* show the current score */
        update_score_cb (0);

        /* Create a clutter renderer widget */
        clutter_embed = new GtkClutter.Embed ();
        clutter_embed.show ();
        var first_run = settings.get_boolean ("first-run");

        if (first_run)
        {
            var stack = build_first_run_stack ();
            stack.add_named (clutter_embed, "game");
            main_box.pack_start (stack, true, true);
        }
        else
        {
            main_box.pack_start (clutter_embed, true, true);
            init_keyboard ();
        }
    }

    internal SwellFoopWindow (Gtk.Application application, GLib.Settings settings)
    {
        Object (application: application, settings: settings);

        stage = (Clutter.Stage) clutter_embed.get_stage ();
        stage.background_color = Clutter.Color.from_string ("#000000");  /* background color is black */

        /* Create an instance of game with initial values for row, column and color */
        game = new Game (get_board_size ().rows, get_board_size ().columns, settings.get_int ("colors"));

        /* Game score change will be sent to the main window and show in the score label */
        game.update_score.connect (update_score_cb);
        game.complete.connect (complete_cb);
        game.started.connect (started_cb);

        /* Create an instance of game view. This follow the Model-View-Controller paradigm */
        view = new GameView ();
        /* Initialize the themes needed by actors */
        view.theme_name = settings.get_string ("theme");
        view.is_zealous = settings.get_boolean ("zealous");
        view.game = game;
        stage.add_child (view);
        /* Request an appropriate size for the game view */
        stage.set_size (view.width, view.height);
        clutter_embed.set_size_request ((int) stage.width, (int) stage.height);

        /* When the mouse leaves the window we need to update the view */
        clutter_embed.leave_notify_event.connect (view.board_left_cb);
    }

    private inline Stack build_first_run_stack ()
    {
        CssProvider css_provider = new CssProvider ();
        css_provider.load_from_resource ("/org/gnome/SwellFoop/ui/swell-foop.css");
        Gdk.Screen? gdk_screen = Gdk.Screen.get_default ();
        if (gdk_screen != null) // else..?
            StyleContext.add_provider_for_screen ((!) gdk_screen, css_provider, STYLE_PROVIDER_PRIORITY_APPLICATION);

        Builder builder = new Builder.from_resource ("/org/gnome/SwellFoop/ui/first-run-stack.ui");
        var stack = (Stack) builder.get_object ("first_run_stack");
        var tip_label = (Label) builder.get_object ("tip_label");
        /* Translators: text appearing on the first-run screen; to test, run `gsettings set org.gnome.swell-foop first-run true` before launching application */
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

    private void update_score_cb (int points_awarded)
    {
        var score = 0;
        if (game != null)
            score = game.score;

        /* Translators: subtitle of the headerbar; the %u is replaced by the score */
        headerbar.subtitle = _("Score: %u").printf (score);
    }

    private void complete_cb ()
    {
        Idle.add (() => { add_score (); return Source.REMOVE; });
        game_in_progress = false;
    }

    private inline void started_cb ()
    {
        game_in_progress = true;
    }

    private Size get_board_size ()
    {
        for (var i = 0; i < SwellFoop.sizes.length; i++)
        {
            if (SwellFoop.sizes [i].id == settings.get_string ("size"))
                return SwellFoop.sizes [i];
        }

        return SwellFoop.sizes [0];
    }

    /*\
    * * internal calls
    \*/

    internal void new_game ()
    {
        game = new Game (get_board_size ().rows,
                         get_board_size ().columns,
                         settings.get_int ("colors"));
        game.update_score.connect (update_score_cb);
        game.complete.connect (complete_cb);
        game.started.connect (started_cb);
        view.theme_name = settings.get_string ("theme");
        view.game = game;
        view.is_zealous = settings.get_boolean ("zealous");

        stage.set_size (view.width, view.height);
        clutter_embed.set_size_request ((int) stage.width, (int) stage.height);

        game_in_progress = false;

        update_score_cb (0);
    }

    internal inline void set_theme_name (string new_theme)
    {
        view.theme_name = new_theme;
    }

    internal inline void set_is_zealous (bool is_zealous)
    {
        view.is_zealous = is_zealous;
    }

    internal inline void on_shutdown ()
    {
        /* Record the score if the game isn't over. */
        if (game != null && !game.has_completed () && game.score > 0)
            complete_cb ();
    }

    /*\
    * * actions
    \*/

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

        var result = dialog.run ();
        dialog.destroy ();

        if (result == ResponseType.YES)
            new_game ();
    }

    /*\
    * * keyboard
    \*/

    private EventControllerKey key_controller;          // for keeping in memory

    private inline void init_keyboard ()
    {
        key_controller = new EventControllerKey (this);
        key_controller.key_pressed.connect (on_key_pressed);
    }

    private inline bool on_key_pressed (EventControllerKey _key_controller, uint keyval, uint keycode, Gdk.ModifierType state)
    {
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

    class construct
    {
        score_categories = new HashTable<string, Games.Scores.Category> (str_hash, str_equal);
        for (uint8 i = 2; i <= 4; i++)
            foreach (unowned Size size in SwellFoop.sizes)
            {
                string id = @"$(size.id)-$i";
                string name = ngettext ("%s, %d color", "%s, %d colors", i).printf (size.name, i);
                Games.Scores.Category category = new Games.Scores.Category (id, name);
                score_categories.insert (id, (owned) category);
            }
    }

    private inline void init_scores ()  // called on construct
    {
        scores_context = new Games.Scores.Context.with_importer (
            "swell-foop",
            /* Translators: in the Scores dialog, label introducing for which board configuration (size and number of colors) the best scores are displayed */
            _("Type"),
            this,
            category_request,
            Games.Scores.Style.POINTS_GREATER_IS_BETTER,
            new Games.Scores.HistoryFileImporter (parse_old_score));
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
        foreach (unowned Size size in SwellFoop.sizes)
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
}
