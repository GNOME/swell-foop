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

using Config;

private class GameView : GtkClutter.Embed
{
    private Clutter.Stage stage;
    private GameGroup group;

    construct
    {
        stage = (Clutter.Stage) get_stage ();
        stage.background_color = Clutter.Color.from_string ("#000000");  /* background color is black */

        group = new GameGroup ();
        stage.add_child (group);

        /* Request an appropriate size for the game view */
        init_size ();
    }

    private void init_size ()
    {
        stage.set_size (group.width, group.height);
        set_size_request ((int) stage.width, (int) stage.height);
    }

    /*\
    * * proxy calls
    \*/

    internal void set_game (Game game)
    {
        group.game = game;
        init_size ();
    }

    internal void set_theme_name (string theme_name)
    {
        group.theme_name = theme_name;
    }

    internal void set_is_zealous (bool is_zealous)
    {
        group.is_zealous = is_zealous;
    }

    internal void board_left_cb ()
    {
        group.board_left_cb ();
    }

    internal void cursor_move (int x, int y)
    {
        group.cursor_move (x, y);
    }

    internal void cursor_click ()
    {
        group.cursor_click ();
    }
}

private class GameGroup : Clutter.Group
{
    private TileActor? highlighted = null;

    private CursorActor cursor;
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
    private TileActor? [,] tiles;

    /* Group containing all the actors in the current game */
    private Clutter.Actor game_actors;

    /* Game being played */
    private bool game_is_set = false;
    private Game _game;
    internal Game game
    {
        private get { if (!game_is_set) assert_not_reached (); return _game; }
        internal set
        {
            if (game_is_set)
                game_actors.destroy ();
            game_actors = new Clutter.Actor ();
            add_child (game_actors);

            /* Remove old tiles */
            remove_tiles ();

            if (game_is_set)
                SignalHandler.disconnect_matched (game, SignalMatchType.DATA, 0, 0, null, null, this);
            _game = value;
            game_is_set = true;
            game.complete.connect (game_complete_cb);
            game.update_score.connect (update_score_cb);

            /* Put tiles in new locations */
            tiles = new TileActor? [game.columns, game.rows];
            cursor_x = 0;
            cursor_y = 0;
            place_tiles ();

            width  = tile_size * game.columns;
            height = tile_size * game.rows;
        }
    }

    /* This is a <ThemeName -- ThemeObject> container */
    private HashTable<string, Theme> themes;

    /* Theme being used */
    private string _theme_name = "shapesandcolors";
    internal string theme_name
    {
        private get { return _theme_name; }
        internal set
        {
            if (theme_name == value)
                return;
            _theme_name = value;
            remove_tiles ();
            place_tiles ();
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
                var tile = tiles[x, y];
                if (tile == null)
                    continue;
                tiles[x, y] = null;

                SignalHandler.disconnect_matched (tile, SignalMatchType.DATA, 0, 0, null, null, this);
                tile.destroy ();
            }
        }

        cursor.destroy ();
    }

    private void place_tiles ()
    {
        if (!game_is_set)
            return;

        var theme = themes.lookup (theme_name);
        if (theme == null)
            theme = themes.lookup ("shapesandcolors");

        for (var x = 0; x < game.columns; x++)
        {
            for (var y = 0; y < game.rows; y++)
            {
                /* For each tile object, we create a tile actor for it */
                var l = game.get_tile (x, y);
                if (l == null || l.closed)
                    continue;
                var tile = new TileActor (l, theme.textures[l.color], tile_size);

                /* The event from the model will be caught and responded by the view */
                l.move.connect (move_cb);
                l.close.connect (close_cb);

                /* Physical position in the stage */
                float xx, yy;
                xx = x * tile_size;
                yy = (game.rows - y - 1) * tile_size;
                tile.set_position (xx, yy);

                /* Respond to the user interactions */
                tile.reactive = true;
                var tap = new Clutter.TapAction ();
                tile.add_action (tap);
                tap.tap.connect (remove_region_cb);
                tile.enter_event.connect (tile_entered_cb);
                tile.leave_event.connect (tile_left_cb);

                tiles[x, y] = tile;
                game_actors.add_child (tile);
            }
        }

        cursor = new CursorActor (theme.cursor, tile_size);
        game_actors.add_child (cursor);
        cursor.hide ();
    }

    internal bool is_zealous { private get; internal set; }

    construct
    {
        /* Initialize the theme resources */
        themes = new HashTable<string, Theme> (str_hash, str_equal);
        var theme = new Theme ("colors");
        themes.insert ("colors", theme);

        theme = new Theme ("shapesandcolors");
        themes.insert ("shapesandcolors", theme);
    }

    /* When a tile in the model layer is closed, play an animation at the view layer */
    private inline void close_cb (uint8 grid_x, uint8 grid_y)
    {
        unowned TileActor? tile_actor = tiles[grid_x, grid_y];
        if (tile_actor != null)
            ((!) tile_actor).animate_out ();
    }

    /* When a tile in the model layer is moved, play an animation at the view layer */
    private inline void move_cb (uint8 old_x, uint8 old_y, uint8 new_x, uint8 new_y)
    {
        var tile = tiles[old_x, old_y];
        tiles[new_x, new_y] = tile;
        var new_xx = new_x * tile_size;
        var new_yy = (game.rows - new_y - 1) * tile_size;

        tile.animate_to (new_xx, new_yy, is_zealous);
    }

    /* Sets the opacity for all tiles connected to the actor */
    private void opacity_for_connected_tiles (TileActor? actor, Opacity opacity)
    {
        if (actor == null)
            return;

        var connected_tiles = game.connected_tiles (actor.tile);
        foreach (var l in connected_tiles)
        {
            TileActor? tile_actor = tiles[l.grid_x, l.grid_y];
            if (tile_actor != null)
                ((!) tile_actor).update_opacity (opacity);
        }
    }

    /* When the mouse enters a tile, bright up the connected tiles */
    private bool tile_entered_cb (Clutter.Actor actor, Clutter.CrossingEvent event)
    {
        if (cursor_active)
            return false;

        var tile = (TileActor) actor;

        opacity_for_connected_tiles (tile, Opacity.FULL);
        highlighted = tile;

        return false;
    }

    /* When the mouse leaves a tile, lower the brightness of the connected tiles */
    private bool tile_left_cb (Clutter.Actor actor, Clutter.CrossingEvent event)
    {
        if (cursor_active)
            return false;

        var tile = (TileActor) actor;

        opacity_for_connected_tiles (tile, Opacity.HALF);

        return false;
    }

    /* When the user click a tile, send the model to remove the connected tile. */
    private void remove_region_cb (Clutter.TapAction tap, Clutter.Actor actor)
    {
        var tile = (TileActor) actor;

        opacity_for_connected_tiles (highlighted, Opacity.HALF);

        if (cursor_active)
        {
            cursor_active = false;
            cursor.hide ();
        }

        /* Move the cursor to where the mouse was clicked. Expected for mixed mouse/keyboard use */
        cursor_x = tile.tile.grid_x;
        cursor_y = tile.tile.grid_y;

        game.remove_connected_tiles (tile.tile);
    }

    /* When the mouse leaves the application window, reset all tiles to the default brightness */
    internal void board_left_cb ()
    {
        game.reset_visit ();

        foreach (TileActor? tile_actor in tiles)
            if (tile_actor != null)
                ((!) tile_actor).update_opacity (Opacity.HALF);
    }

    private TileActor? find_tile_at_position (int position_x, int position_y)
    {
        foreach (TileActor? tile_actor in tiles)
            if (tile_actor != null
             && ((!) tile_actor).tile.grid_x == position_x
             && ((!) tile_actor).tile.grid_y == position_y)
                return tile_actor;
        return null;
    }

    /* Move Keyboard cursor */
    internal void cursor_move (int x, int y)
    {
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

        opacity_for_connected_tiles (highlighted, Opacity.HALF);
        highlighted = find_tile_at_position (cursor_x, cursor_y);

        if (highlighted != null)
            opacity_for_connected_tiles (highlighted, Opacity.FULL);

        float xx, yy;
        xx = cursor_x * tile_size;
        yy = (game.rows - 1 - cursor_y) * tile_size;
        cursor.set_position (xx, yy);
        cursor.show ();
    }

    /* Keyboard Cursor Click */
    internal void cursor_click ()
    {
        game.remove_connected_tiles (tiles[cursor_x, cursor_y].tile);
        highlighted = tiles[cursor_x, cursor_y];
        opacity_for_connected_tiles (highlighted, Opacity.FULL);
    }

    /* Show flying score animation after each tile-removing click */
    private void update_score_cb (uint points_awarded)
    {
        if (is_zealous)
        {
            var text = new ScoreActor (game.rows / 5, width, height);
            game_actors.add_child (text);
            text.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.BOTH, 0.5f));
            text.animate_score (points_awarded);
        }
    }

    /* Show the final score when the game is over */
    private void game_complete_cb ()
    {
        var text = new ScoreActor (game.rows / 5, width, height);
        game_actors.add_child (text);
        text.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.BOTH, 0.5f));
        text.animate_final_score (game.score);

        /* Translators: text of a button that appears on the board at the end of a game */
        var play_again_button = new Gtk.Button.with_mnemonic (_("_Play Again"));
        play_again_button.width_request = 130;
        play_again_button.height_request = 40;
        play_again_button.action_name = "win.new-game";
        play_again_button.show ();

        var style = play_again_button.get_style_context ();
        style.add_class ("suggested-action");

        var button_actor = new GtkClutter.Actor.with_contents (play_again_button);
        game_actors.add_child (button_actor);
        button_actor.visible = true;
        button_actor.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.X_AXIS, 0.5f));
        button_actor.add_constraint (new Clutter.AlignConstraint (this, Clutter.AlignAxis.Y_AXIS, 0.88f));

        button_actor.set_easing_mode (Clutter.AnimationMode.EASE_OUT_ELASTIC);
        button_actor.set_easing_duration (2000);
        button_actor.z_position = -50;
        button_actor.set_opacity (255);
    }
}

/**
 *  This class holds the textures for a specific theme. These textures are used for creating light
 *  actors and cursor actor.
 */
private class Theme : Object
{
    internal Clutter.Image[] textures;
    internal Clutter.Image cursor;

    internal Theme (string name)
    {
        textures = new Clutter.Image [4];
        string[4] colors = {"blue", "green", "yellow", "red"};

        /* Create the textures required to render */
        try
        {
            for (uint8 i = 0; i < 4; i++) {
                 var pixbuf = new Gdk.Pixbuf.from_file (Path.build_filename (Config.DATADIR, "themes", name, colors[i] + ".svg"));
                textures[i] = new Clutter.Image ();
                textures[i].set_data (pixbuf.get_pixels (), Cogl.PixelFormat.RGBA_8888,
                    pixbuf.get_width (), pixbuf.get_height (),  pixbuf.get_rowstride ());
            }
            var pixbuf = new Gdk.Pixbuf.from_file (Path.build_filename (Config.DATADIR, "themes", name, "highlight.svg"));
            cursor = new Clutter.Image ();
            cursor.set_data (pixbuf.get_pixels (), Cogl.PixelFormat.RGBA_8888,
               pixbuf.get_width (), pixbuf.get_height (),  pixbuf.get_rowstride ());
        }
        catch (Clutter.TextureError e)
        {
            warning ("Failed to load textures: %s", e.message);
        }
        catch (GLib.Error e)
        {
            warning ("Failed to load textures: %s", e.message);
        }
    }
}

private enum Opacity
{
    NULL,
    HALF,
    FULL;
}

/**
 *  This class defines the view of a tile. All clutter related stuff goes here
 */
private class TileActor : Clutter.Actor
{
    /* Tile being represented */
    internal Tile tile;

    internal TileActor (Tile tile, Clutter.Image texture, int size)
    {
        this.tile = tile;
        update_opacity (Opacity.HALF);
        set_size (size, size);
        content = texture;

        set_content_gravity (Clutter.ContentGravity.CENTER);
        set_pivot_point (0.5f, 0.5f);
    }

    internal void update_opacity (Opacity opacity)
    {
        switch (opacity)
        {
            case Opacity.NULL:  set_opacity (  0);  break;
            case Opacity.HALF:  set_opacity (180);  break;
            case Opacity.FULL:  set_opacity (255);  break;
            default: assert_not_reached ();
        }
    }

    /* Destroy the tile */
    internal void animate_out ()
    {
        /* When the animination is done, hide the actor */
        set_easing_mode (Clutter.AnimationMode.LINEAR);
        set_easing_duration (500);
        set_scale (2.0, 2.0);
        update_opacity (Opacity.NULL);
        transitions_completed.connect (hide_tile_cb);
    }

    private void hide_tile_cb ()
    {
        hide ();
    }

    /* Define how the tile moves */
    internal void animate_to (double new_x, double new_y, bool is_zealous = false)
    {
        var anim_mode = is_zealous ? Clutter.AnimationMode.EASE_OUT_BOUNCE : Clutter.AnimationMode.EASE_OUT_QUAD;
        set_easing_mode (anim_mode);
        set_easing_duration (500);
        set_position ((float) new_x, (float) new_y);
    }
}

private class CursorActor : Clutter.Actor
{
    internal CursorActor (Clutter.Content texture, int size)
    {
        set_opacity (180);
        set_size (size, size);
        content = texture;

        set_content_gravity (Clutter.ContentGravity.CENTER);
        set_pivot_point (0.5f, 0.5f);
    }
}

/**
 *  This class defines the view of a score. All clutter related stuff goes here
 */
private class ScoreActor : Clutter.Group
{
    private Clutter.Text label;
    private float scene_width;
    private float scene_height;
    private int game_size;

    internal ScoreActor (int game_size, double width, double height)
    {
        label = new Clutter.Text ();
        label.set_color (Clutter.Color.from_string ("rgba(255, 255, 255, 255)"));

        add_child (label);

        set_pivot_point (0.5f, 0.5f);

        this.scene_width = (float) width;
        this.scene_height = (float) height;
        this.game_size = game_size;
    }

    internal void animate_score (uint points)
    {
        if (points == 0)
            return;

        label.set_font_name ("Bitstrem Vera Sans Bold 30");
        label.set_text ("+" + points.to_string ());

        /* The score will be shown repeatedly therefore we need to reset some important properties
         * before the actual animation */
        set_opacity (255);
        z_position = 0f;

        set_easing_mode (Clutter.AnimationMode.EASE_OUT_SINE);
        set_easing_duration (600);
        z_position = 500f;
        set_opacity (0);
        transitions_completed.connect (() => { destroy (); });
    }

    internal void animate_final_score (uint points)
    {
        label.set_font_name ("Bitstrem Vera Sans 30");
        var points_label = ngettext (/* Label showing the number of points at the end of the game */
                                     "%u point", "%u points", points).printf (points);

        /* Translators: text of a label that appears on the board at the end of a game */
        label.set_markup ("<b>%s</b>\n%s".printf (_("Game Over!"), points_label));
        label.set_line_alignment (Pango.Alignment.CENTER);

        /* The score will be shown repeatedly therefore we need to reset some important properties
         * before the actual animation */
        set_opacity (255);
        z_position = -300f + game_size * 100;

        set_easing_mode (Clutter.AnimationMode.EASE_OUT_ELASTIC);
        set_easing_duration (2000);
        z_position = -200 + game_size * 150;
        set_opacity (255);
    }
}
