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
 *  This is the model layer of a tile.
 */
private class Tile : Object
{
    /* Property */
    private bool _closed = false;
    internal bool closed
    {
        internal get { return _closed; }
        private set
        {
            _closed = value;
            /* Send close signal */
            if (_closed)
                close (grid_x, grid_y);
        }
    }

    internal int grid_x     { internal get; private set; }
    internal int grid_y     { internal get; private set; }
    internal int color      { internal get; private set; }
    internal bool visited   { internal get; private set; default = false; }

    /* Signals */
    internal signal void move (int old_x, int old_y, int new_x, int new_y);
    internal signal void close (int grid_x, int grid_y);

    /* Constructor */
    internal Tile (int x, int y, int c)
    {
        grid_x = x;
        grid_y = y;
        color  = c;
    }

    /* Do not use this mothod to initialize the position. */
    internal void update_position (int new_x, int new_y)
    {
        var old_x = grid_x;
        var old_y = grid_y;

        if ((new_x != old_x) || (new_y != old_y))
        {
            grid_x = new_x;
            grid_y = new_y;

            /* Send move signal to actor in the view */
            if (!closed)
                move (old_x, old_y, new_x, new_y);
        }
    }
}

/**
 *  This is the model layer of the whole game. All game logic goes here. This class tries not to
 *  bring in any visual stuff to comply the separation of view-model idea.
 */
private class Game : Object
{
    private Tile[,] tiles;
    private bool is_started = false;

    /* Game score */
    internal int score { internal get; private set; default = 0; }

    private int _color_num = 3;
    public int color_num
    {
        internal get { return _color_num; }
        protected construct set     // TODO should be doable to make construct only again
        {
            if (value < 2 || value > 4)
                _color_num = 3;
            else
                _color_num = value;
        }
    }

    /* Property */
    public int rows       { internal get; protected construct; default = 8; }
    public int columns    { internal get; protected construct; default = 8; }

    internal signal void update_score (int points_awarded);
    internal signal void complete ();
    internal signal void started ();

    /* Constructor */
    internal Game (int rows, int columns, int color_num, Variant? variant = null)
    {
        Object (rows: rows, columns: columns, color_num: color_num);
        if (variant == null || !load_saved_game ((!) variant))
            create_new_game ();
    }

    private inline void create_new_game ()
    {
        /* A 2D array holds all tiles */
        tiles = new Tile [rows, columns];

        for (var x = 0; x < columns; x++)
        {
            for (var y = 0; y < rows; y++)
            {
                int c = (int) Math.floor (Random.next_double () * color_num);
                tiles[y, x] = new Tile (x, y, c);
            }
        }

        is_started = false;
    }

    /* Recursively find all the connected tile from li */
    private List<Tile> _connected_tiles (Tile? li)
    {
        var cl = new List<Tile> ();

        if (li.visited || li.closed)
            return cl;

        var x = li.grid_x;
        var y = li.grid_y;

        li.visited = true;

        cl.append (li);

        if ((y + 1) < rows && tiles[y + 1, x] != null && (li.color == tiles[y + 1, x].color))
            cl.concat (_connected_tiles (tiles[y + 1, x]));

        if ((y - 1) >= 0 && tiles[y - 1, x] != null && (li.color == tiles[y - 1, x].color))
            cl.concat (_connected_tiles (tiles[y - 1, x]));

        if ((x + 1) < columns && tiles[y, x + 1] != null && (li.color == tiles[y, x + 1].color))
            cl.concat (_connected_tiles (tiles[y, x + 1]));

        if ((x - 1) >= 0 && tiles[y, x - 1] != null && (li.color == tiles[y, x - 1].color))
            cl.concat (_connected_tiles (tiles[y, x - 1]));

        return cl;
    }

    internal List<Tile> connected_tiles (Tile li)
    {
        foreach (var l in tiles)
        {
            if (l != null)
                l.visited = false;
        }

        List<Tile> cl = _connected_tiles (li);

        /* single tile will be ignored */
        if (cl.length () < 2)
            cl = null;

        return cl;
    }

    internal Tile get_tile (int x, int y)
    {
        return tiles[y, x];
    }

    internal bool remove_connected_tiles (Tile tile)
    {
        List<Tile> cl = connected_tiles (tile);

        if (cl == null)
            return false;

        foreach (var l in cl)
            l.closed = true;

        int new_x = 0;

        for (int x = 0; x < columns; x++)
        {
            var not_closed_tiles = new List<Tile> ();
            var closed_tiles = new List<Tile> ();

            /* for each column, separate not-closed and closed tiles */
            for (int y = 0; y < rows; y++)
            {
                var li = tiles[y, x];

                if (li == null)
                    break;

                if (li.closed)
                    closed_tiles.append (li);
                else
                    not_closed_tiles.append (li);
            }

            /* append closed tiles to not-closed tiles */
            not_closed_tiles.concat ((owned) closed_tiles);

            /* update tile array at the current column, not-closed tiles aret at the bottom, closed ones top */
            for (int y = 0; y < rows; y++)
                tiles[y, new_x] = not_closed_tiles.nth_data (y);

            /* flag to check if current column is empty */
            var has_empty_col = true;

            /* update the positions (grid_x, grid_y) of tiles at the current column */
            for (int y = 0; y < rows; y++)
            {
                var l = tiles[y, new_x];

                if (l == null)
                    break;

                l.update_position (new_x, y);

                if (!l.closed)
                    has_empty_col = false;
            }

            /* If the current column is empty, don't increment new_x. Otherwise increment */
            if (!has_empty_col)
                new_x++;
        }

        /* The remaining columns are do-not-cares. Assign null to them */
        for (; new_x < columns; new_x++)
            for (int y = 0; y < rows; y++)
                tiles[y, new_x] = null;

        increment_score_from_tiles ((int)cl.length ());

        if (!is_started) {
            is_started = true;
            started ();
        }

        if (this.has_completed ())
        {
            if (this.has_won ())
                increment_score (1000);
            complete ();
        }

        return false;
    }

    internal void reset_visit ()
    {
        foreach (var l in tiles)
        {
            if (l != null)
                l.visited = false;
        }
    }

    internal bool has_completed ()
    {
        foreach (var l in tiles)
        {
            if (l != null && !l.closed && (connected_tiles (l).length () > 1))
                return false;
        }

        return true;
    }

    internal bool has_won ()
    {
        foreach (var l in tiles)
        {
            if (l != null && !l.closed)
                return false;
        }

        return true;
    }

    internal void increment_score_from_tiles (int n_tiles)
    {
        var points_awarded = 0;

        if (n_tiles >= 3)
            points_awarded = (n_tiles - 2) * (n_tiles - 2);

        increment_score (points_awarded);
    }

    internal void increment_score (int increment)
    {
        score += increment;
        update_score (increment);
    }

    /*\
    * * loading and saving
    \*/

    private inline bool load_saved_game (Variant variant)
    {
        if (variant.get_type_string () != "m(yqaay)")
            return false;   // assert_not_reached() ?

        Variant? child = variant.get_maybe ();
        if (child == null)
            return false;

        VariantIter iter = new VariantIter ((!) child);
        uint8 color_num;
        uint16 score;
        iter.next ("y", out color_num);
        iter.next ("q", out score);
        Variant tmp_variant = iter.next_value ();

        if (color_num < 2 || color_num > 4)
            return false;

        // all the following way to extract values feels horrible, but there is a bug when trying to do it properly (05/2020)
        Variant tmp_variant_2 = tmp_variant.get_child_value (0);
        uint rows = (uint) tmp_variant.n_children ();
        uint columns = (uint) tmp_variant_2.n_children ();
        if (rows    != this.rows
         || columns != this.columns)
            return false;

        this.color_num = color_num;
        this.score = score;
        update_score (score);
        tiles = new Tile [rows, columns];
        for (uint8 i = 0; i < rows; i++)
        {
            tmp_variant_2 = tmp_variant.get_child_value (i);
            for (uint8 j = 0; j < columns; j++)
            {
                Variant tmp_variant_3 = tmp_variant_2.get_child_value (j);
                uint8 color = tmp_variant_3.get_byte ();
                if (color == 0)
                {
                    tiles [rows - i - 1, j] = new Tile (j, (int) (rows - i - 1), 0);
                    tiles [rows - i - 1, j].closed = true;
                }
                else
                    tiles [rows - i - 1, j] = new Tile (j, (int) (rows - i - 1), color - 1);
            }
        }
        is_started = true;
        return true;
    }

    internal Variant get_saved_game ()
    {
        if (!is_started || has_completed ())
            return new Variant ("m(yqaay)", null);

        VariantBuilder builder = new VariantBuilder (new VariantType ("(yqaay)"));
        builder.add ("y", (uint8) color_num);
        builder.add ("q", (uint16) score);
        builder.open (new VariantType ("aay"));
        VariantType ay_type = new VariantType ("ay");
        for (uint8 i = (uint8) rows; i > 0; i--)
        {
            builder.open (ay_type);
            for (uint8 j = 0; j < columns; j++)
                if (tiles [i - 1, j] == null || ((!) tiles [i - 1, j]).closed)
                    builder.add ("y", 0);
                else
                    builder.add ("y", tiles [i - 1, j].color + 1);
            builder.close ();
        }
        builder.close ();
        return new Variant.maybe (null, builder.end ());
    }
}
