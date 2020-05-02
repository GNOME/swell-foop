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

    /* Game history */
    private History history;

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

        history = new History (Path.build_filename (Environment.get_user_data_dir (), "swell-foop", "history"));
        history.load ();
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
        var date = new DateTime.now_local ();
        var entry = new HistoryEntry (date, game.columns, game.rows, game.color_num, game.score);
        history.add (entry);
        history.save ();
        game_in_progress = false;
    }

    private inline void started_cb ()
    {
        game_in_progress = true;
    }

    private Size get_board_size ()
    {
        for (var i = 0; i < ((SwellFoop) application).sizes.length; i++)
        {
            if (((SwellFoop) application).sizes[i].id == settings.get_string ("size"))
                return ((SwellFoop) application).sizes[i];
        }

        return ((SwellFoop) application).sizes[0];
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
        var dialog = new ScoreDialog (history);
        dialog.modal = true;
        dialog.transient_for = this;

        dialog.run ();
        dialog.destroy ();
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
}
