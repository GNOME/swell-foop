/**
 *  This class defines the view of a game. All clutter related stuff goes here. It follows the
 *  principle of MVC framework. This class deals with the presentation (view) layer. It communicates
 *  with the model class by composite relation and with the control layer by means of signals and
 *  events.
 */
public class GameView : Clutter.Group
{
    /* A 2D array holding all tiles */
    private TileActor[,] tiles;

    /* Group containing all the actors in the current game */
    private Clutter.Group? game_actors = null;

    /* Game being played */
    private Game? _game = null;
    public Game? game
    {
        get { return _game; }
        set
        {
            if (game_actors != null)
                game_actors.destroy ();
            game_actors = new Clutter.Group ();
            add_actor (game_actors);

            /* Remove old tiles */
            remove_tiles ();

            if (game != null)
                SignalHandler.disconnect_matched (game, SignalMatchType.DATA, 0, 0, null, null, this);
            _game = value;
            game.complete.connect (game_complete_cb);
            game.update_score.connect (update_score_cb);

            /* Put tiles in new locations */
            tiles = new TileActor [game.columns, game.rows];
            place_tiles ();

            width  = tile_size * game.columns;
            height = tile_size * game.rows;
        }
    }

    /* This is a <ThemeName -- ThemeObject> container */
    private HashTable<string, Theme> themes;

    /* Theme being used */
    private string _theme_name = "shapesandcolors";
    public string theme_name
    {
        get { return _theme_name; }
        set
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
        if (game == null)
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
    }

    private void place_tiles ()
    {
        if (game == null)
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
                if (l == null)
                    continue;
                var tile = new TileActor (l, theme.textures[l.color], tile_size);

                /* The event from the model will be caught and responded by the view */
                l.move.connect (move_cb);
                l.close.connect (close_cb);

                /* Physical position in the stage */
                float xx, yy;
                xx = x * tile_size + tile_size / 2;
                yy = (game.rows - y - 1) * tile_size + tile_size / 2;
                tile.set_position (xx, yy);

                /* Respond to the user interactions */
                tile.reactive = true;
                tile.button_release_event.connect (remove_region_cb);
                tile.enter_event.connect (tile_entered_cb);
                tile.leave_event.connect (tile_left_cb);

                tiles[x, y] = tile;
                game_actors.add_actor (tile);
            }
        }
    }

    public bool is_zealous;

    public GameView ()
    {
        /* Initialize the theme resources */
        themes = new HashTable<string, Theme> (str_hash, str_equal);
        var theme = new Theme ("colors");
        themes.insert ("colors", theme);
        foreach (var t in theme.textures)
        {
            t.hide ();
            add_actor (t);
        }
        theme = new Theme ("shapesandcolors");
        themes.insert ("shapesandcolors", theme);
        foreach (var t in theme.textures)
        {
            t.hide ();
            add_actor (t);
        }
    }

    /* When a tile in the model layer is closed, play an animation at the view layer */
    public void close_cb (int grid_x, int grid_y)
    {
        tiles[grid_x, grid_y].animate_out ();
    }

    /* When a tile in the model layer is moved, play an animation at the view layer */
    public void move_cb (int old_x, int old_y, int new_x, int new_y)
    {
        var tile = tiles[old_x, old_y];
        tiles[new_x, new_y] = tile;
        var new_xx = new_x * tile_size + tile_size / 2.0;
        var new_yy = (game.rows - new_y - 1) * tile_size + tile_size / 2.0;

        tile.animate_to (new_xx, new_yy, is_zealous);
    }

    /* When the mouse enters a tile, bright up the connected tiles */
    private bool tile_entered_cb (Clutter.Actor actor, Clutter.CrossingEvent event)
    {
        var tile = (TileActor) actor;

        var connected_tiles = game.connected_tiles (tile.tile);
        foreach (var l in connected_tiles)
            tiles[l.grid_x, l.grid_y].opacity = 255;

        return false;
    }

    /* When the mouse leaves a tile, lower the brightness of the connected tiles */
    private bool tile_left_cb (Clutter.Actor actor, Clutter.CrossingEvent event)
    {
        var tile = (TileActor) actor;

        var connected_tiles = game.connected_tiles (tile.tile);
        foreach (var l in connected_tiles)
            tiles[l.grid_x, l.grid_y].opacity = 180;

        return false;
    }

    /* When the user click a tile, send the model to remove the connected tile. */
    private bool remove_region_cb (Clutter.Actor actor, Clutter.ButtonEvent event)
    {
        var tile = (TileActor) actor;

        game.remove_connected_tiles (tile.tile);

        return false;
    }

    /* When the mouse leaves the application window, reset all tiles to the default brightness */
    public bool board_left_cb ()
    {
        game.reset_visit ();

        foreach (var tile in tiles)
            tile.opacity = 180;

        return false;
    }

    /* Show flying score animation after each tile-removing click */
    public void update_score_cb (int points_awarded)
    {
        if (is_zealous)
        {
            var text = new ScoreActor (width / 2.0, height / 2.0, width, height);
            game_actors.add_actor (text);
            text.animate_score (points_awarded);
        }
    }

    /* Show the final score when the game is over */
    public void game_complete_cb ()
    {
        var text = new ScoreActor (width / 2.0, height / 2.0, width, height);
        game_actors.add_actor (text);
        text.animate_final_score (game.score);
    }
}

/**
 *  This class holds the textures for a specific theme. These textures are used for creating light
 *  actors.
 */
public class Theme
{
    public Clutter.Texture[] textures;

    public Theme (string name)
    {
        textures = new Clutter.Texture [4];
        string[4] colors = {"blue", "green", "yellow", "red"};

        /* Create the textures required to render */
        try
        {
            for (int i = 0; i < 4; i++)
                textures[i] = new Clutter.Texture.from_file (Path.build_filename (DATADIR, "themes", name, colors[i] + ".svg"));
        }
        catch (Clutter.TextureError e)
        {
            warning ("Failed to load textures: %s", e.message);
        }
    }
}

/**
 *  This class defines the view of a tile. All clutter related stuff goes here
 */
private class TileActor : Clutter.Clone
{
    /* Tile being represented */
    public Tile tile;

    public TileActor (Tile tile, Clutter.Texture texture, int size)
    {
        this.tile = tile;
        source = texture;
        opacity = 180;
        set_size (size, size);
        set_anchor_point (size / 2, size / 2);
    }

    /* Destroy the tile */
    public void animate_out ()
    {
        /* When the animination is done, hide the actor */
        var a = animate (Clutter.AnimationMode.LINEAR, 500, "scale-x", 2.0, "scale-y", 2.0, "opacity", 0);
        a.timeline.completed.connect (hide_tile_cb);
    }

    private void hide_tile_cb ()
    {
        hide ();
    }

    /* Define how the tile moves */
    public void animate_to (double new_x, double new_y, bool is_zealous = false)
    {
        var anim_mode = is_zealous ? Clutter.AnimationMode.EASE_OUT_BOUNCE : Clutter.AnimationMode.EASE_OUT_QUAD;
        animate (anim_mode, 500, "x", new_x, "y", new_y);
    }
}

/**
 *  This class defines the view of a score. All clutter related stuff goes here
 */
public class ScoreActor : Clutter.Group
{
    private Clutter.Text label;
    private float scene_width;
    private float scene_height;

    public ScoreActor (double x, double y, double width, double height)
    {
        label = new Clutter.Text ();
        label.set_color (Clutter.Color.from_string ("rgba(255, 255, 255, 255)"));

        anchor_gravity = Clutter.Gravity.CENTER;
        add_actor (label);

        this.x = (float) x;
        this.y = (float) y;
        this.scene_width = (float)width;
        this.scene_height = (float)height;
    }

    public void animate_score (int points)
    {
        if (points <= 0)
            return;

        label.set_font_name ("Bitstrem Vera Sans Bold 40");
        label.set_text ("+" + points.to_string());

        /* The score will be shown repeatedly therefore we need to reset some important properties
         * before the actual animation */
        opacity = 255;
        depth = 0;

        var a = animate (Clutter.AnimationMode.EASE_OUT_SINE, 600, "depth", 500.0, "opacity", 0);
        a.timeline.completed.connect (() => { destroy (); });
    }

    public void animate_final_score (uint points)
    {
        label.set_font_name ("Bitstrem Vera Sans 50");
        var points_label = ngettext (/* Label showing the number of points at the end of the game */
                                     "%u point", "%u points", points).printf (points);
        label.set_markup ("<b>%s</b>\n%s".printf (_("Game Over!"), points_label));
        label.set_line_alignment (Pango.Alignment.CENTER);

        /* The score will be shown repeatedly therefore we need to reset some important properties
         * before the actual animation */
        opacity = 255;
        depth = 0;

        scale_x = scale_y = 0.0;
        float scale_to = scene_width / this.width;
        animate (Clutter.AnimationMode.EASE_OUT_ELASTIC, 2000, scale_x: scale_to, scale_y: scale_to, opacity: 255);
    }
}
