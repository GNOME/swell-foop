/*
 * Copyright (C) 2010-2013 Robert Ancell
 *
 * This program is free software: you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free Software
 * Foundation, either version 2 of the License, or (at your option) any later
 * version. See http://www.gnu.org/copyleft/gpl.html the full text of the
 * license.
 */

/**
 *  This class defines the view of a game. All clutter related stuff goes here. It follows the
 *  principle of MVC framework. This class deals with the presentation (view) layer. It communicates
 *  with the model class by composite relation and with the control layer by means of signals and
 *  events.
 */

using Gtk;

[GtkTemplate (ui = "/org/gnome/SwellFoop/ui/game-view.ui")]
private class GameView : Widget
{
    [GtkChild] private Board board;

    private Game game;
    private ulong game_complete_handler = 0;
    private ulong score_updated_handler = 0;

    construct
    {
        BinLayout layout = new BinLayout ();
        set_layout_manager (layout);
    }

    internal void set_game (Game game)
    {
        if (game_complete_handler != 0 || score_updated_handler != 0)
            SignalHandler.disconnect_by_func (game, null, this);

        this.game = game;
        game_complete_handler = game.complete.connect (on_game_complete);
        score_updated_handler = game.update_score.connect (on_score_updated);

        board.game = game;

        on_new_game ();
    }

    /*\
    * * proxy calls
    \*/

    private bool is_zealous = true;
    internal void set_is_zealous (bool is_zealous)
    {
        this.is_zealous = is_zealous;
        board.is_zealous = is_zealous;
    }

    internal void board_left_cb ()
    {
        board.board_left_cb ();
    }

    internal void cursor_move (int x, int y)
    {
        board.cursor_move (x, y);
    }

    internal void cursor_click ()
    {
        board.cursor_click ();
    }

    /*\
    * * scores
    \*/

    [GtkChild] private Revealer score_revealer;
    [GtkChild] private Label    score_label;

    private ulong score_revealed_handler = 0;

    private inline void on_score_updated (uint points)
    {
        if (!is_zealous || points == 0)
            return;

        /* Translators: text displayed in the center of the board each time the player scores; the %u is replaced by the number of points */
        score_label.set_text (_("+%u").printf (points));

        score_revealer.set_reveal_child (true);
        if (score_revealed_handler == 0)
            score_revealed_handler = Timeout.add (250, () => {
                    score_revealer.set_reveal_child (false);
                    score_revealed_handler = 0;
                    return Source.REMOVE;
                });
    }

    /*\
    * * final score
    \*/

    [GtkChild] private Revealer final_score_revealer;
    [GtkChild] private Label    final_score_label;

    /* Show the final score when the game is over */
    private inline void on_game_complete ()
    {
        /* Translators: text of a label that appears on the board at the end of a game; the %u is replaced by the score */
        var points_label = ngettext ("%u point", "%u points", game.score).printf (game.score);

        /* Translators: text of a label that appears on the board at the end of a game */
        final_score_label.set_markup ("<b>%s</b>\n%s".printf (_("Game Over!"), points_label));

        final_score_revealer.show ();
        final_score_revealer.set_transition_duration (500);
        final_score_revealer.set_reveal_child (true);
    }

    private inline void on_new_game ()
    {
        final_score_revealer.set_transition_duration (0);
        final_score_revealer.set_reveal_child (false);
        final_score_revealer.hide ();
    }
}

private class Board : Widget
{
    private TileView? highlighted = null;

    private bool cursor_active = false;
    private int _cursor_x;
    private int cursor_x
    {
        private get { return this._cursor_x; }
        private set { this._cursor_x = value.clamp (0, game.columns - 1); }
    }

    private int _cursor_y;
    private int cursor_y
    {
        private get { return this._cursor_y; }
        private set { this._cursor_y = value.clamp (0, game.rows - 1); }
    }

    /* A 2D array holding all tiles */
    private TileView? [,] tiles;

    /* Group containing all the actors in the current game */
//    private Clutter.Actor game_actors;

    /* Game being played */
    private bool game_is_set = false;
    private Game _game;
    internal Game game
    {
        private get { if (!game_is_set) assert_not_reached (); return _game; }
        internal set
        {
//            if (game_is_set)
//                game_actors.destroy ();
//            game_actors = new Clutter.Actor ();
//            add_child (game_actors);

            /* Remove old tiles */
            remove_tiles ();

            if (game_is_set)
                SignalHandler.disconnect_matched (game, SignalMatchType.DATA, 0, 0, null, null, this);
            _game = value;
            game_is_set = true;
            game.undone.connect (move_undone_cb);

            /* Put tiles in new locations */
            tiles = new TileView? [game.columns, game.rows];
            cursor_x = 0;
            cursor_y = 0;
            place_tiles ();

            set_size_request (tile_size * game.columns, tile_size * game.rows);
        }
    }

    /* Size of tiles */
    private int tile_size = 50;

    private void remove_tiles ()
    {
        if (!game_is_set)
            return;

        for (var x = 0; x < game.columns; x++)
        {
            for (var y = 0; y < game.rows; y++)
            {
                unowned TileView? tile_view = tiles[x, y];
                if (tile_view == null)
                    continue;

                if (((!) tile_view).click_controller_pressed_handler != 0)
                    SignalHandler.disconnect (((!) tile_view).click_controller, ((!) tile_view).click_controller_pressed_handler);
                SignalHandler.disconnect (((!) tile_view).inout_controller, ((!) tile_view).inout_controller_enter_handler);
                SignalHandler.disconnect (((!) tile_view).inout_controller, ((!) tile_view).inout_controller_leave_handler);

                ((!) tile_view).unparent ();
                tiles[x, y] = null;
            }
        }
    }

    private void place_tiles ()
    {
        if (!game_is_set)
            return;

        for (var x = 0; x < game.columns; x++)
        {
            for (var y = 0; y < game.rows; y++)
            {
                /* For each tile object, we create a tile actor for it */
                Tile? tile = game.get_tile (x, y);
                TileView tile_view;
                if (tile == null || ((!) tile).closed)
                    tile_view = new TileView.empty (tile_size);
                else
                    tile_view = new TileView (tile, tile_size);

                tiles[x, y] = tile_view;
                tile_view.insert_before (this, /* insert last */ null);

                FixedLayoutChild child_layout = (FixedLayoutChild) layout.get_layout_child (tile_view);
                tile_view.child_layout = child_layout;

                /* The event from the model will be caught and responded by the view */
                if (tile != null)
                {
                    ((!) tile).move.connect (move_cb);
                    ((!) tile).close.connect (close_cb);
                }

                /* Respond to the user interactions */
                if (tile_view.click_controller != null)
                    tile_view.click_controller_pressed_handler = ((!) tile_view.click_controller).pressed.connect (remove_region_cb);

                tile_view.inout_controller_enter_handler = tile_view.inout_controller.enter.connect (tile_entered_cb);
                tile_view.inout_controller_leave_handler = tile_view.inout_controller.leave.connect (tile_left_cb);

                /* visual position */
                Graphene.Point point = Graphene.Point ();
                point.init ((float) (x * tile_size), (float) ((game.rows - y - 1) * tile_size));
                Gsk.Transform transform = new Gsk.Transform ();
                transform = transform.translate (point);
                child_layout.set_transform (transform);
            }
        }
    }

    private bool _is_zealous = false;
    internal bool is_zealous
    {
        private  get { return _is_zealous; }
        internal set { _is_zealous = value; if (value) add_css_class ("zealous"); else remove_css_class ("zealous"); }
    }

    private FixedLayout layout;
    construct
    {
        layout = new FixedLayout ();
        set_layout_manager (layout);

        add_css_class ("board");
    }

    /* When a tile in the model layer is closed, play an animation at the view layer */
    private inline void close_cb (uint8 grid_x, uint8 grid_y)
    {
        unowned TileView? tile_actor = tiles[grid_x, grid_y];
        if (tile_actor != null)
            ((!) tile_actor).animate_out (is_zealous);
    }

    /* When a tile in the model layer is moved, play an animation at the view layer */
    private inline void move_cb (uint8 old_x, uint8 old_y, uint8 new_x, uint8 new_y)
    {
        // swap tiles in the tiles array
        unowned TileView? tile_view_1 = tiles[old_x, old_y];
        if (tile_view_1 == null)
            assert_not_reached ();
        unowned TileView? tile_view_2 = tiles[new_x, new_y];

        tiles[new_x, new_y] = tile_view_1;
        tiles[old_x, old_y] = tile_view_2;

        tile_view_1.animate_move ((float) (old_x * tile_size), (float) ((game.rows - old_y - 1) * tile_size),
                                  (float) (new_x * tile_size), (float) ((game.rows - new_y - 1) * tile_size),
                                  is_zealous);
    }

    /* Sets or unsets the highlight for all tiles connected to the given tile */
    private void highlight_connected_tiles (TileView? given_tile, bool highlight)
    {
        if (given_tile == null)
            return;

        var connected_tiles = game.connected_tiles (given_tile.tile);
        foreach (unowned Tile tile in connected_tiles)
        {
            TileView? tile_view = tiles[tile.grid_x, tile.grid_y];
            if (tile_view != null)
                ((!) tile_view).set_highlight (highlight);
        }
    }

    /* When the mouse enters a tile, bright up the connected tiles */
    private void tile_entered_cb (EventControllerMotion inout_controller, double x, double y, Gdk.CrossingMode mode)
    {
        if (cursor_active)
            return;

        TileView tile_view = (TileView) inout_controller.get_widget ();

        highlight_connected_tiles (tile_view, true);
        highlighted = tile_view;
    }

    /* When the mouse leaves a tile, lower the brightness of the connected tiles */
    private void tile_left_cb (EventControllerMotion inout_controller, Gdk.CrossingMode mode)
    {
        if (cursor_active)
            return;

        TileView tile_view = (TileView) inout_controller.get_widget ();

        highlight_connected_tiles (tile_view, false);
    }

    /* When the user click a tile, send the model to remove the connected tile. */
    private void remove_region_cb (GestureClick click_controller, int n_press, double x, double y)
    {
        TileView tile_view = (TileView) click_controller.get_widget ();

        highlight_connected_tiles (highlighted, false);

        if (cursor_active)
        {
            cursor_active = false;
//            cursor.hide ();
        }

        /* Move the cursor to where the mouse was clicked. Expected for mixed mouse/keyboard use */
        cursor_x = tile_view.tile.grid_x;
        cursor_y = tile_view.tile.grid_y;

        game.remove_connected_tiles (tile_view.tile);
    }

    /* When the mouse leaves the application window, reset all tiles to the default brightness */
    internal void board_left_cb ()
    {
        foreach (TileView? tile_actor in tiles)
            if (tile_actor != null)
                ((!) tile_actor).set_highlight (false);
    }

    private TileView? find_tile_at_position (int position_x, int position_y)
    {
        foreach (TileView? tile_actor in tiles)
            if (tile_actor != null
             && ((!) tile_actor).tile.grid_x == position_x
             && ((!) tile_actor).tile.grid_y == position_y)
                return tile_actor;
        return null;
    }

    /* Move Keyboard cursor */
    internal void cursor_move (int x, int y)
    {
        // update abstract cursor coords
        if (cursor_active)
        {
            int old_cursor_x = cursor_x;
            int old_cursor_y = cursor_y;

            cursor_x += x;
            cursor_y += y;

            if (cursor_x == old_cursor_x
             && cursor_y == old_cursor_y)
                return;
        }
        else
            cursor_active = true;

        // highlight and unhighlight
        TileView? cursor_tile = find_tile_at_position (cursor_x, cursor_y);

        if ((highlighted != null && cursor_tile == null)
         || (highlighted == null && cursor_tile != null)
         || (highlighted != null && cursor_tile != null && ((!) highlighted).tile.color != ((!) cursor_tile).tile.color))
        {
            // highlight_connected_tiles() handles correctly a null TileView
            highlight_connected_tiles (highlighted, false);
            highlight_connected_tiles (cursor_tile, true);
        }

        highlighted = cursor_tile;

        // update visual cursor position
        float xx, yy;
        xx = cursor_x * tile_size;
        yy = (game.rows - 1 - cursor_y) * tile_size;
//        cursor.set_position (xx, yy);
//        cursor.show ();
    }

    /* Keyboard Cursor Click */
    internal void cursor_click ()
    {
        game.remove_connected_tiles (tiles[cursor_x, cursor_y].tile);
        highlighted = tiles[cursor_x, cursor_y];
        highlight_connected_tiles (highlighted, true);
    }

    private inline void move_undone_cb ()
    {
        game = game;
    }
}

/**
 *  This class defines the view of a tile. All clutter related stuff goes here
 */
private class TileView : Widget
{
    /* Tile being represented */
    public Tile? tile   { internal get; protected construct; default = null; }
    public uint size    { internal get; protected construct; }

    public EventControllerMotion inout_controller { internal get; protected construct; }
    public GestureClick?         click_controller { internal get; protected construct; default = null; }
    internal ulong click_controller_pressed_handler = 0;
    internal ulong inout_controller_enter_handler = 0;
    internal ulong inout_controller_leave_handler = 0;

    internal FixedLayoutChild child_layout { private get; internal set; }

    private static uint8 ZEALOUS_ANIMATION = 12;
    private static uint8 STANDARD_ANIMATION = 30;

    private bool tile_destroyed = false;

    internal TileView (Tile tile, uint size)
    {
        EventControllerMotion _inout_controller = new EventControllerMotion ();
        GestureClick _click_controller = new GestureClick ();
        Object (tile: tile,
                size: size,
                inout_controller: _inout_controller,
                click_controller: _click_controller);
    }

    internal TileView.empty (uint size)
    {
        EventControllerMotion _inout_controller = new EventControllerMotion ();
        Object (size: size,
                inout_controller: _inout_controller);
    }

    construct
    {
        set_size_request ((int) size, (int) size);
        add_css_class ("tile");

        if (tile == null)
            add_css_class ("removed");
        else
            switch (tile.color)
            {
                case 4: add_css_class ("red");      break;
                case 1: add_css_class ("blue");     break;
                case 2: add_css_class ("green");    break;
                case 3: add_css_class ("yellow");   break;
                case 0: add_css_class ("removed");  break;
                default: assert_not_reached ();
            }

        set_highlight (false);

        add_controller (inout_controller);
        if (click_controller != null)
            add_controller ((!) click_controller);
    }

    internal void set_highlight (bool highlight)
    {
        if (tile_destroyed)
            return;

        if (highlight)
            add_css_class ("highlight");
        else
            remove_css_class ("highlight");
    }

    /* Destroy the tile */
    internal void animate_out (bool is_zealous)
    {
        /* When the animination is done, hide the actor */
        tile_destroyed = true;
        can_target = false;
        if (click_controller != null)
            remove_controller ((!) click_controller);
        remove_css_class ("highlight");
        add_css_class ("removed");
        Timeout.add (is_zealous ? ZEALOUS_ANIMATION * 10: STANDARD_ANIMATION * 10, () => { hide (); return Source.REMOVE; });
    }

    /* Define how the tile moves */
    private uint tick_id = 0;
    private float current_x = 0.0f;
    private float current_y = 0.0f;
    internal void animate_move (float old_x, float old_y, float new_x, float new_y, bool is_zealous = false)
    {
        Timeout.add (is_zealous ? ZEALOUS_ANIMATION * 10 : STANDARD_ANIMATION * 10, () => {
                if (tick_id == 0)
                {
                    current_x = old_x;
                    current_y = old_y;
                }
                else
                    remove_tick_callback (tick_id);

                uint8 i = is_zealous ? ZEALOUS_ANIMATION : STANDARD_ANIMATION;
                float move_distance_x = (new_x - current_x) / (float) i;
                float move_distance_y = (new_y - current_y) / (float) i;

                tick_id = add_tick_callback (() => {
                        i--;
                        Graphene.Point point = Graphene.Point ();
                        Gsk.Transform transform = new Gsk.Transform ();

                        current_x = new_x - (float) i * move_distance_x;
                        current_y = new_y - (float) i * move_distance_y;
                        point.init (current_x, current_y);
                        transform = transform.translate (point);
                        child_layout.set_transform (transform);

                        if (i == 0)
                        {
                            tick_id = 0;
                            return Source.REMOVE;
                        }
                        else
                            return Source.CONTINUE;
                    });
                return Source.REMOVE;
            });
    }
}
