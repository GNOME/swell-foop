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

    public uint8 grid_x   { internal get; protected construct set; }
    public uint8 grid_y   { internal get; protected construct set; }
    public uint8 color    { internal get; protected construct; }    /* 1 <= color <= 4 */
    // Vala tip or bug: looks like "private" means "accessible only from this file"; but if both get and set are private, there is a warning
    internal bool visited { protected get; private set; default = false; }

    /* Signals */
    internal signal void move (uint8 old_x, uint8 old_y, uint8 new_x, uint8 new_y);
    internal signal void close (uint8 grid_x, uint8 grid_y);

    /* Constructor */
    internal Tile (uint8 x, uint8 y, uint8 c)
    {
        Object (grid_x: x, grid_y: y, color: c);
    }

    /* Do not use this mothod to initialize the position. */
    internal void update_position (uint8 new_x, uint8 new_y)
    {
        uint8 old_x = grid_x;
        uint8 old_y = grid_y;

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
    private Tile? [,] tiles;
    private bool is_started = false;

    /* Game score */
    internal uint score { internal get; private set; default = 0; }

    private uint8 _color_num = 3;
    public uint8 color_num
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
    public uint8 rows       { internal get; protected construct; }
    public uint8 columns    { internal get; protected construct; }

    internal signal void update_score (uint points_awarded);
    internal signal void complete ();
    internal signal void started ();

    /* Constructor */
    internal Game (uint8 rows, uint8 columns, uint8 color_num, Variant? variant = null)
    {
        Object (rows: rows, columns: columns, color_num: color_num);
        if (variant == null || !load_saved_game ((!) variant))
            create_new_game ();
    }

    private inline void create_new_game ()
    {
        /* A 2D array holds all tiles */
        tiles = new Tile? [rows, columns];

        for (uint8 x = 0; x < columns; x++)
        {
            for (uint8 y = 0; y < rows; y++)
            {
                uint8 c = (uint8) Math.floor (Random.next_double () * color_num) + 1;
                tiles[y, x] = new Tile (x, y, c);
            }
        }

        is_started = false;
    }

    /* Recursively find all the connected tile from given_tile */
    private static List<Tile> _connected_tiles (Tile? given_tile, ref Tile? [,] tiles)
    {
        List<Tile> cl = new List<Tile> ();

        if (given_tile == null || ((!) given_tile).visited || ((!) given_tile).closed)
            return cl;

        uint8 x = ((!) given_tile).grid_x;
        uint8 y = ((!) given_tile).grid_y;

        ((!) given_tile).visited = true;

        cl.append ((!) given_tile);

        unowned Tile? tile = tiles[y + 1, x];
        if (y + 1 < tiles.length [0]
         && tile != null && (((!) given_tile).color == ((!) tile).color))
            cl.concat (_connected_tiles (tile, ref tiles));

        if (y >= 1)
        {
            tile = tiles[y - 1, x];
            if (tile != null && (((!) given_tile).color == ((!) tile).color))
                cl.concat (_connected_tiles (tile, ref tiles));
        }

        tile = tiles[y, x + 1];
        if (x + 1 < tiles.length [1]
         && tile != null && (((!) given_tile).color == ((!) tile).color))
            cl.concat (_connected_tiles (tile, ref tiles));

        if (x >= 1)
        {
            tile = tiles[y, x - 1];
            if (tile != null && (((!) given_tile).color == ((!) tile).color))
                cl.concat (_connected_tiles (tile, ref tiles));
        }

        return cl;
    }

    internal List<Tile> connected_tiles (Tile given_tile)
    {
        List<Tile> cl = _connected_tiles (given_tile, ref tiles);

        foreach (unowned Tile? tile in tiles)
        {
            if (tile != null)
                ((!) tile).visited = false;
        }

        /* single tile will be ignored */
        if (cl.length () < 2)
            return new List<Tile> ();   // technically similar to null, but clearer from Vala pov

        return cl;
    }

    internal Tile? get_tile (uint8 x, uint8 y)
    {
        return tiles[y, x];
    }

    internal bool remove_connected_tiles (Tile given_tile)
    {
        List<Tile> cl = connected_tiles (given_tile);

        if (cl.length () < 2)
            return false;

        foreach (unowned Tile tile in (!) cl)
            tile.closed = true;

        uint8 new_x = 0;

        for (uint8 x = 0; x < columns; x++)
        {
            List<Tile> not_closed_tiles = new List<Tile> ();
            List<Tile> closed_tiles     = new List<Tile> ();

            /* for each column, separate not-closed and closed tiles */
            for (uint8 y = 0; y < rows; y++)
            {
                unowned Tile? tile = tiles[y, x];

                if (tile == null)
                    break;

                if (((!) tile).closed)
                    closed_tiles.append ((!) tile);
                else
                    not_closed_tiles.append ((!) tile);
            }

            /* append closed tiles to not-closed tiles */
            not_closed_tiles.concat ((owned) closed_tiles);

            /* update tile array at the current column, not-closed tiles are at the bottom, closed ones top */
            for (uint8 y = 0; y < rows; y++)
                tiles[y, new_x] = not_closed_tiles.nth_data (y);

            /* flag to check if current column is empty */
            bool has_empty_col = true;

            /* update the positions (grid_x, grid_y) of tiles at the current column */
            for (uint8 y = 0; y < rows; y++)
            {
                unowned Tile? tile = tiles[y, new_x];

                if (tile == null)
                    break;

                ((!) tile).update_position (new_x, y);

                if (!((!) tile).closed)
                    has_empty_col = false;
            }

            /* If the current column is empty, don't increment new_x. Otherwise increment */
            if (!has_empty_col)
                new_x++;
        }

        /* The remaining columns are do-not-cares. Assign null to them */
        for (; new_x < columns; new_x++)
            for (uint8 y = 0; y < rows; y++)
                tiles[y, new_x] = null;

        increment_score_from_tiles ((uint16) cl.length ());

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

    private bool has_completed ()
    {
        foreach (unowned Tile? tile in tiles)
        {
            if (tile != null && !((!) tile).closed && (connected_tiles ((!) tile).length () > 1))
                return false;
        }

        return true;
    }

    private inline bool has_won ()
    {
        foreach (unowned Tile? tile in tiles)
        {
            if (tile != null && !((!) tile).closed)
                return false;
        }

        return true;
    }

    private void increment_score_from_tiles (uint16 n_tiles)
    {
        uint points_awarded = 0;

        if (n_tiles >= 3)
            points_awarded = (uint) (n_tiles - 2) * (uint) (n_tiles - 2);

        increment_score (points_awarded);
    }

    private void increment_score (uint increment)
    {
        score += increment;
        update_score (increment);
    }

    /*\
    * * loading and saving
    \*/

    private inline bool load_saved_game (Variant variant)
    {
        if (variant.get_type_string () != "m(yuaay)")
            return false;   // assert_not_reached() ?

        Variant? child = variant.get_maybe ();
        if (child == null)
            return false;

        VariantIter iter = new VariantIter ((!) child);
        uint8 color_num;
        uint score;
        iter.next ("y", out color_num);
        iter.next ("u", out score);
        Variant? tmp_variant = iter.next_value ();
        if (tmp_variant == null)
            assert_not_reached ();

        if (color_num < 2 || color_num > 4)
            return false;

        // all the following way to extract values feels horrible, but there is a bug when trying to do it properly (05/2020)
        Variant tmp_variant_2 = ((!) tmp_variant).get_child_value (0);
        uint rows = (uint) ((!) tmp_variant).n_children ();
        uint columns = (uint) tmp_variant_2.n_children ();
        if (rows    != this.rows
         || columns != this.columns)
            return false;

        Tile? [,] tiles = new Tile? [rows, columns];
        for (uint8 i = 0; i < rows; i++)
        {
            tmp_variant_2 = ((!) tmp_variant).get_child_value (i);
            for (uint8 j = 0; j < columns; j++)
            {
                Variant tmp_variant_3 = tmp_variant_2.get_child_value (j);
                uint8 color = tmp_variant_3.get_byte ();
                if (color > 4)
                    return false;
                if (color == 0)
                    tiles [rows - i - 1, j] = null;
                else
                    tiles [rows - i - 1, j] = new Tile (j, (uint8) (rows - i - 1), color);
            }
        }

        this.tiles = tiles;
        this.color_num = color_num;
        this.score = score;
        update_score (score);
        is_started = true;
        return true;
    }

    internal Variant get_saved_game ()
    {
        if (!is_started || has_completed ())
            return new Variant ("m(yuaay)", null);

        VariantBuilder builder = new VariantBuilder (new VariantType ("(yuaay)"));
        builder.add ("y", color_num);
        builder.add ("u", score);
        builder.open (new VariantType ("aay"));
        VariantType ay_type = new VariantType ("ay");
        for (uint8 i = rows; i > 0; i--)
        {
            builder.open (ay_type);
            for (uint8 j = 0; j < columns; j++)
            {
                unowned Tile? tile = tiles [i - 1, j];
                if (tile == null || ((!) tile).closed)
                    builder.add ("y", 0);
                else
                    builder.add ("y", ((!) tile).color);
            }
            builder.close ();
        }
        builder.close ();
        return new Variant.maybe (null, builder.end ());
    }
}
